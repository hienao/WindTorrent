# 防御性编程禁止规则 - 文档落地实施计划（阶段 1）

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 `CLAUDE.md` 和 `AGENTS.md` 落地"禁止防御性编程"硬性规则，约束 AI 与未来开发。

**Architecture:** `CLAUDE.md` 作为主体写入完整规则章节（6 条禁止清单 + 错误传播规范 + 外部数据分层 fail-fast + 6 条允许例外）；`AGENTS.md` 在 ANTI-PATTERNS 章节新增精简指针指向 CLAUDE.md。两文件各自独立提交，便于回溯。

**Tech Stack:** Markdown 文档编辑（无代码改动、无测试框架）。

**范围:** 仅阶段 1（文档规则落地）。阶段 2 代码清理（services / controllers / models / core 四批次）**不在本计划**，后续单独规划。

**内容来源:** 设计文档 `docs/superpowers/specs/2026-06-14-remove-defensive-programming-design.md` 的 4.1 / 4.2 节，内容已稳定，本计划完整内联（执行者无需回看设计文档）。

---

## File Structure

| 文件 | 责任 | 本次改动 |
|------|------|----------|
| `CLAUDE.md` | 给 Claude Code 的完整 guidance | 末尾新增 `## 编码规范：禁止防御性编程` 章节（主体） |
| `AGENTS.md` | 项目知识库（PROJECT KNOWLEDGE BASE） | `## ANTI-PATTERNS (THIS PROJECT)` 章节新增 1 条精简指针 |

新章节与 CLAUDE.md 现有 `## 架构规范`、`## 注意事项` 等 `##` 级章节平级。AGENTS.md 新条目与现有 `- **Controller init() pattern**` 等 bullet 平级。

---

### Task 1: CLAUDE.md 新增「编码规范：禁止防御性编程」章节

**Files:**
- Modify: `CLAUDE.md`（在第 156 行「日志系统」注意事项之后追加新 `##` 级章节）

- [ ] **Step 1: 用 Edit 在 CLAUDE.md 末尾追加新章节**

调用 Edit 工具，参数如下。

`old_string`（CLAUDE.md 第 156 行，文件内唯一）:

````
2. **日志系统**: 使用统一的 `Log` 工具类，在 main() 中调用 `Log.init()` 初始化。
````

`new_string`（原行 + 空行 + 完整新章节，照原样粘贴）:

````
2. **日志系统**: 使用统一的 `Log` 工具类，在 main() 中调用 `Log.init()` 初始化。

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

- [ ] **Step 2: 验证新章节的小节标题齐全**

Run:

```bash
grep -c "^## 编码规范：禁止防御性编程" CLAUDE.md
grep -c "^### 禁止的模式" CLAUDE.md
grep -c "^### 错误传播规范" CLAUDE.md
grep -c "^### 外部数据解析" CLAUDE.md
grep -c "^### 允许的例外" CLAUDE.md
```

Expected: 每条命令都输出 `1`（5 个小节标题全部存在）。若任一输出 `0`，检查 Step 1 的 new_string 是否完整粘贴。

- [ ] **Step 3: 验证 6 条禁止清单的关键词齐全**

Run:

```bash
grep -c "静默吞异常" CLAUDE.md
grep -c "不可能为 null 的 null 检查" CLAUDE.md
grep -c 'try-catch 处理"未找"' CLAUDE.md
grep -c "吞掉致命初始化错误" CLAUDE.md
grep -c "内部已保证字段的兜底" CLAUDE.md
grep -c "重复参数/状态验证" CLAUDE.md
```

Expected: 每条都输出 `1`。

> 注意：第 3 条 grep 模式 `"未找"` 可能因引号转义不匹配，若输出 `0`，改用 `grep -c "try-catch 处理" CLAUDE.md`（应输出 `1`）。

- [ ] **Step 4: 验证代码块闭合（``` 出现次数为偶数）**

Run:

```bash
grep -o '```' CLAUDE.md | wc -l
```

Expected: 偶数。新增章节含 6 个禁止清单（其中 5 条各含一个 ```dart 块 = 10 个 ```），共 10 个 ```，加上原文件已有的代码块。只要总数为偶数即表示代码块成对闭合。若为奇数，说明某代码块未闭合，回查 Step 1。

- [ ] **Step 5: 提交**

```bash
git add CLAUDE.md
git commit -m "docs: CLAUDE.md 新增禁止防御性编程编码规范"
```

---

### Task 2: AGENTS.md 新增精简指针

**Files:**
- Modify: `AGENTS.md`（在 `## ANTI-PATTERNS (THIS PROJECT)` 章节内，第 90 行 `sample_feature missing` 条目之后新增一条 bullet）

- [ ] **Step 1: 用 Edit 在 ANTI-PATTERNS 章节新增条目**

调用 Edit 工具，参数如下。

`old_string`（AGENTS.md 第 90 行，文件内唯一）:

````
- **sample_feature missing** — Referenced in docs but doesn't exist
````

`new_string`（原行 + 新条目）:

````
- **sample_feature missing** — Referenced in docs but doesn't exist
- **防御性编程（禁止）** — 本项目采用 fail-fast 原则。详见 `CLAUDE.md` 的「编码规范：禁止防御性编程」章节。核心：禁止静默吞异常（catch 后返回默认值不传播）、禁止不可能为 null 的 null 检查、禁止 try-catch 处理"未找到"（用 firstWhereOrNull）、禁止吞致命初始化错误。错误传播链：service 抛异常 → controller 写 errorState → UI 显示。
````

- [ ] **Step 2: 验证指针条目存在且引用章节名正确**

Run:

```bash
grep -c "防御性编程（禁止）" AGENTS.md
grep -c "编码规范：禁止防御性编程" AGENTS.md
```

Expected: 都输出 `1`。第一条确认新 bullet 存在；第二条确认引用的 CLAUDE.md 章节名与 Task 1 Step 1 写入的标题（`## 编码规范：禁止防御性编程`）完全一致。

- [ ] **Step 3: 验证新条目位于 ANTI-PATTERNS 章节内（而非 UNIQUE STYLES 等其他章节）**

Run:

```bash
awk '/^## ANTI-PATTERNS/,/^## /' AGENTS.md | grep -c "防御性编程（禁止）"
```

Expected: 输出 `1`（确认条目在 ANTI-PATTERNS 章节范围内）。若输出 `0`，说明插入位置错误，回查 Step 1 的 old_string 锚点。

- [ ] **Step 4: 提交**

```bash
git add AGENTS.md
git commit -m "docs: AGENTS.md ANTI-PATTERNS 新增防御性编程禁止指针"
```

---

### Task 3: 交叉验证与完成确认

**说明:** 确认两文件规则一致、指针指向有效、章节结构完整、工作区干净。

- [ ] **Step 1: 验证 AGENTS.md 引用的 CLAUDE.md 章节确实存在**

Run:

```bash
grep -q "^## 编码规范：禁止防御性编程" CLAUDE.md && echo "PASS: CLAUDE.md 章节存在" || echo "FAIL: 章节缺失"
```

Expected: `PASS: CLAUDE.md 章节存在`

- [ ] **Step 2: 验证 CLAUDE.md 新章节为 `##` 级（与其他顶级章节平级，非误入更深层级）**

Run:

```bash
grep -n "^## 编码规范：禁止防御性编程" CLAUDE.md
```

Expected: 输出形如 `158:## 编码规范：禁止防御性编程`（行号可能不同，关键是以 `## ` 开头，两个井号）。

- [ ] **Step 3: 确认两文件工作区干净（均已提交）**

Run:

```bash
git status --short CLAUDE.md AGENTS.md
```

Expected: 无输出（两文件均已 commit，无未提交改动）。

- [ ] **Step 4: 查看本计划产出的两个提交**

Run:

```bash
git log --oneline -2
```

Expected: 看到两条提交：
- `docs: AGENTS.md ANTI-PATTERNS 新增防御性编程禁止指针`
- `docs: CLAUDE.md 新增禁止防御性编程编码规范`

- [ ] **Step 5: 阶段 1 完成确认**

阶段 1 文档落地完成。CLAUDE.md 含完整禁止规则，AGENTS.md 含精简指针。**下一步**：进入阶段 2 代码清理（services → controllers → main.dart → models → core 四批次），需单独规划实施计划。

---

## Self-Review 记录

（执行前由计划编写者完成的自审，执行者无需关注）

**1. Spec 覆盖：** 设计文档 4.1（CLAUDE.md 完整规则）→ Task 1；4.2（AGENTS.md 指针）→ Task 2。设计文档阶段 1 范围全覆盖。阶段 2 明确排除。

**2. 占位符扫描：** 无 TBD/TODO；所有 new_string 完整内联；验证命令含 expected 输出。

**3. 一致性：** AGENTS.md 指针引用的章节名「编码规范：禁止防御性编程」与 CLAUDE.md Task 1 写入的 `## 编码规范：禁止防御性编程` 完全一致；Task 3 Step 1/2 专门交叉验证此一致性。
