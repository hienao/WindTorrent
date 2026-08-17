# qBittorrent 双版本兼容 实现报告

> **日期**: 2026-06-15
> **规格文档**: [design](../specs/2026-06-15-qbittorrent-dual-version-compat-design.md)
> **实现计划**: [plan](../plans/2026-06-15-qbittorrent-dual-version-compat.md)

## 概述

实现 qBittorrent 双版本兼容，让 app 在保持单一 `QBitService` 入口的前提下，自动探测并同时支持 `qBittorrent 4.1–4.6.x`（legacy，pause/resume 端点）与 `5.0+`（modern，stop/start 端点），对用户完全透明。

## 架构变更

`QBitService` 从单版本（仅 5.0+）单体实现重构为 **facade 模式**：

```
QBitService (facade)
  ├── QBitVersionDetector          ← app/version + app/webapiVersion 探测代际
  ├── QBitSession                  ← 统一登录 / SID 维护 / 请求发送 / 403 重试
  └── QBitApiAdapter               ← 统一接口
        └── QBitBaseApiAdapter     ← 共享实现（增删查、限速、任务解析）
              ├── QBitV4Adapter    ← override pause/resume（4.1–4.6.x）
              └── QBitV5Adapter    ← override stop/start（5.0+）
  缓存: _profile + _adapter（探测一次，后续复用）
```

- **detector**：login → 读 `app/version` → 解析 major/minor → `<4.1` 抛 `UnsupportedError`、版本不可解析抛 `FormatException`、否则按 `major≥5` 判定代际
- **session**：承载 `login` / `getText` / `postForm` / `sendMultipart`，网络 I/O 统一转 `DownloaderServiceException(network)`，`postForm` 遇 403 自动重登重试一次
- **facade**：首次调用触发一次探测并缓存 adapter，后续所有操作直接委托

## 新建文件

| 文件 | 说明 |
|------|------|
| `lib/services/qbit/qbit_api_generation.dart` | 代际枚举（v4Legacy / v5Modern） |
| `lib/services/qbit/qbit_server_profile.dart` | 不可变探测结果 |
| `lib/services/qbit/qbit_version_detector.dart` | 版本探测器 |
| `lib/services/qbit/qbit_session.dart` | 共享会话（登录/请求/403 重试/multipart） |
| `lib/services/qbit/qbit_api_adapter.dart` | adapter 契约（全 10 方法） |
| `lib/services/qbit/qbit_base_api_adapter.dart` | 共享实现 + `_parseTask` / `_parseStatus` |
| `lib/services/qbit/qbit_v4_adapter.dart` | 4.x pause/resume 端点 |
| `lib/services/qbit/qbit_v5_adapter.dart` | 5.x stop/start 端点 |
| `test/unit/services/qbit/qbit_version_detector_test.dart` | detector 4 测试 |
| `test/unit/services/qbit/qbit_torrent_adapter_test.dart` | adapter 端点契约 2 测试 |
| `test/unit/services/qbit/qbit_service_facade_test.dart` | facade 缓存 + 403 重试 2 测试 |
| `test/unit/services/qbit/qbit_common_operations_test.dart` | 共享操作回归 2 测试 |

## 修改文件

| 文件 | 变更 |
|------|------|
| `lib/services/qbit_service.dart` | 从单版本单体重构为纯委托 facade |
| `test/unit/downloader_services_test_connection_test.dart` | qbit 4.x 从拒绝改为接受（minVersion 5.0→4.1） |
| `test/unit/downloader_services_add_task_test.dart` | qbit mock 响应 detect 流程 |

## 测试覆盖

qbit 相关 30 项全部通过：

- **detector**：4.x→v4Legacy、5.x→v5Modern、malformed→FormatException、<4.1→UnsupportedError
- **adapter**：v4 pause/resume、v5 stop/start 端点契约
- **facade**：探测缓存（versionReads==1）、403 重登重试（loginCalls==2）
- **共享操作**：addTask multipart 经 facade、getSpeedConfig 读 preferences
- **连接测试回归**：4.x success、5.x success、4.0.x versionUnsupported（minVersion 4.1）、authFailed
- **add_task 回归**：multipart 上传、savepath 字段、403 异常

## 关键行为变更

| 场景 | 改动前 | 改动后 |
|------|--------|--------|
| qBittorrent 4.1–4.6.x 连接 | 拒绝 (versionUnsupported, minVersion 5.0) | 接受（v4Legacy，pause/resume） |
| qBittorrent 5.0+ 连接 | 接受（仅 stop/start） | 接受（v5Modern，stop/start） |
| qBittorrent <4.1 | 拒绝 (minVersion 5.0) | 拒绝 (minVersion 4.1) |
| 版本探测 | 仅 app/version major≥5 | app/version + app/webapiVersion，按代际选 adapter |
| 403 会话过期重试 | 仅 pause/resume | 所有 postForm 操作统一重试一次 |

## 对计划的合理偏离

- **Task 1 提前创建 `qbit_session.dart`**：计划将其归到 Task 2，但 `QBitVersionDetector` 依赖它，否则 Task 1 测试无法编译——计划内部前后依赖矛盾。
- **`QBitSession` 补齐生产健壮性**：计划骨架的 session 仅有 `login`/`getText`/`postForm`，无 timeout、无网络异常转换、无 multipart、无 403 重试。按 CLAUDE.md fail-fast 分层异常范式与现有 403 重试行为补全。
- **`common_operations_test` 加 `versionReads` 断言**：计划原测试在 Task 3 旧实现下也会通过（无法驱动），加断言让 TDD 红真正验证"经 facade 探测"。
- **`getSpeedConfigDescriptor()` 保留在 QBitService**：计划未提及，但属 `DownloaderService` 基类抽象方法、版本无关，不迁入 adapter。

## 未改动文件

- `lib/features/downloaders/presentation/controllers/downloader_controller.dart` — 不感知版本
- `lib/features/tasks/presentation/controllers/task_controller.dart` — 不感知版本
- `lib/models/downloader.dart` — 未持久化 `apiGeneration`（计划首Pass有意不存）
- UI 页面与路由 — 无新增版本选择 UI

## 已知预存问题（非本次引入）

`test/unit/models_test.dart` 与 `test/unit/services_test.dart` 中 `Downloader.fromJson` 不解析 `status` 字段（默认 offline，测试期望 online），经 git stash 验证为 dev 分支预存失败，与本改动无关。
