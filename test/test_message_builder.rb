require_relative "test_helper"

class TestMessageHelpers < Minitest::Test
  include TestHelper

  def test_build_message_empty
    result = Syodosima.build_message([])
    assert_equal Syodosima::MessageConstants::MESSAGE_NO_EVENTS, result
  end

  def test_build_message_empty_with_future_date
    future_date = Date.new(2025, 12, 25)
    result = Syodosima.build_message([], future_date)
    assert_equal "2025年12月25日の予定はありません。", result
  end

  def test_build_message_with_timed_event
    start_time = DateTime.new(2025, 10, 19, 9, 0, 0, "+09:00")
    end_time = DateTime.new(2025, 10, 19, 10, 0, 0, "+09:00")
    event = create_mock_event("会議", start_time, end_time)

    result = Syodosima.build_message([event])
    expected = Syodosima::MessageConstants::MESSAGE_WITH_EVENTS_PREFIX +
               Syodosima::MessageConstants.event_time_format("09:00〜10:00", "会議")

    assert_equal expected, result
  end

  def test_build_message_with_timed_event_and_description
    start_time = DateTime.new(2025, 10, 19, 9, 0, 0, "+09:00")
    end_time = DateTime.new(2025, 10, 19, 10, 0, 0, "+09:00")
    event = create_mock_event("会議", start_time, end_time, description: "10F 大会議室")

    result = Syodosima.build_message([event])
    expected = Syodosima::MessageConstants::MESSAGE_WITH_EVENTS_PREFIX +
               Syodosima::MessageConstants.event_time_with_desc("09:00〜10:00", "会議", "10F 大会議室")

    assert_equal expected, result
  end

  def test_build_message_with_timed_event_future_date
    start_time = DateTime.new(2025, 12, 25, 9, 0, 0, "+09:00")
    end_time = DateTime.new(2025, 12, 25, 10, 0, 0, "+09:00")
    event = create_mock_event("クリスマス会議", start_time, end_time)
    future_date = Date.new(2025, 12, 25)

    result = Syodosima.build_message([event], future_date)
    expected = "2025年12月25日の予定をお知らせします。\n\n#{Syodosima::MessageConstants.event_time_format('09:00〜10:00', 'クリスマス会議')}"

    assert_equal expected, result
  end

  def test_format_event_all_day
    event = create_mock_event("休日")
    assert_equal Syodosima::MessageConstants.event_all_day_format("休日"), Syodosima.format_event(event)
  end

  def test_format_event_all_day_with_description
    event = create_mock_event("休日", nil, nil, description: "家族旅行")
    assert_equal Syodosima::MessageConstants.event_all_day_with_desc("休日", "家族旅行"), Syodosima.format_event(event)
  end
end
