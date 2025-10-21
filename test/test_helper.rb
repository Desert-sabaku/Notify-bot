require "bundler/setup"
require "minitest/autorun"
require "minitest/mock"
require "dotenv"
require "date"

module TestHelper
  EventTime = Struct.new(:date_time, :date)
  Event = Struct.new(:start, :end, :summary)

  # Set up environment variables for testing
  def setup_env_vars
    ENV["DISCORD_BOT_TOKEN"] = "test_token"
    ENV["DISCORD_CHANNEL_ID"] = "123456789"
    ENV["GOOGLE_CREDENTIALS_JSON"] = '{"type":"service_account","project_id":"test"}'
    ENV["GOOGLE_TOKEN_YAML"] = "test_token_yaml"
  end

  # Clean up environment variables after testing
  def cleanup_env_vars
    ENV.delete("DISCORD_BOT_TOKEN")
    ENV.delete("DISCORD_CHANNEL_ID")
    ENV.delete("GOOGLE_CREDENTIALS_JSON")
    ENV.delete("GOOGLE_TOKEN_YAML")
  end

  # helper to stub top-level methods defined in lib/main.rb
  def stub_global(method_name, replacement)
    replacement_proc = replacement.respond_to?(:call) ? replacement : ->(*_) { replacement }

    visibility = if Object.private_method_defined?(method_name)
                   :private
                 elsif Object.protected_method_defined?(method_name)
                   :protected
                 else
                   :public
                 end

    original_method = Object.instance_method(method_name)

    Object.define_method(method_name, replacement_proc)
    Object.send(visibility, method_name)
    Kernel.define_method(method_name, replacement_proc)
    Kernel.send(visibility, method_name)

    yield
  ensure
    Object.define_method(method_name, original_method)
    Object.send(visibility, method_name)

    Kernel.define_method(method_name) do |*args, &block|
      original_method.bind(self).call(*args, &block)
    end
    Kernel.send(visibility, method_name)
  end

  # Create mock Google Calendar event
  def create_mock_event(summary, start_date_time = nil, end_date_time = nil)
    start_time = start_date_time ? EventTime.new(start_date_time, nil) : EventTime.new(nil, Date.today.to_s)
    end_time = EventTime.new(end_date_time, nil)
    Event.new(start_time, end_time, summary)
  end
end
