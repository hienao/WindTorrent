# Connect Transmission

[Home](../README.md) · [简体中文](zh-CN/transmission.md) · [Troubleshooting](faq.md)

## Prepare the server

Enable Transmission's RPC interface and configure its username, password, listening address, and port. The common RPC port is `9091`. If your deployment uses an RPC IP whitelist or host whitelist, allow the phone or VPN network and the hostname you actually use.

Setting names vary by Transmission version. Use your version's configuration documentation, and stop the daemon before editing its settings file so changes are not overwritten. Keep RPC authentication enabled and restrict network access to devices you trust.

## Add it in WindTorrent

Open **Downloaders → +**, select **Transmission**, and fill in:

| Field | Example / value |
| --- | --- |
| Name | `Home Transmission` |
| Server address | `192.168.1.20` — replace with your server's hostname or IP |
| Port | `9091`, or your mapped **RPC** port |
| HTTPS | Off for this local HTTP example; match your actual endpoint |
| Username / password | Your RPC credentials |

The RPC port is different from the BitTorrent peer port. WindTorrent appends `/transmission/rpc` and detects the legacy or modern RPC protocol automatically, including the JSON-RPC 2.0 protocol introduced in Transmission 4.1.

Enter only the hostname or IP in the address field. If you use a reverse proxy, preserve `/transmission/rpc` and allow the `X-Transmission-Session-Id` header through. Custom RPC URL prefixes are not configurable in the app.

## Check the result

Save the connection and open its task list. Test with a magnet link or torrent file you have permission to download. Transmission manages torrent tasks; a direct URL must point to torrent metadata rather than an arbitrary file. Files and save paths belong to the Transmission server.

For `401` errors, check RPC credentials. For `403` or `421`, inspect RPC access restrictions and hostname rules. A `409` response can be part of Transmission's normal session negotiation; if it persists in the app, check that your proxy forwards the session header. See [troubleshooting](faq.md).

Reference: [Transmission configuration documentation](https://github.com/transmission/transmission/blob/main/docs/Editing-Configuration-Files.md).
