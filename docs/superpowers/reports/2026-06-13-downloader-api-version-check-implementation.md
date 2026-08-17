# 下载器 API 版本检查（添加时硬门禁）实现报告

> 状态：**已完成**（2026-06-13）
> 关联文档：[设计](../specs/2026-06-13-downloader-api-version-check-design.md) · [实现计划](../plans/2026-06-13-downloader-api-version-check.md)

## 目标回顾

添加 / 编辑下载器时，对 Aria2、qBittorrent、Transmission 执行**服务端版本硬门禁**（版本不符拒绝保存），并把获取到的版本号记录到模型、显示在管理页卡片。同时修复 qBit 版本检查失效与错误吞没的既有缺陷。

## 完成的工作

### 1. ConnectionResult 结果对象（新增）
**文件**：`lib/services/connection_result.dart`

Dart 3 `sealed class`，让 `testConnection()` 由 `bool` 升级为"成功 / 失败 + 类别 + 原因"，使"版本不符"能与"认证失败 / 无法连接"区分：

- `ConnectionSuccess({String? serverVersion})` — 连接成功且版本达标，携带服务端版本。
- `ConnectionFailure(category, reason, {actualVersion, minVersion})` — 失败，携带类别与人类可读原因。
- `ConnectionFailureCategory` 枚举：`versionUnsupported` / `authFailed` / `networkError` / `unknown`。

调用方用 Dart 3 模式匹配（`switch`）穷尽处理 sealed 层级。

### 2. Downloader.version 字段（新增）
**文件**：`lib/models/downloader.dart`

新增 `final String? version`（服务端版本号），贯穿构造 / `fromJson`（`as String?`，旧数据兼容为 null）/ `toJson` / `copyWith`（`version ?? this.version` 语义）。仅在添加 / 编辑成功连接时由 controller 写入；后台刷新不更新。

### 3. 全链路签名适配 + 版本检查 + 硬门禁 + UI 反馈（breaking change 核心）

**服务层**（`base_downloader_service.dart` + 三个 service）：抽象方法 `testConnection()` 返回类型 `Future<bool>` → `Future<ConnectionResult>`，各 service 在 `testConnection()` 内自治完成版本校验：

| 下载器 | 版本来源 | 最低门槛 | 判定方式 |
|---|---|---|---|
| Aria2 | `aria2.getVersion` 的 `result.version` | **1.36** | major.minor 比较（`_meetsMinVersion`） |
| qBittorrent | `GET /api/v2/app/version`（去 `v` 前缀） | **5.0** | major ≥ 5 |
| Transmission | `session-get` 的 `arguments['rpc-version-semver']` | **6.0.0** | semver 三段比较（`_meetsSemver`） |

> **qBit 关键修复**：原 `webapiVersion` 主版本号判断在 4.x / 5.x 都返回 major=2，**永远为 false**，旧版能直接通过；且抛出的 `DownloaderConnectionException` 被外层 `catch` 吞掉。现已改用 `app/version`、不再 throw，对齐现有 `stop`/`start` 端点对 5.0+ 的硬依赖。

**删除** `lib/services/downloader_connection_exception.dart`（qBit 不再 throw 后无引用）。

**控制器**（`downloader_controller.dart`）：
- `refreshStatus` 判定条件由 `!connected` 改为 `result is! ConnectionSuccess`，原失败计数 → offline 阈值（3 次）逻辑完整保留。
- `addDownloader` / `updateDownloader` 实现**硬门禁**：仅 `ConnectionSuccess` 时持久化（写 `version: result.serverVersion`、`status: online`），任何 `ConnectionFailure`（含 `networkError`）都不保存，并把结果原样回传 UI。

**编辑页**（`downloader_editor_page.dart` `_save`）：据 `switch (result)` 模式匹配——成功 → SnackBar「连接成功」+ `pop`；版本不符 → 不 `pop` + SnackBar「版本过低：当前 X，需 ≥Y」；认证失败 / 网络 / 未知各有针对性文案。

### 4. 管理页卡片版本徽章
**文件**：`lib/features/home/presentation/pages/management_tab.dart`

新增私有 `_VersionBadge`（pill 样式中性灰，与彩色 `_StatusBadge` 视觉区分），用 `Wrap` 与状态徽章并排（窄屏自动换行）。`version` 为 null / 空串时显示 `—`。

## 数据流

```
editor._save
  → controller.add/updateDownloader(downloader)
      → service.testConnection()  → ConnectionResult
      → ConnectionSuccess           → 持久化(写 version) + status=online → editor: SnackBar「连接成功」+ pop
      → versionUnsupported          → 不持久化 → editor: 不 pop + SnackBar「版本过低：当前 X，需 ≥Y」
      → authFailed                  → 不持久化 → editor: 不 pop + SnackBar「认证失败」
      → networkError / unknown      → 不持久化 → editor: 不 pop + SnackBar「无法连接」
```

后台 20s `refreshStatus` 继续只消费 `result is ConnectionSuccess`，不触发门禁 UI、不更新 version（版本仅在添加 / 编辑时获取）。

## 测试覆盖

新增 **6 个测试文件，23 个用例，全部通过**：

| 测试文件 | 用例数 | 覆盖 |
|---|---|---|
| `test/unit/connection_result_test.dart` | 4 | sealed 对象行为 |
| `test/unit/downloader_version_test.dart` | 4 | version 字段（默认 / 往返 / 旧 JSON 兼容 / copyWith） |
| `test/unit/downloader_services_test_connection_test.dart` | 8 | 三 service 版本解析边界（达标 / 过低 / 认证失败） |
| `test/unit/downloader_controller_gate_test.dart` | 3 | controller 硬门禁（不保存 / 保存写 version / 认证失败不保存） |
| `test/widget/downloader_editor_gate_test.dart` | 2 | 编辑页 pop + SnackBar 反馈 |
| `test/widget/management_tab_version_badge_test.dart` | 2 | 管理页版本徽章渲染 |

## 提交记录

| Commit | 说明 |
|---|---|
| `ba923b6` | feat: 新增 ConnectionResult 连接结果对象 |
| `9921ae8` | feat: Downloader 模型新增 version 字段 |
| `9c45fae` | feat: 下载器 API 版本硬门禁 + ConnectionResult 接入全链路 |
| `171bfcf` | feat: 下载器管理页卡片显示版本号徽章 |
| `3a9e44a` | chore: 移除 downloader_editor_gate_test 未使用的 import |
| `03ce014` | docs: 新增下载器版本门禁实现报告 |
| `c15da65` | fix: Transmission 版本显示改用应用版本而非 RPC 协议版本 |
| `4b611b1` | docs: 实现报告补充 Transmission 版本显示口径修复 |
| `96b2351` | fix: Transmission testConnection 读 JSON-RPC 2.0 响应的 result 而非 arguments |
| `55e8250` | docs: 实现报告补充 Transmission 响应解析路径根因修复 |
| `50713d1` | fix: Transmission 4.1.0+ JSON-RPC 2.0 响应字段名为 snake_case |

均在 `dev` 分支。实现遵循 subagent-driven-development：每个任务「实现 → 规约符合性审查 → 代码质量审查」三阶段，全部通过。

## 后续修复：Transmission 版本显示口径（2026-06-13）

实现后用户反馈：添加 Transmission 时提示"版本过低，需 ≥6.0.0"，但 **6.0.0 是 RPC 协议版本号**（`rpc-version-semver`），不是 Transmission 应用版本号（4.x），用户无法对应、误以为要装一个不存在的"Transmission 6.0"。

**根因**：`transmission_service.dart` 全程用 `rpc-version-semver`（RPC 协议版本）做门禁判定**和**显示/记录。门禁判定正确（snake_case + JSON-RPC 2.0 确实是 rpc 6.0.0 / Transmission 4.1.0 才有），但**显示口径错误**——Aria2/qBit 都显示应用版本（1.36.0 / 5.0.0），唯独 Transmission 显示 RPC 协议版本（6.0.0），不一致。

**修复**（[Transmission 官方 rpc-spec](https://github.com/transmission/transmission/blob/main/docs/rpc-spec.md) 第 5 节确认版本对应）：
- 门禁判定：保持 `rpc-version-semver ≥ 6.0.0` 不变（技术依据正确，app 依赖 snake_case 字段）。
- 显示/记录口径：改用 `session-get` 的 `version` 字段（应用版本长字符串 `$version ($revision)`，如 `4.1.0 (ae226418eb)`），截取首段作为应用版本号。
- `minVersion` 由 `6.0.0` 改为 `4.1.0`（应用版本口径）。

| Transmission App | rpc-version-semver | 修复后行为 |
|---|---|---|
| 4.0.x（旧版） | 5.3.0 | 拒绝，提示「版本过低：当前 4.0.3，需 ≥4.1.0」 |
| 4.1.0+（达标） | 6.0.0 | 成功，管理页徽章显示 `4.1.0` |

效果：用户看到的是 Transmission 应用版本（与 Aria2/qBit 一致），能直接对应到自己该升级到的版本。**注意**：4.0.x 旧版仍被正确拒绝（app 依赖 snake_case），只是提示信息从无意义的"6.0.0"变为有意义的"4.1.0"。

## 后续修复：Transmission testConnection 响应解析路径（2026-06-13，真正根因）

上一修复（`c15da65`）上线后用户反馈：**版本够高（确为 4.1.0+）却仍提示"未达到 4.1.0"**。这次是真正导致"连不上"的根因——上一修复只改了显示口径，没发现**读取路径本身就是错的**。

**根因**：`testConnection()` 自行解析 `session_get` 响应时读 `data['arguments']`，那是**旧协议（Transmission 4.1.0 之前）**的字段路径。但我们的请求是 JSON-RPC 2.0 格式（`_buildRequest` 用 `jsonrpc: 2.0`），4.1.0+ 服务端回 JSON-RPC 2.0 响应，数据在 `data['result']` 对象里（[rpc-spec 第 2 节](https://github.com/transmission/transmission/blob/main/docs/rpc-spec.md) Example response：`{"jsonrpc":"2.0","result":{"version":"4.1.0 (...)"},"id":...}`），**没有 `arguments` 键**。

后果：`semver` / `version` 都读到空 → 走 `semver.isEmpty` 分支 → **所有 4.1.0+ 都被误判为版本不符**。用户看到"需 ≥4.1.0"但 actualVersion 为空，正是此分支。

**为何之前没发现——同谋 bug**：原测试 mock 用旧协议格式（`result:'success'` + `arguments:{...}`），与实现共享同一个错误假设，测试"通过"了却没覆盖真实格式。`_call` 方法本就正确用 `data['result']`（getTasks / getSpeedConfig 等经 `_call` 的都正常），唯独 `testConnection` 为绕开 `_call` 的 session 循环依赖自行解析时写错了路径。

**修复**（`96b2351`）：
- 实现：`data['arguments']` → `data['result']`（`transmission_service.dart:102`）。
- 测试 mock：从旧协议格式改为真实 JSON-RPC 2.0 格式（`result` 是对象），消除同谋 bug，此后测试才真正覆盖协议契约。

**教训**：当测试与实现基于同一份（错误的）协议假设时，测试无法发现协议级 bug。修复真实服务问题时，应让 mock 严格对齐官方协议规范，而非沿用既有调用的格式惯性。

## 后续修复：Transmission 4.1.0+ JSON-RPC 2.0 字段名 snake_case（2026-06-13，第 3 层根因）

`96b2351`（响应载体）修复后用户仍反馈：**版本够高（4.1.2）却提示"未达到 4.1.0"**——`actualVersion=4.1.2` 读到了，但门禁仍判失败。这次是字段名层。

**根因（协议分岔）**：Transmission 根据**请求格式**回不同响应格式。用户补充的完整 rpc-spec + transmission-rpc Python 库源码（活跃维护、连真实 Transmission）交叉证实：
- **transmission-rpc 发旧协议请求**（`{method, arguments}`，无 `jsonrpc`）→ 收**旧协议响应** `{result:"success", arguments:{...}}`，字段名 **kebab 连字符**（`rpc-version-semver`）
- **我们发 JSON-RPC 2.0 请求**（`jsonrpc:"2.0"`）→ 收 **JSON-RPC 2.0 响应** `{jsonrpc, result:{...}}`，而 4.1.0 breaking change"switch to snake_case for all strings"把字段名转成 **snake 下划线**（`rpc_version_semver`）

`version` 是单词（snake/kebab 无别）能读到 4.1.2；`rpc-version-semver` 在 JSON-RPC 2.0 响应里是 `rpc_version_semver`，代码读 kebab 连字符读不到 → semver 空 → 走 `isEmpty` 分支 → "当前 4.1.2 需≥4.1.0"。`_call` 链用 `total_size`/`alt_speed_enabled` 等 snake_case 字段能工作，也佐证响应是 snake_case。

spec 文档自身不一致（session 参数表第 610 行写 `rpc_version_semver` 下划线，Protocol versions 历史第 829 行写 `rpc-version-semver` 连字符），正是歧义来源——前者是 4.1.0+ 实际字段，后者是历史名。

**修复**（`50713d1`）：
- 实现：字段名两种都读（`rpc-version-semver ?? rpc_version_semver`）；响应载体兼容 `result` 对象（JSON-RPC 2.0）与 `arguments`（旧协议）。4 种组合全覆盖。
- 测试 mock 改用真实 snake_case 字段名（彻底消除前 3 次的同谋 mock）；新增旧协议格式（`arguments`+kebab）兼容测试，覆盖防御代码两条路径。

**教训（累积）**：这个 bug 被剥了 3 层（显示口径 → 响应载体 → 字段名），每层都因"测试 mock 与实现共享同一错误协议假设"而漏掉。根因始终是**mock 没对齐真实线协议**。最终通过抓取第三方库（transmission-rpc）源码 + 用户补充的完整官方 spec 交叉验证，才锁定协议分岔这一底层事实。今后对接外部协议，mock 必须以实际抓包/权威库源码为准，不能凭文档片段或既有调用惯性推断。

## 已知问题（pre-existing，与本特性无关）

实现过程中发现仓库**已存在** 6 个测试失败，经独立验证在特性改动之前（base commit）就已存在，**非本特性引入**，亦不在本特性范围内：

1. `test/unit/auth_controller_test.dart` — 加载阶段错误（`AuthProvider` 抽象签名不匹配）。
2. `test/unit/models_test.dart: should create from JSON correctly` — `Downloader.fromJson` 从不解析 `status` 字段（默认 offline），测试期望 online。
3. `test/unit/services_test.dart: fromJson should parse correctly` — 同上 status 解析问题。
4-6. `test/widget/home_page_test.dart ×3` — HomePage AppBar 图标 / 标题断言（疑似某次 AppBar 改动后测试未同步）。

> 建议：上述 #2 / #3 指向一个真实 bug（`Downloader.status` 未持久化 / 反序列化），可在后续单独修复。`flutter analyze` 另有 5 个 `use_null_aware_elements` info 亦为 pre-existing。

## 范围外（设计文档已明确）

- 后台 `refreshStatus` 增加版本门禁（保持仅用 `isSuccess` 的宽容策略）。
- 为兼容 qBit 4.x 补写 `pause`/`resume` 旧端点（门槛坚持 5.0+）。
- 后台刷新自动更新版本号（版本仅在添加 / 编辑时获取）。
- 统一 `DownloaderVersionChecker` 抽象层（已否决，YAGNI）。
