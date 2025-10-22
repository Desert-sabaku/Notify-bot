$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "syodosima"
require "bundler/setup"
require "minitest/autorun"
require "minitest/mock"
require "dotenv"
require "date"

module TestHelper
  EventTime = Struct.new(:date_time, :date)
  Event = Struct.new(:start, :end, :summary)

  ENV_KEYS = %w[DISCORD_BOT_TOKEN DISCORD_CHANNEL_ID GOOGLE_CREDENTIALS_JSON GOOGLE_TOKEN_YAML].freeze

  # Set up environment variables for testing (optionally override via hash)
  def setup_env_vars(overrides = {})
    @__env_backup = ENV_KEYS.to_h { |k| [k, ENV.key?(k) ? ENV[k] : :__missing__] }
    defaults = {
      "DISCORD_BOT_TOKEN" => "test_token",
      "DISCORD_CHANNEL_ID" => "123456789",
      "GOOGLE_CREDENTIALS_JSON" => '{"type":"service_account","project_id":"test"}',
      "GOOGLE_TOKEN_YAML" => "test_token_yaml"
    }
    defaults.merge(overrides).each { |k, v| ENV[k] = v }
  end

  # Clean up environment variables after testing
  def cleanup_env_vars
    return unless defined?(@__env_backup) && @__env_backup

    @__env_backup.each do |k, v|
      v == :__missing__ ? ENV.delete(k) : ENV[k] = v
    end
    @__env_backup = nil
  end

  # Helper to stub top-level methods
  def stub_global(method_name, replacement)
    replacement_proc = replacement.respond_to?(:call) ? replacement : ->(*_) { replacement }
    raise ArgumentError, "stub_global requires a block" unless block_given?

    visibility = if Object.private_method_defined?(method_name)
                   :private
                 elsif Object.protected_method_defined?(method_name)
                   :protected
                 else
                   :public
                 end

    unless Object.private_method_defined?(method_name) ||
           Object.protected_method_defined?(method_name) ||
           Object.method_defined?(method_name)
      raise NameError, "Undefined top-level method '#{method_name}'"
    end

    original_method = Object.instance_method(method_name)

    Object.define_method(method_name, replacement_proc)
    Object.send(visibility, method_name)
    Kernel.define_method(method_name, replacement_proc)
    Kernel.send(visibility, method_name)

    yield
  ensure
    Object.define_method(method_name) { |*args, &block| original_method.bind(self).call(*args, &block) }
    Object.send(visibility, method_name)
    Kernel.define_method(method_name) { |*args, &block| original_method.bind(self).call(*args, &block) }
    Kernel.send(visibility, method_name)
  end

  # Create a mock authorizer that captures the user_id passed to get_credentials
  # and returns the provided return_value (or nil).
  #
  # Additionally, you can provide an `extra_methods` hash to define other
  # singleton methods on the mock. Each entry should be method_name => return_value_or_proc.
  # The arguments passed to those methods will be captured into `capture_hash` under
  # the method name as a symbol (e.g. capture_hash[:get_and_store_credentials_from_code] = [args...]).
  #
  # An optional block is yielded the mock and capture_hash for further customization.
  #
  # Usage examples:
  #   captured = {}
  #   mock = mock_authorizer_with_credentials(captured, mock_credentials)
  #
  #   # with extra method that returns a fixed value
  #   mock = mock_authorizer_with_credentials(captured, nil, extra_methods: { get_and_store_credentials_from_code: mock_credentials })
  #
  #   # with extra method implemented as a proc
  #   mock = mock_authorizer_with_credentials(captured, nil, extra_methods: { foo: ->(a, b) { a + b } })
  def mock_authorizer_with_credentials(
    capture_hash, return_value = nil, extra_methods: {}
  )
    capture_hash ||= {}
    raise ArgumentError, "capture_hash must be a Hash" unless capture_hash.is_a?(Hash)

    mock_authorizer = Object.new
    mock_authorizer.define_singleton_method(:get_credentials) do |user_id|
      capture_hash[:user_id] = user_id
      return_value
    end

    extra_methods.each do |method_name, ret|
      mock_authorizer.define_singleton_method(method_name) do |*args|
        capture_hash[method_name.to_sym] = args
        if ret.respond_to?(:call)
          ret.call(*args)
        else
          ret
        end
      end
    end

    yield mock_authorizer, capture_hash if block_given?

    mock_authorizer
  end

  # Create mock Google Calendar event
  def create_mock_event(summary, start_date_time = nil, end_date_time = nil)
    start_time = start_date_time ? EventTime.new(start_date_time, nil) : EventTime.new(nil, Date.today.to_s)
    end_time = EventTime.new(end_date_time, nil)
    Event.new(start_time, end_time, summary)
  end
end
