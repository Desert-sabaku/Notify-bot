require_relative "syodosima/version"

require "bundler/setup"
require "google/apis/calendar_v3"
require "googleauth"
require "googleauth/stores/file_token_store"
require "fileutils"
require "discordrb"
require "date"
require "dotenv/load"
require "rbconfig"
require "webrick"
require "uri"

# Syodosima integrates Google Calendar with Discord to send daily event notifications
module Syodosima
  class Error < StandardError; end

  # Validate required environment variables and configuration constants
  require_relative "syodosima/config"
  require_relative "syodosima/logger"
  require_relative "syodosima/messages"
  require_relative "syodosima/oauth"
  require_relative "syodosima/discord"
  require_relative "syodosima/message"

  # Validate required environment variables and configuration constants
  #
  # @return [void]
  # @raise [SystemExit] if required environment variables are missing
  def self.validate_env!
    missing = REQUIRED_ENV_VARS.select { |k, _| ENV[k].nil? || ENV[k].empty? }
    return if missing.empty?

    msg = "Missing required environment variable(s):\n"
    missing.each do |key, desc|
      msg += "  - #{key}: #{desc}\n"
    end
    msg += "\nPlease set these variables in your .env file or environment."
    abort msg
  end

  # Write credential files from environment variables#
  #
  # @return [void]
  def self.write_credential_files!
    write_env_file("GOOGLE_CREDENTIALS_JSON", CREDENTIALS_PATH)
    write_env_file("GOOGLE_TOKEN_YAML", TOKEN_PATH)
  end

  # Helper to write an environment variable content to a file with restrictive perms.
  #
  # @param [String] env_key the environment variable key
  # @param [String] path the file path to write to
  # @return [void]
  def self.write_env_file(env_key, path)
    v = ENV[env_key]
    return if v.to_s.strip == ""

    FileUtils.mkdir_p(File.dirname(path))
    File.open(path, File::WRONLY | File::CREAT | File::TRUNC, 0o600) { |f| f.write(v) }
    created_files << path
  end

  # Register at_exit handler only in CI environments
  if ENV["CI"] || ENV["GITHUB_ACTIONS"]
    at_exit do
      created_files.each do |file|
        File.delete(file) if File.exist?(file)
      rescue StandardError => e
        warn "Warning: Failed to cleanup #{file}: #{e.message}"
      end
    end
  end

  # Fetch today's events from Google Calendar
  #
  # @return [Array<Google::Apis::CalendarV3::Event>] list of today's events
  def self.fetch_today_events
    service = Google::Apis::CalendarV3::CalendarService.new
    service.client_options.application_name = APPLICATION_NAME
    service.authorization = authorize

    time_min, time_max = today_time_window

    events = service.list_events(
      "primary",
      single_events: true,
      order_by: "startTime",
      time_min: time_min,
      time_max: time_max
    )
    events.items
  end

  # Compute RFC3339 time_min/time_max for today according to TIMEZONE_OFFSET
  #
  # @return [Array<String>] [time_min, time_max] in RFC3339 format
  def self.today_time_window
    timezone_offset = ENV.fetch("TIMEZONE_OFFSET", "+09:00")
    now_tz = DateTime.now.new_offset(timezone_offset)
    today = now_tz.to_date
    time_min = DateTime.new(today.year, today.month, today.day, 0, 0, 0, timezone_offset).rfc3339
    time_max = DateTime.new(today.year, today.month, today.day, 23, 59, 59, timezone_offset).rfc3339
    [time_min, time_max]
  end

  # Main entry point to run the notification process
  #
  # @return [void]
  def self.run
    validate_env!
    write_credential_files!

    logger.info("今日の予定を取得しています...")
    events = fetch_today_events

    message = build_message(events)

    logger.info("Discordに通知を送信します...")
    send_discord_message(message)
    logger.info("完了しました！")
  end
end
