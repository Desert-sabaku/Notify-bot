require_relative "test_helper"

class BotSpy
  attr_reader :sent_messages, :run_argument

  def initialize
    @sent_messages = []
  end

  def ready(&block)
    @ready_block = block
  end

  def run(async)
    @run_argument = async
    @ready_block&.call(nil)
  end

  def send_message(channel, message)
    @sent_messages << [channel, message]
  end

  def stop
    @stopped = true
  end

  def join
    @joined = true
  end

  def stopped?
    !!@stopped
  end

  def joined?
    !!@joined
  end
end

class FakeCalendarService
  ClientOptions = Struct.new(:application_name)
  Response = Struct.new(:items)

  attr_accessor :authorization
  attr_reader :client_options, :list_args

  def initialize(events)
    @events = events
    @client_options = ClientOptions.new
  end

  def list_events(calendar_id, **params)
    @list_args = [calendar_id, params]
    Response.new(@events)
  end
end

class TestSyodosima < Minitest::Test
  include TestHelper

  def test_that_it_has_a_version_number
    refute_nil ::Syodosima::VERSION
  end

  def setup
    setup_env_vars
    @bot_token = ENV["DISCORD_BOT_TOKEN"]
    @channel_id = ENV["DISCORD_CHANNEL_ID"]
    reset_constant(:DISCORD_BOT_TOKEN, @bot_token)
    reset_constant(:DISCORD_CHANNEL_ID, @channel_id)
  end

  def teardown
    cleanup_env_vars
  end

  def test_environment_variables_present
    assert @bot_token, "DISCORD_BOT_TOKEN should be set"
    assert @channel_id, "DISCORD_CHANNEL_ID should be set"
    assert ENV["GOOGLE_CREDENTIALS_JSON"], "GOOGLE_CREDENTIALS_JSON should be set"
    assert ENV["GOOGLE_TOKEN_YAML"], "GOOGLE_TOKEN_YAML should be set"
  end

  def test_authorize_with_valid_credentials
    mock_client_id = Object.new
    mock_token_store = Object.new
    mock_credentials = Object.new

    captured_path = nil
    captured_token_path = nil
    captured_authorizer_args = nil
    captured = {}

    mock_authorizer = mock_authorizer_with_credentials(captured, mock_credentials)

    Google::Auth::ClientId.stub :from_file, lambda { |path|
      captured_path = path
      mock_client_id
    } do
      Google::Auth::Stores::FileTokenStore.stub :new, lambda { |file:|
        captured_token_path = file
        mock_token_store
      } do
        Google::Auth::UserAuthorizer.stub :new, lambda { |client, scope, store|
          captured_authorizer_args = [client, scope, store]
          mock_authorizer
        } do
          assert_equal mock_credentials, Syodosima.authorize
        end
      end
    end

    assert_equal Syodosima::CREDENTIALS_PATH, captured_path
    assert_equal Syodosima::TOKEN_PATH, captured_token_path
    assert_equal [mock_client_id, Syodosima::SCOPE, mock_token_store], captured_authorizer_args
    assert_equal "default", captured[:user_id]
  end

  def test_authorize_with_invalid_credentials
    mock_client_id = Object.new
    mock_token_store = Object.new

    captured_path = nil
    captured_token_path = nil
    captured_authorizer_args = nil
    captured = {}

    mock_authorizer = mock_authorizer_with_credentials(captured, nil)

    Google::Auth::ClientId.stub :from_file, lambda { |path|
      captured_path = path
      mock_client_id
    } do
      Google::Auth::Stores::FileTokenStore.stub :new, lambda { |file:|
        captured_token_path = file
        mock_token_store
      } do
        Google::Auth::UserAuthorizer.stub :new, lambda { |client, scope, store|
          captured_authorizer_args = [client, scope, store]
          mock_authorizer
        } do
          error = assert_raises(RuntimeError) { Syodosima.authorize }
          expected_message = "Google認証に失敗しました。ローカルで一度認証を通し、token.yamlをSecretに登録してください。"
          assert_equal expected_message, error.message
        end
      end
    end

    assert_equal Syodosima::CREDENTIALS_PATH, captured_path
    assert_equal Syodosima::TOKEN_PATH, captured_token_path
    assert_equal [mock_client_id, Syodosima::SCOPE, mock_token_store], captured_authorizer_args
    assert_equal "default", captured[:user_id]
  end

  def test_fetch_today_events
    events = [create_mock_event("Test Event")]
    service = FakeCalendarService.new(events)
    credentials = Object.new

    Google::Apis::CalendarV3::CalendarService.stub :new, service do
      Syodosima.stub :authorize, credentials do
        result = Syodosima.fetch_today_events

        assert_equal events, result
        assert_equal credentials, service.authorization
        assert_equal Syodosima::APPLICATION_NAME, service.client_options.application_name

        calendar_id, params = service.list_args
        assert_equal "primary", calendar_id
        assert_equal true, params[:single_events]
        assert_equal "startTime", params[:order_by]
        assert_match(/T00:00:00\+09:00\z/, params[:time_min])
        assert_match(/T23:59:59\+09:00\z/, params[:time_max])
      end
    end
  end

  def test_send_discord_message
    bot_spy = BotSpy.new
    test_message = "Test message"

    Discordrb::Bot.stub :new, bot_spy do
      capture_io { Syodosima.send_discord_message(test_message) }
    end

    assert_equal [[@channel_id, test_message]], bot_spy.sent_messages
    assert bot_spy.stopped?, "Bot should stop after sending message"
    assert bot_spy.joined?, "Bot should join after run"
    assert_equal true, bot_spy.run_argument
  end

  def test_main_with_no_events
    result = run_main_and_capture_message([])

    assert_equal @channel_id, result[:channel]
    assert_equal "おはようございます！\n今日の予定はありません。", result[:message]
    assert result[:bot].stopped?, "Bot should stop after notifying"
    assert result[:bot].joined?, "Bot should join after notifying"
  end

  def test_main_with_events
    start_time = DateTime.new(2025, 10, 19, 9, 0, 0, "+09:00")
    end_time = DateTime.new(2025, 10, 19, 10, 0, 0, "+09:00")
    events = [create_mock_event("会議", start_time, end_time)]

    result = run_main_and_capture_message(events)
    message = result[:message]
    expected = "おはようございます！\n今日の予定をお知らせします。\n\n【09:00〜10:00】 会議\n"
    assert_equal expected, message
    assert_equal @channel_id, result[:channel]
  end

  def test_main_with_all_day_event
    events = [create_mock_event("休日")]

    result = run_main_and_capture_message(events)
    message = result[:message]
    expected = "おはようございます！\n今日の予定をお知らせします。\n\n【終日】 休日\n"
    assert_equal expected, message
    assert_equal @channel_id, result[:channel]
  end

  def test_main_and_module_run_consistent
    events = [create_mock_event("一致テスト")]

    top = run_main_and_capture_message(events)
    mod = run_module_and_capture_message(events)

    assert_equal top[:message], mod[:message]
    assert_equal top[:channel], mod[:channel]
  end

  private

  def run_module_and_capture_message(events)
    bot_spy = BotSpy.new

    Syodosima.stub :fetch_today_events, events do
      Discordrb::Bot.stub :new, bot_spy do
        capture_io { Syodosima.run }
      end
    end

    last_message = bot_spy.sent_messages.last
    {
      message: last_message&.last,
      channel: last_message&.first,
      bot: bot_spy
    }
  end

  def run_main_and_capture_message(events)
    bot_spy = BotSpy.new

    Syodosima.stub :fetch_today_events, events do
      Discordrb::Bot.stub :new, bot_spy do
        capture_io { Syodosima.run }
      end
    end

    last_message = bot_spy.sent_messages.last
    {
      message: last_message&.last,
      channel: last_message&.first,
      bot: bot_spy
    }
  end

  def reset_constant(name, value)
    if Syodosima.const_defined?(name)
      Syodosima.send(:remove_const, name)
      Syodosima.const_set(name, value)
    else
      Object.send(:remove_const, name)
      Object.const_set(name, value)
    end
  end
end
