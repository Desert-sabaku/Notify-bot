# Message constants for Syodosima
#
# Centralized error messages, log messages, and user-facing text
# to ensure consistency between implementation and tests.
module Syodosima
  # Message constants module
  #
  # Contains all user-facing and log messages as frozen constants
  # to maintain consistency across the codebase and tests.
  module MessageConstants
    # Environment validation messages
    ENV_MISSING_PREFIX = "Missing required environment variable(s):\n".freeze
    ENV_MISSING_ITEM_FORMAT = "  - %s: %s\n".freeze
    ENV_MISSING_SUFFIX = "\nPlease set these variables in your .env file or environment.".freeze

    # Log messages
    LOG_FETCHING_EVENTS = "今日の予定を取得しています...".freeze
    LOG_SENDING_DISCORD = "Discordに通知を送信します...".freeze
    LOG_COMPLETED = "完了しました！".freeze

    # Discord messages
    DISCORD_MESSAGE_NIL_EMPTY = "Message cannot be nil or empty".freeze
    DISCORD_FAILED_SEND_FORMAT = "Failed to send Discord message: %s".freeze
    DISCORD_BOT_READY = "Bot is ready!".freeze
    DISCORD_FAILED_SEND_MESSAGE_FORMAT = "Failed to send message: %s".freeze
    DISCORD_DELIVERY_FAILED = "Message delivery failed".freeze
    DISCORD_MESSAGE_SENT = "Message sent and bot stopped.".freeze

    # Message builder messages
    MESSAGE_NO_EVENTS = "おはようございます！\n今日の予定はありません。".freeze
    MESSAGE_WITH_EVENTS_PREFIX = "おはようございます！\n今日の予定をお知らせします。\n\n".freeze
    EVENT_TIME_FORMAT_TEMPLATE = "【%s】 %s\n".freeze
    EVENT_ALL_DAY_FORMAT_TEMPLATE = "【終日】 %s\n".freeze

    # Logger formats
    JSON_LOG_FORMAT_TEMPLATE = '{"timestamp":"%s","app":"%s","level":"%s","message":"%s"}'.freeze
    TEXT_LOG_FORMAT_TEMPLATE = "%s [%s] %s -- : %s\n".freeze

    # OAuth messages
    WEBRICK_ERROR_FORMAT = "WEBrick server error: %s".freeze

    # OAuth and authentication error messages
    AUTH_FAILED_CI = "Google認証に失敗しました。CI 上では対話認証ができませんので、" \
                     "ローカルで一度認証を通し、token.yaml を Secret (GOOGLE_TOKEN_YAML) に登録してください。".freeze
    AUTH_FAILED_NO_METHOD = "Google認証に失敗しました。ローカルで一度認証を通し、token.yamlをSecretに登録してください。".freeze
    AUTH_CODE_EXCHANGE_FAILED = "Google認証に失敗しました（コード交換エラー）".freeze
    AUTH_CODE_NOT_RECEIVED = "認可コードが取得できませんでした。ブラウザでアクセスした際にこのプロセスが起動しているか確認してください。".freeze

    # OAuth flow information messages
    BROWSER_AUTH_PROMPT = "ブラウザで認証してください：".freeze
    BROWSER_AUTO_OPEN_FAILED = "ブラウザを自動で開けませんでした。URLを手動で開いてください：".freeze
    AUTH_SUCCESS_HTML = "<html><body><h1>認証成功！このウィンドウを閉じてください。</h1></body></html>".freeze

    # Token corruption messages
    CORRUPTED_TOKEN_DETECTED = "Detected corrupted token store".freeze
    BACKUP_CREATED = "Backed up corrupted token file to:".freeze
    BACKUP_COPIED = "Copied corrupted token file to backup:".freeze
    BACKUP_FAILED = "Failed to backup/delete corrupted token file".freeze

    # Helper methods for formatted messages
    #
    # @param [Integer] port the port number for OAuth callback
    # @return [String] formatted callback info message
    def self.oauth_callback_info(port)
      "このプロセスは 127.0.0.1:#{port} でコールバックを待ち受けます。（PATH: /oauth2callback または /auth/callback）"
    end

    # @param [String] token_path path to the token file
    # @param [Class] error_class the error class
    # @param [String] error_message the error message
    # @return [String] formatted corrupted token log message
    def self.corrupted_token_log(token_path, error_class, error_message)
      "#{CORRUPTED_TOKEN_DETECTED} (#{token_path}): #{error_class}: #{error_message}"
    end

    # @param [String] message the error message
    # @return [String] formatted auth code exchange error message
    def self.auth_code_exchange_error(message)
      "#{AUTH_CODE_EXCHANGE_FAILED}: #{message}"
    end

    # @param [String] token_path path to the token file
    # @param [String] error_message the error message
    # @return [String] formatted backup failed log message
    def self.backup_failed_log(token_path, error_message)
      "#{BACKUP_FAILED} #{token_path}: #{error_message}"
    end

    # @param [String] key environment variable key
    # @param [String] desc description
    # @return [String] formatted environment missing item
    def self.env_missing_item(key, desc)
      format(ENV_MISSING_ITEM_FORMAT, key, desc)
    end

    # @param [String] error_message the error message
    # @return [String] formatted Discord failed send message
    def self.discord_failed_send(error_message)
      DISCORD_FAILED_SEND_FORMAT % error_message
    end

    # @param [String] error_message the error message
    # @return [String] formatted Discord failed send message
    def self.discord_failed_send_message(error_message)
      DISCORD_FAILED_SEND_MESSAGE_FORMAT % error_message
    end

    # @param [String] formatted_time the formatted time string
    # @param [String] summary the event summary
    # @return [String] formatted event time message
    def self.event_time_format(formatted_time, summary)
      format(EVENT_TIME_FORMAT_TEMPLATE, formatted_time, summary)
    end

    # @param [String] summary the event summary
    # @return [String] formatted all-day event message
    def self.event_all_day_format(summary)
      EVENT_ALL_DAY_FORMAT_TEMPLATE % summary
    end

    # @param [String] timestamp the timestamp
    # @param [String] app_name the app name
    # @param [String] level the log level
    # @param [String] message the log message
    # @return [String] formatted JSON log
    def self.json_log_format(timestamp, app_name, level, message)
      format(JSON_LOG_FORMAT_TEMPLATE, timestamp, app_name, level, message)
    end

    # @param [String] timestamp the timestamp
    # @param [String] app_name the app name
    # @param [String] level the log level
    # @param [String] message the log message
    # @return [String] formatted text log
    def self.text_log_format(timestamp, app_name, level, message)
      format(TEXT_LOG_FORMAT_TEMPLATE, timestamp, app_name, level, message)
    end

    # @param [String] error_message the error message
    # @return [String] formatted WEBrick error message
    def self.webrick_error(error_message)
      WEBRICK_ERROR_FORMAT % error_message
    end
  end
end
