# 连接 qBittorrent

[返回首页](../../README.zh-CN.md) · [English](../qbittorrent.md) · [故障排查](faq.md)

## 准备服务端

在 qBittorrent 设置中打开「Web UI」，启用远程控制，配置 WebUI 用户名和密码，并记录监听地址与端口。无桌面环境或容器部署请使用对应部署方式的 WebUI 配置。保留认证与 WebUI 安全检查。

WindTorrent 支持 qBittorrent 4.1+ 使用的 WebUI API，并自动识别 4.x 和 5.x 接口代际。遇到特定版本差异时，请在反馈中提供准确的服务端版本。

## 在 WindTorrent 中添加

打开「下载器 → +」，选择「qBittorrent」并填写：

| 字段 | 示例或说明 |
| --- | --- |
| 名称 | `家里的 qBittorrent` |
| 服务器地址 | `192.168.1.20`，替换为服务端实际主机名或 IP |
| 端口 | `8080`，或映射后的 **WebUI** 端口 |
| HTTPS | 与 WebUI 接口的实际协议一致 |
| 用户名 / 密码 | WebUI 登录凭据 |

填写 WebUI 端口，不能填写 BitTorrent 节点连接端口。Docker 部署填写宿主机发布的端口，而非容器内部端口。

地址栏仅填写主机名或 IP，App 自动添加 `/api/v2/...`。反向代理需要在主机根路径下提供这些接口；App 当前不能配置 `/qbittorrent/` 等自定义前缀。接口前的额外网页登录或交互式验证也可能阻止 App 访问。

## 确认连接

保存后进入任务列表，使用你有权下载的磁力链接或种子文件验证。qBittorrent 处理种子任务，普通文件的 HTTP 链接不会使它变成通用 HTTP 下载器。保存路径指向 qBittorrent 服务端的文件系统。

登录失败时，先在手机浏览器中使用相同凭据验证 WebUI，检查连续失败后是否触发临时 IP 封禁。代理场景出现 `403` 时，检查代理和 WebUI 的主机名、来源设置，不要直接全面关闭安全检查。更多说明见[故障排查](faq.md)。

参考：[qBittorrent 官方 WebUI API 文档](https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-%28qBittorrent-5.0%29)。
