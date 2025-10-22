# Discord helpers
#
# Provides small helpers to create a short-lived Discord bot instance
# and deliver a single message. Extracted to keep the core module
# focused on orchestration.
module Syodosima
  def self.send_discord_message(message)
    bot = create_discord_bot(DISCORD_BOT_TOKEN)
    deliver_message_with_bot(bot, DISCORD_CHANNEL_ID, message)
  end

  # Create a Discord bot instance (extracted for testability)
  def self.create_discord_bot(token)
    Discordrb::Bot.new(token: token)
  end

  # Deliver message using a bot instance and manage its lifecycle
  def self.deliver_message_with_bot(bot, channel, message)
    bot.ready do |_event|
      logger.info("Bot is ready!")
      bot.send_message(channel, message)
      bot.stop
    end

    bot.run(true)
    bot.join
    logger.info("Message sent and bot stopped.")
  end
end
