# FAQ and troubleshooting

[Home](../README.md) · [简体中文](zh-CN/faq.md)

## Does WindTorrent download files onto my phone?

WindTorrent is a remote manager. You run Aria2, qBittorrent, or Transmission on another machine; that downloader transfers the files and saves them on its own filesystem. Adding a torrent file from your phone sends the torrent metadata to the selected downloader.

## Which downloader should I connect?

Connect the one you already use. Aria2 supports general file downloads as well as torrent tasks; qBittorrent and Transmission focus on BitTorrent. Available task inputs and detail views vary by downloader. WindTorrent does not provide a hosted downloader service.

Connection guides: [Aria2](aria2.md) · [qBittorrent](qbittorrent.md) · [Transmission](transmission.md).

## Why can't I connect?

Work through these checks in order:

1. Confirm the downloader is running and its RPC or WebUI interface is enabled.
2. Put the phone on a network that can reach the server. A LAN address needs the same LAN or a VPN route; `localhost` and `127.0.0.1` on your phone refer to the phone itself.
3. Check the host and the **remote management port**, including Docker port mappings. Peer ports are different.
4. Match the HTTPS switch to the actual endpoint. The switch alone does not configure server certificates or TLS.
5. Recheck the RPC secret or username/password, then firewall and access-list rules.
6. If a proxy is involved, make sure it forwards the expected API routes and headers without an interactive login page.

For qBittorrent or Transmission, opening the WebUI in the phone's browser is a useful connectivity check. Aria2's `/jsonrpc` endpoint is an API, so opening it in a browser is not a complete connection test.

## What does this error usually mean?

| Symptom | Check first |
| --- | --- |
| Timeout / connection refused | Host, port, listener, firewall, VPN route, container mapping |
| Authentication failed / `401` | RPC secret or WebUI/RPC username and password |
| `403` / `421` | Access lists, accepted hostnames, proxy restrictions, qBittorrent IP bans |
| `404` / HTML returned instead of API data | Wrong port, custom URL prefix, proxy routing, login redirect |
| TLS / certificate error | HTTPS mode, hostname, certificate trust, server certificate chain |
| Persistent Transmission `409` | Proxy forwarding of `X-Transmission-Session-Id` |

These are starting points, not a diagnosis for every deployment. Record the exact error and downloader version when reporting a problem.

## How do I enter a server URL or reverse proxy address?

Use a hostname or IP in **Server address**, fill in **Port** separately, and select **HTTPS** when appropriate. For an HTTPS endpoint at `https://downloads.example.com:443`, enter `downloads.example.com`, port `443`, and enable HTTPS.

The app builds these paths automatically:

| Downloader | Required route |
| --- | --- |
| Aria2 | `/jsonrpc` |
| qBittorrent | `/api/v2/...` |
| Transmission | `/transmission/rpc` |

Custom base paths such as `/downloads/qbittorrent/` are not configurable. Use a dedicated hostname that exposes the required routes, or connect directly over a trusted network or VPN.

## Can I use it away from home?

Yes, when the phone has a route to your downloader. A private LAN address will not work over mobile data by itself. Use a VPN into your network or an authenticated HTTPS setup. Keep credentials enabled and avoid exposing unauthenticated management ports to the internet.

## Where should the save path point?

To a directory accessible to the downloader process. In Docker, this is usually the path **inside the container**, with a volume mapped to the desired host directory. An Android folder path does not refer to the server's disk. Check directory permissions and available space on the server if adding a task fails.

## How do Free and Pro differ?

They offer the same core download management. Free can show advertising after its seven-day introductory period, subject to privacy choices. Pro is a separate paid Google Play app without advertising SDKs. Both use Firebase Analytics as described in the [privacy policy](https://hienao-apps.pages.dev/windtorrent/privacy/).

## Can I move settings between Free and Pro?

Yes. Export a local JSON backup from the existing app's **Settings → Backup & Restore**, then import it in the other edition. Both apps can be installed together. Import replaces the destination app's downloader list, so export its settings first if you need to keep them.

Backups include downloader addresses and credentials. Store them privately; do not upload them to issues. Moving settings does not move downloaded files or server-side tasks.

## Where do I install it or check for updates?

Use [Google Play Free](https://play.google.com/store/apps/details?id=com.hienao.windtorrent) or [Google Play Pro](https://play.google.com/store/apps/details?id=com.hienao.windtorrent.pro). This repository provides documentation and feedback rather than APK downloads. See [release notes](../CHANGELOG.md) for recent changes; availability may differ by region or rollout stage.

## Is WindTorrent open source?

The application is closed source. This repository contains public documentation and feedback, and accepts documentation improvements. It does not contain the application source code.

## How do I report a problem safely?

Search [existing issues](https://github.com/hienao/WindTorrent/issues) first, then use the [bug report form](https://github.com/hienao/WindTorrent/issues/new?template=bug_report.yml). Include the app version and edition, Android version, downloader type and version, network setup, steps, and exact error.

Remove passwords, tokens, server addresses, private tracker URLs, task names, and other personal data from attachments. Never attach a backup. Send sensitive details to [support](mailto:shiwentao666@gmail.com) privately.
