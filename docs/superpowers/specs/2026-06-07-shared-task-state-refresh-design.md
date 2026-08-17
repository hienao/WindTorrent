# 共享任务状态与刷新联动设计

## 目标

解决 WindWalker 中“添加任务成功后任务列表看起来没有刷新”的问题，并统一以下页面的任务状态来源与刷新机制：

- 单下载器任务列表页 `TasksPage`
- 首页汇总任务页 `AllTasksTabPage`
- 任务详情页 `TaskDetailPage`

本次设计要求在以下操作成功后，相关页面都能及时反映最新任务状态：

- 添加任务
- 暂停任务
- 恢复任务
- 删除任务

## 问题现状

当前任务状态存在多处各自维护的问题：

- `AddTaskPage` 调用 `DownloaderController.addTask(...)` 成功后仅弹提示并 `pop`
- `TasksPage` 在页面内部自行创建 `TaskController`
- `AllTasksTabPage` 在页面内部自行创建 `TaskController`
- `TaskDetailPage` 在页面内部自行创建 `TaskController`

这导致“任务变更事件”和“任务列表刷新动作”没有统一状态源，页面之间也没有共享缓存或刷新通知。

直接表现为：

- 添加任务成功后，返回列表页时常常仍显示旧数据
- 详情页中暂停、恢复、删除任务后，其他列表页不会立即同步
- 汇总页与单下载器页可能显示不同步的状态

## 范围

本次包含：

- 任务状态改为全局共享 `TaskController`
- `TasksPage`、`AllTasksTabPage`、`TaskDetailPage` 改为订阅共享状态
- 添加/暂停/恢复/删除后的事件驱动刷新
- 低频全局轮询兜底刷新
- 任务详情页操作与列表页状态联动

本次不包含：

- 下载器连接状态刷新机制重构
- 任务筛选和搜索交互重做
- 后台常驻同步或系统级 push
- Web/iOS/桌面端专项适配

## 设计选择

### 方案 A：仅把 `TasksPage` 刷新补齐

思路：

- 添加任务成功后 `pop(true)`
- 调用方收到返回值后手工 reload

优点：

- 改动最小

缺点：

- 只能解决局部页面刷新
- 汇总页和详情页联动问题仍然存在
- 状态源继续分散

### 方案 B：全局共享 `TaskController`

思路：

- 在应用级 `Provider` 中提供共享的 `TaskController`
- 所有任务页都订阅这一份状态
- 所有任务变更操作都收敛到共享 controller 中

优点：

- 状态源唯一
- 页面联动自然成立
- 适合后续扩展轮询、缓存、局部刷新

缺点：

- 需要调整现有页面创建 controller 的方式

### 方案 C：新建 `TaskRepository/TaskStore`

思路：

- 增加 repository 或 store 层
- 页面 controller 仅做轻量代理

优点：

- 架构最干净

缺点：

- 以当前项目规模来说偏重
- 会引入一轮额外抽象，不利于这次快速收敛问题

## 结论

采用方案 B。

本次以“共享 `TaskController` + 事件驱动刷新 + 低频轮询兜底”的混合方案实现。

## 架构设计

### 共享状态源

在 `lib/app.dart` 中，把 `TaskController` 提升为全局 `Provider`，与现有的：

- `AuthController`
- `DownloaderController`
- `SettingsController`

并列提供。

此后：

- `TasksPage` 不再内部 new `TaskController`
- `AllTasksTabPage` 不再内部 new `TaskController`
- `TaskDetailPage` 不再内部 new `TaskController`

所有页面统一从 `context.watch<TaskController>()` 或 `context.read<TaskController>()` 读取与操作任务状态。

### 数据结构

`TaskController` 从“单列表状态”升级为“多下载器共享缓存”。

建议维护以下状态：

- `Map<String, List<DownloadTask>> _tasksByDownloader`
- `Map<String, bool> _loadingByDownloader`
- `bool _isRefreshingAll`
- `DownloadTask? _currentTask`
- `String? _currentTaskId`
- `String? _currentTaskDownloaderId`
- `Timer? _refreshTimer`

建议暴露以下只读接口：

- `List<DownloadTask> tasksForDownloader(String downloaderId)`
- `List<DownloadTask> get allTasks`
- `bool isLoadingDownloader(String downloaderId)`
- `bool get isRefreshingAll`
- `DownloadTask? get currentTask`
- `bool get isLoadingDetail`

### 刷新策略

采用混合刷新策略：

#### 事件驱动刷新

以下操作成功后，立即刷新受影响下载器的数据：

- 添加任务
- 暂停任务
- 恢复任务
- 删除任务

优点：

- 实时性强
- 网络开销比全量刷新更小

#### 低频全局轮询

共享 `TaskController` 在有页面使用时启动低频轮询，例如每 20 到 30 秒执行一次。

轮询行为：

- 读取当前已配置下载器
- 仅刷新在线下载器的任务列表
- 更新 `_tasksByDownloader`

作用：

- 兜底修正远端状态变化
- 解决仅靠事件驱动可能遗漏的状态漂移

### 页面联动规则

#### `TasksPage`

- 按 `downloaderId` 从共享 controller 中读取对应下载器任务
- 首次进入时调用 `loadTasksForDownloader(...)`
- 下拉刷新和刷新按钮仍触发该方法

#### `AllTasksTabPage`

- 直接使用共享 controller 的 `allTasks`
- 首次进入时调用 `loadAllTasks(...)`
- 汇总页不再手动循环调用页面内私有 controller 收集任务

#### `TaskDetailPage`

- 详情页改为依赖共享 controller 的 `loadTaskDetail(taskId, downloaderId, ...)`
- 暂停、恢复、删除仍在详情页发起
- 操作成功后，共享 controller 负责刷新对应下载器缓存
- 列表页和汇总页因共享状态自动同步

## 接口设计

`TaskController` 建议新增或调整为以下接口：

- `Future<void> loadTasksForDownloader(String downloaderId, DownloaderController downloaderController, {bool force = false})`
- `Future<void> loadAllTasks(DownloaderController downloaderController, {bool force = false})`
- `Future<bool> addTask(AddTaskRequest request, DownloaderController downloaderController)`
- `Future<void> pauseTask(String taskId, String downloaderId, DownloaderController downloaderController)`
- `Future<void> resumeTask(String taskId, String downloaderId, DownloaderController downloaderController)`
- `Future<void> removeTask(String taskId, String downloaderId, DownloaderController downloaderController, {bool deleteFiles = false})`
- `Future<void> loadTaskDetail(String taskId, String downloaderId, DownloaderController downloaderController)`
- `void startAutoRefresh(DownloaderController downloaderController)`
- `void stopAutoRefresh()`

### 参数调整原则

当前 `TaskController` 依赖内部 `_currentDownloaderId` 处理任务详情和任务操作，这种方式容易受页面切换影响。

本次建议改为：

- 所有任务操作显式传入 `downloaderId`
- 详情加载显式传入 `taskId + downloaderId`

这样可以减少共享 controller 下的状态串扰。

## 页面改造要点

### `AddTaskPage`

当前添加页成功后调用 `DownloaderController.addTask(...)`，但不会刷新共享任务缓存。

本次改为：

- 提交时调用共享 `TaskController.addTask(...)`
- `TaskController` 内部创建任务成功后立即刷新目标下载器任务列表
- 页面仍可保持“成功后返回上一页”的交互

这样返回列表页时不需要依赖额外 reload 逻辑。

### `TasksPage`

改造后页面不维护私有 `TaskController` 实例，只负责：

- 读取共享任务状态
- 传递当前 `downloaderId`
- 显示筛选结果

### `AllTasksTabPage`

改造后页面不再自己汇总所有下载器任务，而是直接读取共享的聚合结果。

这样可以避免：

- 页面内重复遍历下载器
- 多个页面各自请求同一批任务
- 汇总页与单下载器页显示不一致

### `TaskDetailPage`

详情页保留自身 5 秒刷新详情的行为可以接受，但其任务操作必须走共享 controller。

如果详情页继续定时刷新，要求：

- 只刷新当前详情任务
- 不破坏共享 controller 中的下载器任务缓存

如果实现复杂度较高，也可以在本次先保留详情页定时拉详情，同时让操作完成后刷新下载器列表缓存。

## 错误处理

- 单个下载器任务刷新失败时，不清空其他下载器缓存
- 某个下载器离线时，保留其上一次成功加载的任务缓存，避免页面闪空
- 添加/暂停/恢复/删除失败时，不触发成功态刷新
- 详情页删除成功后，可以继续返回上一页；返回后列表页应已是最新状态

## 性能与一致性

- 单下载器页默认只刷新目标下载器任务
- 汇总页全量刷新时按下载器逐个拉取，避免一次性全量重构现有 service 接口
- 聚合结果 `allTasks` 由 `_tasksByDownloader` 派生，避免额外维护第二份可变列表
- 轮询间隔保持低频，避免对远端下载器造成过多请求压力

## 测试要求

至少覆盖以下验证：

### Controller 测试

- `addTask` 成功后刷新目标下载器缓存
- `pauseTask/resumeTask/removeTask` 成功后刷新目标下载器缓存
- `loadAllTasks` 能正确聚合多下载器任务

### Widget 测试

- `TasksPage` 订阅共享状态后，任务变化会反映到 UI
- `AllTasksTabPage` 订阅共享状态后，新增任务会自动出现在汇总页
- `TaskDetailPage` 删除任务后返回列表页，列表状态已同步

## 验收标准

- 添加任务成功后，返回 `TasksPage` 能立即看到新任务
- 添加任务成功后，返回 `AllTasksTabPage` 能立即看到新任务
- 在详情页执行暂停、恢复、删除后，相关列表页同步更新
- 不再由页面各自创建私有 `TaskController`
- 任务状态读取统一来自全局共享 `TaskController`
- 存在低频兜底刷新机制，避免长时间状态漂移
