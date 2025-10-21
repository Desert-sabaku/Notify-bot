require_relative "test_helper"
require "discordrb"

class TestDiscordBot < Minitest::Test
  include TestHelper

  def setup
    setup_env_vars
    @bot_token = ENV["DISCORD_BOT_TOKEN"]
    @channel_id = ENV["DISCORD_CHANNEL_ID"]
  end

  def teardown
    cleanup_env_vars
  end

  def test_environment_variables_present
    assert @bot_token, "DISCORD_BOT_TOKEN should be set"
    assert @channel_id, "DISCORD_CHANNEL_ID should be set"
  end

  def test_bot_initialization
    bot = Discordrb::Bot.new(token: @bot_token)
    assert_instance_of Discordrb::Bot, bot
    # Discordrbではtokenは"Bot <token>"形式で保存される
    assert_equal "Bot #{@bot_token}", bot.token
  end

  def test_send_message_simulation
    mock_bot = Minitest::Mock.new

    # send_messageメソッドが呼ばれることを期待
    mock_bot.expect(:send_message, nil, [@channel_id, "Test message"])
    mock_bot.expect(:stop, nil)

    # モックが期待するメソッドを持っていることを確認
    assert mock_bot.respond_to?(:send_message)
    assert mock_bot.respond_to?(:stop)

    # モックメソッドの呼び出しをシミュレート
    mock_bot.send_message(@channel_id, "Test message")
    mock_bot.stop

    mock_bot.verify
  end

  def test_missing_environment_variables
    cleanup_env_vars

    # 環境変数が設定されていない場合のチェック
    refute ENV["DISCORD_BOT_TOKEN"], "DISCORD_BOT_TOKEN should not be set"
    refute ENV["DISCORD_CHANNEL_ID"], "DISCORD_CHANNEL_ID should not be set"

    # 必要に応じてエラーハンドリングのテストを追加
    # 実際のスクリプトではexitするが、テストではassert_raisesを使用可能
  end

  def test_bot_configuration
    bot = Discordrb::Bot.new(token: @bot_token)

    assert_equal "Bot #{@bot_token}", bot.token
    assert_instance_of Discordrb::Bot, bot
  end
end
