# Message helpers
#
# Small utilities for building and formatting the daily notification
# message sent to Discord. Extracted from the main module for clarity
# and better testability.
module Syodosima
  # Build the daily notification message from events
  #
  # @param [Array<Google::Apis::CalendarV3::Event>] events list of events
  # @return [String] the formatted message
  def self.build_message(events)
    return "おはようございます！\n今日の予定はありません。" if events.empty?

    message = "おはようございます！\n今日の予定をお知らせします。\n\n"
    events.each { |e| message += format_event(e) }
    message
  end

  # Format a single event into a message line
  #
  # @param [Google::Apis::CalendarV3::Event] event the event to format
  # @return [String] the formatted event string
  def self.format_event(event)
    if event.start.date_time
      start_time = event.start.date_time
      end_time = event.end.date_time
      formatted_time = "#{start_time.strftime('%H:%M')}〜#{end_time.strftime('%H:%M')}"
      "【#{formatted_time}】 #{event.summary}\n"
    else
      "【終日】 #{event.summary}\n"
    end
  end
end
