# Message constants for Syodosima
#
# Centralized error messages, log messages, and user-facing text
# to ensure consistency between implementation and tests.
module Syodosima
  # Message constants module
  #
  # Contains all user-facing and log messages as frozen constants
  # to maintain consistency across the codebase and tests.
  module Messages
    # OAuth and authentication error messages
    AUTH_FAILED_CI = <<~AFC.freeze
      Google認証に失敗しました。CI 上では対話認証ができませんので、
      ローカルで一度認証を通し、token.yaml を Secret (GOOGLE_TOKEN_YAML) に登録してください。
    AFC
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
    def self.oauth_callback_info(port)
      "このプロセスは 127.0.0.1:#{port} でコールバックを待ち受けます。（PATH: /oauth2callback または /auth/callback）"
    end

    def self.corrupted_token_log(token_path, error_class, error_message)
      "#{CORRUPTED_TOKEN_DETECTED} (#{token_path}): #{error_class}: #{error_message}"
    end

    def self.auth_code_exchange_error(message)
      "#{AUTH_CODE_EXCHANGE_FAILED}: #{message}"
    end

    def self.backup_failed_log(token_path, error_message)
      "#{BACKUP_FAILED} #{token_path}: #{error_message}"
    end
  end
end
