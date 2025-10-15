require "bundler/setup"
require "discordrb"
require "dotenv"

# .envファイルを読み込む
Dotenv.load

# .envからトークンとチャンネルIDを取得
DISCORD_BOT_TOKEN = ENV["DISCORD_BOT_TOKEN"]
DISCORD_CHANNEL_ID = ENV["DISCORD_CHANNEL_ID"]

# トークンやIDが設定されているか確認
unless DISCORD_BOT_TOKEN && DISCORD_CHANNEL_ID
  puts "エラー: .envファイルにDISCORD_BOT_TOKENとDISCORD_CHANNEL_IDを設定してください。"
  exit
end

puts "Discord Botを初期化しています..."
# Botを作成
bot = Discordrb::Bot.new(token: DISCORD_BOT_TOKEN)

puts "BotをDiscordに接続しています..."
# Botが準備完了になったらメッセージを送信
bot.ready do
  puts "接続完了！"
  puts "チャンネルID: #{DISCORD_CHANNEL_ID} にテストメッセージを送信します..."

  # メッセージを送信
  bot.send_message(DISCORD_CHANNEL_ID, "こんにちは！これはDiscordへの通知テストです！ 🎉")

  puts "メッセージを送信しました。Botを停止します。"
  # Botを停止
  bot.stop
end

# Botを実行
bot.run
puts "テストが完了しました。"
