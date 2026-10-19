# 连接 Aria2

[返回首页](../../README.zh-CN.md) · [English](../aria2.md) · [故障排查](faq.md)

## 准备服务端

开启 Aria2 的 JSON-RPC 接口，检查现有 `aria2.conf`：

```ini
enable-rpc=true
rpc-listen-port=6800
rpc-secret=REPLACE_WITH_YOUR_OWN_SECRET
```

手机从另一台设备连接时，Aria2 需要监听手机可访问的网络接口。仅在你控制的网络内、通过防火墙限制访问时设置 `rpc-listen-all=true`。保留 RPC 认证；外出访问建议使用 VPN，或正确配置认证的 HTTPS 接口。现有部署可能已完成这些设置。修改后，按现有服务或容器的方式重启生效。

## 在 WindTorrent 中添加

打开「下载器 → +」，选择「Aria2」并填写：

| 字段 | 示例或说明 |
| --- | --- |
| 名称 | `家里的 Aria2` |
| 服务器地址 | `192.168.1.20`，替换为服务端实际主机名或 IP |
| 端口 | `6800`，或映射后的 RPC 端口 |
| HTTPS | 此局域网 HTTP 示例关闭；仅在接口已支持 HTTPS 时开启 |
| RPC Secret | 服务端 `rpc-secret` 的值，不加 `token:` 前缀 |

保存连接。App 自动使用 `/jsonrpc` 路径，地址栏不要填写端口、`/jsonrpc` 或完整 URL。打开 HTTPS 开关不会自动为服务端配置 TLS。

使用反向代理时，需要在主机根路径下保留 `/jsonrpc`。App 当前不能配置任意 URL 前缀。

## 确认连接

下载器应显示在线。进入任务列表，添加你有权访问的受支持链接，例如 Linux 发行版下载。文件保存在 Aria2 所在设备上，使用其默认目录或你填写的服务端保存路径。

连接失败时检查密钥、监听地址、防火墙和 Docker 端口映射。超时通常先排查网络连通性；认证失败先核对 RPC 密钥。更多说明见[故障排查](faq.md)。

参考：[Aria2 官方 RPC 配置](https://aria2.github.io/manual/en/html/aria2c.html#rpc-options)。
