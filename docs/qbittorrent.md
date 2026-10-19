# Connect qBittorrent

[Home](../README.md) · [简体中文](zh-CN/qbittorrent.md) · [Troubleshooting](faq.md)

## Prepare the server

In qBittorrent's settings, open **Web UI** and enable the remote control interface. Set a WebUI username and password, then note the listening address and port. With a headless or container deployment, use that deployment's WebUI configuration. Keep authentication and the WebUI security checks enabled.

WindTorrent supports the WebUI API used by qBittorrent 4.1+ and detects the 4.x or 5.x API generation automatically. If a particular server version behaves differently, include its exact version in a report.

## Add it in WindTorrent

Open **Downloaders → +**, select **qBittorrent**, and fill in:

| Field | Example / value |
| --- | --- |
| Name | `Home qBittorrent` |
| Server address | `192.168.1.20` — replace with your server's hostname or IP |
| Port | `8080`, or your mapped **WebUI** port |
| HTTPS | Match the protocol used by the WebUI endpoint |
| Username / password | Your WebUI credentials |

Use the WebUI port, not the BitTorrent peer port. For Docker, use the host's published port rather than the container's internal port.

Enter only the hostname or IP in the address field. WindTorrent adds `/api/v2/...` itself. A reverse proxy must expose those API routes at the host root; custom prefixes such as `/qbittorrent/` are not configurable in the app. An extra browser login page or interactive access challenge in front of the API can also block the app.

## Check the result

Save the connection and open its task list. Try a magnet link or torrent file you have permission to download. qBittorrent handles torrent tasks; an HTTP link to an arbitrary file does not turn it into a general HTTP downloader. Save paths refer to the qBittorrent server's filesystem.

If login fails, first verify the same credentials in the WebUI using your phone's browser. Check for temporary IP bans after repeated failures. For proxy-related `403` errors, inspect the proxy and WebUI host/origin settings rather than turning off security checks broadly. See [troubleshooting](faq.md).

Reference: [qBittorrent WebUI API documentation](https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-%28qBittorrent-5.0%29).
