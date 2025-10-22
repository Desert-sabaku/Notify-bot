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
