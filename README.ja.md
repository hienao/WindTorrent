<p align="center">
  <img src="assets/readme/icon.png" width="88" height="88" alt="WindTorrent アプリのアイコン">
</p>

<h1 align="center">WindTorrent</h1>

<p align="center"><strong>複数のダウンローダーを、ひとつの Android アプリで。</strong></p>
<p align="center">スマートフォンから Aria2、qBittorrent、Transmission をまとめて管理。</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.hienao.windtorrent">Google Play で無料版を入手</a> ·
  <a href="https://play.google.com/store/apps/details?id=com.hienao.windtorrent.pro">Pro を入手</a> ·
  <a href="https://hienao-apps.pages.dev/windtorrent/">公式サイト</a>
</p>

<p align="center"><a href="README.md">English</a> · <a href="README.zh-CN.md">简体中文</a> · 日本語 · <a href="README.de.md">Deutsch</a><br>
  <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> · <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.ru.md">Русский</a></p>

WindTorrent は、NAS、サーバー、パソコンで稼働しているダウンローダーに接続するリモート管理アプリです。進捗の確認、タスクの追加、一時停止、再開をひとつの場所で行えます。ファイルのダウンロードと保存は、接続先のダウンローダーが動作する機器で行われます。

<p align="center">
  <a href="assets/readme/overview.webp"><img src="assets/readme/overview.webp" width="31%" alt="Google Play 掲載画像：ダウンローダーとタスクの概要"></a>
  <a href="assets/readme/downloaders.webp"><img src="assets/readme/downloaders.webp" width="31%" alt="Google Play 掲載画像：Aria2、qBittorrent、Transmission の接続管理"></a>
  <a href="assets/readme/tasks.webp"><img src="assets/readme/tasks.webp" width="31%" alt="Google Play 掲載画像：タスク検索、状態フィルター、ダウンロード進捗"></a>
</p>

<p align="center"><sub>公式 Google Play の英語版掲載画像です。クリックすると拡大できます。実際の画面はバージョンにより異なる場合があります。</sub></p>

## 切り替える手間を減らし、管理をもっと手軽に

- **複数のダウンローダーを一括管理。** Aria2、qBittorrent、Transmission の複数インスタンスに接続できます。
- **状況をひと目で確認。** タスクの状態、進捗、ダウンロード速度、アップロード速度を確認できます。
- **日常の操作をスムーズに。** リンクや torrent ファイルからタスクを追加し、一時停止、再開、削除できます。対応する入力形式はダウンローダーによって異なります。
- **必要なときに詳しく確認。** 対応するダウンローダーでは、ファイル、トラッカー、ピア、タスク設定を確認できます。
- **自分に合った使い方で。** テーマや言語を選び、ローカル JSON のエクスポートとインポートでダウンローダー設定を移行できます。

## 接続を始める

1. [WindTorrent Free](https://play.google.com/store/apps/details?id=com.hienao.windtorrent) または [WindTorrent Pro](https://play.google.com/store/apps/details?id=com.hienao.windtorrent.pro) をインストールします。
2. ダウンローダーのリモートインターフェースを有効にし、スマートフォンから接続できることを確認します。
3. 「ダウンローダー」で「+」をタップし、種類、ホスト、ポート、認証情報を入力します。HTTPS の設定をサーバーに合わせて保存します。

| ダウンローダー | リモートインターフェース | 一般的なポート | 接続ガイド（英語） |
| --- | --- | --- | --- |
| Aria2 | JSON-RPC | `6800` | [Aria2](docs/aria2.md) |
| qBittorrent | WebUI API | `8080` | [qBittorrent](docs/qbittorrent.md) |
| Transmission | RPC | `9091` | [Transmission](docs/transmission.md) |

Docker のポートマッピングを含め、実際に接続できるポートを指定してください。アドレス欄にはホスト名または IP アドレスを入力します。API パスはアプリが自動で補います。リバースプロキシの要件は各ガイドを参照してください。

## Free と Pro

| | WindTorrent Free | WindTorrent Pro |
| --- | --- | --- |
| 基本のダウンロード管理機能 | 利用可能 | 利用可能 |
| 広告 | 7 日間の体験期間後、プライバシー設定に応じて表示 | 広告 SDK なし |
| 購入方法 | 無料でインストール | 独立した有料アプリ |
| 入手先 | [Google Play](https://play.google.com/store/apps/details?id=com.hienao.windtorrent) | [Google Play](https://play.google.com/store/apps/details?id=com.hienao.windtorrent.pro) |

両方のアプリを同時にインストールできます。設定はローカル JSON で移行できます。Pro は個別に購入するアプリで、Free 内のアプリ内課金によるアップグレードではありません。両版とも Firebase Analytics を使用します。詳細は[プライバシーポリシー（英語・中国語）](https://hienao-apps.pages.dev/windtorrent/privacy/)をご覧ください。

## 言語とサポート

アプリの表示言語は英語、簡体字中国語、日本語です。このリポジトリの紹介ページは 8 言語で用意しています。詳細な接続ガイドと FAQ は[英語](docs/faq.md)と[簡体字中国語](docs/zh-CN/faq.md)で提供しています。

[不具合の報告](https://github.com/hienao/WindTorrent/issues/new?template=bug_report.yml)や[機能の提案](https://github.com/hienao/WindTorrent/issues/new?template=feature_request.yml)をお待ちしています。フォームと文書への貢献方法は[英語・中国語](CONTRIBUTING.md)で案内しています。[更新履歴（英語・中国語）](CHANGELOG.md)もご覧ください。

スクリーンショットやログを共有する前に、パスワード、RPC シークレット、非公開 URL、個人的なタスク情報を削除してください。バックアップには接続認証情報が含まれるため、公開 Issue に添付しないでください。機密性のある内容は[サポート窓口](mailto:shiwentao666@gmail.com)へご連絡ください。

## このリポジトリについて

ここは WindTorrent の公式ドキュメントとフィードバック用の公開リポジトリです。アプリはクローズドソースで、アプリのソースコードは含まれていません。Aria2、qBittorrent、Transmission は独立したプロジェクトであり、WindTorrent との提携関係はありません。

[公式サイト（英語・中国語）](https://hienao-apps.pages.dev/windtorrent/) · [プライバシーポリシー（英語・中国語）](https://hienao-apps.pages.dev/windtorrent/privacy/) · [サポート](mailto:shiwentao666@gmail.com)
