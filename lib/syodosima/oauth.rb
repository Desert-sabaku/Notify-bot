require "fileutils"

# OAuth helper functions
#
# Contains helpers for performing Google OAuth interactive flows and
# for starting a local HTTP server to receive the callback during
# user authorization. These are extracted from the main module to
# keep the top-level module concise.
module Syodosima
  # Perform OAuth authorization and return credentials
  #
  # @return [Google::Auth::UserRefreshCredentials] the OAuth credentials
  # @raise [String] if authorization fails in CI or other environments
  def self.authorize
    client_id, token_store = client_id_and_token_store
    authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
    user_id = "default"

    begin
      credentials = authorizer.get_credentials(user_id)
    rescue StandardError => e
      # Some environments may raise a PStore::Error when the token file is corrupted.
      # Avoid requiring the pstore library; detect by class name instead.
      raise unless e.is_a?(::PStore::Error)

      logger.warn(MessageConstants.corrupted_token_log(TOKEN_PATH, e.class, e.message))

      # In CI, do not attempt deletion or interactive auth; surface a clear error.
      raise MessageConstants::AUTH_FAILED_CI if ENV["CI"] || ENV["GITHUB_ACTIONS"]

      handle_corrupted_token
      # Retry once after cleanup
      client_id, token_store = client_id_and_token_store
      authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
      credentials = authorizer.get_credentials(user_id)
    end

    return credentials unless credentials.nil?

    # perform interactive authorization flow (extracted to reduce complexity)
    interactive_auth_flow(authorizer, user_id)
  end

  # Handle corrupted token file by backing up and deleting
  #
  # @return [void]
  def self.handle_corrupted_token
    return unless File.exist?(TOKEN_PATH)

    begin
      ts = Time.now.utc.strftime("%Y%m%d%H%M%S")
      backup = "#{TOKEN_PATH}.#{ts}.bak"
      begin
        File.rename(TOKEN_PATH, backup)
        logger.warn("#{MessageConstants::BACKUP_CREATED} #{backup}")
      rescue StandardError
        FileUtils.cp(TOKEN_PATH, backup)
        logger.warn("#{MessageConstants::BACKUP_COPIED} #{backup}")
        File.delete(TOKEN_PATH)
      end
    rescue StandardError => e
      logger.warn(MessageConstants.backup_failed_log(TOKEN_PATH, e.message))
    end
  end

  # Extracted interactive auth flow to reduce method complexity
  #
  # @param [Google::Auth::UserAuthorizer] authorizer the OAuth authorizer
  # @param [String] user_id the user ID
  # @return [Google::Auth::UserRefreshCredentials] the OAuth credentials
  # @raise [String] if authorization fails
  def self.interactive_auth_flow(authorizer, user_id)
    raise MessageConstants::AUTH_FAILED_CI if ENV["CI"] || ENV["GITHUB_ACTIONS"]

    raise MessageConstants::AUTH_FAILED_NO_METHOD unless authorizer.respond_to?(:get_authorization_url)

    port = oauth_port
    redirect_uri = redirect_uri_for_port(port)

    _server, code_container, server_thread = start_oauth_server(port)

    auth_url = authorizer.get_authorization_url(base_url: redirect_uri)
    logger.info(MessageConstants::BROWSER_AUTH_PROMPT)
    logger.info(auth_url)
    logger.info(MessageConstants.oauth_callback_info(port))

    open_auth_url(auth_url)

    server_thread.join

    code = code_container[:code]
    raise MessageConstants::AUTH_CODE_NOT_RECEIVED if code.nil? || code.to_s.strip.empty?

    begin
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id,
        code: code,
        base_url: redirect_uri
      )
    rescue StandardError => e
      raise MessageConstants.auth_code_exchange_error(e.message)
    end

    credentials
  end

  # Get the OAuth port from environment or default
  #
  # @return [Integer] the port number
  def self.oauth_port
    (ENV["OAUTH_PORT"] || "8080").to_i
  end

  # Generate redirect URI for the given port
  #
  # @param [Integer] port the port number
  # @return [String] the redirect URI
  def self.redirect_uri_for_port(port)
    "http://127.0.0.1:#{port}/oauth2callback"
  end

  # Helper: create client id and token store
  #
  # @return [Array<Google::Auth::ClientId, Google::Auth::Stores::FileTokenStore>] [client_id, token_store]
  def self.client_id_and_token_store
    client_id = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
    [client_id, token_store]
  end

  # Helper: start oauth HTTP server and return [server, code_container, thread]
  #
  # @param [Integer] port the port to listen on
  # @return [Array<WEBrick::HTTPServer, Hash, Thread>] [server, code_container, server_thread]
  def self.start_oauth_server(port)
    code_container = { code: nil }

    server = create_webrick_server(port)
    # create a handler that closes over the server so it can shut it down
    mounted_handler = oauth_request_handler(code_container, server)
    server.mount_proc "/oauth2callback", &mounted_handler
    server.mount_proc "/auth/callback", &mounted_handler

    server_thread = Thread.new do
      server.start
    rescue StandardError => e
      warn MessageConstants.webrick_error(e.message)
    end

    [server, code_container, server_thread]
  end

  # Create WEBrick server with minimal logging (extracted for clarity)
  #
  # @param [Integer] port the port to listen on
  # @return [WEBrick::HTTPServer] the configured server
  def self.create_webrick_server(port)
    WEBrick::HTTPServer.new(Port: port, Logger: WEBrick::Log.new(IO::NULL), AccessLog: [])
  end

  # Return a proc that handles oauth callback requests and stores the code
  #
  # @param [Hash] code_container hash to store the authorization code
  # @param [WEBrick::HTTPServer] server the WEBrick server to shutdown
  # @return [Proc] the request handler proc
  def self.oauth_request_handler(code_container, server)
    proc do |req, res|
      q = URI.decode_www_form(req.query_string || "").to_h
      code_container[:code] = q["code"] || req.query["code"]
      res.body = MessageConstants::AUTH_SUCCESS_HTML
      res.content_type = "text/html; charset=utf-8"
      Thread.new { server.shutdown }
    end
  end

  # Helper: try to open auth URL in browser (best-effort)
  #
  # @param [String] auth_url the authorization URL to open
  # @return [void]
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
    logger.warn(MessageConstants::BROWSER_AUTO_OPEN_FAILED)
    logger.warn(auth_url)
  end
end
