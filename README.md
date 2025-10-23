# Syodosima

Syodosima gem is a tool to notify Discord of appointments on a given Google Calendar and provides a CLI wrapper.

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add syodosima
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install syodosima
```

For manual installation, follow these steps.

1. Clone the repository:

```bash
git clone https://github.com/Desert-sabaku/syodosima.git
cd syodosima
```

2. Install dependencies:

```bash
bundle install
```

## Usage

Syodosima automatically retrieves today's appointments from Google Calendar and sends notifications to a Discord channel.

### Features

-   Automatically retrieve today's appointments from Google Calendar
-   Properly display timed events and all-day events
-   Send notifications to Discord channels
-   Support for automatic execution in GitHub Actions

### Configuration

#### Google Calendar API Setup

1. Create a new project in [Google Cloud Console](https://console.cloud.google.com/)
2. Enable Google Calendar API
3. Create credentials (OAuth 2.0 Client ID)
4. Download the `credentials.json` file

#### Discord Bot Setup

1. Create a new application in [Discord Developer Portal](https://discord.com/developers/applications)
2. Create a bot and obtain the token
3. Invite the bot to the server and obtain the channel ID

### Environment Variable Setup

Please set the following environment variables:

#### For Local Execution

Create a `.env` file and add the following content:

```env
DISCORD_BOT_TOKEN=your_discord_bot_token_here
DISCORD_CHANNEL_ID=your_channel_id_here
# Paste the contents of credentials.json
GOOGLE_CREDENTIALS_JSON={"installed":{"client_id":"...","client_secret":"...","redirect_uris":["http://localhost"]}}
```

> [!IMPORTANT]
> Browser authentication is required on first run only. After authentication,
> token information will be displayed. Save it to `.env` as `GOOGLE_TOKEN_YAML_BASE64`.

#### For GitHub Actions Execution

Set the following secrets in GitHub repository Settings > Secrets and variables > Actions:

-   `DISCORD_BOT_TOKEN`: Discord Bot token
-   `DISCORD_CHANNEL_ID`: Discord channel ID to send notifications to
-   `GOOGLE_CREDENTIALS_JSON`: Contents of credentials.json file
-   `GOOGLE_TOKEN_YAML_BASE64`: Base64-encoded token displayed after first authentication

### Running the Application

#### Local Execution

**First run (browser authentication required):**

```bash
bundle exec rake run:once
```

After authentication, token information will be displayed in the console:

```
======================================================================
認証が完了しました。以下のトークンを.envファイルに保存してください：
----------------------------------------------------------------------
GOOGLE_TOKEN_YAML_BASE64=LS0tCmRlZmF1bHQ6IC4uLg==
----------------------------------------------------------------------

.envファイルに自動で保存しますか？ (y/N):
======================================================================
```

If you enter `y`, the token will be automatically saved to your `.env` file.
If you enter `N` or want to save manually, add the displayed `GOOGLE_TOKEN_YAML_BASE64=...` line to your `.env` file.

**Subsequent runs (no re-authentication needed):**

```bash
bundle exec rake run:once
```

> [!IMPORTANT]
> Once you set `GOOGLE_TOKEN_YAML_BASE64` in `.env`, you can run without browser authentication.

**Running with irb**

If installed as a gem:

```bash
irb
irb(main):001> require "syodosima"
=> true
irb(main):002> Syodosima.run
```

#### Automatic Execution in GitHub Actions

Create a GitHub Actions workflow file (e.g., `.github/workflows/notify.yml`):

```yaml
name: Daily Calendar Notification

on:
    schedule:
        - cron: "0 0 * * *" # Run daily at 0:00 (UTC)
    workflow_dispatch: # Manual execution also possible

jobs:
    notify:
        runs-on: ubuntu-latest
        steps:
            - uses: actions/checkout@v3
            - uses: ruby/setup-ruby@v1
              with:
                  ruby-version: "3.4"
            - name: Install dependencies
              run: bundle install
            - name: Run notification bot
              run: bundle exec rake run:once
              env:
                  DISCORD_BOT_TOKEN: ${{ secrets.DISCORD_BOT_TOKEN }}
                  DISCORD_CHANNEL_ID: ${{ secrets.DISCORD_CHANNEL_ID }}
                  GOOGLE_CREDENTIALS_JSON: ${{ secrets.GOOGLE_CREDENTIALS_JSON }}
                  GOOGLE_TOKEN_YAML: ${{ secrets.GOOGLE_TOKEN_YAML }}
```

### Notification Example

Example of messages sent by the bot:

```text
Good morning!
I'll let you know today's schedule.

【09:00〜10:00】 Team Meeting
【13:00〜14:00】 Project Review
【All Day】 Holiday
```

### Notes

-   Google authentication is required for the first run
-   Timezone follows system settings
-   Only appointments from the primary calendar in Google Calendar are retrieved

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/desert-sabaku/syodosima. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/syodosima/blob/gem/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
