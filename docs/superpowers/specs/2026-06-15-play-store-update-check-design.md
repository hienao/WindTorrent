# Play 商店更新检测与低打扰提醒设计

Date: 2026-06-15
Status: Approved for spec review
Scope: WindWalker Android 更新检测与提醒

## Summary

WindWalker 目前已经具备两个与版本相关的基础能力：

- `AppVersion.displayVersion()`：展示本地应用版本
- `ReviewManager().openStoreListing()`：打开商店详情页

但项目还没有“检测 Play 商店是否存在新版本”的能力，也没有与之配套的低打扰提醒策略。

本设计的目标是在 **不干扰当前使用体验** 的前提下，为正式 Android 包增加官方 Play 更新检测能力，并将用户体验分成两层：

- 常态层：静默检查，有更新时只显示轻提示
- 提醒层：仅在满足严格条件时弹一次非强制弹窗

更新动作统一为跳转 Play 商店详情页，不在第一期实现应用内更新安装流程。

## Goals

- 基于 Google Play 官方更新能力判断是否有新版本
- 平时只做轻提示，不主动打断用户
- 满足条件时提供一次温和弹窗提醒
- 有进行中的下载任务时绝不弹窗
- `debug/dev` 包不启用更新检测能力
- 保持更新检测逻辑与 UI 解耦，符合现有 `Provider + ChangeNotifier` 架构

## Non-Goals

- 不抓取 Play 商店网页或解析商店 HTML
- 不引入自建远端版本配置中心
- 不实现强制更新
- 不实现 Google Play 应用内更新安装流
- 不为 iOS、桌面端或侧载渠道构建完整更新方案

## Current State

当前代码中的相关基础设施如下：

- [lib/core/utils/app_version.dart](/Volumes/Data/Code/GitHub/WindWalker/lib/core/utils/app_version.dart:1)
  - 通过 `package_info_plus` 获取本地版本信息
- [lib/core/utils/review_manager.dart](/Volumes/Data/Code/GitHub/WindWalker/lib/core/utils/review_manager.dart:1)
  - 已封装 `openStoreListing()`
- [lib/features/settings/presentation/pages/about_page.dart](/Volumes/Data/Code/GitHub/WindWalker/lib/features/settings/presentation/pages/about_page.dart:1)
  - 已有版本展示与“评分”入口，适合作为“检查更新”入口落点
- [lib/app.dart](/Volumes/Data/Code/GitHub/WindWalker/lib/app.dart:1)
  - 已采用 `MultiProvider` 注册全局 `ChangeNotifier`
- [lib/main.dart](/Volumes/Data/Code/GitHub/WindWalker/lib/main.dart:1)
  - 已具备首帧/启动埋点，可将静默检查延后到首屏稳定之后

这意味着第一期不需要重做版本展示或商店跳转，只需补齐“检查 + 决策 + 提示”的中间层。

## Constraints

- 只在 Android 正式包启用；`debug/dev` 包不启用
- 更新检查不属于致命启动依赖，失败时不得影响主流程
- 必须遵守当前项目“低打扰”目标，避免打断正在使用中的用户
- 与项目现有 fail-fast 文化兼容：
  - Play 更新检查失败可静默降级并记录日志
  - 但不得伪造“已是最新版本”等误导性状态
- 控制器与页面不直接依赖底层 Play API，保持边界清晰

## User Experience Decision

本功能采用“轻提示 + 温和弹窗”的双层策略。

### 1. 轻提示层

当检测到 Play 存在新版本时：

- 在“关于”页展示“发现新版本”或等价状态文案
- 在个人页或设置入口展示轻量提示标记
- 不主动弹窗

轻提示层是更新触达的默认路径，优先级高于任何主动打断。

### 2. 温和弹窗层

只有在以下条件同时满足时，才允许弹一次非强制弹窗：

- 当前检测结果为“有新版本”
- 当前没有进行中的下载任务
- 当前构建不是 `debug/dev`
- 当前会话尚未消费弹窗机会
- 今天尚未弹过更新提醒
- 距离上次真正弹窗已超过冷却期
- 用户没有对当前目标版本点过“稍后”

弹窗动作只有两个：

- `去更新`：跳转 Play 商店详情页
- `稍后`：关闭弹窗，并记录当前目标版本已被用户延后

不提供强制更新，不提供“以后不再提醒全部版本”的全局关闭。

## Proposed Architecture

建议新增四个职责清晰的单元：

1. `UpdateService`
2. `UpdatePromptPolicy`
3. `UpdateController`
4. UI 接入点

### 1. UpdateService

`UpdateService` 只负责与 Google Play 官方更新能力交互，不负责弹窗时机、节流、UI 状态。

Responsibilities:

- 判断当前环境是否允许启用更新检查
- 调用 Google Play 官方更新能力查询是否存在可用更新
- 将结果转换为稳定的领域模型
- 暴露打开 Play 商店详情页的能力
- 当官方更新能力不可用时，显式返回“无法判断更新状态”，不回退到抓取商店网页

建议输出的结果对象示意：

- `isUpdateAvailable`
- `availableVersionCode`
- `source`（固定为 `playStore`，便于未来扩展）

`UpdateService` 不负责：

- 记录“今天是否提醒过”
- 判断是否弹窗
- 管理页面上的 badge 展示

### 2. UpdatePromptPolicy

`UpdatePromptPolicy` 只负责判断“当前应该如何提醒”，不直接操作 UI。

Inputs:

- 是否为受支持的正式 Android 包
- 当前是否有可用更新
- 当前是否存在进行中的下载任务
- 上次弹窗时间
- 今天是否已经提醒过
- 当前版本是否已被用户点过“稍后”
- 当前会话是否已经消费过一次弹窗机会

Outputs:

- `none`
- `badgeOnly`
- `dialogAllowed`

策略原则：

- 默认先偏向 `badgeOnly`
- 只有严格条件全满足才返回 `dialogAllowed`
- “有下载进行中”直接压制弹窗，最多返回 `badgeOnly`

### 3. UpdateController

`UpdateController` 采用现有项目风格，使用 `ChangeNotifier` 暴露更新状态，统一协调服务调用、策略判断和本地持久化。

Suggested responsibilities:

- 在合适时机触发静默检查
- 缓存最近一次已知更新结果
- 计算并暴露轻提示状态
- 暴露“当前是否允许弹窗”
- 处理手动“检查更新”
- 记录“稍后”操作和最近提醒时间
- 保证弹窗机会在单个会话内只消费一次

Suggested state:

- `isChecking`
- `hasUpdate`
- `availableVersionCode`
- `shouldShowUpdateBadge`
- `shouldOfferUpdateDialog`
- `lastCheckAt`

### 4. UI Integration Points

建议第一期接入以下页面与层级：

- `AboutPage`
  - 增加“检查更新”入口
  - 有更新时展示“发现新版本”状态
- `ProfileTab` 或设置入口
  - 展示轻提示标记
- 顶层首页稳定后
  - 由宿主页面根据 `UpdateController` 状态决定是否消费一次弹窗机会

页面只消费 `UpdateController` 暴露出来的状态和动作，不直接调用 Play 更新 API。

## Runtime Flow

运行时流程建议如下：

1. 应用完成首屏稳定
2. `UpdateController` 发起一次静默检查
3. `UpdateService` 查询 Google Play 更新状态
4. 若检查失败：
   - 写日志
   - 不改变现有 UI 流程
   - 不伪造“已最新”
5. 若检查成功且有新版本：
   - 更新本地状态
   - `UpdatePromptPolicy` 计算当前是 `badgeOnly` 还是 `dialogAllowed`
6. UI 根据 `UpdateController` 状态展示轻提示
7. 若允许弹窗，由宿主页面在安全时机消费一次弹窗机会
8. 用户点击：
   - `去更新` => 跳转 Play 商店，并记录提醒时间
   - `稍后` => 记录当前 `availableVersionCode` 已被延后

## Enablement Rules

第一期启用规则明确如下：

### Enabled

- Android 正式包
- 具备 Google Play 官方更新能力可用条件的安装场景

### Disabled

- `debug` 包
- `dev` 包
- 非 Android 平台

对禁用场景：

- 不做静默检查
- 不展示自动更新提示
- 可保留手动跳商店能力，前提是该入口在产品上仍有意义

对“正式包但官方更新能力当前不可用”的场景：

- 视为“自动检测不可用”
- 不回退到解析商店页面
- 只保留已有的手动跳商店能力

## Persistence Model

本地仅保存实现低打扰所需的最小状态，建议沿用项目当前的本地轻量存储模式。

Suggested persisted fields:

- `last_update_prompt_at`
- `last_update_prompt_day`
- `dismissed_update_version_code`
- `last_known_available_version_code`

原则：

- 只保存用户体验决策所需状态
- 不缓存复杂历史
- 不做远端同步

## Dialog Throttling Policy

第一期默认节流规则建议如下：

- 启动后延迟到首屏稳定再检查
- 每个自然日最多弹窗一次
- 距离上次真正弹窗至少 7 天
- 同一个 `availableVersionCode`，用户点过“稍后”后不再重复弹
- 当前存在下载任务时永不弹窗
- 手动“检查更新”不受弹窗节流限制，但仍不强弹

这是一套偏保守的默认值，优先保护体验；后续若需要更高更新触达率，可以单独调策略。

## Error Handling

更新检测是增强能力，不是主流程依赖，因此错误处理采用“静默失败 + 明确不误导”的方式。

Rules:

- 检查失败时不得影响应用启动、导航、任务列表、下载控制等主流程
- 不向用户弹出错误 toast 或错误对话框
- 记录 `Log.w()` 或 `Log.e()`，便于排查
- 失败时保留“未知状态”，而不是假装“没有更新”

特别说明：

- 这类静默降级是合理边界处理，不等同于项目禁止的“吞业务错误后返回默认成功状态”
- 因为更新提醒不是任务执行、登录、初始化这类核心业务

## Testing Strategy

建议覆盖三层验证：

### 1. Policy Unit Tests

覆盖 `UpdatePromptPolicy` 的关键组合：

- 有更新 + 无下载 + 冷却期外 => `dialogAllowed`
- 有更新 + 下载中 => `badgeOnly`
- 有更新 + 今日已提醒 => `badgeOnly`
- 有更新 + 当前版本已点稍后 => `badgeOnly`
- `debug/dev` => `none`
- 无更新 => `none`

### 2. Controller Unit Tests

覆盖 `UpdateController` 的关键行为：

- 静默检查成功后状态更新
- 检查失败后不污染现有状态
- 手动检查路径可正常触发商店跳转
- “稍后”能正确记录版本
- 弹窗机会在单次会话中只消费一次

### 3. Widget / Integration Verification

覆盖用户可见行为：

- About 页显示“检查更新”入口
- 有更新时显示轻提示文案或标记
- 满足条件时出现一次非强制弹窗
- 下载中不弹窗
- 点击“去更新”走商店跳转
- 点击“稍后”后重进同版本不重复弹

## Rollout Notes

建议实现顺序：

1. 先落 `UpdateService` 与结果模型
2. 再落 `UpdatePromptPolicy`
3. 再接入 `UpdateController`
4. 最后接 About 页、个人页和弹窗宿主点

这样可以把复杂度留在中间层，UI 接入阶段会更轻、更安全。

## Recommendation

第一期推荐方案总结如下：

- 用 Google Play 官方能力判断是否有更新
- 正式 Android 包启用，`debug/dev` 包不启用
- 平时只做轻提示
- 满足严格条件才弹一次非强制弹窗
- 有下载任务时绝不弹窗
- 更新动作统一跳转 Play 商店

这个方案在“稳定性、体验控制、实现复杂度”三者之间最平衡，也最符合 WindWalker 当前的产品节奏。
