require "bundler/setup"
require "google/apis/calendar_v3"
require "googleauth"
require "googleauth/stores/file_token_store"
require "fileutils"
require "discordrb"
require "date"
require "dotenv/load"

File.write("credentials.json", ENV["GOOGLE_CREDENTIALS_JSON"]) if ENV["GOOGLE_CREDENTIALS_JSON"]
File.write("token.yaml", ENV["GOOGLE_TOKEN_YAML"]) if ENV["GOOGLE_TOKEN_YAML"]

OOB_URI = "urn:ietf:wg:oauth:2.0:oob".freeze
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

  raise "Google認証に失敗しました。ローカルで一度認証を通し、token.yamlをSecretに登録してください。" if credentials.nil?

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

  jst_offset = "+09:00"
  now_jst = DateTime.now.new_offset(jst_offset)
  today = now_jst.to_date
  time_min = DateTime.new(today.year, today.month, today.day, 0, 0, 0, jst_offset).rfc3339
  time_max = DateTime.new(today.year, today.month, today.day, 23, 59, 59, jst_offset).rfc3339

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
