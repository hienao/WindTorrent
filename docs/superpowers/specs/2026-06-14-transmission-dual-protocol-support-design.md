# Transmission 新旧协议双栈支持设计

## 目标

让当前 app 在**保持对用户透明**的前提下，同时支持：

- Transmission `4.1.0+`
- Transmission `4.1.0` 以下旧版本

支持范围以当前 app 已有的 Transmission 主要功能为准：

- 连接测试
- 任务列表
- 任务详情
- 添加任务（URL / torrent 文件）
- 暂停 / 恢复
- 删除任务
- 读取 / 设置限速

目标不是“放宽版本门禁”，而是让上述功能在新旧协议下都能稳定工作。

## 背景

当前 [TransmissionService](/Volumes/Data/Code/GitHub/WindWalker/lib/services/transmission_service.dart) 已按 `4.1.0+` 路径实现：

- 请求格式：JSON-RPC 2.0
- 方法名：snake_case，例如 `session_get` / `torrent_add`
- 响应载体：`result`
- 字段名：snake_case，例如 `hash_string` / `total_size` / `alt_speed_enabled`

而 `4.1.0` 以下旧版本使用的是另一套 RPC 风格：

- 请求格式：legacy RPC
- 方法名：kebab-case，例如 `session-get` / `torrent-add`
- 响应载体：`result: "success"` + `arguments`
- 字段名：旧命名风格，例如 `hashString` / `totalSize` / `alt-speed-enabled`

这不是单一字段兼容问题，而是**协议、方法名、字段名、响应结构**同时分叉。继续在单个 service 方法里堆条件判断，维护成本会快速上升。

## 设计原则

- **用户无感**：下载器类型仍然只有一个 `Transmission`，不新增“Transmission 旧版”入口。
- **协议差异收敛到内部**：controller、UI、`DownloaderService` 抽象层不感知新旧协议。
- **以能力可用为准**：连接成功不代表支持；如果旧版本缺失主功能所需能力，应在添加 / 编辑时明确拒绝。
- **现代协议优先**：优先尝试 `4.1.0+` 路径，失败后再回退旧协议探测。
- **统一领域输出**：不把原始协议字段泄漏到 service 外部，上层继续只消费 `DownloadTask`、`DownloaderSpeedConfig` 等统一模型。

## 范围

本次包含：

- Transmission 自动协议识别
- `TransmissionService` 内部协议分层
- modern / legacy 两套 adapter
- Transmission `testConnection()` 从“版本硬门禁”改为“协议识别 + 能力校验”
- Transmission 主要功能双栈兼容
- 单元测试补齐 detector、adapter、facade 三层

本次不包含：

- 新增 UI 配置项让用户手动选择协议
- 变更其他下载器（Aria2 / qBittorrent）的兼容策略
- 对极老旧、关键字段缺失的 Transmission 版本做降级部分支持
- 后台轮询逻辑的大规模重构

## 方案选择

### 推荐方案：统一门面 + 双协议 adapter

保留对外唯一的 `TransmissionService`，内部拆成三层：

1. `TransmissionProtocolDetector`
2. `TransmissionRpcAdapter` 抽象接口
3. `TransmissionModernRpcAdapter` / `TransmissionLegacyRpcAdapter`

优点：

- 协议差异被限定在 adapter 层
- 对 controller / UI 侵入最小
- 便于为 modern / legacy 分别补充完整测试
- 后续若某个旧版行为有特例，只需修改 legacy adapter

### 不选方案：单类自适应

在现有 `TransmissionService` 每个方法里写 `if (legacy) ... else ...`。

问题：

- 协议分支会散落到所有业务方法
- 测试需要覆盖每个方法的每个分支
- 后续继续演进时非常容易出现同一字段在不同方法里兼容不一致

### 不选方案：拆成两个下载器类型

把 Transmission 拆成“新版”和“旧版”两个下载器类型。

问题：

- 与“用户无感”目标冲突
- 增加 UI 和存量数据复杂度
- 协议知识泄漏到产品层

## 架构设计

### 对外边界

对外仍保留：

- `DownloaderType.transmission`
- `DownloaderController` 创建 `TransmissionService`
- `TransmissionService extends DownloaderService`

也就是说，controller、UI、模型层不需要知道是否是 modern 或 legacy。

### 内部结构

#### `TransmissionProtocolDetector`

职责：

- 建立首次握手
- 自动识别服务器协议类型
- 解析应用版本与协议版本
- 产出结构化探测结果

建议结果对象：

```dart
enum TransmissionProtocol { modern, legacy }

class TransmissionProtocolInfo {
  const TransmissionProtocolInfo({
    required this.protocol,
    required this.appVersion,
    this.rpcSemver,
    this.rpcVersion,
    this.sessionId,
  });

  final TransmissionProtocol protocol;
  final String appVersion;
  final String? rpcSemver;
  final int? rpcVersion;
  final String? sessionId;
}
```

#### `TransmissionRpcAdapter`

职责：

- 对外暴露统一能力接口
- 内部处理方法名、字段名、响应载体的协议差异

建议接口：

```dart
abstract class TransmissionRpcAdapter {
  Future<ConnectionResult> testConnection();
  Future<List<DownloadTask>> getTasks();
  Future<DownloadTask?> getTaskDetail(String taskId);
  Future<Map<String, dynamic>> getGlobalStat();
  Future<String> addTask(AddTaskRequest request);
  Future<void> pauseTask(String taskId);
  Future<void> resumeTask(String taskId);
  Future<void> removeTask(String taskId, {bool deleteFiles = false});
  Future<DownloaderSpeedConfig> getSpeedConfig();
  Future<bool> setSpeedConfig(DownloaderSpeedConfig config);
}
```

#### `TransmissionModernRpcAdapter`

负责：

- JSON-RPC 2.0 请求构造
- `result` 响应解析
- snake_case 字段映射

#### `TransmissionLegacyRpcAdapter`

负责：

- legacy RPC 请求构造
- `result: "success" + arguments` 响应解析
- legacy 方法名与字段名映射

### `TransmissionService` 的新角色

`TransmissionService` 不再直接承担全部协议细节，而是作为门面：

1. 首次使用时通过 detector 完成协议识别
2. 根据结果实例化并缓存对应 adapter
3. 后续所有业务调用委托给 adapter
4. 向 controller / UI 维持现有统一接口

## 自动识别与握手流程

识别顺序采用“**modern 优先，legacy 回退**”。

### 第一步：现代协议探测

先发送现代协议 `session_get`：

```json
{
  "jsonrpc": "2.0",
  "method": "session_get",
  "id": 1
}
```

沿用现有 `409 -> 读取 X-Transmission-Session-Id -> 重试` 流程。

### 第二步：识别 modern

若满足以下任一条件，判定为 `modern`：

- 响应包含 `jsonrpc == "2.0"` 且 `result` 为对象
- `result` 中出现 `rpc_version_semver`
- `result` 中出现 snake_case 字段，如 `download_dir`、`alt_speed_enabled`

### 第三步：识别 legacy

若现代请求返回旧协议形态，也允许直接判定为 `legacy`，例如：

```json
{
  "result": "success",
  "arguments": { ... }
}
```

或 `arguments` 中出现以下旧风格特征字段：

- `rpc-version-semver`
- `hashString`
- `downloadDir`
- `alt-speed-enabled`

### 第四步：显式旧协议回退探测

如果现代协议请求失败，再发送 legacy `session-get`：

```json
{
  "method": "session-get",
  "tag": 1
}
```

若返回 `result: "success"` 与 `arguments`，则确认 `legacy`。

### 第五步：失败归类

只有 modern 和 legacy 两轮都失败时，才返回连接失败：

- `401` / 认证问题 -> `authFailed`
- 网络错误 / 超时 -> `networkError`
- 有响应但无法判定协议或关键字段异常 -> `unknown`

## 能力校验策略

`4.1.0` 以下旧版本不再因为“版本低于 4.1.0”被一刀切拒绝。

但为了满足“主要功能都可用”的目标，`testConnection()` 必须在协议识别成功后继续做**能力校验**。判定标准不是“能连上”，而是“主功能链条能成立”。

校验原则：

- modern：保持当前主路径，只需验证关键字段可读取
- legacy：必须验证主功能所需关键方法和字段可工作
- 如果某个旧版本过旧，缺失主功能必需字段或方法，则统一返回 `ConnectionFailure(versionUnsupported)`；`unknown` 仅用于响应格式损坏、关键结构无法解析等非预期协议异常

最低要求不是硬编码成 `4.1.0`，而是由能力是否完整决定。

## 主要功能的协议映射

### 1. 连接测试与版本显示

- modern：
  - 应用版本来自 `result.version`
  - 协议版本来自 `result.rpc_version_semver`
- legacy：
  - 应用版本来自 `arguments.version`
  - 协议版本优先取 `arguments.rpc-version-semver`
  - 若缺失 semver，则退化读取 `rpc-version`

对上层统一只暴露应用版本，如 `4.0.5`、`4.1.2`。

### 2. 任务列表与详情

modern `fields`：

- `id`
- `hash_string`
- `name`
- `total_size`
- `percent_done`
- `rate_download`
- `rate_upload`
- `status`
- `eta`
- `peers_sending_to_us`
- `peers_getting_from_us`
- `added_date`
- `done_date`
- `download_dir`

legacy 对应字段：

- `id`
- `hashString`
- `name`
- `totalSize`
- `percentDone`
- `rateDownload`
- `rateUpload`
- `status`
- `eta`
- `peersSendingToUs`
- `peersGettingFromUs`
- `addedDate`
- `doneDate`
- `downloadDir`

adapter 负责把两边都转换成同一个 `DownloadTask`。

### 3. 添加任务

modern：

- 方法：`torrent_add`
- 参数：`filename` / `metainfo` / `download_dir`
- 响应：`torrent_added` / `torrent_duplicate`

legacy：

- 方法：`torrent-add`
- 参数：`filename` / `metainfo` / `download-dir`
- 响应：`torrent-added` / `torrent-duplicate`

对上层统一只返回任务 id 字符串。

### 4. 暂停 / 恢复 / 删除

modern：

- `torrent_stop`
- `torrent_start`
- `torrent_remove`
- 删除参数：`delete_local_data`

legacy：

- `torrent-stop`
- `torrent-start`
- `torrent-remove`
- 删除参数：`delete-local-data`

### 5. 限速配置

modern 使用：

- `session_get`
- `session_set`
- `alt_speed_enabled`
- `speed_limit_down`
- `speed_limit_up`
- `alt_speed_down`
- `alt_speed_up`

legacy 使用：

- `session-get`
- `session-set`
- `alt-speed-enabled`
- `speed-limit-down`
- `speed-limit-up`
- `alt-speed-down`
- `alt-speed-up`

两边统一映射成 `DownloaderSpeedConfig`。

### 6. 全局统计

modern：

- `session_stats`
- snake_case 结果字段

legacy：

- `session-stats`
- 旧字段风格

建议 adapter 内部统一输出当前 controller 期望的语义 key，例如：

- `downloadSpeed`
- `uploadSpeed`
- `torrentCount`

避免把协议字段继续暴露到 controller 层。

## 缓存与重试策略

### 缓存内容

`TransmissionService` 实例内缓存：

- `TransmissionProtocolInfo`
- `TransmissionRpcAdapter`
- `sessionId`

### 重新识别时机

仅在以下情况允许重新探测：

- 当前尚未识别过协议
- 已缓存 adapter，但收到明显不符合当前协议的响应

### 限制

- `409` 仅刷新 session，不重新切协议
- 协议重探测最多执行一次，避免无限循环
- 同一个 service 生命周期内，协议类型不应频繁来回切换

## 错误处理

连接失败分类保持与现有 `ConnectionResult` 一致：

- `authFailed`
- `networkError`
- `unknown`

额外约束：

- 对于“协议识别成功但能力校验失败”的旧版本，返回明确失败，不允许像现在这样先保存再在运行时出错
- 错误信息应能区分：
  - 地址 / 端口 / 网络问题
  - 用户名 / 密码问题
  - 服务器协议过旧或能力不足

## 对现有代码的改动建议

### `lib/services/transmission_service.dart`

重构为 facade，不再直接实现所有协议细节。

### 新增内部文件

建议新增：

- `lib/services/transmission/transmission_protocol_detector.dart`
- `lib/services/transmission/transmission_protocol_info.dart`
- `lib/services/transmission/transmission_rpc_adapter.dart`
- `lib/services/transmission/transmission_modern_rpc_adapter.dart`
- `lib/services/transmission/transmission_legacy_rpc_adapter.dart`

如果团队更偏好少文件，也可以先保留在单文件内的私有类，再根据实现体量拆分。但逻辑边界必须保留。

### `DownloaderController`

理想情况下无需业务分叉，只继续通过 `TransmissionService` 访问统一能力。

唯一语义变化：

- `testConnection()` 对 legacy 可返回成功
- 添加 / 编辑下载器时不再把 `<4.1.0` 直接判为不支持

## 测试策略

测试需要覆盖三层。

### 1. detector 单测

覆盖场景：

- modern 请求 -> modern 响应
- modern 请求 -> legacy 响应
- modern 探测失败 -> legacy 探测成功
- 409 session 流程
- 401 认证失败
- 两轮都失败

### 2. adapter 单测

为 modern / legacy adapter 各自覆盖主要功能：

- `getTasks`
- `getTaskDetail`
- `addTask`
- `pauseTask`
- `resumeTask`
- `removeTask`
- `getSpeedConfig`
- `setSpeedConfig`
- `getGlobalStat`

重点验证：

- 两套协议最终产出的 `DownloadTask` 一致
- 两套协议最终产出的 `DownloaderSpeedConfig` 一致

### 3. facade/service 单测

验证：

- 首次自动识别并缓存 adapter
- 后续调用不重复探测
- session 过期只刷新 token
- 协议异常时允许一次重探测
- modern 和 legacy 都能通过 `testConnection()`
- 过旧 legacy 会因能力不足被明确拒绝

## 风险与取舍

### 风险

- legacy 字段和方法名覆盖不全，会导致某个操作只在部分旧版本可用
- 过度依赖单次握手结果，可能掩盖少数非标准部署差异
- 若继续让 controller 依赖原始字段名，会把兼容逻辑泄漏到 adapter 外部

### 取舍

- 不做用户手动选协议，换取更好的默认体验
- 不承诺支持“所有旧版 Transmission”，而是承诺支持“满足当前主要功能要求的旧版”
- 不在第一版设计里引入更复杂的“能力矩阵 UI”，先以统一支持/拒绝为主

## 成功标准

满足以下条件则视为设计达标：

- 用户添加 Transmission 下载器时无需手动选择新旧协议
- `4.1.0+` 继续按当前路径正常工作
- `4.1.0` 以下、协议符合预期且能力完整的版本可完成主要功能链路
- 过旧或能力不足的旧版会在添加 / 编辑时被明确拒绝
- controller 和 UI 不需要新增协议分支
- 测试能分别证明 modern / legacy 两条路径的领域输出一致
