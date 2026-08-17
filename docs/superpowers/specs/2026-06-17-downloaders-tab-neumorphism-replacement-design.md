# 下载器 Tab 拟物化替换方案

日期：2026-06-17  
状态：对话内方案已确认，待最终文档复核  
参考设计稿：`design/v2/downloaders-tab-neumorphism-ui-mockup.html`

## 概述

本方案用于按 v2 下载器设计稿替换当前首页的“下载器”tab 页面，同时小幅升级首页公共壳的 FAB 配置能力。

已确认实施方式：

- 采用方案 B：公共壳 FAB 升级 + 下载器页内容替换。
- 下载器 tab 的添加入口纳入 `NeoHomeShell` 公共 FAB，不在 `ManagementTab` 内部重复声明。
- 第一阶段只改公共 FAB 配置和下载器 tab 内容，不重构任务 tab、我的 tab 或下载器编辑/配置页面。

## 目标

- 将当前下载器 tab 替换为设计稿中的拟物化下载器管理页。
- 下载器页与总览页共享同一套 `NeoHomeShell` 背景、底部 tab、悬浮 FAB 规则。
- 将公共 FAB 从“仅支持是否显示”升级为“每个 tab 可配置动作”。
- 下载器卡片只展示下载器身份、地址、类型、版本、协议、状态和操作，不展示下载速度和任务数。
- 将低频或危险操作收敛到“更多”菜单，卡片主操作固定为 `任务 / 配置 / 更多`。
- 保留现有业务数据来源、路由语义、删除逻辑和下拉刷新。

## 非目标

- 不修改下载器编辑页、下载器配置页、任务列表页或任务详情页。
- 不改变 `DownloaderController` 的数据结构和刷新逻辑。
- 不新增下载器统计字段。
- 不在下载器 tab 中展示下载速度和任务数，这些信息继续由总览页承担。
- 不在页面上展示“下拉刷新状态”提示。

## 当前状态

### `HomeTabContainer`

当前职责：

- 管理 `_currentIndex`。
- 使用 `NeoHomeShell` 渲染公共首页壳。
- 初始化 `DownloaderController`。
- 执行更新检查与更新弹窗。
- 将总览、下载器、任务、我的四个 tab 传给公共壳。

当前问题：

- `NeoHomeTabItem` 只有 `showFab`，只能表达当前 tab 是否显示 FAB。
- 公共 FAB 的点击行为目前由 `NeoHomeShell.onFabPressed` 统一提供，无法按 tab 配置不同动作。
- 总览 tab 的 FAB 是“添加任务”，下载器 tab 也需要 FAB，但语义应为“添加下载器”。

需要保留：

- `IndexedStack`。
- `_currentIndex` 切换方式。
- 首帧后的 `DownloaderController.init()`。
- 更新检查和弹窗逻辑。
- 公共底部 tab。

需要替换：

- FAB 配置方式从单一 `onFabPressed` 升级为 per-tab 配置。

### `ManagementTab`

当前职责：

- 在 `initState` 中调用 `DownloaderController.loadDownloaders()`。
- 使用 `Consumer<DownloaderController>` 读取下载器列表。
- 使用 `RefreshIndicator` 下拉刷新下载器列表。
- 使用 `Scaffold + AppBar` 展示页面标题。
- 展示下载器卡片。
- 声明添加下载器 `FloatingActionButton.extended`。
- 删除下载器时使用默认 `AlertDialog`。

需要保留：

- `loadDownloaders()` 首次加载。
- `RefreshIndicator` 下拉刷新。
- 空态。
- 加载态。
- 点击进入任务页：`/tasks?id=<downloaderId>&type=<downloaderType>`。
- 点击配置：`/downloaders/<id>/config`。
- 点击编辑：`/downloaders/<id>/edit`。
- 删除确认后调用 `DownloaderController.removeDownloader(id)`。
- 版本展示：有版本显示版本号，无版本显示占位 `—`。

需要替换：

- 移除页面内部 `Scaffold`、`AppBar` 和 `FloatingActionButton.extended`。
- 替换传统卡片视觉为拟物化下载器卡片。
- 将 `配置 / 编辑 / 删除` 的直接三按钮结构调整为 `任务 / 配置 / 更多`。
- 将 `编辑 / 删除` 放入“更多”菜单。
- 删除弹窗改为拟物化样式。

## 总体设计

第一阶段拆成两层：

1. 公共首页壳 FAB 配置能力
2. 下载器 tab 内容

公共首页壳负责所有 tab 共享的底部导航、背景和 FAB 位置；下载器 tab 只负责下载器列表、空态、加载态和下载器相关操作。

## 公共首页壳设计

### `NeoHomeFabConfig`

新增公共 FAB 配置对象，用来描述当前 tab 的悬浮操作。

字段：

- `tooltip`
- `icon`
- `onPressed`

语义：

- 配置为空时不展示 FAB。
- 配置存在时展示 `NeoHomeFab`。
- `NeoHomeFab` 继续保持当前拟物化蓝色悬浮按钮视觉。

### `NeoHomeTabItem`

`NeoHomeTabItem.showFab` 不再适合作为长期能力。

建议替换为：

- `fabConfig` 或从 `NeoHomeShell` 接收 `NeoHomeFabConfig? Function(int selectedIndex)`。

优先方案：

- `HomeTabContainer` 根据 `_currentIndex` 计算当前 FAB 配置。
- `NeoHomeShell` 接收 `NeoHomeFabConfig? fabConfig`。
- `NeoHomeShell` 不理解业务路由，只负责展示和执行 `onPressed`。

这样 `NeoHomeShell` 不需要知道“总览”“下载器”等业务语义，边界更清晰。

### FAB 规则

第一阶段配置如下：

- 总览 tab：`tooltip = 添加任务`，`icon = Icons.add_rounded`，点击跳转 `AppConstants.addTaskRoute`。
- 下载器 tab：`tooltip = 添加下载器`，`icon = Icons.add_rounded`，点击跳转 `/downloaders/new`。
- 任务 tab：不显示 FAB。
- 我的 tab：不显示 FAB。

## 下载器 Tab 内容设计

### 页面结构

`ManagementTab` 改为嵌入公共壳的内容页，不再返回独立 `Scaffold`。

页面由以下模块组成：

1. 顶部标题区
2. 列表标题
3. 下载器列表 / 空态 / 加载态
4. 更多菜单
5. 删除确认弹窗

### 顶部标题区

展示文案：

- 主标题：`下载器`
- 副标题：`管理已配置的下载器`

规则：

- 不展示右上角添加按钮。
- 添加下载器只通过公共悬浮 FAB 进入。
- 标题保持横向正常排版，不被按钮挤压。

### 列表标题

展示：

- `已配置下载器`

规则：

- 不展示“下拉刷新状态”提示。
- 下拉刷新功能保留，但不在视觉层额外提示。

### 下载器卡片

每个下载器卡片展示：

- 统一重绘下载器类型图标。
- 下载器名称。
- `host:port`。
- 状态 badge：在线 / 离线 / 错误。
- 类型 pill：Aria2 / qBittorrent / Transmission。
- 版本 pill：版本号；没有版本时显示 `—`。
- 协议 pill：HTTP / HTTPS。
- 操作区：`任务 / 配置 / 更多`。

明确不展示：

- 下载速度。
- 上传速度。
- 任务数量。
- 任务运行状态统计。

这些信息继续由总览页承担，避免两个 tab 重复表达。

### 下载器类型图标

下载器图标不直接复用当前 emoji，也不混用未经统一处理的官方原图。

采用统一重绘风格：

- Aria2：橙色渐变方圆底，`a²` 字形，加分段下载线。
- qBittorrent：绿色渐变方圆底，白色圆形内置 `q`。
- Transmission：红色渐变方圆底，白色传输箭头。

目标：

- 三类图标在尺寸、圆角、阴影和色彩饱和度上保持一致。
- 保留官方标识的可识别特征。
- 适配浅色和深色主题。

### 空态

空态使用拟物化卡片展示：

- 主文案：`还没有添加下载器`
- 辅助文案：使用现有 `addDownloaderHint` 或等价中文文案。

规则：

- 空态不内置添加按钮。
- 添加入口仍然使用公共 FAB。

### 加载态

加载态使用页面内软表面样式：

- 可使用居中的 `CircularProgressIndicator`。
- 或使用 1-2 个拟物化骨架卡片。

第一阶段建议使用简单加载态，避免额外复杂动效。

## 交互设计

### 卡片操作

卡片操作固定三项：

- `任务`
- `配置`
- `更多`

交互：

- 点击 `任务`：进入该下载器任务页。
- 点击 `配置`：进入该下载器配置页。
- 点击 `更多`：打开拟物化菜单。

### 更多菜单

菜单项：

- `编辑`
- `删除`

规则：

- 菜单从“更多”按钮附近弹出。
- `删除` 使用危险色。
- 点击菜单外部关闭。
- 菜单不改变当前列表滚动状态。

### 删除确认弹窗

弹窗内容：

- 标题：使用现有 `deleteDownloader`。
- 内容：使用现有 `confirmDeleteDownloader`。
- 操作：`取消` 和 `删除`。

确认后：

- 调用 `context.read<DownloaderController>().removeDownloader(downloader.id)`。
- 关闭弹窗。

规则：

- 弹窗视觉使用拟物化表面。
- 不改变删除业务逻辑。
- 不吞掉删除异常，继续沿用 controller 现有错误处理模式。

### 下拉刷新

保留当前 `RefreshIndicator`。

触发：

- 调用 `DownloaderController.loadDownloaders()`。

规则：

- 页面不额外展示“下拉刷新状态”提示。
- 空态和列表态都应可下拉刷新。

## 路由设计

继续使用现有路由：

- 添加下载器：`/downloaders/new`
- 任务：`/tasks?id=<downloaderId>&type=<downloaderType>`
- 配置：`/downloaders/<id>/config`
- 编辑：`/downloaders/<id>/edit`

不新增路由。

## 组件边界

建议新增下载器 tab 专用 widgets 文件，例如：

- `lib/features/home/presentation/widgets/neo_downloader_widgets.dart`

可包含：

- `NeoDownloaderCard`
- `NeoDownloaderTypeIcon`
- `NeoDownloaderStatusBadge`
- `NeoDownloaderInfoPill`
- `NeoDownloaderMoreMenu`
- `NeoDownloaderDeleteDialog`
- `NeoDownloaderEmptyState`

边界规则：

- `ManagementTab` 负责读取 controller、组织列表和触发路由。
- `NeoDownloaderCard` 只负责单个下载器展示和回调。
- `NeoDownloaderMoreMenu` 只负责菜单展示，不直接访问 controller。
- `NeoDownloaderDeleteDialog` 返回用户选择或接收确认回调，不直接持有下载器列表状态。
- 通用拟物化表面继续优先复用 `NeoCard`、`NeoSurface`、`NeoBadge` 等核心组件。

## 测试设计

### 更新现有测试

更新 `test/widget/management_tab_version_badge_test.dart`：

- 有版本时显示版本号。
- 无版本时显示 `—`。
- 适配新的拟物化卡片结构。

更新 `test/widget/home/neo_home_shell_test.dart`：

- 验证公共 FAB 可根据当前 tab 配置改变 tooltip 和点击行为。
- 验证无 FAB 配置的 tab 不展示 FAB。

更新 `test/widget/home_page_test.dart`：

- 首页仍能启动。
- 底部仍使用 `NeoHomeTabBar`。
- 总览 tab FAB 仍展示“添加任务”。

### 新增测试

新增或扩展下载器 tab widget 测试：

- 渲染标题 `下载器` 和副标题 `管理已配置的下载器`。
- 不渲染 `AppBar`。
- 不渲染页面内部 `FloatingActionButton.extended`。
- 渲染下载器名称、`host:port`、状态、类型、版本、协议。
- 不渲染下载速度和任务数量。
- 点击 `任务` 跳转 `/tasks?id=<id>&type=<type>`。
- 点击 `配置` 跳转 `/downloaders/<id>/config`。
- 点击 `更多` 显示 `编辑` 和 `删除`。
- 点击 `编辑` 跳转 `/downloaders/<id>/edit`。
- 点击 `删除` 打开删除确认弹窗。
- 确认删除后调用 `removeDownloader(id)`。

### 回归验证

重点回归：

- `flutter test test/widget/management_tab_version_badge_test.dart`
- `flutter test test/widget/home/neo_home_shell_test.dart`
- `flutter test test/widget/home_page_test.dart`
- 下载器 tab 新增测试文件
- `flutter analyze`

## 实施顺序建议

1. 先升级 `NeoHomeShell` 的 FAB 配置能力，并更新公共壳测试。
2. 再替换 `HomeTabContainer` 的 FAB 配置映射。
3. 再新增下载器拟物化 widgets。
4. 再替换 `ManagementTab` 内容结构。
5. 最后更新/新增测试并跑回归。

## 风险与约束

- 公共 FAB 改造会影响总览 tab，需要测试确保“添加任务”不回归。
- `ManagementTab` 去掉内部 `Scaffold` 后，需要确认 `RefreshIndicator`、弹窗、菜单都有正确的 `Material` / `Overlay` 上下文。
- 下载器卡片不展示速度和任务数是明确产品决策，后续不要在实现时又补回。
- 删除弹窗视觉变化不能改变删除业务行为。
- 下载器图标第一阶段可用 Flutter 自绘/组合 widget 实现，不需要引入图片资源。
