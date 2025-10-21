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

# Validate required environment variables
required_env_vars = {
  "DISCORD_BOT_TOKEN" => "Discord bot token for sending messages",
  "DISCORD_CHANNEL_ID" => "Discord channel ID where messages will be sent"
}

missing_vars = required_env_vars.select { |key, _| ENV[key].nil? || ENV[key].empty? }

unless missing_vars.empty?
  error_message = "Missing required environment variable(s):\n"
  missing_vars.each do |key, description|
    error_message += "  - #{key}: #{description}\n"
  end
  error_message += "\nPlease set these variables in your .env file or environment."
  abort error_message
end

# Track which files were created by this script run
CREATED_FILES = []

# Write credential files with restrictive permissions
if (v = ENV["GOOGLE_CREDENTIALS_JSON"]).to_s.strip != ""
  File.open("credentials.json", File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
    file.write(v)
  end
  CREATED_FILES << "credentials.json"
end

if (v = ENV["GOOGLE_TOKEN_YAML"]).to_s.strip != ""
  File.open("token.yaml", File::WRONLY | File::CREAT | File::TRUNC, 0o600) do |file|
    file.write(v)
  end
  CREATED_FILES << "token.yaml"
end

# Cleanup handler - only remove files created in this run
at_exit do
  # Only cleanup in CI/GitHub Actions environments
  if ENV["CI"] || ENV["GITHUB_ACTIONS"]
    CREATED_FILES.each do |file|
      File.delete(file) if File.exist?(file)
    rescue StandardError => e
      warn "Warning: Failed to cleanup #{file}: #{e.message}"
    end
  end
end

REDIRECT_URI = "http://127.0.0.1:8080/auth/callback".freeze
APPLICATION_NAME = "Discord Calendar Notifier".freeze
CREDENTIALS_PATH = "credentials.json".freeze
TOKEN_PATH = "token.yaml".freeze
SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY

DISCORD_BOT_TOKEN = ENV["DISCORD_BOT_TOKEN"]
DISCORD_CHANNEL_ID = ENV["DISCORD_CHANNEL_ID"]

# Authorize Google Calendar API
#
# @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
# @raise [RuntimeError] if authorization fails
def authorize
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

    # Start an HTTP server to receive the OAuth2 callback. Default port is 8080
    # so it matches common redirect URIs like http://127.0.0.1:8080/oauth2callback.
    port = (ENV["OAUTH_PORT"] || "8080").to_i
    redirect_uri = "http://127.0.0.1:#{port}/oauth2callback"

    server = WEBrick::HTTPServer.new(Port: port, Logger: WEBrick::Log.new("/dev/null"), AccessLog: [])

    code_container = { code: nil }

    handler = proc do |req, res|
      # Extract code from query parameters
      q = URI.decode_www_form(req.query_string || "").to_h
      code_container[:code] = q["code"] || req.query["code"]
      res.body = "<html><body><h1>認証成功！このウィンドウを閉じてください。</h1></body></html>"
      res.content_type = "text/html; charset=utf-8"
      # Shutdown server after handling
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

    # Auto-open browser (best-effort)
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

    # Wait until server handles the callback and shuts down
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

# Fetch today's events from Google Calendar
#
# @return [Array<Google::Apis::CalendarV3::Event>] List of today's events
# @raise [Google::Apis::Error] if API request fails
def fetch_today_events # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
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

# Send a message to a Discord channel
#
# @param [String] message The message to send
# @return [void]
def send_discord_message(message)
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

# Main execution flow
#
# @return [void]
def main # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
  puts "今日の予定を取得しています..."
  events = fetch_today_events

  if events.empty?
    message = "おはようございます！\n今日の予定はありません。"
  else
    message = "おはようございます！\n今日の予定をお知らせします。\n\n"
    events.each do |event|
      # date_timeが設定されていれば時刻付き、dateが設定されていれば終日
      if event.start.date_time
        start_time = event.start.date_time
        # Event objects use `start` and `end` fields; access end.date_time
        end_time = event.end.date_time
        formatted_time = "#{start_time.strftime('%H:%M')}〜#{end_time.strftime('%H:%M')}"
        message += "【#{formatted_time}】 #{event.summary}\n"
      else
        message += "【終日】 #{event.summary}\n"
      end
    end
  end

  puts "Discordに通知を送信します..."
  send_discord_message(message)
  puts "完了しました！"
end

main if __FILE__ == $PROGRAM_NAME
