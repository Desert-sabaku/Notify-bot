require "bundler/setup"
require "google/apis/calendar_v3"
require "googleauth"
require "googleauth/stores/file_token_store"
require "fileutils"
require "discordrb"
require "date"

# --- GitHub Actions用の設定 ---
File.write("credentials.json", ENV["GOOGLE_CREDENTIALS_JSON"]) if ENV["GOOGLE_CREDENTIALS_JSON"]
File.write("token.yaml", ENV["GOOGLE_TOKEN_YAML"]) if ENV["GOOGLE_TOKEN_YAML"]

# --- 定数設定 ---
OOB_URI = "urn:ietf:wg:oauth:2.0:oob".freeze
APPLICATION_NAME = "Discord Calendar Notifier".freeze
CREDENTIALS_PATH = "credentials.json".freeze
TOKEN_PATH = "token.yaml".freeze
SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY

DISCORD_BOT_TOKEN = ENV["DISCORD_BOT_TOKEN"]
DISCORD_CHANNEL_IDS_STRING = ENV["DISCORD_CHANNEL_ID"]

# --- Google Calendar API認証 ---
def authorize
  client_id = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
  token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
  authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
  user_id = "default"
  credentials = authorizer.get_credentials(user_id)

  raise "Google認証に失敗しました。ローカルで一度認証を通し、token.yamlをSecretに登録してください。" if credentials.nil?

  credentials
end

# --- Google Calendarから予定を取得 ---
def fetch_today_events
  service = Google::Apis::CalendarV3::CalendarService.new
  service.client_options.application_name = APPLICATION_NAME
  service.authorization = authorize

  today = Date.today
  time_min = DateTime.new(today.year, today.month, today.day, 0, 0, 0).rfc3339
  time_max = DateTime.new(today.year, today.month, today.day, 23, 59, 59).rfc3339

  events = service.list_events(
    "primary",
    single_events: true,
    order_by: "startTime",
    time_min: time_min,
    time_max: time_max
  )
  events.items
end

# --- Discordにメッセージを送信 ---
def send_discord_message(message)
  # カンマ区切りの文字列を、IDの配列に変換する
  channel_ids = DISCORD_CHANNEL_IDS_STRING.split(",")

  if channel_ids.empty?
    puts "通知先のチャンネルIDが設定されていません。"
    return
  end

  bot = Discordrb::Bot.new(token: DISCORD_BOT_TOKEN)

  bot.ready do |event|
    puts "Bot is ready!"

    # 各チャンネルIDに対して順番にメッセージを送信
    channel_ids.each do |id|
      puts "Sending to channel: #{id}"
      bot.send_message(id.strip, message) # .stripで万が一の空白を除去
    end

    bot.stop
  end

  bot.run(true)
  bot.join
  puts "All messages sent and bot stopped."
end
# --- ★★★ここまで修正★★★ ---

# --- メイン処理 ---
def main
  puts "今日の予定を取得しています..."
  events = fetch_today_events

  if events.empty?
    message = "おはようございます！\n今日の予定はありません。"
  else
    message = "おはようございます！\n今日の予定をお知らせします。\n\n"
    events.each do |event|
      start_time = event.start.date || event.start.date_time

      if start_time.is_a?(Google::Apis::CalendarV3::EventDateTime)
        formatted_time = start_time.strftime("%H:%M")
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

# --- スクリプト実行 ---
main
