require_relative "test_helper"

class TestDiscordHelpers < Minitest::Test
  include TestHelper

  def setup
    setup_env_vars
    # Ensure Syodosima constants reflect the test env
    reset_constant(Syodosima, :DISCORD_BOT_TOKEN, ENV["DISCORD_BOT_TOKEN"])
    reset_constant(Syodosima, :DISCORD_CHANNEL_ID, ENV["DISCORD_CHANNEL_ID"])
  end

  def teardown
    cleanup_env_vars
  end

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
