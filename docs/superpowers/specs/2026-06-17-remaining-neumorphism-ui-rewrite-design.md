# 剩余页面 Neumorphism UI 重写方案

日期：2026-06-17  
状态：对话内方案已确认，待最终文档复核  
参考设计稿目录：`design/v2/`

## 概述

本方案用于将 WindWalker 中尚未完成 v2 Neumorphism UI 重写的页面，按现有 `design/v2` 设计稿分批落地为 Flutter 页面。

本次明确排除：

- 启动页：`startup_page.dart`
- 首页总览 tab：`data_tab.dart`
- 首页下载器 tab：`management_tab.dart`

原因：

- 启动页已存在独立拟物化实现，并且本轮用户明确排除。
- 总览 tab 和下载器 tab 已按 v2 方向完成主要改造。

本次覆盖 10 个页面：

- `add_task_page.dart`
- `all_tasks_tab_page.dart` / `tasks_tab.dart`
- `tasks_page.dart`
- `task_detail_page.dart`
- `downloader_editor_page.dart`
- `downloader_config_page.dart`
- `profile_tab.dart`
- `login_page.dart`
- `settings_page.dart`
- `about_page.dart`

## 目标

- 按 `design/v2` 中对应页面稿统一剩余页面的 v2 soft UI 风格。
- 保留现有路由、Provider 数据来源、业务行为和错误传播方式。
- 将常见视觉结构沉淀为小而明确的 Neo 组件，避免每页散落重复 `BoxDecoration`。
- 分三批实现，降低一次性改动风险。
- 为每批补充 focused widget tests，覆盖关键行为和主要视觉契约。

## 非目标

- 不重写启动页。
- 不重写已完成的总览 tab 和下载器 tab。
- 不改变 `DownloaderController`、`TaskController`、`SettingsController`、`AuthController`、`UpdateController` 的业务职责。
- 不调整 go_router 路由结构。
- 不新增下载器或任务数据字段。
- 不引入新的状态管理框架。
- 不把本轮变成完整设计系统重构；只抽取本轮确实复用的组件。

## 设计依据

本轮实现以以下设计稿为页面视觉依据：

- `design/v2/add-task-neumorphism-ui-mockup.html`
- `design/v2/tasks-tab-neumorphism-ui-mockup.html`
- `design/v2/downloader-tasks-neumorphism-ui-mockup.html`
- `design/v2/task-detail-neumorphism-ui-mockup.html`
- `design/v2/downloader-editor-neumorphism-ui-mockup.html`
- `design/v2/downloader-config-neumorphism-ui-mockup.html`
- `design/v2/profile-tab-neumorphism-ui-mockup.html`
- `design/v2/login-neumorphism-ui-mockup.html`
- `design/v2/settings-neumorphism-ui-mockup.html`
- `design/v2/about-neumorphism-ui-mockup.html`

共享视觉语言继续使用：

- 雾灰蓝浅色背景与深石墨深色背景。
- 外凸 `NeoCard` / `NeoSurface`。
- 内凹输入、筛选、选择项。
- 语义状态色只用于状态 badge、进度条、图标块和危险操作。
- 页面内标题区替代普通 Material `AppBar` 的强存在感。
- 底部固定操作区继续使用 `NeoActionBar`。

## 总体实现方式

采用分三批页面族重写：

1. 任务流
2. 下载器配置流
3. 账户设置流

每批内部允许抽取当批真实复用的小组件。组件抽取以边界清晰为准：

- 能用现有 `NeoCard`、`NeoSection`、`NeoInputShell`、`NeoActionBar` 表达的，不重复造。
- 同一批页面重复出现 2 次以上，且语义一致的结构，可以抽取。
- 不为未来未验证页面提前抽象。

## 共享组件设计

### `NeoPageHeader`

用途：

- 替代本轮页面中普通 `AppBar` 的视觉主标题区。
- 适用于登录外的二级页面、任务页、配置页、设置页。

建议能力：

- `title`
- `subtitle`
- 可选返回按钮
- 可选右侧图标按钮，例如刷新
- 使用页面内容区内布局，不作为 `Scaffold.appBar`

约束：

- 不承载业务逻辑。
- 只通过回调触发返回、刷新等动作。
- 文案过长时必须省略，不挤压右侧按钮。

### `NeoSettingRow`

用途：

- 我的页、设置页、关于页入口行。

建议能力：

- 左侧拟物图标块。
- 标题。
- 副标题。
- 右侧 chevron、当前值、badge 或 loading indicator。
- 可选危险态。

约束：

- 行高稳定。
- 不使用普通 `ListTile`。
- 危险态只影响图标和文字强调，不改变整行布局。

### `NeoFormFieldShell`

用途：

- 下载器编辑页、下载器配置页、添加任务页的输入项。

建议能力：

- label。
- value / child。
- 可选 suffix，例如 `KB/s`。
- 可选 enabled 状态。

约束：

- 继续使用 Flutter 表单校验，不绕开 `TextFormField` 的 validator。
- 只负责外层拟物容器和布局。

### `NeoChoicePill` / `NeoFilterStrip`

用途：

- 任务状态筛选。
- 下载器类型选择。
- 主题/语言选项可复用。

建议能力：

- selected 状态。
- label。
- optional icon。
- horizontal scroll。

约束：

- 选中态用内凹或蓝色弱底表达。
- 不使用 Material `ChoiceChip` 作为最终视觉。

### `NeoStatusHeroCard`

用途：

- 任务详情页 hero。
- 单下载器任务页下载器身份卡。
- 下载器配置页下载器身份卡。

建议能力：

- 左侧图标。
- 主标题和副标题。
- 状态 badge。
- 可选 progress / meta row。

约束：

- 只做展示，不持有刷新或操作逻辑。

### `NeoModalSheet` / `NeoConfirmDialog`

用途：

- 设置页主题/语言选择。
- 退出登录确认。
- 关于页更新确认。
- 任务删除确认可继续复用现有 `delete_task_dialog.dart` 的 Neo 方向。

约束：

- 保留原有确认行为。
- 弹层和弹窗使用软表面、内凹选项、明确主/次操作。

## 第一批：任务流

覆盖文件：

- `lib/features/add_task/presentation/pages/add_task_page.dart`
- `lib/features/home/presentation/pages/all_tasks_tab_page.dart`
- `lib/features/home/presentation/pages/tasks_tab.dart`
- `lib/features/tasks/presentation/pages/tasks_page.dart`
- `lib/features/tasks/presentation/pages/task_detail_page.dart`

### 添加任务页

参考：`design/v2/add-task-neumorphism-ui-mockup.html`

保留行为：

- 初始 URL 参数填充。
- 下载器选择。
- 链接输入。
- Torrent 文件选择入口。
- 保存路径输入。
- 来源冲突确认。
- 提交时调用现有 controller/service。
- 底部开始下载操作。

视觉改造：

- 页面内 `NeoPageHeader` 替代普通 AppBar。
- 下载器选择卡使用 `NeoStatusHeroCard` 或专用选择卡。
- 链接输入和保存路径使用内凹表单壳。
- 链接来源和种子来源使用两个外凸 source card。
- 底部操作使用 `NeoActionBar`。
- 选择下载器底部弹层和来源冲突确认弹窗使用 Neo 风格。

测试重点：

- 初始 URL 仍能填入输入框。
- 无下载器或未选择下载器时的提示仍存在。
- 来源冲突确认仍能触发。
- 点击提交仍调用原有 add task 路径。

### 任务列表 tab

参考：`design/v2/tasks-tab-neumorphism-ui-mockup.html`

保留行为：

- `TasksTab` 继续转发到 `AllTasksTabPage`。
- `AllTasksTabPage` 首次加载所有下载器任务。
- 使用 `TaskController.startAutoRefresh`。
- 搜索任务名、保存路径、下载器名。
- 状态筛选。
- 下拉刷新。
- 点击任务进入详情页。

视觉改造：

- 移除内部 `Scaffold.appBar` 的传统视觉，改为页面内标题与刷新软按钮。
- 搜索框使用 `NeoInputShell` 或新表单壳。
- `ChoiceChip` 替换为 `NeoFilterStrip`。
- 任务卡保留标题、下载器、进度、状态、速度、大小信息，但使用 v2 任务卡布局。
- 空态和加载态使用 Neo 软卡。

测试重点：

- 搜索仍按任务名、路径、下载器名过滤。
- 状态筛选仍过滤对应任务。
- 点击任务路由参数不变。
- 刷新按钮和下拉刷新仍调用加载逻辑。

### 单下载器任务页

参考：`design/v2/downloader-tasks-neumorphism-ui-mockup.html`

保留行为：

- `/tasks?id=<downloaderId>&type=<downloaderType>` 路由。
- 返回按钮可配置。
- 刷新按钮可配置。
- 搜索当前下载器任务。
- 状态筛选。
- 暂停、继续、删除任务。
- 点击进入任务详情。

视觉改造：

- 顶部增加下载器身份卡，展示类型、名称、地址或类型 label。
- 任务筛选与任务卡视觉和任务列表 tab 保持一致。
- 卡片底部展示 `暂停/继续/详情/删除` 操作。
- 删除继续使用 Neo 删除确认弹窗。

测试重点：

- 给定 downloaderId 时只读取该下载器任务。
- 暂停、继续、删除调用正确的 downloaderId。
- 无任务状态显示 Neo 空态。
- 路由到详情页参数不变。

### 任务详情页

参考：`design/v2/task-detail-neumorphism-ui-mockup.html`

保留行为：

- 首次加载和 5 秒定时刷新。
- 下拉刷新。
- 暂停、继续、删除。
- 删除成功后返回上一页。
- 文件信息、下载信息、连接信息的数据来源不变。

视觉改造：

- 顶部任务状态 hero：任务名、下载器、状态 badge、进度、速度/体积。
- 文件信息、下载信息、连接信息继续分组，但改为稳定 KV row。
- 底部固定操作条保留 `暂停 / 继续 / 删除`。
- 初始加载状态使用 Neo loading surface。

测试重点：

- loading detail 时展示加载态。
- 当前任务为空时不崩溃，展示占位。
- 暂停/继续按钮 enable 规则不变。
- 删除确认后调用删除并返回。

## 第二批：下载器配置流

覆盖文件：

- `lib/features/downloaders/presentation/pages/downloader_editor_page.dart`
- `lib/features/downloaders/presentation/pages/downloader_config_page.dart`

### 新增/编辑下载器页

参考：`design/v2/downloader-editor-neumorphism-ui-mockup.html`

保留行为：

- 新增和编辑共用页面。
- 根据 downloaderId 查找已有下载器。
- 不存在时提示并返回。
- 类型切换时默认端口更新。
- HTTPS 开关。
- Aria2 使用 RPC Secret。
- qBittorrent / Transmission 使用用户名和密码。
- 保存时表单校验。
- 保存后连接测试。
- 根据 `ConnectionSuccess` / `ConnectionFailure` 展示结果。

视觉改造：

- 类型选择从 `DropdownButtonFormField` 改为三张类型软卡。
- 基础信息和认证信息分为两个 Neo 表单面板。
- 端口和 HTTPS 可以同排展示。
- 输入项使用内凹表单壳。
- 底部固定保存按钮保留 loading 状态。

测试重点：

- 新增页默认 Aria2 与默认端口。
- 类型切换更新端口。
- Aria2 和非 Aria2 认证字段切换正确。
- 表单校验仍阻止非法提交。
- 保存成功返回，失败显示对应错误。

### 下载器配置页

参考：`design/v2/downloader-config-neumorphism-ui-mockup.html`

保留行为：

- 加载 `SpeedConfigDescriptor`。
- descriptor 为空时展示不支持配置。
- 读取并填充当前限速配置。
- toggle 控制相关字段启用状态。
- 非负整数校验。
- 保存 `DownloaderSpeedConfig`。
- 保存成功 Snackbar，失败展示错误状态。

视觉改造：

- 顶部下载器身份卡展示名称、地址、状态。
- descriptor section 映射为 Neo 配置分组。
- toggle 行使用拟物开关行。
- KB/s 字段使用内凹表单壳并固定单位。
- 不支持配置和错误状态使用页面内 Neo 空态/错误态。
- loading 和 error 时隐藏底部保存按钮。

测试重点：

- descriptor 为空时不展示保存按钮。
- 已有配置能填入字段。
- toggle 改变后相关字段启用状态正确。
- 非法输入阻止保存。
- 保存成功和失败反馈正确。

## 第三批：账户设置流

覆盖文件：

- `lib/features/home/presentation/pages/profile_tab.dart`
- `lib/features/auth/presentation/pages/login_page.dart`
- `lib/features/settings/presentation/pages/settings_page.dart`
- `lib/features/settings/presentation/pages/about_page.dart`

### 我的 tab

参考：`design/v2/profile-tab-neumorphism-ui-mockup.html`

保留行为：

- 未登录点击账号卡进入 `/login`。
- 已登录展示 displayName / email / photoUrl。
- 隐私政策外链。
- 联系开发者 mailto。
- 分享应用。
- 进入设置。
- 进入关于页。
- 更新可用时关于入口展示更新提示。

视觉改造：

- 使用账号品牌卡作为第一视觉。
- 登录/未登录状态在卡内表达。
- 版本/更新状态作为 meta tile。
- 支持和应用入口使用 `NeoSettingRow`。
- 移除普通 `Card` + `ListTile` 视觉。

测试重点：

- 未登录点击账号卡进入登录页。
- 已登录不触发登录跳转。
- 支持入口调用原行为。
- 更新可用时关于入口显示更新提示。

### 登录页

参考：`design/v2/login-neumorphism-ui-mockup.html`

保留行为：

- 已登录时自动回首页。
- 返回按钮。
- Google 登录。
- loading 时禁用按钮并显示 loading。
- errorMessage 展示。
- terms notice 展示。

视觉改造：

- 居中品牌登录卡。
- Google 登录作为主按钮。
- 错误提示作为卡内或按钮上方 Neo 错误提示。
- 条款说明保持弱文本。

测试重点：

- 点击登录调用 `signInWithGoogle`。
- loading 状态按钮不可用。
- errorMessage 可见。
- 已登录触发回首页。

### 设置页

参考：`design/v2/settings-neumorphism-ui-mockup.html`

保留行为：

- 返回按钮。
- 主题模式选择。
- 语言选择。
- 已登录时显示退出登录。
- 退出登录确认。

视觉改造：

- 通用设置分组使用 `NeoSettingRow`。
- 主题/语言选择 bottom sheet 改为 Neo 样式。
- 退出登录作为危险分组独立展示。
- 退出确认使用 Neo confirm dialog。

测试重点：

- 主题选择更新 `SettingsController`。
- 语言选择更新 `SettingsController`。
- 未登录不显示退出登录。
- 确认退出后调用 `AuthController.signOut`。

### 关于页

参考：`design/v2/about-neumorphism-ui-mockup.html`

保留行为：

- 返回按钮。
- 展示 AppVersion。
- 手动检查更新。
- update 状态文案。
- 有更新时弹窗，确认后打开商店。
- 无更新时 Snackbar。
- 评价应用打开商店。

视觉改造：

- 品牌版本卡作为第一视觉。
- 版本、检查更新、评价应用入口使用 `NeoSettingRow`。
- 更新状态使用 badge 或 meta 文案。
- 更新确认使用 Neo dialog。

测试重点：

- update 状态文案正确。
- 点击检查更新调用 controller。
- 有更新时确认弹窗出现。
- 确认更新调用 `openStorePage`。
- 评价入口调用 ReviewManager 行为可通过注入或现有测试策略覆盖。

## 数据流与错误处理

本轮不改变 controller/service 的职责。

任务相关：

- `DownloaderController` 继续负责下载器列表、状态和服务工厂。
- `TaskController` 继续负责任务列表、单下载器任务、任务详情和任务操作。
- UI 只读取 controller 状态并触发 controller 方法。

下载器配置相关：

- `DownloaderController` 继续负责新增、更新、连接测试、速度配置 descriptor 与保存。
- UI 保留表单校验，错误反馈不吞异常。

账户设置相关：

- `AuthController` 继续负责登录、登出和用户状态。
- `SettingsController` 继续负责主题和语言。
- `UpdateController` 继续负责更新检查和商店跳转。

错误处理规则：

- 不引入静默 catch 后返回默认值。
- 页面内部可捕获平台能力调用错误，例如外链、分享失败，但必须记录 `Log.e` 并显示用户可见反馈。
- 配置加载错误展示 Neo 错误态，不伪装为空态。
- 不支持配置与加载错误区分展示。

## 测试策略

每批实现时至少覆盖：

- 页面主要文案和结构存在。
- 关键 controller 回调仍被触发。
- 路由参数不变。
- loading / empty / error 其中至少一个非正常状态。
- 暗色主题下组件不会依赖浅色硬编码文本色。

建议新增或更新测试：

- `test/widget/add_task_page_test.dart`
- `test/widget/all_tasks_tab_shared_state_test.dart`
- `test/widget/tasks_page_shared_state_test.dart`
- 新增 `test/widget/task_detail_neumorphism_test.dart`
- 新增 `test/widget/downloader_editor_neumorphism_test.dart`
- 新增 `test/widget/downloader_config_neumorphism_test.dart`
- 更新 `test/widget/profile_tab_update_badge_test.dart`
- 更新或新增 `test/widget/login_page_test.dart`
- 更新 `test/widget/settings_page_test.dart`
- 更新 `test/widget/about_page_update_test.dart`

## 实施顺序

推荐顺序：

1. 抽取最小共享组件：`NeoPageHeader`、`NeoSettingRow`、`NeoChoicePill`、`NeoFormFieldShell`。
2. 第一批任务流。
3. 第二批下载器配置流。
4. 第三批账户设置流。
5. 统一跑格式化、分析和相关 widget/unit tests。

如果单批改动仍然过大，第一批任务流可再拆：

- 1A：任务列表 tab + 单下载器任务页。
- 1B：添加任务页 + 任务详情页。

## 验收标准

- 10 个页面均不再呈现普通 Material `Card/ListTile/ChoiceChip/AppBar` 为主视觉。
- 页面与 `design/v2` 对应设计稿的信息架构一致。
- 浅色与深色主题均使用 `NeoThemeTokens`，不硬编码只适合浅色主题的文本色。
- 原有业务行为和路由语义保持不变。
- 关键 widget tests 通过。
- `flutter analyze` 通过。
