# Syodosima

Syodosima gem は、指定された Google Calendar の予定を Discord に通知するツールです。

## インストール

gem をインストールし、アプリケーションの Gemfile に追加するには、以下のコマンドを実行してください：

```bash
bundle add syodosima
```

Bundler を使用して依存関係を管理していない場合は、以下のコマンドで gem をインストールしてください：

```bash
gem install syodosima
```

### 依存関係

このアプリケーションは以下の Ruby gem を使用しています：

#### 必須依存関係

- `discordrb` - Discord API を操作するためのライブラリ
- `google-apis-calendar_v3` - Google Calendar API を操作するためのライブラリ
- `dotenv` - 環境変数を管理するためのライブラリ

#### 開発用依存関係

- `rubocop` - Ruby コードのスタイルチェック
- `solargraph` - Ruby の言語サーバー

### ソースからの手動インストール

1. リポジトリをクローンします：

```bash
git clone https://github.com/Desert-sabaku/syodosima.git
cd syodosima
```

2. 依存関係をインストールします：

```bash
bundle install
```

## 使用方法

Syodosima は Google Calendar から今日の予定を自動的に取得し、Discord チャンネルに通知を送信します。

### 機能

- Google Calendar から今日の予定を自動取得
- 時刻付きイベントと終日イベントを適切に表示
- Discord チャンネルに通知を送信
- GitHub Actions での自動実行に対応

### 設定

#### Google Calendar API の設定

1. [Google Cloud Console](https://console.cloud.google.com/) で新しいプロジェクトを作成
2. Google Calendar API を有効化
3. 認証情報を作成（OAuth 2.0 クライアント ID）
4. `credentials.json` ファイルをダウンロード

#### Discord Bot の設定

1. [Discord Developer Portal](https://discord.com/developers/applications) で新しいアプリケーションを作成
2. Bot を作成し、トークンを取得
3. Bot をサーバーに招待し、チャンネル ID を取得

### 環境変数の設定

以下の環境変数を設定してください：

#### ローカル実行時

`.env` ファイルを作成し、以下の内容を記述：

```env
DISCORD_BOT_TOKEN=your_discord_bot_token_here
DISCORD_CHANNEL_ID=your_channel_id_here
GOOGLE_CREDENTIALS_JSON={"type":"service_account","project_id":"..."}  # credentials.jsonの内容
GOOGLE_TOKEN_YAML=credentials_yaml_content_here  # token.yamlの内容
```

#### GitHub Actions 実行時

GitHub リポジトリの Settings > Secrets and variables > Actions で以下のシークレットを設定：

- `DISCORD_BOT_TOKEN`: Discord Bot のトークン
- `DISCORD_CHANNEL_ID`: 通知を送信する Discord チャンネル ID
- `GOOGLE_CREDENTIALS_JSON`: credentials.json ファイルの内容
- `GOOGLE_TOKEN_YAML`: token.yaml ファイルの内容

### アプリケーションの実行

#### ローカル実行

1. 初回実行時は Google 認証が必要です：

```bash
bundle exec rake run:once
```

2. ブラウザで Google 認証を行い、表示されたコードをコンソールに入力
3. 認証情報が `token.yaml` に保存されます

#### GitHub Actions での自動実行

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
              run: bundle exec rake run:once
              env:
                  DISCORD_BOT_TOKEN: ${{ secrets.DISCORD_BOT_TOKEN }}
                  DISCORD_CHANNEL_ID: ${{ secrets.DISCORD_CHANNEL_ID }}
                  GOOGLE_CREDENTIALS_JSON: ${{ secrets.GOOGLE_CREDENTIALS_JSON }}
                  GOOGLE_TOKEN_YAML: ${{ secrets.GOOGLE_TOKEN_YAML }}
```

### 通知の例

Bot が送信するメッセージの例：

```text
おはようございます！
今日の予定をお知らせします。

【09:00〜10:00】 チームミーティング
【13:00〜14:00】 プロジェクトレビュー
【終日】 休日
```

### 注意事項

- 初回実行時は Google 認証が必要です
- タイムゾーンはシステムの設定に従います
- Google Calendar のプライマリカレンダーの予定のみを取得します

## 開発

リポジトリをチェックアウトした後、`bin/setup` を実行して依存関係をインストールしてください。その後、`rake test` を実行してテストを実行できます。また、`bin/console` を実行すると、実験用のインタラクティブプロンプトが利用できます。

この gem をローカルマシンにインストールするには、`bundle exec rake install` を実行してください。新バージョンをリリースするには、`version.rb` のバージョン番号を更新し、`bundle exec rake release` を実行してください。これにより、バージョン用の git タグが作成され、git コミットと作成されたタグがプッシュされ、`.gem` ファイルが [rubygems.org](https://rubygems.org) にプッシュされます。

## 貢献

バグレポートとプルリクエストは、GitHub の https://github.com/desert-sabaku/syodosima で受け付けています。このプロジェクトは、コラボレーションのための安全で歓迎的な空間となることを目的としており、貢献者は [行動規範](https://github.com/[USERNAME]/syodosima/blob/gem/CODE_OF_CONDUCT.md) を遵守することが期待されます。

## ライセンス

この gem は、[MIT License](https://opensource.org/licenses/MIT) の条件の下でオープンソースとして利用可能です。

## 行動規範

Syodosima プロジェクトのコードベース、issue トラッカー、チャットルーム、メーリングリストでやり取りするすべての人々は、[行動規範](https://github.com/[USERNAME]/syodosima/blob/gem/CODE_OF_CONDUCT.md) を遵守することが期待されます。
