require_relative "syodosima/version"

require "bundler/setup"
require "google/apis/calendar_v3"
require "googleauth"
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
  require_relative "syodosima/message_constants"
  require_relative "syodosima/memory_token_store"
  require_relative "syodosima/oauth"
  require_relative "syodosima/discord"
  require_relative "syodosima/message_builder"

  # Validate required environment variables and configuration constants
  #
  # @return [void]
  # @raise [SystemExit] if required environment variables are missing
  def self.validate_env!
    missing = REQUIRED_ENV_VARS.select { |k, _| ENV[k].nil? || ENV[k].empty? }
    return if missing.empty?

    msg = MessageConstants::ENV_MISSING_PREFIX
    missing.each do |key, desc|
      msg += MessageConstants.env_missing_item(key, desc)
    end
    msg += MessageConstants::ENV_MISSING_SUFFIX
    abort msg
  end

  # Fetch today's events from Google Calendar
  #
  # @return [Array<Google::Apis::CalendarV3::Event>] list of today's events
  def self.fetch_today_events
    fetch_events(Date.today)
  end

  # Fetch events from Google Calendar for a specific date
  #
  # @param [Date] date the date to fetch events for
  # @return [Array<Google::Apis::CalendarV3::Event>] list of events for the specified date
  def self.fetch_events(date)
    service = Google::Apis::CalendarV3::CalendarService.new
    service.client_options.application_name = APPLICATION_NAME
    service.authorization = authorize

    time_min, time_max = time_window(date)

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
    time_window(Date.today)
  end

  # Compute RFC3339 time_min/time_max for a specific date according to TIMEZONE_OFFSET
  #
  # @param [Date] date the date to compute the time window for
  # @return [Array<String>] [time_min, time_max] in RFC3339 format
  def self.time_window(date)
    timezone_offset = ENV.fetch("TIMEZONE_OFFSET", "+09:00")
    time_min = DateTime.new(date.year, date.month, date.day, 0, 0, 0, timezone_offset).rfc3339
    time_max = DateTime.new(date.year, date.month, date.day, 23, 59, 59, timezone_offset).rfc3339
    [time_min, time_max]
  end

  # Main entry point to run the notification process
  #
  # @param [Date, nil] date the date to fetch events for (defaults to today)
  # @return [void]
  def self.run(date = nil)
    validate_env!

    target_date = date || Date.today
    logger.info(MessageConstants.log_fetching_events(target_date))
    events = fetch_events(target_date)

    message = build_message(events, target_date)

    logger.info(MessageConstants::LOG_SENDING_DISCORD)
    send_discord_message(message)
    logger.info(MessageConstants::LOG_COMPLETED)
  end
end
