require_relative "test_helper"

class TestMessageHelpers < Minitest::Test
  include TestHelper

  def test_build_message_empty
    result = Syodosima.build_message([])
    assert_equal "おはようございます！\n今日の予定はありません。", result
  end

  def test_build_message_with_timed_event
    start_time = DateTime.new(2025, 10, 19, 9, 0, 0, "+09:00")
    end_time = DateTime.new(2025, 10, 19, 10, 0, 0, "+09:00")
    event = create_mock_event("会議", start_time, end_time)

    result = Syodosima.build_message([event])
    expected = "おはようございます！\n今日の予定をお知らせします。\n\n【09:00〜10:00】 会議\n"
    assert_equal expected, result
  end

  def test_format_event_all_day
    event = create_mock_event("休日")
    assert_equal "【終日】 休日\n", Syodosima.format_event(event)
  end
end
