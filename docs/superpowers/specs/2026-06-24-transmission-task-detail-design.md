# Transmission 任务详情重设计

日期：2026-06-24
状态：已在对话中确认，待评审

## 摘要

WindWalker 当前只有一个通用任务详情页 [task_detail_page.dart](/Volumes/Data/Code/GitHub/WindWalker/lib/features/tasks/presentation/pages/task_detail_page.dart)，页面内容基于通用 `DownloadTask` 摘要模型拼装，适合展示基础状态，但不足以承载 qBittorrent 和 Transmission 各自原生语义明显不同的详情能力。

本次设计先以 Transmission 为起点，建立“共享详情壳 + 下载器专属详情模块”的结构：

- 详情入口和公共操作保持统一
- 下载器类型决定进入哪个专属详情页
- 本轮只落地 Transmission 的信息主页和四个子页入口
- `文件 / 服务器 / 节点 / 选项` 子页先建立路由和页面壳，不在本轮补齐完整功能

这个方案允许后续给 qBittorrent 建立独立详情页，而不会把差异继续塞进一个越来越臃肿的通用页面。

## 目标

- 让 Transmission 任务详情页更贴近用户熟悉的原生信息架构。
- 保留统一的详情进入方式、公共操作区、刷新和错误处理模式。
- 避免继续向 `DownloadTask` 通用模型硬塞 Transmission 专属详情字段。
- 为后续 qBittorrent 专属详情页建立可复用的工程模式。

## 非目标

- 本轮不实现 qBittorrent 的专属详情页。
- 本轮不实现 Transmission 文件树、tracker 列表、peer 列表、选项编辑的完整业务能力。
- 本轮不重做任务列表页、概览页或底部导航结构。
- 本轮不引入一个横向 Tab 容器承载五个详情页。

## 当前问题

当前实现存在三个核心问题：

1. 一个通用页面试图承载所有下载器详情语义，但当前数据源只有基础任务摘要。
2. `DownloadTask` 适合列表和基础状态，不适合继续装载 Transmission 特有的详细信息、tracker/peer/options 能力。
3. 如果继续沿用“一个页面内按下载器类型分支”的方式，后续接入 qBittorrent 只会堆出更多条件分支和 nullable 字段。

## 已确认方向

用户已在对话中确认以下设计决策：

- 原生优先，而不是强行追求所有下载器共用同一套详情内容。
- 本轮只做“独立信息页 + 各子页入口”，不在一个迭代里把所有子页真实能力一起补完。
- 信息页字段尽量贴近原生 Web UI / App 的“信息页”语义。
- 导航形态采用“信息主页 + 入口卡片”，而不是顶部五个页签。
- 当前阶段先完整设计 Transmission，qBittorrent 后补。

## 方案比较

### 方案 A：共享详情壳 + 下载器专属详情模块

这是本次推荐并已确认的方案。

- 统一路由入口、顶部 Hero、底部任务操作、通用加载/错误态
- 按下载器类型分发到专属详情页
- Transmission 使用自己的详情模型、controller、子页和 service 接口

优点：

- 保留产品内一致的外壳体验
- 允许各下载器详情语义充分分化
- 为 qBittorrent 后续接入提供稳定模板

缺点：

- 需要比当前实现多引入一层详情分发与专属状态管理

### 方案 B：每种下载器完全独立一整套详情功能

- 每个下载器从路由到操作栏都各自实现

优点：

- 灵活度最高

缺点：

- 公共逻辑会大量重复
- 后续维护刷新、埋点、错误态时成本更高

### 方案 C：继续保留一个通用详情页，内部按类型分支

优点：

- 表面上改动最小

缺点：

- 当前问题会继续累积
- 页面结构和模型边界会越来越混乱

## 总体架构

### 详情分发

现有详情入口语义保留，但不再默认直接渲染通用 [task_detail_page.dart](/Volumes/Data/Code/GitHub/WindWalker/lib/features/tasks/presentation/pages/task_detail_page.dart)。

建议新增一个“详情分发页”或保留现有页面作为分发壳，职责仅包括：

- 解析 `taskId`、`downloaderId`、`taskName`
- 根据下载器类型选择具体详情页
- 保留公共埋点入口

例如：

- Transmission -> `TransmissionTaskDetailPage`
- qBittorrent -> 后续 `QBitTaskDetailPage`
- Aria2 -> 暂时可回落现有通用详情页或后续另行设计

### 公共层职责

以下能力保持在公共层，不在每个下载器页面重复实现：

- 统一详情路由入口
- 顶部任务 Hero 区
- 底部 `暂停 / 继续 / 删除` 操作栏
- 基础任务状态轮询与刷新节奏
- 通用加载态、错误态、埋点

### 下载器专属层职责

Transmission 专属层负责：

- 信息首页内容
- `文件 / 服务器 / 节点 / 选项` 入口区
- 对应四个子页路由壳
- Transmission 详情数据模型
- Transmission 详情专属 controller / state
- Transmission 详情 service 接口

## Transmission 页面结构

### 首页定位

`TransmissionTaskDetailPage` 的默认页就是“信息页”。页面主轴为：

1. 顶部统一 Hero 区
2. 信息页四个 section
3. `更多详情` 入口区

### 信息页分组

信息页尽量贴近用户提供的 Transmission 截图，拆成四组：

#### 种子信息

- 总计大小
- 分块信息
- 保存位置
- 隐私状态
- 创建者
- 创建时间
- Magnet

#### 传输

- 总计下载
- 可用率
- 已下载
- 已上传
- 分享率
- 平均速度

#### 日期

- 已添加
- 完成时间
- 最后活动

#### 运行时间

- 下载耗时
- 做种耗时

### 更多详情入口

信息内容下方增加一个入口区，使用卡片或列表入口承载四个独立页面：

- 文件列表
- 服务器
- 节点
- 选项

每个入口展示：

- 标题
- 一行简短说明
- 可选的摘要信息

推荐摘要示例：

- 文件列表：文件数 / 总大小
- 服务器：tracker 数量
- 节点：peer 数量
- 选项：是否支持编辑 / 当前优先级摘要

本轮只需要把入口结构和导航建立好，不要求所有摘要都真实可用。

## Transmission 子页深化设计（下一阶段）

以下内容用于定义 `文件 / 服务器 / 节点 / 选项` 四个子页的后续正式形态。

它们不改变本文前面已经确认的“当前迭代只建立子页壳和路由”的边界，而是为后续迭代提供完整信息架构与交互约束。

### 子页总原则

- `文件 / 服务器 / 节点` 三页首版为只读，不提供修改类交互。
- `选项` 页首版为可操作设置页，但只开放有限的任务级设置项。
- 四页继续复用共享详情壳：统一 header、hero、底部公共任务操作、刷新与错误处理。
- 子页使用 Transmission 专属模型，不向 `DownloadTask` 回填大量专属字段。

### 文件页

文件页首版做“只读目录树”，结构尽量贴近原生截图，但针对移动端阅读做适配。

页面结构：

- hero 下方展示轻量摘要条
- 主体为树形列表

摘要条字段：

- 根目录名
- 总文件数
- 总大小
- 总完成度

树节点规则：

- 目录节点
  - 文件夹图标
  - 名称
  - 聚合大小
  - 聚合完成度
  - 可展开 / 收起
- 文件节点
  - 文件图标
  - 文件名
  - 文件大小
  - 已完成 / 总大小
  - 完成百分比

首版交互：

- 仅支持展开 / 收起目录
- 不支持勾选、跳过、优先级修改、批量操作

排序规则：

- 默认按 Transmission 返回的原始层级组织
- 同层优先目录，再文件
- 首版不提供排序切换

数据模型建议：

- `TransmissionTaskFileNode`
  - `path`
  - `name`
  - `isDirectory`
  - `size`
  - `downloaded`
  - `progress`
  - `children`

页面状态建议：

- 额外维护 `expandedPaths` 集合，用于记录展开目录
- 展开状态只存在页面层，不进入 service 层

### 服务器页

服务器页代码层建议命名为 `trackers`，UI 继续显示“服务器”。

首版做高信息密度的 tracker 详情卡片列表，不做折叠。

页面结构：

- hero 下方显示摘要条
- 主体为 tracker 卡片列表

摘要条字段：

- tracker 总数
- 正常 tracker 数
- 有效种子总数

每张 tracker 卡片字段：

- 主标题：tracker 域名或 `host:port`
- 右上角：层级 / tier
- 详情字段
  - 最后更新
  - 下次更新于
  - 最后刮擦
  - 种子数
  - 下载数
  - 已下载数

状态表达：

- 正常 tracker：普通卡片样式
- 更新失败 / 无效 tracker：错误态文案或 badge
- 没有 tracker：显示明确空态

首版不做：

- 卡片菜单
- 手动更新 tracker
- 新增 / 删除 / 编辑 tracker
- 排序切换

数据模型建议：

- `TransmissionTaskTracker`
  - `id`
  - `host`
  - `announce`
  - `tier`
  - `lastAnnounceAt`
  - `nextAnnounceAt`
  - `lastScrapeAt`
  - `seederCount`
  - `leecherCount`
  - `downloadCount`
  - `status`
  - `errorMessage`

### 节点页

节点页代码层建议命名为 `peers`，UI 继续显示“节点”。

首版做高密度单行 peer 卡片，目标是快速识别当前连接对端及其传输状态。

页面结构：

- hero 下方显示摘要条
- 主体为 peer 行卡列表

摘要条字段：

- 当前节点总数
- 正在下载给我的节点数
- 正在从我上传的节点数

每个节点卡片字段：

- 第一行
  - IP 地址
  - 进度百分比
- 第二行
  - 客户端名称 / 版本
  - 端口
- 第三行
  - 下载速度
  - 上传速度

视觉优先级：

- IP 为首要识别信息
- 进度放右侧，便于快速判断对端完成度
- 下载 / 上传速度用方向图标或样式区分，但不只靠颜色表达

首版不做：

- 节点操作菜单
- 封禁 / 断开
- 排序切换
- 国家 / 地区、旗帜、地理信息
- 更细粒度的协议与加密状态展示

数据模型建议：

- `TransmissionTaskPeer`
  - `address`
  - `clientName`
  - `port`
  - `progress`
  - `downloadSpeed`
  - `uploadSpeed`
  - `isDownloadingToUs`
  - `isUploadingFromUs`

### 选项页

选项页是四个子页中唯一的可操作页面。

首版严格限制在任务级设置，不扩展到保存路径等更重属性。

可编辑范围仅包含：

- 传输优先级
- 下载限速
- 上传限速
- 分享率限制
- 不活跃限制

页面结构：

- hero 下方直接进入设置表单
- 页面提供显式 `保存` 动作
- 表单按 section 分组

#### Section 1：传输优先级

- 字段：传输优先级
- 控件：下拉或 segmented choice
- 值域：
  - 低
  - 中
  - 高

#### Section 2：传输带宽

- 字段：
  - 服从全局带宽限制
  - 下载限制
  - 上传限制
- 控件：
  - 一个总开关：`服从全局带宽限制`
  - 两个子开关：是否启用下载 / 上传任务级限制
  - 数值输入框，单位固定 `KB/s`

行为约束：

- 若“服从全局带宽限制”开启，下载 / 上传任务级限制输入项置灰
- 若关闭，再允许分别开启下载 / 上传限制并填写数值

#### Section 3：分享率限制

- 字段：
  - 模式
  - 值
- 控件：
  - 模式下拉
  - 数值输入
- 模式值域：
  - 全局设置
  - 已禁用
  - 自定义

行为约束：

- `全局设置` 时值字段只读或隐藏
- `已禁用` 时值字段只读并显示禁用态
- `自定义` 时允许输入分享率值

#### Section 4：不活跃限制

- 字段：
  - 模式
  - 值（分钟）
- 控件：
  - 模式下拉
  - 数值输入
- 模式值域：
  - 全局设置
  - 已禁用
  - 自定义

行为约束：

- `全局设置` 时值字段只读或隐藏
- `已禁用` 时值字段只读并显示禁用态
- `自定义` 时允许输入分钟值

保存策略：

- 首版采用显式保存，不做边改边提交
- 任一字段变更后页面进入脏状态
- 点击保存后执行校验并一次性提交全部任务选项
- 成功后清除脏状态并提示“已保存”
- 失败后保留用户输入并显示错误

校验规则：

- 速度限制必须是非负整数
- 分享率限制必须是非负数
- 不活跃限制必须是非负整数分钟
- 空字符串不直接提交，应转为未设置或非法输入错误

首版不做：

- 自动保存
- 离开页复杂冲突对话
- 保存路径编辑
- 更细粒度的高级任务参数

## 路由设计

维持现有详情入口语义：

- `/tasks/detail/:id`

进入后根据 `downloader.type` 分发到具体详情页面。Transmission 内部建议使用真实语义命名的子路由：

- `/tasks/detail/:id/transmission/info`
- `/tasks/detail/:id/transmission/files`
- `/tasks/detail/:id/transmission/trackers`
- `/tasks/detail/:id/transmission/peers`
- `/tasks/detail/:id/transmission/options`

说明：

- UI 可以继续展示成“信息 / 文件 / 服务器 / 节点 / 选项”
- 代码和路由层建议使用 `trackers`、`peers` 这样的真实含义命名，避免“服务器/节点”这种 UI 词汇影响后续维护理解

## 数据模型设计

### 保留通用摘要模型

[download_task.dart](/Volumes/Data/Code/GitHub/WindWalker/lib/models/download_task.dart) 继续作为跨下载器共享的基础任务模型，负责：

- 列表展示
- 顶部 Hero 区状态摘要
- 公共任务操作条件判断

不建议继续把 Transmission 专属详情字段扩展进 `DownloadTask`。

### 新增 Transmission 专属详情模型

建议新增 `TransmissionTaskDetail`，持有信息页所需全部字段，并带上子页入口摘要信息。

字段分组建议：

- 基础标识：`taskId`、`name`、`downloaderId`
- 信息页字段：大小、piece、路径、隐私、creator、createdAt、magnet
- 传输字段：availablePercent、downloadedEver、uploadedEver、ratio、averageSpeed
- 日期字段：addedAt、completedAt、lastActivityAt
- 运行时间字段：downloadingDuration、seedingDuration
- 子页摘要字段：`fileCount`、`trackerCount`、`peerCount`、`optionsEditable`

如果某些字段当前 RPC 暂不支持，也应当在专属模型层明确为空，而不是再次退回通用模型。

## Service 接口设计

### 保留现有通用详情接口

`DownloaderService.getTaskDetail(String taskId)` 继续保留，用于：

- 详情页首屏基础状态
- 顶部 Hero 刷新
- 公共操作可用性判断

### 新增 Transmission 专属详情接口

建议在 Transmission service / adapter 层新增专属详情能力，例如：

- `getTaskFullDetail(String taskId)` -> `TransmissionTaskDetail`

这个接口只服务于 Transmission 详情页，不要求其他下载器同步实现同样深度。

这样可以保证：

- 公共摘要刷新和专属详情拉取分层
- 未来 qBittorrent 可以定义自己的详情接口和模型，而不是被统一契约反向绑死

## 状态流设计

### 公共状态

[task_controller.dart](/Volumes/Data/Code/GitHub/WindWalker/lib/features/tasks/presentation/controllers/task_controller.dart) 继续负责：

- 任务列表缓存
- 当前任务基础状态
- 公共任务操作
- 顶部 Hero 需要的通用信息

### 专属详情状态

建议为 Transmission 新增专属详情 controller 或等价状态对象，例如：

- `TransmissionTaskDetailController`

职责：

- 加载 `TransmissionTaskDetail`
- 管理信息页与入口区所需状态
- 管理子页壳的加载态、错误态和刷新态

这能避免把 Transmission 专属字段继续塞进 `TaskController.currentTask`。

## 错误处理

沿用项目当前 fail-fast 原则：

- service 抛异常，不静默返回伪默认值
- controller 捕获异常并写入显式错误态
- UI 显式区分三种状态：
  - 加载失败
  - 暂无数据
  - 功能尚未实现

对子页入口的特殊要求：

- 如果当前后端能力明确不支持，应在入口层标记不可用或“即将支持”
- 不要让用户点击后进入一个没有解释的空白页

## 本轮实现范围

本轮只包含以下内容：

- 建立详情分发结构
- 建立 `TransmissionTaskDetailPage`
- 实现信息页四个 section
- 在信息页底部增加四个子页入口
- 建立四个子页的路由和页面壳
- 建立 Transmission 专属详情模型与基础 service/controller 结构

## 本轮不包含

- 文件树展开、勾选、优先级调整
- tracker 列表真实交互
- peer 列表真实交互
- 选项页编辑、校验与保存
- Transmission 子页顶部工具栏动作，例如新增 tracker、排序、保存
- qBittorrent 专属详情页

## 测试策略

至少覆盖以下四类测试：

### 路由分发测试

- Transmission 任务能进入 Transmission 专属详情页

### 信息页渲染测试

- 四个 section 正确出现
- 关键字段缺失时展示规则稳定

### 入口导航测试

- `文件 / 服务器 / 节点 / 选项` 入口可跳到对应壳页

### service / controller 单测

- Transmission 专属详情字段解析正确
- 异常会进入错误态，而不是被吞掉

## 验收标准

- Transmission 任务进入的是专属详情页，而不是继续渲染一个通用字段页。
- 首页默认展示信息页，而不是五个横向 Tab。
- 信息页按 `种子信息 / 传输 / 日期 / 运行时间` 四组呈现。
- 信息页底部提供 `文件 / 服务器 / 节点 / 选项` 四个入口。
- 四个入口都能跳到独立页面壳。
- `DownloadTask` 不因本次设计继续膨胀为 Transmission 专属详情模型。
- 结构上允许后续按同一模式接入 qBittorrent 专属详情页。
