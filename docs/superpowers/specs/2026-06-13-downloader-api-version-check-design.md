# 下载器 API 版本检查（添加时硬门禁）设计

## 目标

在**添加 / 编辑下载器**时，对 Aria2、qBittorrent、Transmission 三种下载器执行服务端版本校验：

- 版本低于最低要求 → **拒绝保存**（硬门禁），并明确告知"当前版本 / 要求版本"。
- 同时修复现有版本检查的失效与错误吞没问题，让“版本不符”首次能和“认证失败 / 无法连接”区分开。
- 额外：成功连接时**记录下载器服务端版本号**到模型（添加 / 编辑时获取并更新），并在下载器管理页卡片的在线状态旁以 pill 徽章显示。

## 问题现状

### 1. Aria2 — 实质上没有检查

`aria2_service.dart` 的 `testConnection()` 调用了 `aria2.getVersion`，但**只看 HTTP 200，完全忽略返回的 `version` 字段**。Aria2 的 RPC 协议长期稳定、破坏性变更极少，因此此处检查必要性最低，但当前确实没有版本校验。

### 2. qBittorrent — 有检查，但完全失效（双重 Bug）

`qbit_service.dart` 的 `testConnection()`（约 69–91 行）声称要求 qBit 5.0+，但存在两个致命问题：

- **判断逻辑拦不住旧版**：代码读取 `/api/v2/app/webapiVersion` 并取其主版本号判断 `< 2`。但 `webapiVersion` 在 qBit 4.x 与 5.x 返回的主版本号**都是 2**（4.1–4.6.x ≈ `2.0`–`2.11.x`，5.0+ ≈ `2.11`–`2.15.1`）。因此 `majorVersion < 2` **永远为 false**，4.x 旧版能直接通过。
- **错误被吞**：即使检查命中，抛出的 `DownloaderConnectionException` 被外层 `catch (e) { return false; }` 吞掉，用户只看到"连接失败"。

**后果**：代码使用了 qBit 5.0+ 才有的 `torrents/stop`、`torrents/start` 端点（4.x 为 `pause`/`resume`）。连接到 4.x 时 `testConnection()` 会"通过"，但**暂停 / 恢复任务在运行时才失败**。

### 3. Transmission — 完全没有检查（与注释自相矛盾）

`transmission_service.dart` 类注释声明"要求 Transmission 4.1.0+（rpc_version_semver 6.0.0+，即 JSON-RPC 2.0 + snake_case 字段名）"，但 `testConnection()` **根本未读取 `rpc-version-semver`**，只发 `session-get` 查看是否成功。连接旧版 Transmission（2.x/3.x，驼峰字段名）会通过 `testConnection()`，但 `getTasks()` 因字段名不匹配而解析失败。

### 架构层面的根本缺陷

1. `DownloaderService.testConnection()` 返回 `bool`，**无法携带失败原因**——版本不符、认证错误、网络不通三者无法区分。
2. 添加 / 更新下载器时（`DownloaderController.addDownloader` / `updateDownloader`）确实调用了 `testConnection()`，但**不论结果都保存**；编辑页 `_save()` 保存后直接 `Navigator.pop()`，**从不向用户反馈连接结果**——添加一个连不上的下载器也算"成功"，仅在列表里显示 offline。

## 范围

本次包含：

- 新增 `ConnectionResult` 结果对象，`testConnection()` 返回类型由 `bool` 改为 `ConnectionResult`。
- 三个下载器 service 在各自 `testConnection()` 内自治完成版本校验，并返回带原因的结果。
- 修复 qBit 失效的版本判断（改用 `app/version`）与错误吞没。
- `DownloaderController.addDownloader` / `updateDownloader` 实现硬门禁：版本不符 / 认证失败时不保存并把结果回传 UI。
- 编辑页 `_save()` 依据结果决定是否 `pop`，失败时以 SnackBar 展示具体原因。
- 更新所有受影响的调用点与既有测试。
- 新增 `Downloader.version` 字段持久化；添加 / 编辑成功时写入版本；后台刷新不更新版本。
- 下载器管理页卡片在在线状态徽章旁并排显示版本 pill 徽章。

本次不包含：

- 后台 20s `refreshStatus` 增加版本门禁（保持仅用 `isSuccess` 的宽容策略）。
- 为兼容 qBit 4.x 而补写 `pause`/`resume` 旧端点（门槛坚持 5.0+，与现有代码一致）。
- 后台刷新自动更新版本号（版本仅在添加 / 编辑时获取）。
- 版本检查器抽象层（统一 `DownloaderVersionChecker`，见"设计选择"）。
- iOS / 桌面端专项适配。

## 设计决策

| 决策项 | 选择 | 理由 |
|---|---|---|
| 处理策略 | **硬门禁**：版本不符拒绝保存 | 贴合"加个版本限制"诉求；避免运行时踩坑（如 qBit 4.x 暂停恢复失败） |
| qBittorrent 门槛 | **5.0+** | 现有代码已按 5.0+ 编写（`stop`/`start` 端点），零额外兼容工作 |
| Transmission 门槛 | **4.1+**（rpc-version-semver ≥ 6.0.0） | snake_case 字段名 + JSON-RPC 2.0 是现有代码的硬性依赖 |
| Aria2 门槛 | **1.36+** | 统一门禁体验；用到的均为早期稳定 API，门槛主要起"统一"作用 |
| 技术方案 | **方案 A**：结果对象 + 每个 service 自治 | 内聚、职责清晰，`refreshStatus` 适配代价极低 |

### 备选方案（已否决）

- **方案 B：统一 `DownloaderVersionChecker` + 结果对象**。门槛集中可配，但版本解析与协议细节会割裂到 service 与 checker 两处；目前仅三种异构协议，属过度设计（YAGNI）。
- **方案 C：保持 `bool`，新增 `checkVersion()`**。改动面最小，但留下两个语义重叠（都需建连）的方法，调用者需记忆"何时调哪个"，且 qBit `testConnection` 内失效判断仍需单独修复，逻辑分叉。

## 架构设计

### `ConnectionResult`（新增，Dart 3 `sealed`）

文件：`lib/services/connection_result.dart`

```dart
sealed class ConnectionResult {
  const ConnectionResult();
  bool get isSuccess => false;
}

class ConnectionSuccess extends ConnectionResult {
  const ConnectionSuccess({this.serverVersion});

  /// 服务端实际版本（供 controller 写入 Downloader.version）
  final String? serverVersion;

  @override
  bool get isSuccess => true;
}

enum ConnectionFailureCategory {
  versionUnsupported, // 服务端版本低于最低要求
  authFailed,         // 认证失败（用户名/密码/RPC secret 错误）
  networkError,       // 网络/超时/不可达
  unknown,            // 其他未分类错误
}

class ConnectionFailure extends ConnectionResult {
  final ConnectionFailureCategory category;
  final String reason;            // 人类可读说明
  final String? actualVersion;    // 服务端实际版本（versionUnsupported 时）
  final String? minVersion;       // 要求的最低版本（versionUnsupported 时）

  const ConnectionFailure(
    this.category,
    this.reason, {
    this.actualVersion,
    this.minVersion,
  });

  bool get isVersionUnsupported =>
      category == ConnectionFailureCategory.versionUnsupported;
}
```

调用方用 `switch` 模式匹配（Dart 3）穷尽处理 `ConnectionSuccess` / `ConnectionFailure`。

### 各 service 的版本检查实现

每个 service 在 `testConnection()` 内，于建连 / 认证成功之后执行版本校验，并据此返回 `ConnectionResult`。最低门槛以各 service 内私有常量定义。

- **Aria2**：调用 `aria2.getVersion`，读取返回的 `version` 字符串，解析主.次版本，校验 ≥ `1.36`。低于门槛 → `ConnectionFailure(versionUnsupported, reason, actualVersion: <实际>, minVersion: '1.36')`。
- **qBittorrent**：登录（`_login`）成功后，`GET /api/v2/app/version`（返回形如 `v5.0.0`），去除前导非数字字符后取主版本号，校验 ≥ `5`。低于门槛 → `versionUnsupported`。**此步骤替换原失效的 `webapiVersion` 主版本号判断**；不再 `throw DownloaderConnectionException`，改为直接 `return ConnectionFailure`。
- **Transmission**：在已有的 `session-get`（已处理 409 CSRF 重试）成功响应里，读取 `arguments['rpc-version-semver']`，做语义化版本比较 ≥ `6.0.0`。低于门槛 → `versionUnsupported`。

三个 service 在版本达标、连接成功时，统一返回 `ConnectionSuccess(serverVersion: <解析到的版本字符串>)`，供 controller 写入 `Downloader.version`。各类型版本来源：Aria2 = `getVersion.version`、qBit = `app/version`（去 `v` 前缀后保留主.次.修订）、Trans = `rpc-version-semver`。

### 调用链与门禁

```
DownloaderEditorPage._save()
  → DownloaderController.addDownloader(downloader) | updateDownloader(downloader)
      → service.testConnection()  // 返回 ConnectionResult
      → switch (result):
           ConnectionSuccess            → 持久化, status=online,  返回 success
           ConnectionFailure(version…)  → 不持久化, 返回 result（回传 UI）
           ConnectionFailure(auth…)     → 不持久化, 返回 result
           ConnectionFailure(network/…) → 不持久化, 返回 result
```

- `addDownloader` / `updateDownloader` 的返回类型由 `Future<void>` 改为 `Future<ConnectionResult>`。
- 成功时把 `result.serverVersion` 写入 `Downloader.version` 并持久化（添加 / 编辑都更新）；后台 `refreshStatus` **不**更新 `version`，仅消费 `isSuccess`。
- 后台 `refreshStatus`（20s 轮询）继续只消费 `result is ConnectionSuccess`，失败累计仍走现有 3 次阈值 → offline 逻辑，**不触发门禁 UI**。

## 组件清单

| 文件 | 改动 |
|---|---|
| `lib/services/connection_result.dart` | **新增** `ConnectionResult` sealed 层级；`ConnectionSuccess` 携带 `serverVersion` |
| `lib/models/downloader.dart` | **新增** `version` 字段（构造 / `fromJson` 兼容旧数据 / `toJson` / `copyWith`） |
| `lib/services/base_downloader_service.dart` | `testConnection()` 返回类型 `bool` → `ConnectionResult` |
| `lib/services/aria2_service.dart` | testConnection 解析 `getVersion.version`，校验 ≥1.36，返回 `ConnectionResult` |
| `lib/services/qbit_service.dart` | 改用 `app/version` 判 ≥5.0 替换失效判断；版本不符直接返回 `ConnectionFailure`（不再 throw） |
| `lib/services/transmission_service.dart` | testConnection 读取 `rpc-version-semver` 判 ≥6.0.0，返回 `ConnectionResult` |
| `lib/services/downloader_connection_exception.dart` | qBit 不再 throw 后**已无引用，删除**（附带清理） |
| `lib/features/downloaders/presentation/controllers/downloader_controller.dart` | `testConnection/addDownloader/updateDownloader` 适配 `ConnectionResult`；后两者实现硬门禁；`refreshStatus` 改用 `isSuccess` |
| `lib/features/downloaders/presentation/pages/downloader_editor_page.dart` | `_save` 依据 `ConnectionResult` 决定是否 `pop`，失败时 SnackBar 显示原因 |
| `lib/features/home/presentation/pages/management_tab.dart` | `_DownloaderCard` 在 `_StatusBadge` 旁并排版本 pill 徽章（`_VersionBadge`） |

## 数据流：添加下载器时的门禁

```
editor._save
  → controller.addDownloader(downloader)
      → service.testConnection()  → ConnectionResult
      → 成功: 持久化(写入 version) + status=online      → editor: SnackBar "连接成功" + pop
      → 版本不符: 不持久化                 → editor: 不 pop + SnackBar "版本过低：当前 vX，需 ≥Y"
      → 认证失败: 不持久化                 → editor: 不 pop + SnackBar "认证失败：请检查用户名/密码"
      → 网络/未知: 不持久化                → editor: 不 pop + SnackBar "无法连接：请检查地址/端口/网络"
```

更新下载器（编辑）走相同流程。

## 错误处理与 UI 反馈

- **硬门禁语义**：`addDownloader` / `updateDownloader` 仅在 `ConnectionSuccess` 时持久化。任何 `ConnectionFailure`（含 `networkError`）都不保存——因为门禁要求"既连得上、版本又达标"。
- **UI 反馈**：失败时**不 `pop`**，留在编辑页让用户改配置或放弃。使用 SnackBar（与编辑页现有 SnackBar 用法一致，符合 `DESIGN.md` "Error states: concise message + retry when possible"）。`versionUnsupported` 时把"实际版本 / 要求版本"一并展示。
- **后台刷新区别对待**：`refreshStatus` 对失败宽容（累计 offline），不弹门禁——版本不会在运行中改变，门禁只在添加 / 编辑时执行。

## 版本号记录与显示

- **记录**：`Downloader` 新增 `String? version`。`addDownloader` / `updateDownloader` 在 `ConnectionSuccess` 时把 `serverVersion` 写入并随配置持久化到 GetStorage。
- **更新时机**：仅添加 / 编辑时获取；后台 `refreshStatus` 不更新 `version`，离线下载器保留上次编辑时的版本值。
- **显示**：`management_tab.dart` 的 `_DownloaderCard` 把现有 `_StatusBadge` 与新增 `_VersionBadge` 放进同一 `Row`（`mainAxisSize: min`）并排显示。`_VersionBadge` 复用 pill 样式，但用中性灰（`AppColors.textSecondaryLight`）与彩色状态徽章区分。
- **版本缺失**：`version == null`（仅添加时尚无此字段的历史数据）时，`_VersionBadge` 显示 `—`；下次编辑保存即补全。

## 版本检查细节备忘

- **qBit `app/version` 返回格式**：形如 `v5.0.0`，解析前需去除前导非数字字符（`v`）；取主版本号 `>= 5`。
- **Trans `rpc-version-semver`**：`session-get` 的 `arguments` 内字段，字符串语义化版本（如 `"6.0.0"`），比较 `>= 6.0.0`。需在已有 409 CSRF 重试逻辑成功后再读取。
- **Aria2 `getVersion`**：返回 `{"version": "1.36.0", "enabledFeatures": [...]}`，取 `version` 解析主.次版本，校验 `>= 1.36`。

## 测试策略

- **更新既有**：
  - `test/widget/test_helpers.dart:73` 的 fake `testConnection` 签名由 `Future<bool>` 改为 `Future<ConnectionResult>`；同步更新 `addDownloader` / `updateDownloader` 的 fake 返回值。
  - `test/unit/services_test.dart` 中 Aria2 `testConnection` 相关断言适配新返回类型。
- **新增单元测试**：
  - 三个 service 的版本解析与门槛判断，mock http 返回边界值：qBit `v4.5.0`（拒）/ `v5.0.0`（过）、Trans `rpc-version-semver` `5.3.0`（拒）/ `6.0.0`（过）、Aria2 `1.35.0`（拒）/ `1.36.0`（过）。
  - `DownloaderController.addDownloader` 在 `versionUnsupported` 时**不写入 GetStorage** 且返回正确 `ConnectionFailure`。
- **新增 Widget 测试**：`DownloaderEditorPage._save` 在版本不符 / 认证失败时**不 `pop`** 并显示对应 SnackBar 文案。
- **新增**：`Downloader.version` 序列化往返测试，含“旧 JSON 无 `version` 字段 → 反序列化为 null”的兼容用例。
- **新增**：`management_tab` 卡片有版本时显示 `_VersionBadge`（如 `v5.0.0`）、`version == null` 时显示 `—`。

## 兼容性与风险

- **`testConnection()` 签名变更是 breaking change**：所有实现（三个 service）与调用点（`DownloaderController` 及其测试 fake）必须同步更新，否则编译失败。grep 已确认生产代码仅 `DownloaderController` 调用 `service.testConnection()`。
- **Trans 版本读取依赖 session-get 成功**：若服务端未启用 CSRF（直接 200），现有逻辑已覆盖；版本字段缺失（极旧版本）应回退为 `unknown` 失败而非崩溃。
- **qBit 端点选择**：改用 `app/version` 后，需登录 SID；现有 testConnection 已是"先登录后查询"顺序，保持不变。
- **删除 `DownloaderConnectionException`**：确认 grep 全仓仅 `qbit_service.dart` 引用，移除安全。
- **`Downloader.fromJson` 兼容旧数据**：已持久化的 JSON 无 `version` 字段时反序列化为 `null`，不影响现有配置加载。
- **版本新鲜度取舍**：后台不更新版本，离线后重新上线的下载器不会自动刷新版本，需手动编辑保存——这是“仅添加 / 编辑时获取”的已知取舍。
