# Discord helpers
#
# Provides small helpers to create a short-lived Discord bot instance
# and deliver a single message. Extracted to keep the core module
# focused on orchestration.
module Syodosima
  # Send a message to Discord channel
  #
  # @param [String] message the message to send
  # @return [void]
  # @raise [ArgumentError] if message is nil or empty
  def self.send_discord_message(message)
    raise ArgumentError, "Message cannot be nil or empty" if message.nil? || message.empty?

    bot = create_discord_bot(DISCORD_BOT_TOKEN)
    deliver_message_with_bot(bot, DISCORD_CHANNEL_ID, message)
  rescue StandardError => e
    logger.error("Failed to send Discord message: #{e.message}")
  end

  # Create a Discord bot instance (extracted for testability)
  #
  # @param [String] token the Discord bot token
  # @return [Discordrb::Bot] the bot instance
  def self.create_discord_bot(token)
    Discordrb::Bot.new(token: token)
  end

  # Deliver message using a bot instance and manage its lifecycle
  #
  # @param [Discordrb::Bot] bot the bot instance
  # @param [String] channel the channel ID to send to
  # @param [String] message the message to send
  # @return [void]
  # @raise [RuntimeError] if message delivery fails
  def self.deliver_message_with_bot(bot, channel, message)
    error_occurred = false

    bot.ready do |_event|
      logger.info("Bot is ready!")
      bot.send_message(channel, message)
    rescue StandardError => e
      logger.error("Failed to send message: #{e.message}")
      error_occurred = true
    ensure
      bot.stop
    end

    bot.run(true)
    bot.join

    raise "Message delivery failed" if error_occurred

    logger.info("Message sent and bot stopped.")
  end
end
