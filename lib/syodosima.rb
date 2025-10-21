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

module Syodosima
  class Error < StandardError; end

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

  def self.write_credential_files!
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
        warn "Warning: Failed to cleanup #{file}: #{e.message}"
      end
    end
  end

  def self.authorize
    client_id = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
    token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
    authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
    user_id = "default"
    credentials = authorizer.get_credentials(user_id)

    if credentials.nil?
      if ENV["CI"] || ENV["GITHUB_ACTIONS"]
        raise "Google認証が必要ですが、CI では対話認証できません。token.yaml を Secret(GOOGLE_TOKEN_YAML) として設定してください。"
      end

      unless authorizer.respond_to?(:get_authorization_url)
        raise "Google認証に失敗しました。ローカルで一度認証を通し、token.yamlをSecretに登録してください。"
      end

      port = (ENV["OAUTH_PORT"] || "8080").to_i
      redirect_uri = "http://127.0.0.1:#{port}/oauth2callback"

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

      auth_url = authorizer.get_authorization_url(base_url: redirect_uri)
      puts "ブラウザで認証してください："
      puts auth_url
      puts "このプロセスは 127.0.0.1:#{port} でコールバックを待ち受けます。（PATH: /oauth2callback または /auth/callback）"

      begin
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
        # ignore failures to auto-open
      end

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
      end
    end

    credentials
  end

  def self.fetch_today_events
    service = Google::Apis::CalendarV3::CalendarService.new
    service.client_options.application_name = APPLICATION_NAME
    # Use top-level `authorize` so tests can stub it via TestHelper#stub_global
    service.authorization = Object.send(:authorize)

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
    # Resolve token and channel from top-level constants if present so tests
    # that manipulate top-level constants (reset_constant) work correctly.
    token = if Object.const_defined?(:DISCORD_BOT_TOKEN)
              Object.const_get(:DISCORD_BOT_TOKEN)
            else
              DISCORD_BOT_TOKEN
            end

    channel_id = if Object.const_defined?(:DISCORD_CHANNEL_ID)
                   Object.const_get(:DISCORD_CHANNEL_ID)
                 else
                   DISCORD_CHANNEL_ID
                 end

    bot = Discordrb::Bot.new(token: token)

    bot.ready do |_event|
      puts "Bot is ready!"
      bot.send_message(channel_id, message)
      bot.stop
    end

    bot.run(true)
    bot.join
    puts "Message sent and bot stopped."
  end

  def self.run
    # Delegate to top-level helpers so tests can stub/override them
    Object.send(:validate_env!)
    Object.send(:write_credential_files!)

    puts "今日の予定を取得しています..."
    events = Object.send(:fetch_today_events)

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

    puts "Discordに通知を送信します..."
    Object.send(:send_discord_message, message)
    puts "完了しました！"
  end
end

# Backwards compatibility: expose the previous top-level constants and methods
# that used to be defined in `lib/main.rb`. Tests and external callers may rely
# on these top-level symbols, so define delegators to the `Syodosima` module.

# Constants
APPLICATION_NAME = Syodosima::APPLICATION_NAME unless defined?(APPLICATION_NAME)
CREDENTIALS_PATH = Syodosima::CREDENTIALS_PATH unless defined?(CREDENTIALS_PATH)
TOKEN_PATH = Syodosima::TOKEN_PATH unless defined?(TOKEN_PATH)
SCOPE = Syodosima::SCOPE unless defined?(SCOPE)
DISCORD_BOT_TOKEN = Syodosima::DISCORD_BOT_TOKEN unless defined?(DISCORD_BOT_TOKEN)
DISCORD_CHANNEL_ID = Syodosima::DISCORD_CHANNEL_ID unless defined?(DISCORD_CHANNEL_ID)
CREATED_FILES = Syodosima::CREATED_FILES unless defined?(CREATED_FILES)
REQUIRED_ENV_VARS = Syodosima::REQUIRED_ENV_VARS unless defined?(REQUIRED_ENV_VARS)

# Top-level method delegators. These will be private methods on Object/Kernal
# like the original top-level definitions.
Object.define_method(:validate_env!) { Syodosima.validate_env! }
Object.send(:private, :validate_env!)
Kernel.define_method(:validate_env!) { Syodosima.validate_env! }
Kernel.send(:private, :validate_env!)

Object.define_method(:write_credential_files!) { Syodosima.write_credential_files! }
Object.send(:private, :write_credential_files!)
Kernel.define_method(:write_credential_files!) { Syodosima.write_credential_files! }
Kernel.send(:private, :write_credential_files!)

Object.define_method(:authorize) { Syodosima.authorize }
Object.send(:private, :authorize)
Kernel.define_method(:authorize) { Syodosima.authorize }
Kernel.send(:private, :authorize)

Object.define_method(:fetch_today_events) { Syodosima.fetch_today_events }
Object.send(:private, :fetch_today_events)
Kernel.define_method(:fetch_today_events) { Syodosima.fetch_today_events }
Kernel.send(:private, :fetch_today_events)

Object.define_method(:send_discord_message) { |message| Syodosima.send_discord_message(message) }
Object.send(:private, :send_discord_message)
Kernel.define_method(:send_discord_message) { |message| Syodosima.send_discord_message(message) }
Kernel.send(:private, :send_discord_message)

Object.define_method(:main) { Syodosima.run }
Object.send(:private, :main)
Kernel.define_method(:main) { Syodosima.run }
Kernel.send(:private, :main)
