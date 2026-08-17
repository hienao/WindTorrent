# Transmission 双协议支持 实现报告

> **日期**: 2026-06-14
> **规格文档**: [design](../specs/2026-06-14-transmission-dual-protocol-support-design.md)
> **实现计划**: [plan](../plans/2026-06-14-transmission-dual-protocol-support-implementation-plan.md)

## 概述

实现 Transmission 双协议支持，让 app 在保持单一 `Transmission` 下载器入口的前提下，自动识别并同时支持 `Transmission 4.1.0+`（JSON-RPC 2.0 + snake_case）与 `4.1.0` 以下旧协议版本（legacy RPC + kebab-case）。

## 架构变更

`TransmissionService` 从单体协议实现重构为 **facade 模式**：

```
TransmissionService (facade)
  ├── TransmissionProtocolDetector   ← 协议自动识别
  ├── TransmissionRpcAdapter         ← 统一接口
  │     ├── TransmissionModernRpcAdapter  ← JSON-RPC 2.0
  │     └── TransmissionLegacyRpcAdapter  ← legacy RPC
  └── 缓存: protocolInfo + adapter
```

- **detector**：modern 优先探测 → legacy 回退探测 → 失败分类
- **adapter**：处理方法名、字段名、请求/响应结构的协议差异，对外统一输出 `DownloadTask` / `DownloaderSpeedConfig`
- **facade**：缓存 adapter，后续调用直接委托，协议异常时允许一次重探测

## 新建文件

| 文件 | 说明 |
|------|------|
| `lib/services/transmission/transmission_protocol_info.dart` | 协议枚举、探测结果对象 |
| `lib/services/transmission/transmission_protocol_detector.dart` | modern 优先、legacy 回退的自动识别器 |
| `lib/services/transmission/transmission_rpc_adapter.dart` | 统一 adapter 抽象接口 |
| `lib/services/transmission/transmission_modern_rpc_adapter.dart` | JSON-RPC 2.0 + snake_case 实现 |
| `lib/services/transmission/transmission_legacy_rpc_adapter.dart` | legacy RPC + kebab-case 实现 |
| `test/unit/transmission_protocol_detector_test.dart` | detector 5 个测试 |
| `test/unit/transmission_rpc_adapter_test.dart` | adapter 8 个测试（modern 4 + legacy 4） |
| `test/unit/transmission_service_facade_test.dart` | facade 5 个测试 |

## 修改文件

| 文件 | 变更 |
|------|------|
| `lib/services/transmission_service.dart` | 从单体重构为 facade |
| `test/unit/downloader_services_test_connection_test.dart` | 适配双协议行为（4.0.x 不再拒绝） |
| `test/unit/downloader_controller_gate_test.dart` | 新增 legacy Transmission 成功回归 |

## 测试覆盖

共 45 个 Transmission 相关测试全部通过：

- **detector**：modern 识别、legacy 回退、409 session、401 认证、网络错误
- **modern adapter**：任务列表、添加任务、限速配置、全局统计
- **legacy adapter**：任务列表、添加任务、限速配置、全局统计
- **facade**：modern/legacy 连接成功、401 认证失败、能力不足回退、adapter 缓存
- **controller 门禁**：legacy 成功也保存下载器
- **连接测试回归**：4.1.0+ modern 成功、4.0.x legacy 成功、旧协议格式自动识别

## 关键行为变更

| 场景 | 改动前 | 改动后 |
|------|--------|--------|
| Transmission 4.0.x 连接 | 拒绝 (versionUnsupported) | 接受（自动识别为 legacy） |
| Transmission 4.1.0+ 连接 | 接受（仅 JSON-RPC 2.0） | 接受（自动识别为 modern） |
| 协议格式自动检测 | 无 | modern 优先 → legacy 回退 |
| 极老版本 / 能力不足 | 拒绝 | 仍拒绝（协议识别失败） |

## 未改动文件

- `lib/features/downloaders/presentation/controllers/downloader_controller.dart` — 不感知协议
- `lib/models/downloader.dart` — 已有 `version` 字段可复用
- UI 页面与路由 — 无新增协议选择 UI
