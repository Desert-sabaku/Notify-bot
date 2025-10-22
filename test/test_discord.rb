require_relative "test_helper"

class TestDiscordHelpers < Minitest::Test
  include TestHelper

  def test_create_discord_bot_and_deliver
    bot_spy = BotSpy.new
    # ensure create_discord_bot returns a Discordrb::Bot-like object
    Discordrb::Bot.stub :new, bot_spy do
      Syodosima.send_discord_message("hello")
    end

    assert_equal [[ENV["DISCORD_CHANNEL_ID"], "hello"]], bot_spy.sent_messages
    assert bot_spy.stopped?
    assert bot_spy.joined?
  end
end
