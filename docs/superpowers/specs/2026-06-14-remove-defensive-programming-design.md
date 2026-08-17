# 移除防御性编程 + 文档声明禁止规则

**日期**: 2026-06-14
**状态**: 待实施
**类型**: 重构 + 编码规范
**来源**: brainstorming session

---

## 1. 背景

WindWalker 项目存在大量防御性编程代码，不利于长期维护。经全量代码审查（`services/` / `controllers/` / `core/` / `models/` 四个层面），问题集中在以下几类。

### 1.1 过度防御的典型表现

| # | 模式 | 典型位置 | 危害 |
|---|------|----------|------|
| 1 | 静默吞异常 | `aria2_service.dart:163`（getTasks catch 无日志）、`qbit_service.dart`（几乎每个方法）、`task_controller.dart:279`（`// 忽略错误`） | UI 无法区分"无数据"与"加载失败" |
| 2 | 任务操作不检查返回值 | `aria2_service.dart:206-229` pause/resume/remove 返回 void | 操作失败时 UI 仍显示成功 |
| 3 | 不可能的 null 检查 | 两个 controller 共 9+ 处 `if (service == null)`（switch 已穷举枚举，返回值不可能为 null） | 冗余、误导后来者 |
| 4 | try-catch 处理"未找到" | `downloader_controller.dart:298` getDownloader | 反模式，应改 `firstWhereOrNull` |
| 5 | 吞致命初始化错误 | `main.dart:29-43` Firebase/GetStorage 失败后只 log 继续 runApp | 应用带隐性故障运行，后续崩溃更难诊断 |
| 6 | 吞 bug 的字段兜底 | `download_task.dart:82` `downloaderId ?? ''`、`downloader.dart:62` `port ?? 6800`（多下载器场景默认值语义错误） | 掩盖本应暴露的 bug |
| 7 | `_call` 返回 null 模式 | `aria2_service.dart:281-315`、`transmission_service.dart:367-431` | 把"成功返回 null"与"失败"混为一谈，丢失错误类型 |

### 1.2 合理边界处理（应保留，不算防御性编程）

- 解析外部下载器 API 数据的字段兜底（数据确实不可信）
- 网络请求外层 `try-catch`（捕获 `SocketException`/`Timeout`）
- Flutter `if (!mounted) return;`（async gap 后框架要求）
- `copyWith` 的 `?? this.xxx`（Dart 语言惯例）
- `ConnectionResult` sealed class（类型化错误传播）
- 日志/埋点等次要功能失败时降级

### 1.3 正面范例（清理时应向其看齐）

- `auth_controller.dart`：分层异常处理 + 每个 catch 向 UI 传播可读错误 + telemetry 分类
- `add_task_request.dart`：`clearUrl`/`clearTorrent` 显式布尔参数解决可空字段 copyWith 语义
- `connection_result.dart`：sealed class 用类型系统表达成功/失败+原因
- `log.dart`：日志库自身静默失败是合理的（不能因日志故障破坏调用方流程）

---

## 2. 目标与非目标

### 目标
1. 在 `CLAUDE.md` / `AGENTS.md` 落地"禁止防御性编程"硬性规则，约束 AI 与未来开发
2. 分批清理现有过度防御代码，改为 fail-fast（错误显式传播）
3. 保留合理的边界处理不被误删

### 非目标
- 不引入全新的错误处理架构（如全局 Result 类型），仅在清理过程自然需要时局部采用
- 不重写业务逻辑，只把"静默失败"改为"显式传播"
- 不改动与防御性编程无关的代码

---

## 3. 关键决策

| 决策点 | 选择 | 理由 |
|--------|------|------|
| 界定标准 | 激进 fail-fast | 用户明确选择，相信调用方契约 |
| 工作范围 | 文档 + 代码分阶段 | 规则先行，为清理与未来开发提供准绳；风险可控 |
| 错误传播 | service 抛异常 → controller errorState → UI 显示 | 对齐 `auth_controller` 现有范式 |
| 文档形式 | 硬性禁止 + 模式清单 + 允许例外 | 可执行、可检查，与"不允许写"表述一致 |
| 清理掌控 | 完整清单逐条确认 | 用户逐条标记"移除/保留/调整" |
| 外部数据边界 | 分层 fail-fast | 必填抛错、可选 nullable、未知枚举归 unknown，兼顾严谨与可用性 |
| 文档分工 | CLAUDE.md 主体 + AGENTS.md 指针 | 避免重复维护 |

> **说明**：「激进 fail-fast」是整体界定基调（倾向移除一切兜底、相信契约）；「分层 fail-fast」是"外部不可信数据"这一具体场景的处理细化（必填抛错、可选 nullable、未知枚举归 unknown）。二者不矛盾——后者是前者在下载器 API / 用户输入等不可信输入上的稳健实现，避免因外部数据版本差异导致正常使用时崩溃。

---

## 4. 阶段 1：文档规则

### 4.1 CLAUDE.md 新增章节（完整规则主体）

在 `CLAUDE.md` 末尾新增以下章节：

````markdown
## 编码规范：禁止防御性编程

本项目采用 **fail-fast** 原则：错误必须显式传播，禁止用默认值掩盖失败。对齐现有 `auth_controller` 的分层异常范式与 `ConnectionResult` 的类型化设计。

### 禁止的模式

**1. 静默吞异常** —— `catch` 捕获异常后返回默认值（空列表/空 Map/false/void/空串）且不向调用方传播失败信号。
```dart
// ❌ 禁止
try { return await api.getTasks(); } catch (e) { return []; }

// ✅ 抛出，由 controller 捕获并传播给 UI
try { return await api.getTasks(); } catch (e) { throw Exception('获取任务失败: $e'); }
```

**2. 不可能为 null 的 null 检查** —— 类型已是 non-nullable，或控制流已保证非空（如 switch 穷举枚举的返回值）时，不得写 `if (x == null)`。
```dart
// ❌ 禁止：_createService 的 switch 已穷举 DownloaderType，返回值不可能为 null
final service = _createService(type);
if (service == null) return;
```

**3. try-catch 处理"未找到"等正常控制流** —— 应用 `firstWhereOrNull` / `where().firstOrNull`，而非 try-catch 包裹 `firstWhere`。
```dart
// ❌ 禁止
try { return list.firstWhere((d) => d.id == id); } catch (e) { return null; }

// ✅
return list.where((d) => d.id == id).firstOrNull;
```

**4. 吞掉致命初始化错误** —— 应用启动关键初始化（Firebase、GetStorage 等）失败不得 catch 后继续运行。
```dart
// ❌ 禁止
try { await Firebase.initializeApp(); } catch (e) { Log.e(...); } // 继续 runApp

// ✅ 让异常传播（fail fast），或进入明确降级态
```

**5. 内部已保证字段的兜底** —— 内部创建/传递的对象字段，不得用 `?? defaultValue` 掩盖本应暴露的 bug。
```dart
// ❌ 禁止：downloaderId 是 WindWalker 自身必填字段，缺失即是 bug
downloaderId: json['downloaderId'] ?? ''
```

**6. 重复参数/状态验证** —— 同一前置条件不得在多个方法里反复校验，应抽取 helper 或靠类型/契约保证。

### 错误传播规范

- **service 层**：移除静默 catch，抛出异常（可保留网络 I/O 外层 try-catch，但捕获后必须抛出/传播）
- **controller 层**：catch 异常 → 写入 `errorState`/`errorMessage` 字段 → `notifyListeners()`
- **UI 层**：根据 errorState 显式区分"空数据"与"加载失败"两种状态

### 外部数据解析（分层 fail-fast）

解析下载器 API 响应、用户输入、持久化数据时：
- **协议必填字段**（ID/name/status 等）缺失或类型错 → **抛出解析异常**
- **可选/统计字段** → 用 **nullable 类型**，UI 显式处理 null（不用 `?? 0` 伪装成有值）
- **未知枚举值** → 归入 `unknown`/default 分支 + **告警日志**（便于发现新枚举值）

### 允许的例外（合理边界处理，不算防御性编程）

1. 网络请求外层 `try-catch`（捕获 `SocketException`/`Timeout`）——但捕获后**必须抛出或传播**，不得返回默认值
2. Flutter `if (!mounted) return;`（async gap 后的框架要求）
3. `copyWith` 的 `?? this.xxx`（Dart 语言惯例）；可空字段的"清空 vs 不改"用显式布尔参数（参考 `add_task_request.dart` 的 `clearUrl` 模式）
4. 枚举 `default` 分支归 `unknown` + 告警日志
5. 日志/埋点等次要功能失败时降级（不影响主流程）
6. 幂等保护（如 `if (_initialized) return;`）
````

### 4.2 AGENTS.md 新增（精简指针）

在 `AGENTS.md` 的 `## ANTI-PATTERNS (THIS PROJECT)` 章节新增条目：

```markdown
- **防御性编程（禁止）** —— 本项目采用 fail-fast 原则。详见 `CLAUDE.md` 的「编码规范：禁止防御性编程」章节。核心：禁止静默吞异常（catch 后返回默认值不传播）、禁止不可能为 null 的 null 检查、禁止 try-catch 处理"未找到"（用 firstWhereOrNull）、禁止吞致命初始化错误。错误传播链：service 抛异常 → controller 写 errorState → UI 显示。
```

---

## 5. 阶段 2：代码清理

### 5.1 分批计划

按严重程度排序，每批独立提交、独立测试：

| 批次 | 范围 | 清理重点 | 依赖 |
|------|------|----------|------|
| 1 | `services/`（aria2/qbit/transmission） | 静默 catch、`_call` 返回 null 模式、任务操作返回值 | 无 |
| 2 | `controllers/`（task/downloader/settings）+ `main.dart` | 静默失败、getDownloader try-catch、`_createService` null 检查、main 致命错误 | 批次 1（service 签名变更后 controller 适配） |
| 3 | `models/`（download_task/downloader） | downloaderId 兜底、id/gid 交叉、port 默认值、字段风格统一 | 无（独立） |
| 4 | `core/utils/`（按需） | review_manager.openStoreListing 错误传播等可议项 | 无 |

### 5.2 各批清理重点（基于审查报告的具体行号）

**批次 1 — services/**

- `aria2_service.dart`
  - `163-165` getTasks 静默 catch → 抛异常
  - `171-177` getGlobalStat 双层 try-catch + `?? {}` → 简化为抛异常
  - `206-229` pause/resume/remove 不检查返回值 → 改为检查/抛出
  - `281-315` `_call` 返回 null → 改为抛异常或保留 null 但所有调用方必须显式处理
  - `378-384, 438-443` `_parseTask` 重复 `int.tryParse ?? 0` → 精简一层
- `qbit_service.dart`
  - `130-133` `_login` catch-all → 抛出明确异常（区分网络错误与认证失败）
  - `148-156` getTasks catch-all → 抛异常
  - `180-194` getGlobalStat 双层 catch → 简化
  - `230-234, 251-254` addTask/addDownload catch 返回 `''` → 抛异常
  - `284-287, 318-321, 347-350` pause/resume/remove 重复模板 → 抽 helper + 抛异常
  - `384-387, 433-436` getSpeedConfig/setSpeedConfig catch 返回默认 → 抛异常
- `transmission_service.dart`
  - `201-238` getTasks catch-all（已带 stackTrace，质量较好）→ 改抛异常
  - `240-248` getGlobalStat 双层冗余 → 简化
  - `293-325` pause/resume/remove 重复模板 → 抽 helper + 抛异常
  - `327-344` getSpeedConfig catch → 抛异常
  - `367-431` `_call` catch-all → 改抛异常
  - 保留：`testConnection` 的 409/CSRF/版本双字段处理（合理边界）

**批次 2 — controllers/ + main.dart**

- `task_controller.dart`
  - `279-284` loadTasks `// 忽略错误`（纯静默）→ 抛异常/errorState
  - `109-127, 248-253, 307-312` loadTasks/loadTaskDetail catch → 写 errorState
  - `163, 184, 200, 217, 267, 296, 331, 344, 358, 372` 10+ 处 `if (downloader == null)` → 抽 helper
  - `117, 165, 221` `if (service == null)` → 改 `_createService` 返回类型为非空基类，消除检查
- `downloader_controller.dart`
  - `298-304` getDownloader try-catch → `firstWhereOrNull`
  - `227-238` addTask catch 返回 `''` → 抛异常/errorState
  - `326-332, 343-349` getSpeedConfig/setSpeedConfig catch → 抛异常
  - `93-103` `_loadDownloaders` catch → errorState
  - `145, 187, 220, 315, 325, 341` 6 处 `if (service == null)` → 同上消除
  - 保留：`refreshStatus` 故障隔离 + 失败计数降级（合理的定时任务边界）、`_notifySafely`
- `settings_controller.dart`
  - `51-58` `_loadSettings` catch（注释自承初始化顺序问题）→ 从源头修复初始化顺序
- `main.dart`
  - `29-35, 38-43` Firebase/GetStorage 初始化 catch → 让异常传播（fail fast）
- `auth_controller.dart`：**作为正面范例保留**，几乎不动

**批次 3 — models/**

- `download_task.dart`
  - `82` `downloaderId ?? ''` → 去掉兜底（必填字段，缺失即 bug）
  - `72-73` id/gid 交叉兜底 → 各自独立，必填缺失抛错
  - `89-90` num_seeds/seeders 双字段 → 字段名归一化下沉到 service 层，fromJson 只接收归一化字段
  - 保留：`_parseStatus` 状态映射（外部数据边界处理的正面范例）
- `downloader.dart`
  - `55-62` id/name/host 裸取 vs port 兜底风格不一致 → 统一为必填裸取（缺失抛错），删除 port 的 `?? 6800`（多下载器默认值语义风险）
  - 保留：`DownloaderType.values.firstWhere(orElse)` 兼容老数据、`useHttps ?? false` 向后兼容

**批次 4 — core/utils/（按需）**

- `review_manager.dart:45-51` openStoreListing catch → 让 UI 感知失败（用户主动操作）
- 保留：log.dart 的静默失败、review_manager.requestReview 的后台降级

### 5.3 逐条清单格式

每批清理前，产出 Markdown 清单表格，用户逐条标记后执行：

| # | 文件:行号 | 现状代码 | 建议改法 | 影响评估 | 决定 |
|---|-----------|----------|----------|----------|------|
| 1 | aria2_service.dart:163 | `catch (e) {} return [];` | 抛异常 | controller 需 catch 写 errorState | ☐移除 ☐保留 ☐调整 |

用户对每条标记：`移除`（执行改法）/ `保留`（不动）/ `调整`（说明替代改法）。

---

## 6. 验证方案

每批清理后执行：
1. `flutter test`（全部单元/Widget 测试通过）
2. `flutter analyze`（无新增 warning/error）
3. 关键路径手测：
   - 下载器连接（成功 + 失败场景，UI 显示明确错误）
   - 获取任务列表（在线 + 离线场景，UI 区分"空"与"失败"）
   - 任务暂停/恢复/删除（成功 + 失败场景，UI 反馈失败）
4. 批次 1 完成后，重点验证 service 抛出的异常被 controller 正确捕获并写入 errorState

---

## 7. 验收标准

- [ ] `CLAUDE.md` 新增「编码规范：禁止防御性编程」章节，含 6 条禁止清单 + 错误传播规范 + 外部数据分层 fail-fast + 6 条允许例外
- [ ] `AGENTS.md` ANTI-PATTERNS 章节新增精简指针
- [ ] services 层静默 catch 全部改为抛异常（或保留外层网络 catch 但抛出）
- [ ] controllers 层捕获异常并写入 errorState，UI 能显示失败状态
- [ ] `_createService` 返回类型改为非空，消除 9+ 处 null 检查
- [ ] `getDownloader` 改用 `firstWhereOrNull`
- [ ] `main.dart` 致命初始化错误不再被吞
- [ ] models 层内部字段兜底移除，外部数据按分层 fail-fast 处理
- [ ] `flutter test` 全绿
- [ ] `flutter analyze` 无新增问题
- [ ] 关键路径手测通过（连接/任务列表/任务操作的成功与失败场景）

---

## 8. 风险与缓解

| 风险 | 缓解 |
|------|------|
| fail-fast 后生产环境崩溃增多 | 外部数据采用分层 fail-fast（可选字段 nullable 而非抛错）；每批充分手测；批次 1 优先处理，便于尽早发现问题 |
| service 签名变更引发 controller 连锁修改 | 批次顺序 1→2 保证 service 先稳定；批次 2 是 controller 适配 |
| 移除兜底后暴露历史 bug | 这正是 fail-fast 的目的；逐条清单让用户决定每项，可保留高风险项 |
| 文档规则过严，未来开发受限 | 允许例外清单已覆盖合理场景（网络 try-catch、mounted、copyWith 等） |

---

## 9. 实施顺序总览

1. **阶段 1**：编辑 `CLAUDE.md` + `AGENTS.md`，落地规则（单一提交）
2. **阶段 2 - 批次 1**：产出 services 层逐条清单 → 用户确认 → 执行 → 测试
3. **阶段 2 - 批次 2**：controllers + main.dart（同上流程）
4. **阶段 2 - 批次 3**：models（同上流程）
5. **阶段 2 - 批次 4**：core/utils（同上流程）
6. **收尾**：全量 `flutter test` + 关键路径手测 + 验收清单核对
