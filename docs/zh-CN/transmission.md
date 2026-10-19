# 连接 Transmission

[返回首页](../../README.zh-CN.md) · [English](../transmission.md) · [故障排查](faq.md)

## 准备服务端

开启 Transmission RPC，配置用户名、密码、监听地址与端口。常见 RPC 端口为 `9091`。如果部署启用了 RPC IP 白名单或主机名白名单，请允许手机或 VPN 网段，以及实际使用的主机名访问。

不同版本的配置项名称可能不同，请以对应版本文档为准。直接编辑配置文件前先停止守护进程，避免修改被覆盖。保持 RPC 认证开启，并限制为可信设备访问。

## 在 WindTorrent 中添加

打开「下载器 → +」，选择「Transmission」并填写：

| 字段 | 示例或说明 |
| --- | --- |
| 名称 | `家里的 Transmission` |
| 服务器地址 | `192.168.1.20`，替换为服务端实际主机名或 IP |
| 端口 | `9091`，或映射后的 **RPC** 端口 |
| HTTPS | 此局域网 HTTP 示例关闭；以实际接口协议为准 |
| 用户名 / 密码 | RPC 登录凭据 |

RPC 端口与 BitTorrent 节点端口不同。App 自动补充 `/transmission/rpc`，并识别旧版或新版 RPC 协议，包括 Transmission 4.1 引入的 JSON-RPC 2.0 协议。

地址栏仅填写主机名或 IP。使用反向代理时，保留 `/transmission/rpc`，并允许 `X-Transmission-Session-Id` 头通过。App 当前不能配置自定义 RPC URL 前缀。

## 确认连接

保存后进入任务列表，使用你有权下载的磁力链接或种子文件验证。Transmission 处理种子任务，直接 URL 应指向种子元数据，而非任意普通文件。下载文件和保存路径均位于 Transmission 服务端。

出现 `401` 时检查 RPC 凭据；`403` 或 `421` 时检查 RPC 访问限制和主机名规则。`409` 可以是 Transmission 正常会话协商的一部分；如果 App 持续报错，请检查代理是否转发会话头。更多说明见[故障排查](faq.md)。

参考：[Transmission 官方配置文档](https://github.com/transmission/transmission/blob/main/docs/Editing-Configuration-Files.md)。
