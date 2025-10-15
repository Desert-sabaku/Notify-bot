require "bundler/setup"
require "google/apis/calendar_v3"
require "googleauth"
require "googleauth/stores/file_token_store"
require "fileutils"
require "discordrb"
require "dotenv"
require "date"

# .envファイルから環境変数を読み込む
Dotenv.load

# --- 定数設定 ---
OOB_URI = "urn:ietf:wg:oauth:2.0:oob".freeze
APPLICATION_NAME = "Discord Calendar Notifier".freeze
# credentials.json のパス
CREDENTIALS_PATH = "credentials.json".freeze
# token.yaml のパス（Google認証情報が保存される）
TOKEN_PATH = "token.yaml".freeze
# Google APIが要求する権限の範囲（読み取り専用）
SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY

# Discord BotのトークンとチャンネルID
DISCORD_BOT_TOKEN = ENV["DISCORD_BOT_TOKEN"]
DISCORD_CHANNEL_ID = ENV["DISCORD_CHANNEL_ID"]

# --- Google Calendar API認証 ---
def authorize
  client_id = Google::Auth::ClientId.from_file(CREDENTIALS_PATH)
  token_store = Google::Auth::Stores::FileTokenStore.new(file: TOKEN_PATH)
  authorizer = Google::Auth::UserAuthorizer.new(client_id, SCOPE, token_store)
  user_id = "default"
  credentials = authorizer.get_credentials(user_id)

  # もし認証情報がなければ、ターミナルで認証フローを開始
  if credentials.nil?
    url = authorizer.get_authorization_url(base_url: OOB_URI)
    puts "ブラウザで下記URLを開き、アカウントを認証してください:"
    puts url
    print "表示されたコードを貼り付けてEnterを押してください: "
    code = gets
    credentials = authorizer.get_and_store_credentials_from_code(
      user_id: user_id, code: code, base_url: OOB_URI
    )
  end
  credentials
end

# --- Google Calendarから予定を取得 ---
def fetch_today_events
  # サービスを初期化
  service = Google::Apis::CalendarV3::CalendarService.new
  service.client_options.application_name = APPLICATION_NAME
  service.authorization = authorize

  # 今日の開始時刻と終了時刻をISO 8601形式で取得
  today = Date.today
  time_min = DateTime.new(today.year, today.month, today.day, 0, 0, 0).rfc3339
  time_max = DateTime.new(today.year, today.month, today.day, 23, 59, 59).rfc3339

  # 'primary'はメインのカレンダーを指す
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
  # Botを初期化
  bot = Discordrb::Bot.new(token: DISCORD_BOT_TOKEN)

  # Botがサーバーに接続するまで待つ
  bot.ready do |event|
    puts "Bot is ready!"
    # 指定されたチャンネルにメッセージを送信
    bot.send_message(DISCORD_CHANNEL_ID, message)
    # 送信後、Botを停止
    bot.stop
  end

  # Botを実行（バックグラウンドで）
  bot.run(true)
  # Botが停止するまで待つ
  bot.join
  puts "Message sent and bot stopped."
end

# --- メイン処理 ---
def main
  puts "今日の予定を取得しています..."
  events = fetch_today_events

  # 送信するメッセージを作成
  if events.empty?
    message = "おはようございます！\n今日の予定はありません。"
  else
    message = "おはようございます！\n今日の予定をお知らせします。\n\n"
    events.each do |event|
      # 終日の予定か、時間指定の予定かで表示を分ける
      start_time = event.start.date || event.start.date_time

      if start_time.is_a?(Google::Apis::CalendarV3::EventDateTime)
        # 時間指定の予定
        formatted_time = start_time.strftime("%H:%M")
        message += "【#{formatted_time}】 #{event.summary}\n"
      else
        # 終日の予定
        message += "【終日】 #{event.summary}\n"
      end
    end
  end

  puts "Discordに通知を送信します..."
  send_discord_message(message)
  puts "完了しました！"
end

# --- スクリプト実行 ---
main if __FILE__ == $PROGRAM_NAME
