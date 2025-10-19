# Notify-bot

Google Calendar から今日の予定を取得し、Discord チャンネルに通知する Bot です。

## 機能

-   Google Calendar から今日の予定を自動取得
-   時刻付きイベントと終日イベントを適切に表示
-   Discord チャンネルに通知を送信
-   GitHub Actions での自動実行に対応

## 依存関係

このアプリケーションは以下の Ruby gem を使用しています：

### 必須依存関係

-   `discordrb` - Discord API を操作するためのライブラリ
-   `google-api-client` - Google Calendar API を操作するためのライブラリ
-   `dotenv` - 環境変数を管理するためのライブラリ

### 開発用依存関係

-   `rubocop` - Ruby コードのスタイルチェック
-   `solargraph` - Ruby の言語サーバー

## インストール

1. リポジトリをクローンします：

```bash
git clone https://github.com/Desert-sabaku/Notify-bot.git
cd Notify-bot
```

2. 依存関係をインストールします：

```bash
bundle install
```

## 設定

### Google Calendar API の設定

1. [Google Cloud Console](https://console.cloud.google.com/)で新しいプロジェクトを作成
2. Google Calendar API を有効化
3. 認証情報を作成（OAuth 2.0 クライアント ID）
4. `credentials.json`ファイルをダウンロード

### Discord Bot の設定

1. [Discord Developer Portal](https://discord.com/developers/applications)で新しいアプリケーションを作成
2. Bot を作成し、トークンを取得
3. Bot をサーバーに招待し、チャンネル ID を取得

## 環境変数の設定

以下の環境変数を設定してください：

### ローカル実行時

`.env`ファイルを作成し、以下の内容を記述：

```env
DISCORD_BOT_TOKEN=your_discord_bot_token_here
DISCORD_CHANNEL_ID=your_channel_id_here
GOOGLE_CREDENTIALS_JSON={"type":"service_account","project_id":"..."}  # credentials.jsonの内容
GOOGLE_TOKEN_YAML=credentials_yaml_content_here  # token.yamlの内容
```

### GitHub Actions 実行時

GitHub リポジトリの Settings > Secrets and variables > Actions で以下のシークレットを設定：

-   `DISCORD_BOT_TOKEN`: Discord Bot のトークン
-   `DISCORD_CHANNEL_ID`: 通知を送信する Discord チャンネル ID
-   `GOOGLE_CREDENTIALS_JSON`: credentials.json ファイルの内容
-   `GOOGLE_TOKEN_YAML`: token.yaml ファイルの内容

## 利用方法

### ローカル実行

1. 初回実行時は Google 認証が必要です：

```bash
ruby main.rb
```

2. ブラウザで Google 認証を行い、表示されたコードをコンソールに入力
3. 認証情報が`token.yaml`に保存されます

### GitHub Actions での自動実行

GitHub Actions のワークフローファイル（例: `.github/workflows/notify.yml`）を作成：

```yaml
name: Daily Calendar Notification

on:
    schedule:
        - cron: "0 0 * * *" # 毎日午前0時（UTC）に実行
    workflow_dispatch: # 手動実行も可能

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
              run: ruby main.rb
              env:
                  DISCORD_BOT_TOKEN: ${{ secrets.DISCORD_BOT_TOKEN }}
                  DISCORD_CHANNEL_ID: ${{ secrets.DISCORD_CHANNEL_ID }}
                  GOOGLE_CREDENTIALS_JSON: ${{ secrets.GOOGLE_CREDENTIALS_JSON }}
                  GOOGLE_TOKEN_YAML: ${{ secrets.GOOGLE_TOKEN_YAML }}
```

## 通知の例

Bot が送信するメッセージの例：

```
おはようございます！
今日の予定をお知らせします。

【09:00〜10:00】 チームミーティング
【13:00〜14:00】 プロジェクトレビュー
【終日】 休日
```

## 注意事項

-   初回実行時は Google 認証が必要です
-   タイムゾーンはシステムの設定に従います
-   Google Calendar のプライマリカレンダーの予定のみを取得します

## ライセンス

このプロジェクトは MIT ライセンスの下で公開されています。
