# Syodosima

Syodosima gem は、指定された Google Calendar の予定を Discord に通知するツールおよびその CLI ラッパーです。

## インストール

gem をインストールし、アプリケーションの Gemfile に追加するには、以下のコマンドを実行してください：

```bash
bundle add syodosima
```

Bundler を使用して依存関係を管理していない場合は、以下のコマンドで gem をインストールしてください：

```bash
gem install syodosima
```

手動でインストールする場合は、以下の手順に従ってください。

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

-   Google Calendar から今日の予定を自動取得
-   時刻付きイベントと終日イベントを適切に表示
-   Discord チャンネルに通知を送信
-   GitHub Actions での自動実行に対応

### 設定

#### Google Calendar API の設定

1. [Google Cloud Console](https://console.cloud.google.com/) で新しいプロジェクトを作成
2. Google Calendar API を有効化
3. 認証情報を作成（OAuth 2.0 クライアント ID）
4. OAuth クライアント認証情報の JSON をダウンロード

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
# Google Cloud Console からダウンロードした OAuth クライアント認証情報の JSON を貼り付けてください
GOOGLE_CREDENTIALS_JSON={"installed":{"client_id":"...","client_secret":"...","redirect_uris":["http://localhost"]}}
```

> [!IMPORTANT]
> 初回実行時のみブラウザ認証が必要です。認証後、トークン情報が表示されるので、
> それを`.env`ファイルの`GOOGLE_TOKEN_YAML_BASE64`として保存してください。

#### GitHub Actions 実行時

GitHub リポジトリの Settings > Secrets and variables > Actions で以下のシークレットを設定：

-   `DISCORD_BOT_TOKEN`: Discord Bot のトークン
-   `DISCORD_CHANNEL_ID`: 通知を送信する Discord チャンネル ID
-   `GOOGLE_CREDENTIALS_JSON`: Google Cloud Console からの OAuth クライアント認証情報 JSON
-   `GOOGLE_TOKEN_YAML_BASE64`: 初回認証後に表示される Base64 エンコードされたトークン

### アプリケーションの実行

#### ローカル実行

**初回実行（ブラウザ認証が必要）：**

```bash
bundle exec rake run:once
```

ブラウザで認証を行うと、コンソールに以下のようなトークン情報が表示されます：

```
======================================================================
認証が完了しました。以下のトークンを.envファイルに保存してください：
----------------------------------------------------------------------
GOOGLE_TOKEN_YAML_BASE64=LS0tCmRlZmF1bHQ6IC4uLg==
----------------------------------------------------------------------

.envファイルに自動で保存しますか？ (y/N):
======================================================================
```

`y`を入力すると自動的に`.env`ファイルに保存されます。
`N`を入力した場合や手動で保存したい場合は、表示された`GOOGLE_TOKEN_YAML_BASE64=...`の行を`.env`ファイルに追加してください。

**2 回目以降の実行（再認証不要）：**

```bash
bundle exec rake run:once
```

**特定の日付の予定を取得する場合：**

```bash
DATE=2025-12-25 bundle exec rake run:date
```

> [!IMPORTANT]
> `.env`ファイルに`GOOGLE_TOKEN_YAML_BASE64`を設定すれば、以降はブラウザ認証なしで実行できます。

> [!TIP]
> Discord ライブラリからの websocket 関連のログメッセージを非表示にしたい場合は、grep でフィルタリングできます：
>
> ```bash
> bundle exec rake run:once 2>&1 | grep -v '\[.*websocket\|et-[0-9]\+'
> ```
>
> これらのログは無害ですが、出力をクリーンに保ちたい場合に有用です。

**irb での実行**

gem としてインストールした場合：

```bash
irb
irb(main):001> require "syodosima"
=> true
irb(main):002> Syodosima.run                              # 今日の予定
irb(main):003> Syodosima.run(Date.new(2025, 12, 25))      # 特定の日付
```

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
今日の予定をお知らせします。

【09:00〜10:00】 チームミーティング
【13:00〜14:00】 プロジェクトレビュー
【終日】 休日
```

### 注意事項

-   初回実行時は Google 認証が必要です
-   タイムゾーンはシステムの設定に従います
-   Google Calendar のプライマリカレンダーの予定のみを取得します

## 開発

リポジトリをチェックアウトした後、`bin/setup` を実行して依存関係をインストールしてください。その後、`rake test` を実行してテストを実行できます。また、`bin/console` を実行すると、実験用のインタラクティブプロンプトが利用できます。

この gem をローカルマシンにインストールするには、`bundle exec rake install` を実行してください。新バージョンをリリースするには、`version.rb` のバージョン番号を更新し、`bundle exec rake release` を実行してください。これにより、バージョン用の git タグが作成され、git コミットと作成されたタグがプッシュされ、`.gem` ファイルが [rubygems.org](https://rubygems.org) にプッシュされます。

## 貢献

Bug report と Pull Request は、GitHub の [Desert-sabaku/syodosima](https://github.com/Desert-sabaku/syodosima) で受け付けています。このプロジェクトは、コラボレーションのための安全で歓迎的な空間となることを目的としており、貢献者は [行動規範](https://github.com/Desert-sabaku/syodosima/blob/main/CODE_OF_CONDUCT.md) を遵守することが期待されます。

## ライセンス

この gem は、[MIT License](https://opensource.org/licenses/MIT) の条件の下でオープンソースとして利用可能です。
