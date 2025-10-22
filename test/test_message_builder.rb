require_relative "test_helper"

class TestMessageHelpers < Minitest::Test
  include TestHelper

  def test_build_message_empty
    result = Syodosima.build_message([])
    assert_equal Syodosima::MessageConstants::MESSAGE_NO_EVENTS, result
  end

  def test_build_message_with_timed_event
    start_time = DateTime.new(2025, 10, 19, 9, 0, 0, "+09:00")
    end_time = DateTime.new(2025, 10, 19, 10, 0, 0, "+09:00")
    event = create_mock_event("会議", start_time, end_time)

    result = Syodosima.build_message([event])
    expected = Syodosima::MessageConstants::MESSAGE_WITH_EVENTS_PREFIX + Syodosima::MessageConstants.event_time_format(
      "09:00〜10:00", "会議"
    )
    assert_equal expected, result
  end

  def test_format_event_all_day
    event = create_mock_event("休日")
    assert_equal Syodosima::MessageConstants.event_all_day_format("休日"), Syodosima.format_event(event)
  end
end
