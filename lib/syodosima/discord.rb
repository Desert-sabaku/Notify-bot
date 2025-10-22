# Discord helpers
#
# Provides small helpers to create a short-lived Discord bot instance
# and deliver a single message. Extracted to keep the core module
# focused on orchestration.
module Syodosima
  def self.send_discord_message(message)
    raise ArgumentError, "Message cannot be nil or empty" if message.nil? || message.empty?

    bot = create_discord_bot(DISCORD_BOT_TOKEN)
    deliver_message_with_bot(bot, DISCORD_CHANNEL_ID, message)
  rescue StandardError => e
    logger.error("Failed to send Discord message: #{e.message}")
  end

  # Create a Discord bot instance (extracted for testability)
  def self.create_discord_bot(token)
    Discordrb::Bot.new(token: token)
  end

  # Deliver message using a bot instance and manage its lifecycle
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

    # Add timeout to prevent indefinite blocking
    timeout = 30
    start_time = Time.now
    sleep 0.1 while bot.connected? && (Time.now - start_time < timeout)

    raise "Bot operation timed out after #{timeout} seconds" if Time.now - start_time >= timeout
    raise "Message delivery failed" if error_occurred

    bot.join
    logger.info("Message sent and bot stopped.")
  end
end
