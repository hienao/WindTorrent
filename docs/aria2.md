# Connect Aria2

[Home](../README.md) · [简体中文](zh-CN/aria2.md) · [Troubleshooting](faq.md)

## Prepare the server

Enable Aria2's JSON-RPC interface. In your existing `aria2.conf`, check:

```ini
enable-rpc=true
rpc-listen-port=6800
rpc-secret=REPLACE_WITH_YOUR_OWN_SECRET
```

If your phone connects from another device, Aria2 must listen on an interface reachable from that device. Set `rpc-listen-all=true` only within a network you control, with firewall rules restricting access. Keep RPC authenticated; use a VPN for access away from home, or a properly authenticated HTTPS endpoint. An existing deployment may already have these settings. Apply changes through your normal service or container restart process.

## Add it in WindTorrent

Open **Downloaders → +**, select **Aria2**, and fill in:

| Field | Example / value |
| --- | --- |
| Name | `Home Aria2` |
| Server address | `192.168.1.20` — replace with your server's hostname or IP |
| Port | `6800`, or your mapped RPC port |
| HTTPS | Off for this local HTTP example; on only for a working HTTPS endpoint |
| RPC Secret | The value of your server's `rpc-secret`, without a `token:` prefix |

Save the connection. WindTorrent uses `/jsonrpc` automatically. Do not enter the port, `/jsonrpc`, or a complete URL in the server address field. Selecting HTTPS does not enable TLS on the server.

For a reverse proxy, preserve `/jsonrpc` at the root of the configured host. Arbitrary URL prefixes are not configurable in the app.

## Check the result

The downloader should appear online. Open its task list and add a supported link you control, such as a Linux distribution download. The file will be saved on the Aria2 machine, using its configured destination or the server-side save path you provide.

If connection fails, check the secret, listener address, firewall, and Docker port mapping. A timeout usually calls for checking connectivity first; an authentication error calls for checking the RPC secret. See [troubleshooting](faq.md).

Reference: [Aria2 RPC options](https://aria2.github.io/manual/en/html/aria2c.html#rpc-options).
