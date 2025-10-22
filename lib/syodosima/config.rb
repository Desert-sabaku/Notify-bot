# Configuration constants for Syodosima.
#
# Extracted into a separate file to keep `lib/syodosima.rb` concise and
# to make configuration easier to test and override.
module Syodosima
  APPLICATION_NAME = "Discord Calendar Notifier".freeze

  CREDENTIALS_PATH = ENV.fetch("CREDENTIALS_PATH", "credentials.json")
  TOKEN_PATH = ENV.fetch("TOKEN_PATH", "token.yaml")

  # Google Calendar scope required for reading events
  SCOPE = Google::Apis::CalendarV3::AUTH_CALENDAR_READONLY

  # Discord configuration (expect env or use placeholder)
  DISCORD_BOT_TOKEN = ENV["DISCORD_BOT_TOKEN"]
  DISCORD_CHANNEL_ID = ENV["DISCORD_CHANNEL_ID"]

  # List of env vars required for operation and a short description
  # GOOGLE_TOKEN_YAML is optional; if missing, the app will initiate OAuth flow.
  REQUIRED_ENV_VARS = {
    "DISCORD_BOT_TOKEN" => "Discord bot token used to post messages",
    "DISCORD_CHANNEL_ID" => "Discord channel ID to send notifications to",
    "GOOGLE_CREDENTIALS_JSON" => "Base64 or raw JSON for Google OAuth client credentials"
  }.freeze

  # Track files created at runtime so CI cleanup can remove them.
  # This array is intentionally mutable so runtime code can append paths.
  # Use a class instance variable and accessor to avoid mutable constants.
  @created_files = []

  def self.created_files
    @created_files
  end
end
