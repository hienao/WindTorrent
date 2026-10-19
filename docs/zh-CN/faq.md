# 常见问题与故障排查

[返回首页](../../README.zh-CN.md) · [English](../faq.md)

## 文件会下载到手机吗？

WindTorrent 是远程管理工具。Aria2、qBittorrent 或 Transmission 运行在另一台设备上，负责实际下载并保存文件。从手机选择种子文件时，上传的是种子元数据，任务由所选下载器执行。

## 应该连接哪种下载器？

连接你已经使用的下载器即可。Aria2 支持普通文件下载和种子任务；qBittorrent 与 Transmission 专注 BitTorrent。可用输入类型和详情页面随下载器不同而变化。WindTorrent 不提供托管下载服务。

连接指南：[Aria2](aria2.md) · [qBittorrent](qbittorrent.md) · [Transmission](transmission.md)。

## 为什么连接不上？

建议按顺序检查：

1. 下载器正在运行，RPC 或 WebUI 接口已开启。
2. 手机所在网络能访问服务器。局域网地址需要同一局域网或 VPN 路由；手机上的 `localhost`、`127.0.0.1` 指向手机自身。
3. 地址与**远程管理端口**正确，包括 Docker 端口映射；不要填写节点连接端口。
4. HTTPS 开关与接口协议一致。这个开关不会自动配置服务端证书或 TLS。
5. RPC 密钥、用户名和密码正确，防火墙与访问白名单允许连接。
6. 使用代理时，确认接口路径与必要的请求头可以通过，且没有额外的交互式登录页面。

qBittorrent 和 Transmission 可以先在手机浏览器访问 WebUI 验证连通性。Aria2 的 `/jsonrpc` 是 API，直接在浏览器打开不等于完成连接测试。

## 不同报错先查什么？

| 现象 | 优先检查 |
| --- | --- |
| 超时 / 拒绝连接 | 地址、端口、监听接口、防火墙、VPN 路由、容器映射 |
| 认证失败 / `401` | RPC 密钥或 WebUI/RPC 用户名与密码 |
| `403` / `421` | 访问白名单、允许的主机名、代理限制、qBittorrent IP 封禁 |
| `404` / 返回 HTML 而非 API 数据 | 错误端口、自定义 URL 前缀、代理路由、登录跳转 |
| TLS / 证书错误 | HTTPS 开关、主机名、证书信任与证书链 |
| Transmission 持续 `409` | 代理是否转发 `X-Transmission-Session-Id` |

表格提供排查起点，不能代替对具体部署的诊断。反馈时请记录准确的错误和下载器版本。

## 完整 URL 或反向代理地址怎么填？

「服务器地址」填写主机名或 IP，「端口」单独填写，并按需打开「HTTPS」。例如接口为 `https://downloads.example.com:443`，填写 `downloads.example.com`、端口 `443`，开启 HTTPS。

App 自动拼接以下路径：

| 下载器 | 需要提供的接口路径 |
| --- | --- |
| Aria2 | `/jsonrpc` |
| qBittorrent | `/api/v2/...` |
| Transmission | `/transmission/rpc` |

当前不能配置 `/downloads/qbittorrent/` 等自定义前缀。可以使用独立主机名提供对应路径，或通过可信网络、VPN 直接连接。

## 外出时可以使用吗？

可以，前提是手机能够访问下载器所在网络。仅填写局域网 IP 无法直接从移动网络连接。可通过 VPN 回到家庭网络，或配置带认证的 HTTPS 接口。保留认证，避免将未认证的管理端口暴露到公网。

## 保存路径应该填写哪里？

填写下载器进程能够访问的目录。Docker 场景通常填写**容器内路径**，并将它映射到期望的宿主机目录。手机上的 Android 文件路径不代表服务器磁盘。添加任务失败时检查服务端目录权限和剩余空间。

## Free 与 Pro 有什么区别？

核心下载管理功能相同。Free 在七天体验期后按隐私选择展示广告；Pro 为 Google Play 上单独购买的付费应用，不包含广告 SDK。两个版本均使用 Firebase Analytics，详见[隐私政策](https://hienao-apps.pages.dev/windtorrent/privacy/)。

## 可以在 Free 与 Pro 之间迁移配置吗？

可以。在原 App 的「设置 → 备份与恢复」导出本地 JSON，再到另一版本导入。两个版本可以同时安装。导入会替换目标 App 的下载器列表，需要保留原配置时请先导出。

备份包含下载器地址与连接凭据，请私密保存，不要上传到 Issue。迁移配置不会搬移已下载文件或服务端任务。

## 从哪里安装和更新？

通过 [Google Play Free](https://play.google.com/store/apps/details?id=com.hienao.windtorrent) 或 [Google Play Pro](https://play.google.com/store/apps/details?id=com.hienao.windtorrent.pro)。本仓库提供文档和反馈入口，不提供 APK 下载。近期改进见[更新记录](../../CHANGELOG.md)；实际可用版本可能因地区或分批发布而不同。

## WindTorrent 开源吗？

App 目前为闭源应用。本仓库公开文档与用户反馈，欢迎改进文档，不包含应用源码。

## 怎样安全地报告问题？

先搜索[已有 Issue](https://github.com/hienao/WindTorrent/issues)，再填写[问题反馈表](https://github.com/hienao/WindTorrent/issues/new?template=bug_report.yml)。提供 App 版本与 Free/Pro、Android 版本、下载器类型与版本、网络部署方式、复现步骤和准确错误。

附件中请移除密码、令牌、服务器地址、私有 Tracker 链接、任务名称等个人信息。不要上传备份文件。敏感信息请通过[支持邮箱](mailto:shiwentao666@gmail.com)私下联系。
