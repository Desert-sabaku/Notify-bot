# OAuth helper functions
#
# Contains helpers for performing Google OAuth interactive flows and
# for starting a local HTTP server to receive the callback during
# user authorization. These are extracted from the main module to
# keep the top-level module concise.
module Syodosima
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

      logger.warn(Messages.corrupted_token_log(TOKEN_PATH, e.class, e.message))

      # In CI, do not attempt deletion or interactive auth; surface a clear error.
      raise Messages::AUTH_FAILED_CI if ENV["CI"] || ENV["GITHUB_ACTIONS"]

      if File.exist?(TOKEN_PATH)
        begin
          ts = Time.now.utc.strftime("%Y%m%d%H%M%S")
          backup = "#{TOKEN_PATH}.#{ts}.bak"
          begin
            File.rename(TOKEN_PATH, backup)
            logger.warn("#{Messages::BACKUP_CREATED} #{backup}")
          rescue StandardError
            require "fileutils"
            FileUtils.cp(TOKEN_PATH, backup)
            logger.warn("#{Messages::BACKUP_COPIED} #{backup}")
            File.delete(TOKEN_PATH)
          end
        rescue StandardError => delete_err
          logger.warn(Messages.backup_failed_log(TOKEN_PATH, delete_err.message))
        end
      end

      # Recreate client_id, token store, and authorizer, then retry once
      client_id, token_store = client_id_and_token_store
      authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
      credentials = authorizer.get_credentials(user_id)

      # re-raise non-PStore errors
    end

    return credentials unless credentials.nil?

    # perform interactive authorization flow (extracted to reduce complexity)
    interactive_auth_flow(authorizer, user_id)
  end

  # Extracted interactive auth flow to reduce method complexity
  def self.interactive_auth_flow(authorizer, user_id)
    raise Messages::AUTH_FAILED_CI if ENV["CI"] || ENV["GITHUB_ACTIONS"]

    raise Messages::AUTH_FAILED_NO_METHOD unless authorizer.respond_to?(:get_authorization_url)

    port = oauth_port
    redirect_uri = redirect_uri_for_port(port)

    server, code_container, server_thread = start_oauth_server(port)

    auth_url = authorizer.get_authorization_url(base_url: redirect_uri)
    logger.info(Messages::BROWSER_AUTH_PROMPT)
    logger.info(auth_url)
    logger.info(Messages.oauth_callback_info(port))

    open_auth_url(auth_url)

    server_thread.join

    code = code_container[:code]
    raise Messages::AUTH_CODE_NOT_RECEIVED if code.nil? || code.to_s.strip.empty?

    begin
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id,
        code: code,
        base_url: redirect_uri
      )
    rescue StandardError => e
      raise Messages.auth_code_exchange_error(e.message)
    ensure
      # ensure server is shutdown if still running
      server.shutdown if server && server.status != :Stop
    end

    credentials
  end

  def self.oauth_port
    (ENV["OAUTH_PORT"] || "8080").to_i
  end

  def self.redirect_uri_for_port(port)
    "http://127.0.0.1:#{port}/oauth2callback"
  end

  # Helper: create client id and token store
  def self.client_id_and_token_store
    client_id = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
    [client_id, token_store]
  end

  # Helper: start oauth HTTP server and return [server, code_container, thread]
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
      warn "WEBrick server error: #{e.message}"
    end

    [server, code_container, server_thread]
  end

  # Create WEBrick server with minimal logging (extracted for clarity)
  def self.create_webrick_server(port)
    WEBrick::HTTPServer.new(Port: port, Logger: WEBrick::Log.new(IO::NULL), AccessLog: [])
  end

  # Return a proc that handles oauth callback requests and stores the code
  def self.oauth_request_handler(code_container, server)
    proc do |req, res|
      q = URI.decode_www_form(req.query_string || "").to_h
      code_container[:code] = q["code"] || req.query["code"]
      res.body = Messages::AUTH_SUCCESS_HTML
      res.content_type = "text/html; charset=utf-8"
      Thread.new { server.shutdown }
    end
  end

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
    logger.warn(Messages::BROWSER_AUTO_OPEN_FAILED)
    logger.warn(auth_url)
  end
end
