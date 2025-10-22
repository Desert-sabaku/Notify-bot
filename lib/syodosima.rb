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
  require_relative "syodosima/oauth"
  require_relative "syodosima/discord"
  require_relative "syodosima/message"

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

  def self.write_credential_files!
    write_env_file("GOOGLE_CREDENTIALS_JSON", CREDENTIALS_PATH)
    write_env_file("GOOGLE_TOKEN_YAML", TOKEN_PATH)
  end

  # Helper to write an environment variable content to a file with restrictive perms.
  def self.write_env_file(env_key, path)
    v = ENV[env_key]
    return if v.to_s.strip == ""

    File.open(path, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
      file.write(v)
    end
    CREATED_FILES << path
  end

  at_exit do
    if ENV["CI"] || ENV["GITHUB_ACTIONS"]
      CREATED_FILES.each do |file|
        File.delete(file) if File.exist?(file)
      rescue StandardError => e
        @logger.warn("Warning: Failed to cleanup #{file}: #{e.message}")
      end
    end
  end

  # OAuth helpers (authorize, interactive flow, and local callback server)
  # are implemented in `lib/syodosima/oauth.rb` and required above.

  # Helper: try to open auth URL in browser (best-effort)
  def self.open_auth_url(auth_url)
    host_os = RbConfig::CONFIG["host_os"]
    case host_os
    when /linux|bsd/
      system("xdg-open", auth_url)
    when /darwin/
      system("open", auth_url)
    when /mswin|mingw|cygwin/
      system("cmd", "/c", "start", "", auth_url)
    end
  rescue StandardError
    logger.warn("ブラウザを自動で開けませんでした。URLを手動で開いてください：")
    logger.warn(auth_url)
  end

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
  def self.today_time_window
    timezone_offset = ENV.fetch("TIMEZONE_OFFSET", "+09:00")
    now_tz = DateTime.now.new_offset(timezone_offset)
    today = now_tz.to_date
    time_min = DateTime.new(today.year, today.month, today.day, 0, 0, 0, timezone_offset).rfc3339
    time_max = DateTime.new(today.year, today.month, today.day, 23, 59, 59, timezone_offset).rfc3339
    [time_min, time_max]
  end

  # Discord helpers (bot lifecycle and message delivery) are implemented
  # in `lib/syodosima/discord.rb`.

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

  # message builders moved to `lib/syodosima/message.rb`
end
