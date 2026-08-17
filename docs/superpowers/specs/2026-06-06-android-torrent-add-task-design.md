# Android 种子文件添加任务设计

## 目标

在 Android 的添加任务流程中，为当前支持的三种下载器补齐 `.torrent` 文件支持：

- Aria2
- qBittorrent
- Transmission

用户选择 `.torrent` 文件后，文件只会暂存在表单状态中，真正点击 `开始下载` 时才提交到对应下载器。

## 范围

本次包含：

- Android 端添加任务页面交互
- 统一的任务提交模型
- Controller 层编排
- Service 层种子文件提交流程
- 校验、冲突处理与用户提示
- 新流程相关测试

本次不包含：

- 桌面端支持
- iOS 支持
- 种子内容预览
- 种子内文件列表选择
- 暂停启动、标签、分类、按文件选择等高级种子选项

## 用户体验

### 主流程

1. 用户进入添加任务页。
2. 用户选择下载器。
3. 用户输入链接或磁力链接，或者选择一个 `.torrent` 文件。
4. 用户可选填写保存路径。
5. 用户点击 `开始下载`。
6. 应用将任务提交到当前选择的下载器。
7. 提交成功后，沿用现有成功提示并关闭页面。

### 种子文件行为

- 选择 `.torrent` 文件后不会立即提交。
- 选择完成后，页面展示已选择的文件名。
- 页面提供一个移除已选文件的入口。
- 表单仅在内存中保存种子字节数据和展示文件名。

### 链接与种子冲突时的行为

如果用户在点击 `开始下载` 时，同时填写了链接且也选择了 `.torrent` 文件，应用弹出确认对话框，提供两个操作：

- `使用链接`
- `使用种子文件`

选择后的行为：

- 选择 `使用链接`：清空当前已选择的种子文件，继续用链接提交流程。
- 选择 `使用种子文件`：清空当前链接输入框内容，继续用种子提交流程。
- 取消对话框：本次不提交任务。

### 校验规则

- 未选择下载器时，沿用现有“必须先选择下载器”的提示。
- 链接和种子都为空时，提示新的校验文案：`请输入下载链接或选择 torrent 文件`。
- 如果用户选中了种子，但读取失败或读取结果为空，提示失败并要求重新选择。
- `savePath` 对链接和种子两种来源都保持可选。

## 架构设计

推荐采用“统一任务载荷”的方案。

这样可以尽量把来源差异收敛到数据模型和 service 层，不把不同协议的判断散落在页面逻辑里，也能给三种下载器提供一个稳定一致的提交契约。

### 新增请求模型

新增一个请求对象，例如 `AddTaskRequest`，建议字段如下：

- `String downloaderId`
- `String? url`
- `Uint8List? torrentFileBytes`
- `String? torrentFileName`
- `String? savePath`

约束规则：

- 提交时必须且只能存在一种任务来源：
  - URL 来源：`url != null && url.isNotEmpty`
  - 种子来源：`torrentFileBytes != null && torrentFileBytes.isNotEmpty`
- 当 `torrentFileBytes` 存在时，`torrentFileName` 也必须存在。

为了增强可读性，可以选配增加一个来源枚举，例如：

- `TaskSourceType.url`
- `TaskSourceType.torrentFile`

但这不是强制要求，只要请求校验足够明确即可。

## UI 设计

文件：`lib/features/add_task/presentation/pages/add_task_page.dart`

### 页面状态新增

页面需要新增以下状态：

- 已选种子的字节数据
- 已选种子的展示文件名
- 如有需要，可补充一次性文件读取失败状态用于提示

状态示例：

- `Uint8List? _torrentBytes`
- `String? _torrentFileName`

### 种子选择器行为

将当前 `_pickTorrentFile()` 的占位逻辑替换为 Android 文件选择流程。

要求：

- 只允许选择 `.torrent` 文件。
- 选择后立即把文件读入内存。
- 页面状态中只保留字节数据和文件名。
- 后续提交不依赖原始 URI 持续有效。

### 可见交互变化

保留当前上传卡片的整体结构，在此基础上增加：

- 成功选择后展示文件名
- 一个轻量的 `移除` 操作
- 未选择文件时可保留辅助说明文案

页面主 CTA 仍然保持为一个统一的 `开始下载` 按钮，链接和种子共用这一入口。

## Controller 设计

文件：`lib/features/downloaders/presentation/controllers/downloader_controller.dart`

新增统一提交流程入口，例如：

- `Future<String> addTask(AddTaskRequest request)`

职责包括：

- 根据 `downloaderId` 找到目标下载器
- 在调用 service 前做请求合法性校验
- 创建正确的下载器 service
- 将统一请求对象交给 service 层
- 记录成功与失败日志，并带上来源类型上下文
- 按当前约定返回任务 ID，失败时返回空字符串

现有 `addDownload(...)` 可以暂时保留，作为兼容包装层：内部构造 URL 类型的 `AddTaskRequest` 后转发给 `addTask(...)`。

## Service 契约

文件：`lib/services/base_downloader_service.dart`

新增统一方法，例如：

- `Future<String> addTask(AddTaskRequest request);`

兼容策略：

- 优先方案：后续所有调用统一迁移到 `addTask(...)`。
- 过渡方案：保留 `addDownload(String url, {String? savePath})`，由它作为默认包装或只保留给旧 controller 调用，直到现有调用点迁移完成。

最终目标是把“创建任务”收敛为每个下载器 service 的单一入口。

## 各下载器协议映射

### qBittorrent

文件：`lib/services/qbit_service.dart`

URL 提交流程：

- 继续使用 `POST /api/v2/torrents/add`
- 提交 `urls`
- 如有保存路径，继续带上 `savepath`

种子文件提交流程：

- 仍然使用 `POST /api/v2/torrents/add`
- 切换为 multipart 表单提交
- 通过 `torrents` 字段上传文件
- 如有保存路径，继续带上 `savepath`

说明：

- 保持现有登录与会话处理逻辑不变。
- 成功仍然以 HTTP 200 为准。
- 失败时记录状态码与响应体，便于排查。

### Transmission

文件：`lib/services/transmission_service.dart`

URL 提交流程：

- 继续使用 `torrent-add`
- 通过 `filename` 传入链接

种子文件提交流程：

- 调用 `torrent-add`
- 将种子字节做 base64 编码后，通过 `metainfo` 传入
- 如有保存路径，继续带上 `download_dir`

说明：

- 保持当前 `_call(...)` 中的会话重试逻辑。
- 返回值继续沿用现有的 `torrent_added` / `torrent_duplicate` 解析方式。

### Aria2

文件：`lib/services/aria2_service.dart`

URL 提交流程：

- 继续使用 `aria2.addUri`

种子文件提交流程：

- 调用 `aria2.addTorrent`
- 将种子内容做 base64 编码后传入
- 如有保存路径，通过 options 中的 `dir` 传递

说明：

- 保持当前 token 处理方式不变。
- 返回值继续使用 `gid`，与现有添加任务行为保持一致。

## 错误处理

### UI 层

- 用户取消文件选择：不弹 snackbar，不修改状态
- 文件读取失败：展示面向用户的失败提示
- 链接和种子都为空：阻止提交并给出校验提示
- 链接和种子同时存在：必须先完成二选一再继续提交

### Service 层

- 网络或协议错误继续按当前约定收敛为返回空字符串
- 日志中记录下载器类型、来源类型、是否带保存路径
- v1 不直接把底层协议细节原样暴露给用户

## Android 平台约束

本期仅覆盖 Android。

实现时默认以下前提成立：

- 系统文件选择器返回的是 URI，而不是稳定文件路径
- 因为选择后会立即读入字节数据，所以不需要长期持有 URI 权限
- 常见 `.torrent` 文件体积足够小，可以在 v1 中采用内存暂存方案

本次不要求对已选种子做后台持久化。

## 多语言

需要补充新的本地化文案，包括：

- 来源为空时的校验提示
- 种子读取失败提示
- 已选种子展示文案（如有需要）
- 移除文件按钮文案（如果不沿用现有通用文案）
- 冲突对话框的标题、描述和按钮文案

至少需要更新：

- `lib/l10n/app_zh.arb`
- `lib/l10n/app_en.arb`
- `lib/l10n/app_ja.arb`

之后重新生成本地化代码。

## 测试

### Controller 测试

覆盖以下场景：

- 仅 URL 请求成功
- 仅种子请求成功
- 没有来源的非法请求失败
- 如果保留兼容包装方法，验证其是否正确代理到统一入口

### Service 测试

覆盖三种下载器的协议映射：

- qBittorrent 的 URL 请求体使用 `urls`
- qBittorrent 的种子请求使用 multipart `torrents`
- Transmission 的种子请求使用 `metainfo`
- Aria2 的种子请求使用 `aria2.addTorrent`
- `savePath` 在 URL 与种子两种流程里都能正确映射

### Widget 测试

覆盖以下场景：

- 选中种子后页面展示文件名
- 移除已选种子后页面状态清空
- 同时存在链接和种子时，点击 `开始下载` 会弹出冲突选择框
- 用户做出来源选择后，会清空另一个来源并继续提交

## 实施顺序建议

1. 先补请求模型与 service 契约
2. 再让 controller 接入统一提交入口
3. 然后实现三种下载器的种子提交流程
4. 再更新 Android 添加任务页面与冲突对话框
5. 最后补多语言与测试

这样可以先把协议与边界稳定下来，再接入页面层，返工最少。

## 验收标准

- Android 用户可以在添加任务页选择 `.torrent` 文件
- 页面会在提交前展示已选种子文件名
- 点击 `开始下载` 后，Aria2、qBittorrent、Transmission 都能成功提交种子任务
- 当链接和种子同时存在时，应用会要求用户选择使用哪一种来源，并在选择后清空另一种
- 现有 URL / 磁力链接添加任务能力不回退
- 保存路径在链接和种子两种流程下都有效
- 提交失败时页面不退出，并能给用户明确反馈
