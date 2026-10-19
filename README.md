<p align="center">
  <img src="assets/readme/icon.png" width="88" height="88" alt="WindTorrent app icon">
</p>

<h1 align="center">WindTorrent</h1>

<p align="center"><strong>Your downloaders. One Android app.</strong></p>
<p align="center">Manage Aria2, qBittorrent, and Transmission from your phone.</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.hienao.windtorrent">Get Free on Google Play</a> ·
  <a href="https://play.google.com/store/apps/details?id=com.hienao.windtorrent.pro">Get Pro</a> ·
  <a href="https://hienao-apps.pages.dev/windtorrent/">Website</a>
</p>

<p align="center">English · <a href="README.zh-CN.md">简体中文</a></p>

WindTorrent connects to downloaders you already run on a NAS, server, or computer. Check progress, add tasks, and pause or resume downloads from one place. Files are downloaded by your connected downloader and saved on that machine.

<p align="center">
  <a href="assets/readme/overview.webp"><img src="assets/readme/overview.webp" width="31%" alt="Google Play preview of WindTorrent's downloader and task overview"></a>
  <a href="assets/readme/downloaders.webp"><img src="assets/readme/downloaders.webp" width="31%" alt="Google Play preview of Aria2, qBittorrent, and Transmission connections"></a>
  <a href="assets/readme/tasks.webp"><img src="assets/readme/tasks.webp" width="31%" alt="Google Play preview of task search, status filters, and download progress"></a>
</p>

<p align="center"><sub>Official Google Play preview images. Tap an image to view it larger; the installed version may look different.</sub></p>

## Less switching, more control

- **Keep your downloaders together.** Connect multiple Aria2, qBittorrent, and Transmission instances.
- **See what's happening.** Review task status, progress, download speed, and upload speed.
- **Handle everyday tasks.** Add links or torrent files, then pause, resume, or remove tasks. Accepted inputs depend on the downloader.
- **Look closer when needed.** Inspect task details, with downloader-specific views for files, trackers, peers, and options where supported.
- **Make it yours.** Choose a theme and language, and move downloader settings with local JSON export and import.

## Get connected

1. Install [WindTorrent Free](https://play.google.com/store/apps/details?id=com.hienao.windtorrent) or [WindTorrent Pro](https://play.google.com/store/apps/details?id=com.hienao.windtorrent.pro).
2. Enable your downloader's remote interface and make sure your phone can reach it.
3. Open **Downloaders**, tap **+**, choose the downloader type, and enter its host, port, and credentials. Match the HTTPS switch to your server, then save.

| Downloader | Remote interface | Common port | Connection guide |
| --- | --- | --- | --- |
| Aria2 | JSON-RPC | `6800` | [Connect Aria2](docs/aria2.md) |
| qBittorrent | WebUI API | `8080` | [Connect qBittorrent](docs/qbittorrent.md) |
| Transmission | RPC | `9091` | [Connect Transmission](docs/transmission.md) |

Use your actual externally reachable port, including any Docker port mapping. Enter a hostname or IP in the address field; the app adds the API path automatically. See the guides for examples and reverse proxy requirements.

## Free or Pro?

| | WindTorrent Free | WindTorrent Pro |
| --- | --- | --- |
| Core download management | Included | Included |
| Advertising | After a seven-day introductory period, subject to privacy choices | No advertising SDK |
| Purchase | Free to install | Separate paid app |
| Install | [Google Play](https://play.google.com/store/apps/details?id=com.hienao.windtorrent) | [Google Play](https://play.google.com/store/apps/details?id=com.hienao.windtorrent.pro) |

Both editions can be installed together. Use local JSON export and import to transfer downloader settings. Pro is a separate app purchase, rather than an in-app upgrade. Both editions use Firebase Analytics; see the [privacy policy](https://hienao-apps.pages.dev/windtorrent/privacy/) for details.

## Help shape WindTorrent

Read the [FAQ and troubleshooting guide](docs/faq.md), [report a problem](https://github.com/hienao/WindTorrent/issues/new?template=bug_report.yml), or [suggest a feature](https://github.com/hienao/WindTorrent/issues/new?template=feature_request.yml). English and Chinese reports are welcome. Documentation corrections are welcome through pull requests; see [how to contribute](CONTRIBUTING.md).

Please remove passwords, RPC secrets, private URLs, and personal task information before sharing screenshots or logs. Backup files contain connection credentials and must not be attached to public issues. For sensitive reports, contact [support by email](mailto:shiwentao666@gmail.com).

See [release notes](CHANGELOG.md) for recent changes. If WindTorrent is useful to you, a star helps other users find this project.

## About this repository

This is the official public home for WindTorrent's documentation and feedback. The application is closed source; its source code is not distributed in this repository. Aria2, qBittorrent, and Transmission are separate projects and are not affiliated with WindTorrent.

[Website](https://hienao-apps.pages.dev/windtorrent/) · [Privacy policy](https://hienao-apps.pages.dev/windtorrent/privacy/) · [Support](mailto:shiwentao666@gmail.com)
