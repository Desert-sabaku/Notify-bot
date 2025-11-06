require "bundler/gem_tasks"
require "minitest/test_task"

Minitest::TestTask.create

require "rubocop/rake_task"

RuboCop::RakeTask.new

task default: %i[test rubocop]

namespace :run do
  desc "Run the Syodosima notifier once (loads .env if present)"
  task :once do
    require "dotenv/load"
    require_relative "lib/syodosima"

    Syodosima.run
  end

  desc "Run the Syodosima notifier for a specific date (DATE=YYYY-MM-DD)"
  task :date do
    require "dotenv/load"
    require_relative "lib/syodosima"

    date_str = ENV["DATE"]
    abort "Please specify DATE environment variable (e.g., DATE=2025-11-10)" unless date_str

    begin
      target_date = Date.parse(date_str)
      Syodosima.run(target_date)
    rescue Date::Error => e
      abort "Invalid date format: #{date_str}. Please use YYYY-MM-DD format. Error: #{e.message}"
    end
  end

  desc "Print environment variables used by the notifier"
  task :env do
    require "dotenv/load"

    keys = %w[
      DISCORD_BOT_TOKEN
      DISCORD_CHANNEL_ID
      GOOGLE_CREDENTIALS_JSON
      GOOGLE_TOKEN_YAML
      OAUTH_PORT
      TIMEZONE_OFFSET
      LOG_LEVEL
      LOG_OUTPUT
      LOG_FORMAT
    ]

    keys.each do |k|
      puts "#{k}=#{ENV[k].inspect}"
    end
  end
end
