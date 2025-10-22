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

module Syodosima # rubocop:disable Metrics/ModuleLength,Style/Documentation
  class Error < StandardError; end

  require "logger"

  # Module-level logger. Default to STDOUT, but can be overridden in tests.
  @logger = Logger.new($stdout)
  @logger.level = Logger::INFO

  def self.logger
    @logger
  end

  def self.logger=(val)
    @logger = val
  end

  # Validate required environment variables
  REQUIRED_ENV_VARS = {
    "DISCORD_BOT_TOKEN" => "Discord bot token for sending messages",
    "DISCORD_CHANNEL_ID" => "Discord channel ID where messages will be sent"
  }.freeze

  CREATED_FILES = []

  REDIRECT_URI = "http://127.0.0.1:8080/auth/callback".freeze
  APPLICATION_NAME = "Discord Calendar Notifier".freeze
  CREDENTIALS_PATH = "credentials.json".freeze
  TOKEN_PATH = "token.yaml".freeze
  SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY

  DISCORD_BOT_TOKEN = ENV["DISCORD_BOT_TOKEN"]
  DISCORD_CHANNEL_ID = ENV["DISCORD_CHANNEL_ID"]

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

  def self.write_credential_files! # rubocop:disable Metrics/MethodLength
    if (v = ENV["GOOGLE_CREDENTIALS_JSON"]).to_s.strip != ""
      File.open(CREDENTIALS_PATH, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
        file.write(v)
      end
      CREATED_FILES << CREDENTIALS_PATH
    end

    if (v = ENV["GOOGLE_TOKEN_YAML"]).to_s.strip != ""
      File.open(TOKEN_PATH, File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
        file.write(v)
      end
      CREATED_FILES << TOKEN_PATH
    end
  end

  at_exit do
    if ENV["CI"] || ENV["GITHUB_ACTIONS"]
      CREATED_FILES.each do |file|
        File.delete(file) if File.exist?(file)
      rescue StandardError => e
        logger.warn("Warning: Failed to cleanup #{file}: #{e.message}")
      end
    end
  end

  def self.authorize
    client_id, token_store = client_id_and_token_store
    authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
    user_id = "default"
    credentials = authorizer.get_credentials(user_id)

    return credentials unless credentials.nil?

    if ENV["CI"] || ENV["GITHUB_ACTIONS"]
      raise "Google認証が必要ですが、CI では対話認証できません。token.yaml を Secret(GOOGLE_TOKEN_YAML) として設定してください。"
    end

    unless authorizer.respond_to?(:get_authorization_url)
      raise "Google認証に失敗しました。ローカルで一度認証を通し、token.yamlをSecretに登録してください。"
    end

    port = (ENV["OAUTH_PORT"] || "8080").to_i
    redirect_uri = "http://127.0.0.1:#{port}/oauth2callback"

    server, code_container, server_thread = start_oauth_server(port)

    auth_url = authorizer.get_authorization_url(base_url: redirect_uri)
    logger.info("ブラウザで認証してください：")
    logger.info(auth_url)
    logger.info("このプロセスは 127.0.0.1:#{port} でコールバックを待ち受けます。（PATH: /oauth2callback または /auth/callback）")

    open_auth_url(auth_url)

    server_thread.join

    code = code_container[:code]
    raise "認可コードが取得できませんでした。ブラウザでアクセスした際にこのプロセスが起動しているか確認してください。" if code.nil? || code.to_s.strip.empty?

    begin
      credentials = authorizer.get_and_store_credentials_from_code(
        user_id: user_id,
        code: code,
        base_url: redirect_uri
      )
    rescue StandardError => e
      raise "Google認証に失敗しました（コード交換エラー）: #{e.message}"
    ensure
      # ensure server is shutdown if still running
      server.shutdown if server && server.status != :Stop
    end

    credentials
  end

  # Helper: create client id and token store
  def self.client_id_and_token_store
    client_id = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
    [client_id, token_store]
  end

  # Helper: start oauth HTTP server and return [server, code_container, thread]
  def self.start_oauth_server(port)
    server = WEBrick::HTTPServer.new(Port: port, Logger: WEBrick::Log.new("/dev/null"), AccessLog: [])
    code_container = { code: nil }

    handler = proc do |req, res|
      q = URI.decode_www_form(req.query_string || "").to_h
      code_container[:code] = q["code"] || req.query["code"]
      res.body = "<html><body><h1>認証成功！このウィンドウを閉じてください。</h1></body></html>"
      res.content_type = "text/html; charset=utf-8"
      Thread.new { server.shutdown }
    end

    server.mount_proc "/oauth2callback", &handler
    server.mount_proc "/auth/callback", &handler

    server_thread = Thread.new do
      server.start
    rescue StandardError => e
      warn "WEBrick server error: #{e.message}"
    end

    [server, code_container, server_thread]
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
    logger.warn("ブラウザを自動で開けませんでした。URLを手動で開いてください：")
    logger.warn(auth_url)
  end

  def self.fetch_today_events
    service = Google::Apis::CalendarV3::CalendarService.new
    service.client_options.application_name = APPLICATION_NAME
    service.authorization = authorize

    timezone_offset = ENV.fetch("TIMEZONE_OFFSET", "+09:00")
    now_tz = DateTime.now.new_offset(timezone_offset)
    today = now_tz.to_date
    time_min = DateTime.new(today.year, today.month, today.day, 0, 0, 0, timezone_offset).rfc3339
    time_max = DateTime.new(today.year, today.month, today.day, 23, 59, 59, timezone_offset).rfc3339

    events = service.list_events(
      "primary",
      single_events: true,
      order_by: "startTime",
      time_min: time_min,
      time_max: time_max
    )
    events.items
  end

  def self.send_discord_message(message)
    bot = Discordrb::Bot.new(token: DISCORD_BOT_TOKEN)

    bot.ready do |_event|
      puts "Bot is ready!"
      bot.send_message(DISCORD_CHANNEL_ID, message)
      bot.stop
    end

    bot.run(true)
    bot.join
    puts "Message sent and bot stopped."
  end

  def self.run
    validate_env!
    write_credential_files!

    logger.info("今日の予定を取得しています...")
    events = fetch_today_events

    if events.empty?
      message = "おはようございます！\n今日の予定はありません。"
    else
      message = "おはようございます！\n今日の予定をお知らせします。\n\n"
      events.each do |event|
        if event.start.date_time
          start_time = event.start.date_time
          end_time = event.end.date_time
          formatted_time = "#{start_time.strftime('%H:%M')}〜#{end_time.strftime('%H:%M')}"
          message += "【#{formatted_time}】 #{event.summary}\n"
        else
          message += "【終日】 #{event.summary}\n"
        end
      end
    end

    logger.info("Discordに通知を送信します...")
    send_discord_message(message)
    logger.info("完了しました！")
  end
end
