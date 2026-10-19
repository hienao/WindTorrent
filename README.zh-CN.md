<p align="center">
  <img src="assets/readme/icon.png" width="88" height="88" alt="WindTorrent 应用图标">
</p>

<h1 align="center">WindTorrent</h1>

<p align="center"><strong>一个 App，管理你的多个下载器。</strong></p>
<p align="center">在 Android 上统一管理 Aria2、qBittorrent 和 Transmission。</p>

<p align="center">
  <a href="https://play.google.com/store/apps/details?id=com.hienao.windtorrent">获取免费版</a> ·
  <a href="https://play.google.com/store/apps/details?id=com.hienao.windtorrent.pro">获取 Pro</a> ·
  <a href="https://hienao-apps.pages.dev/windtorrent/">官方网站</a>
</p>

<p align="center"><a href="README.md">English</a> · 简体中文 · <a href="README.ja.md">日本語</a> · <a href="README.de.md">Deutsch</a><br>
  <a href="README.es.md">Español</a> · <a href="README.fr.md">Français</a> · <a href="README.pt-BR.md">Português (Brasil)</a> · <a href="README.ru.md">Русский</a></p>

WindTorrent 连接你已经部署在 NAS、服务器或电脑上的下载器。在手机上查看进度、添加任务、暂停和继续下载。文件由连接的下载器下载，并保存在下载器所在的设备上。

<p align="center">
  <a href="assets/readme/overview.webp"><img src="assets/readme/overview.webp" width="31%" alt="Google Play 展示图：下载器和任务总览"></a>
  <a href="assets/readme/downloaders.webp"><img src="assets/readme/downloaders.webp" width="31%" alt="Google Play 展示图：Aria2、qBittorrent 和 Transmission 连接管理"></a>
  <a href="assets/readme/tasks.webp"><img src="assets/readme/tasks.webp" width="31%" alt="Google Play 展示图：任务搜索、状态筛选和下载进度"></a>
</p>

<p align="center"><sub>以上为官方 Google Play 展示图，点击可查看大图；实际界面可能随版本更新调整。</sub></p>

## 少些切换，管理更从容

- **多个下载器，一处管理。** 添加多个 Aria2、qBittorrent 和 Transmission 实例。
- **任务状态一目了然。** 查看进度、下载速度、上传速度和运行状态。
- **常用操作随手完成。** 添加链接或种子文件，暂停、继续和删除任务；可用输入类型取决于下载器。
- **需要时，查看更多细节。** 查看任务详情，并在支持的下载器中查看文件、Tracker、节点和任务选项。
- **按习惯使用。** 切换主题和语言，通过本地 JSON 导出、导入迁移下载器配置。

## 三步开始使用

1. 安装 [WindTorrent Free](https://play.google.com/store/apps/details?id=com.hienao.windtorrent) 或 [WindTorrent Pro](https://play.google.com/store/apps/details?id=com.hienao.windtorrent.pro)。
2. 为下载器开启远程接口，确认手机能够访问它。
3. 打开「下载器」，点击「+」，选择类型并填写地址、端口和认证信息，按服务端配置设置 HTTPS 后保存。

| 下载器 | 远程接口 | 常见端口 | 连接指南 |
| --- | --- | --- | --- |
| Aria2 | JSON-RPC | `6800` | [连接 Aria2](docs/zh-CN/aria2.md) |
| qBittorrent | WebUI API | `8080` | [连接 qBittorrent](docs/zh-CN/qbittorrent.md) |
| Transmission | RPC | `9091` | [连接 Transmission](docs/zh-CN/transmission.md) |

端口以实际可访问的配置为准，Docker 部署请填写映射后的端口。地址栏填写主机名或 IP，App 会自动补充接口路径。示例和反向代理要求见各连接指南。

## Free 与 Pro 怎么选？

| | WindTorrent Free | WindTorrent Pro |
| --- | --- | --- |
| 核心下载管理 | 完整提供 | 完整提供 |
| 广告 | 七天体验期后按隐私选择展示 | 不包含广告 SDK |
| 购买方式 | 免费安装 | 独立付费应用 |
| 安装入口 | [Google Play](https://play.google.com/store/apps/details?id=com.hienao.windtorrent) | [Google Play](https://play.google.com/store/apps/details?id=com.hienao.windtorrent.pro) |

两个版本可以同时安装，通过本地 JSON 导出、导入迁移下载器配置。Pro 需要单独购买，不通过 Free 内购升级。两个版本均使用 Firebase Analytics，详见[隐私政策](https://hienao-apps.pages.dev/windtorrent/privacy/)。

## 语言支持

App 界面目前支持英文、简体中文和日文。仓库介绍提供八种语言；详细连接指南和 FAQ 提供[英文](docs/faq.md)与[简体中文](docs/zh-CN/faq.md)。

## 一起改进 WindTorrent

先查看[常见问题与故障排查](docs/zh-CN/faq.md)，也可以[报告问题](https://github.com/hienao/WindTorrent/issues/new?template=bug_report.yml)或[提出功能建议](https://github.com/hienao/WindTorrent/issues/new?template=feature_request.yml)。欢迎使用中文或英文。文档改进可以提交 PR，详见[参与方式](CONTRIBUTING.md)。

分享截图或日志前，请移除密码、RPC 密钥、私有链接和个人任务信息。备份包含连接凭据，请勿上传到公开 Issue。敏感问题请通过[支持邮箱](mailto:shiwentao666@gmail.com)联系。

[更新记录](CHANGELOG.md)包含近期改进。如果 WindTorrent 对你有帮助，欢迎点亮 Star，方便更多用户发现它。

## 关于这个仓库

这里是 WindTorrent 官方公开的文档与反馈仓库。App 目前为闭源应用，本仓库不分发应用源码。Aria2、qBittorrent 和 Transmission 是独立项目，与 WindTorrent 无隶属关系。

[官方网站](https://hienao-apps.pages.dev/windtorrent/) · [隐私政策](https://hienao-apps.pages.dev/windtorrent/privacy/) · [联系支持](mailto:shiwentao666@gmail.com)
