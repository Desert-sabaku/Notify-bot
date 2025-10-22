# Logger helpers for Syodosima.
#
# This module configures and exposes a module-level logger instance
# which is driven by the environment variables:
# - LOG_LEVEL (DEBUG/INFO/WARN/ERROR)
# - LOG_OUTPUT (stdout/stderr/file path)
# - LOG_FORMAT (text/json)
#
# The logger is used across the application for consistent output
# and is safe to override in tests via `Syodosima.logger=`.
module Syodosima
  require "logger"

  # Module-level logger. Configurable via environment variables for CI.
  # LOG_LEVEL: DEBUG/INFO/WARN/ERROR/FATAL/UNKNOWN (default INFO, or WARN in CI)
  # LOG_OUTPUT: stdout|stderr|/path/to/file (default stdout)
  # LOG_FORMAT: text|json (default text)

  output = ENV.fetch("LOG_OUTPUT", "stdout")
  logger_output = case output.downcase
                  when "stdout"
                    $stdout
                  when "stderr"
                    $stderr
                  else
                    # treat as file path
                    output
                  end
  @logger = Logger.new(logger_output)

  # Default log level based on environment
  default_level = ENV["CI"] || ENV["GITHUB_ACTIONS"] ? Logger::WARN : Logger::INFO

  # Set log level from environment or use default
  env_level = ENV["LOG_LEVEL"]&.upcase
  @logger.level = if env_level && Logger.const_defined?(env_level)
                    Logger.const_get(env_level)
                  else
                    default_level
                  end

  # Formatter: text or json
  format = ENV.fetch("LOG_FORMAT", "text").downcase
  if format == "json"
    require "json"
    @logger.formatter = proc do |severity, datetime, _progname, msg|
      "#{{ timestamp: datetime.iso8601, app: Syodosima::APPLICATION_NAME, level: severity, message: msg }.to_json}\n"
    end
  else
    @logger.formatter = proc do |severity, datetime, _progname, msg|
      timestamp = datetime.iso8601
      "#{timestamp} [#{Syodosima::APPLICATION_NAME}] #{severity} -- : #{msg}\n"
    end
  end

  def self.logger
    @logger
  end

  def self.logger=(val)
    @logger = val
  end
end
