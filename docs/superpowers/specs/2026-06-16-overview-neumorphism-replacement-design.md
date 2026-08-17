# 总览页拟物化替换方案

日期：2026-06-16
状态：对话内方案已确认，待最终文档复核
参考设计稿：`design/v2/overview-neumorphism-ui-mockup.html`

## 概述

本方案用于按 v2 设计稿替换当前首页的“总览”页面，同时把公共首页壳纳入第一阶段改造范围。

已确认实施方式：

- 采用方案 B：替换 `HomeTabContainer` 公共壳 + 替换 `DataTab` 总览内容。
- 第一阶段只改公共首页壳和总览页内容，不重构其他 tab 内部页面。
- 底部 tab、公共背景、公共 FAB 需要作为后续其他 tab 改造时可复用的逻辑。

## 目标

- 将当前总览页替换为 v2 设计稿中的控制台式拟物化总览。
- 将默认 Material `NavigationBar` 替换为可复用的拟物化底部 tab。
- 将添加任务 FAB 上移到公共首页壳中统一管理。
- 保留下拉刷新，不再展示显式刷新按钮。
- 继续使用现有业务数据来源，不新增 controller 或服务端字段。
- 抽出后续 `下载器 / 任务 / 我的` tab 改造可复用的公共组件边界。

## 非目标

- 不在本阶段重构 `ManagementTab`、`TasksTab`、`ProfileTab` 的内部 UI。
- 不改变 Provider、路由、更新检查、下载器业务逻辑。
- 不新增刷新按钮或新的刷新入口。
- 不改变添加任务、下载器详情、任务列表等现有导航语义。

## 当前状态

### `HomeTabContainer`

当前职责：

- 管理 `_currentIndex`
- 使用 `IndexedStack` 保持 tab 状态
- 初始化 `DownloaderController`
- 执行更新检查与更新弹窗
- 使用默认 Material `NavigationBar`

需要保留：

- `IndexedStack`
- `_currentIndex` 切换方式
- 首帧后的 `DownloaderController.init()`
- 更新检查和弹窗逻辑

需要替换：

- 默认 `NavigationBar`
- 每个 tab 目的地在 `HomeTabContainer` 中直接写死的展示逻辑
- 页面底部导航视觉样式

### `DataTab`

当前职责：

- 读取 `DownloaderController.globalStats`
- 读取 `DownloaderController.downloaders`
- 下拉刷新下载器状态和全局统计
- 展示任务状态总览
- 展示下载器分布列表
- 声明添加任务 FAB

需要保留：

- `Consumer<DownloaderController>`
- `RefreshIndicator`
- `refreshAllStatus()` 与 `refreshGlobalStats()`
- 任务状态 6 类统计
- 下载器分布与点击进入下载器任务页
- 空状态展示

需要替换：

- 顶部 `_OverviewHeader`
- `_StatCard` 网格视觉
- `_DownloaderDistributionCard` 结构与视觉
- `DataTab` 自己声明的 `floatingActionButton`

## 总体设计

第一阶段拆成两层：

1. 公共首页壳
2. 总览页内容

公共首页壳负责所有 tab 共享的页面框架，总览页内容只负责自己的业务展示。这样后续改造下载器、任务、我的 tab 时，可以继续复用同一套底部 tab、背景、安全区、FAB 和基础拟物组件。

## 公共首页壳设计

### `NeoHomeShell`

建议新增 `NeoHomeShell` 作为 `HomeTabContainer` 的展示壳。

职责：

- 接收 `selectedIndex`
- 接收 `onTabSelected`
- 接收 `children`
- 接收 tab 配置
- 使用 `IndexedStack` 渲染 children
- 渲染统一背景
- 渲染底部 `NeoHomeTabBar`
- 根据当前 tab 配置决定是否展示公共 FAB

不负责：

- 初始化下载器
- 更新检查
- 每个 tab 的业务内容
- 具体业务路由推导

`HomeTabContainer` 继续持有状态和业务初始化逻辑，`NeoHomeShell` 只负责视觉和布局。

### `NeoHomeTabBar`

`NeoHomeTabBar` 替代默认 `NavigationBar`。

视觉规则：

- 外层使用外凸拟物表面，类似设计稿中的底部软浮雕托盘。
- 每个 tab 使用固定宽度布局，避免切换时布局跳动。
- 当前选中 tab 使用内凹态表达。
- 未选中 tab 保持轻量图标 + 标签。
- 标签仍然使用当前本地化文案：`总览`、`下载器`、`任务列表`、`我的`。

组件输入：

- `List<NeoHomeTabItem>`
- `selectedIndex`
- `ValueChanged<int> onSelected`

`NeoHomeTabItem` 字段：

- `label`
- `icon`
- `selectedIcon`
- `semanticsLabel`
- `showFab`

### 公共 FAB

添加任务 FAB 从 `DataTab` 移到公共首页壳。

第一阶段规则：

- 只在总览 tab 显示。
- 点击后仍然执行 `context.push(AppConstants.addTaskRoute)`。
- 视觉使用设计稿中的蓝色外凸拟物按钮。
- 后续任务 tab 如需展示同一按钮，可以通过 tab 配置打开。

## 总览页内容设计

`DataTab` 替换为控制台式总览页面，由 4 个模块组成。

### 顶部品牌 Header

使用真实应用图标：

- `assets/branding/app_icon_master.png`

展示内容：

- 标题：`总览`
- 副标题：`WindWalker 控制台` 或等价本地化文案
- 运行状态短文案，例如“当前下载运行平稳”

交互规则：

- 不放右上角刷新按钮。
- 刷新交互统一由下拉刷新承担。

### 运行概览面板

展示当前运行状态的高优先级信息。

数据来源：

- 在线下载器数量：`downloaders.where(status == DownloaderStatus.online).length`
- 活跃任务数：从 `globalStats` 聚合下载中、等待中、做种等状态
- 总下载速度：聚合 `downloaders.downloadSpeed`
- 总上传速度：聚合 `downloaders.uploadSpeed`

展示内容：

- 健康状态 pill
- 总下载速度
- 活跃任务数
- 总上传速度
- 快捷入口：添加任务、下载器、查看任务

快捷入口规则：

- 添加任务：进入 `AppConstants.addTaskRoute`
- 下载器：切换到底部下载器 tab
- 查看任务：切换到底部任务 tab

### 任务状态矩阵

保留 6 类状态：

- 下载中
- 等待中
- 已暂停
- 做种中
- 已完成
- 错误

视觉规则：

- 使用 3 列矩阵。
- 每个状态卡包含图标、数字、标签和语义色。
- 状态色继续使用现有语义色，但以柔和底色和清晰前景表达。
- 卡片风格要成为后续任务页筛选和状态 badge 的参考。

数据来源：

- `globalStats['downloading']`
- `globalStats['waiting']`
- `globalStats['paused']`
- `globalStats['seeding']`
- `globalStats['completed']`
- `globalStats['error']`

### 下载器分布面板

展示下载器类型占比和每个下载器的关键状态。

数据来源：

- `downloaders`
- `Downloader.type`
- `Downloader.status`
- `Downloader.taskCount`
- `Downloader.downloadSpeed`
- `Downloader.uploadSpeed`
- `Downloader.port`
- `Downloader.taskStats`

展示内容：

- 环形占比图：按 `DownloaderType` 统计数量
- 类型数量摘要：Aria2、qBittorrent、Transmission
- 下载器列表行

下载器列表行字段：

- 类型标识
- 名称
- 任务数量
- 下载速度
- 端口或类型信息
- 在线 / 离线 / 错误状态

交互规则：

- 点击下载器行进入当前已有的下载器任务页路由。
- 空列表时展示当前空状态文案和添加引导。

## 公共组件边界

### 首页级组件

建议放在：

- `lib/features/home/presentation/widgets/`

组件：

- `NeoHomeShell`
- `NeoHomeTabBar`
- `NeoHomeTabItem`
- `NeoDashboardHeader`
- `NeoOverviewMetricPanel`
- `NeoStatusMatrix`
- `NeoDownloaderDistribution`

这些组件与首页业务关系更强，不放进底层 `core/theme`。

### 跨页面基础组件

继续放在：

- `lib/core/theme/neo_components.dart`

组件：

- `NeoSurface`
- `NeoCard`
- `NeoInputShell`
- `NeoBadge`
- `NeoProgress`
- `NeoActionBar`
- `NeoButton`

如果首页实现中需要新的真正跨页面组件，可以扩展 `neo_components.dart`，但避免把首页业务组件塞进去。

## 数据流

### 初始化

`HomeTabContainer` 保留现有逻辑：

- 首帧后调用 `DownloaderController.init()`
- 执行 `UpdateController.runSilentCheck()`
- 必要时展示更新弹窗

### 刷新

`DataTab` 保留 `RefreshIndicator`：

- `refreshAllStatus()`
- `refreshGlobalStats()`

不再展示显式刷新按钮。

### 统计推导

总览页新增展示都从现有字段推导：

- 在线数量来自 `downloaders`
- 活跃任务来自 `globalStats`
- 速度来自 `downloaders`
- 类型分布来自 `Downloader.type`

不新增 controller 状态。

## 交互行为

- 底部 tab 点击：只更新 `_currentIndex`
- 公共 FAB 点击：进入添加任务页
- 添加任务快捷入口：进入添加任务页
- 下载器快捷入口：切换到下载器 tab
- 查看任务快捷入口：切换到任务 tab
- 下载器分布行点击：进入对应下载器任务页
- 下拉刷新：刷新下载器状态和全局统计

## 错误与空状态

### 无下载器

下载器分布面板展示：

- 当前空状态文案
- 添加下载器引导
- 保持拟物化空状态容器

### 下载器离线或错误

下载器行仍展示，但状态 pill 使用对应语义色：

- 在线：成功色
- 离线：中性灰蓝
- 错误：错误色

### 统计为空

任务状态矩阵仍展示 6 个状态卡，数值为 0，避免页面结构塌陷。

## 测试策略

### 组件测试

新增或更新 widget test，覆盖：

- `NeoHomeShell` 能渲染 children 和底部 tab。
- 点击底部 tab 会触发 `onTabSelected`。
- 公共 FAB 在总览 tab 显示，并触发添加任务路由。
- `NeoStatusMatrix` 能展示 6 类状态。
- `NeoDownloaderDistribution` 能展示空状态、类型统计和列表行。

### 页面测试

更新现有首页相关测试：

- `home_page_test.dart`
- `management_tab_version_badge_test.dart`
- `profile_tab_update_badge_test.dart`
- 与总览页相关的测试

验证点：

- 首页仍能启动。
- 更新检查逻辑不受公共壳替换影响。
- 点击底部 tab 仍能切换到下载器、任务、我的。
- 总览页能展示 mock downloaders 的在线数量、任务状态和下载器分布。
- 下拉刷新仍调用原有刷新逻辑。

## 验收标准

- v2 设计稿中的总览页核心结构在 Flutter 页面中落地。
- 左上角使用真实 app icon。
- 右上角没有刷新按钮。
- 下拉刷新保留。
- 底部 tab 使用拟物化公共组件替代默认 `NavigationBar`。
- 添加任务 FAB 由公共首页壳管理。
- 其他 tab 内部页面功能不变。
- 后续其他 tab 可复用公共首页壳和底部 tab。
- 现有首页、更新提示、下载器初始化相关测试通过。

## 风险与缓解

### 风险：公共壳影响其他 tab 生命周期

缓解：

- 继续使用 `IndexedStack`。
- 不改变 children 创建方式。
- 不移动 Provider 读取位置。

### 风险：公共 FAB 与页面级 FAB 冲突

缓解：

- 第一阶段移除 `DataTab` 自己的 FAB。
- FAB 显示由 `NeoHomeTabItem.showFab` 或等价配置控制。

### 风险：总览页数据推导出现偏差

缓解：

- 不新增服务端字段。
- 所有新增展示从现有 `globalStats` 和 `downloaders` 推导。
- 对在线数量、活跃任务数、类型分布写 widget/unit 测试。

### 风险：首页业务组件污染 core

缓解：

- 首页业务组件放在 `features/home/presentation/widgets/`。
- 只有真正跨页面的基础拟物组件才进入 `core/theme/neo_components.dart`。

## 已确认决策

- 第一阶段采用方案 B。
- 公共底部 tab 纳入本次替换范围。
- 其他 tab 内部 UI 不在本阶段重构。
- 总览页使用 `design/v2/overview-neumorphism-ui-mockup.html` 作为视觉参考。
- 真实 app icon 使用 `assets/branding/app_icon_master.png`。
- 刷新交互只保留下拉刷新。
