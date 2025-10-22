# Syodosima

Syodosima gem is a tool to notify Discord of appointments on a given Google Calendar.

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add syodosima
```

If bundler is not being used to manage dependencies, install the gem by executing:

```bash
gem install syodosima
```

### Dependencies

This application uses the following Ruby gems:

#### Required Dependencies

-   `discordrb` - Library for operating Discord API
-   `google-apis-calendar_v3` - Library for operating Google Calendar API
-   `dotenv` - Library for managing environment variables

#### Development Dependencies

-   `rubocop` - Ruby code style checker
-   `solargraph` - Ruby language server

### Manual Installation from Source

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

Syodosima automatically retrieves today's appointments from Google Calendar and sends notifications to Discord channels.

### Features

-   Automatically retrieve today's appointments from Google Calendar
-   Properly display timed events and all-day events
-   Send notifications to Discord channels
-   Support for automatic execution in GitHub Actions

### Setup

#### Google Calendar API Setup

1. Create a new project in [Google Cloud Console](https://console.cloud.google.com/)
2. Enable Google Calendar API
3. Create credentials (OAuth 2.0 Client ID)
4. Download the `credentials.json` file

#### Discord Bot Setup

1. Create a new application in [Discord Developer Portal](https://discord.com/developers/applications)
2. Create a bot and get the token
3. Invite the bot to your server and get the channel ID

### Environment Variables

Set the following environment variables:

#### For Local Execution

Create a `.env` file with the following content:

```env
DISCORD_BOT_TOKEN=your_discord_bot_token_here
DISCORD_CHANNEL_ID=your_channel_id_here
GOOGLE_CREDENTIALS_JSON={"type":"service_account","project_id":"..."}  # contents of credentials.json
GOOGLE_TOKEN_YAML=credentials_yaml_content_here  # contents of token.yaml
```

#### For GitHub Actions Execution

Set the following secrets in GitHub repository Settings > Secrets and variables > Actions:

-   `DISCORD_BOT_TOKEN`: Discord Bot token
-   `DISCORD_CHANNEL_ID`: Discord channel ID to send notifications
-   `GOOGLE_CREDENTIALS_JSON`: Contents of credentials.json file
-   `GOOGLE_TOKEN_YAML`: Contents of token.yaml file

### Running the Application

#### Local Execution

1. For first run, Google authentication is required:

```bash
bundle exec rake run:once
```

2. Perform Google authentication in the browser and enter the displayed code in the console
3. Authentication information will be saved in `token.yaml`

#### Automatic Execution with GitHub Actions

Create a GitHub Actions workflow file (e.g., `.github/workflows/notify.yml`):

```yaml
name: Daily Calendar Notification

on:
    schedule:
        - cron: "0 0 * * *" # Run daily at 0:00 UTC
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
おはようございます！
今日の予定をお知らせします。

【09:00〜10:00】 チームミーティング
【13:00〜14:00】 プロジェクトレビュー
【終日】 休日
```

### Notes

-   Google authentication is required for first run
-   Timezone follows system settings
-   Only retrieves appointments from Google Calendar's primary calendar

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/desert-sabaku/syodosima. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [code of conduct](https://github.com/[USERNAME]/syodosima/blob/gem/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Syodosima project's codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/syodosima/blob/gem/CODE_OF_CONDUCT.md).
