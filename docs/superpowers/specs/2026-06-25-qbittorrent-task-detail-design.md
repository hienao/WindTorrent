# qBittorrent 任务详情重设计

日期：2026-06-25
状态：已在对话中确认，待评审

## 摘要

WindWalker 已经为 Transmission 定义了“详情主页只展示信息页，其余能力通过子页入口进入”的结构。qBittorrent 详情也沿用这一条产品级导航原则，但页面内容、字段分组和子页能力保持 qBit 原生语义，不强行与 Transmission 共享字段模型。

本次设计覆盖：

- qBittorrent 详情主页的信息页结构
- `文件 / 服务器 / 节点 / 选项` 四个子页的首版定位
- qBit 专属数据模型与 controller 边界
- 与 Transmission 复用的公共壳边界

## 目标

- 保持 WindWalker 在不同下载器详情页上的整体导航一致性。
- 尽量保留 qBittorrent 原生详情页的信息密度和语义分组。
- 为 qBit 的文件页、服务器页、节点页、选项页建立明确的首版范围。
- 避免把 qBit 专属字段继续塞回 `DownloadTask` 或 Transmission 专属模型。

## 非目标

- 本轮不要求 qBit 顶部保留原生 Tab 作为主导航。
- 本轮不要求文件页支持勾选、跳过、优先级修改。
- 本轮不要求节点页支持管理类交互。
- 本轮不要求选项页覆盖 qBit 全部任务级设置。

## 已确认方向

用户已在对话中确认以下决策：

- qBit 详情主页继续沿用 Transmission 的模式：主页只展示信息页，再提供子页入口。
- 文件页首版为只读，不做勾选。
- 信息主页尽量保留原生全字段，而不是做移动端大幅裁剪。
- 文件页虽然原生可勾选，但 WindWalker 首版改成只读目录树。
- 选项页首版只保留三组可编辑项：
  - 队列优先级
  - 分类
  - 标签

## 总体架构

### 共享层

以下能力继续与其它下载器共用：

- 统一详情路由入口
- 顶部任务 Hero
- 底部公共任务操作栏
- 通用刷新 / 加载 / 错误态
- 主页到底部子页入口的整体交互模式

### qBit 专属层

qBittorrent 专属层负责：

- 信息主页字段编排
- 文件 / 服务器 / 节点 / 选项 入口区
- 四个子页的页面结构与专属模型
- qBit 专属 service 扩展
- qBit 专属详情 controller 族

### 复用原则

可以共享：

- 页面壳
- 入口卡片模式
- 文件树组件思路
- controller 的 loading / error / refresh 状态机结构

不要共享成一个通用大模型：

- qBit 服务器页是“来源统计卡”
- Transmission 服务器页是“tracker 详情卡”
- qBit 选项页是“队列优先级 / 分类 / 标签”
- Transmission 选项页是“带宽 / 分享率 / 不活跃限制”

共享的是框架，不是字段契约。

## 详情主页

### 导航原则

qBit 详情主页继续走：

- 主页只展示信息页
- 底部提供四个子页入口
  - 文件
  - 服务器
  - 节点
  - 选项

不保留原生顶部 Tab 作为 WindWalker 内部的主导航结构。

### 信息主页分组

qBittorrent 信息页字段较多，首版尽量保留原生密度，但重新组织为 4 个 section。

#### 1. 进度

- 进度条
- 当前完成百分比

这一组单独放在最上方，作为视觉起点。

#### 2. 传输

- 连接
- 种子数
- 节点
- 活动时间
- 剩余时间
- 已下载
- 已上传
- 下载速度
- 上传速度
- 限制下载
- 限制上传
- 损耗
- 分享率
- 流行度
- 下次汇报
- 最后完整可见
- 优先级
- 下载时间
- 做种时间

这是主页最长的一组，不建议为了“简洁”而强行砍掉字段。

#### 3. 种子信息

- 总计大小
- 区块
- 创建者
- 添加于
- 私密
- 完成于
- 创建时间
- 保存位置
- 分类
- 信息哈希值 V1
- 信息哈希值 V2
- 注释

#### 4. HTTP 源

- 作为主页底部独立 section 保留
- 展示 HTTP 源数量
- 允许后续作为单独子页或来源列表入口扩展

### 子页入口区

信息 section 之后放 `文件 / 服务器 / 节点 / 选项` 四个入口。

推荐入口摘要：

- 文件：文件数 / 总大小
- 服务器：来源类型数量
- 节点：peer 数量
- 选项：当前优先级 / 分类 / 标签摘要

## 文件页

qBit 文件页首版做“只读目录树”，交互结构参考 Transmission，但字段和视觉节奏贴近 qBit。

### 页面结构

- hero 下方放轻量摘要条
- 主体为树形文件列表

摘要条字段：

- 根任务名
- 总文件数
- 总大小
- 总完成度

### 树节点规则

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
  - 完成百分比

### 首版交互

- 仅支持展开 / 收起目录
- 不支持勾选
- 不支持文件优先级
- 不支持批量操作

### 数据模型建议

- `QBitTaskFileNode`
  - `path`
  - `name`
  - `isDirectory`
  - `size`
  - `downloaded`
  - `progress`
  - `children`

## 服务器页

qBit 服务器页与 Transmission 服务器页差异最大。代码层不建议沿用 tracker-card 语义。

### 页面定位

首版做“来源面板列表”。

展示对象包括：

- DHT
- PeX
- LSD
- 后续若有普通 tracker 统计，也可纳入同一来源列表

### 每张来源卡片字段

- 来源名
- 工作状态
- 节点数
- 种子数
- 下载数
- 已下载

### 说明

这一页更像“来源类型统计卡”，而不是单个 tracker 详情页。

### 首版不做

- 来源操作菜单
- 手动刷新
- 新增 / 删除 / 编辑 tracker

### 数据模型建议

- `QBitTaskSource`
  - `name`
  - `status`
  - `peerCount`
  - `seedCount`
  - `downloadCount`
  - `downloadedCount`

## 节点页

节点页继续保留高密度 peer 列表，但布局更贴 qBit 原生。

### 每个 peer 行字段

- IP:端口
- 协议类型标记（如 BT）
- 状态标签（如空闲、H、X）
- 下载速度
- 上传速度
- 已下载
- 已上传
- 当前进度
- 文件关联百分比

### 首版不做

- 节点管理操作
- 排序切换
- 更多高级对端属性

### 数据模型建议

- `QBitTaskPeer`
  - `address`
  - `port`
  - `protocol`
  - `stateTags`
  - `downloadSpeed`
  - `uploadSpeed`
  - `downloaded`
  - `uploaded`
  - `progress`
  - `relevance`

## 选项页

qBit 选项页首版只保留三组可编辑项：

- 队列优先级
- 分类
- 标签

### Section 1：队列优先级

- 字段：队列优先级
- 控件：单选或下拉

### Section 2：分类

- 展示当前分类
- 可改为已有分类
- 允许输入新分类

### Section 3：标签

- 展示当前标签集合
- 可编辑标签集合

### 保存策略

- 使用显式保存
- 不做边改边存
- 表单进入脏状态后才允许保存
- 保存失败时保留用户输入并显示错误

### 数据模型建议

- `QBitTaskOptions`
  - `queuePriority`
  - `category`
  - `tags`
- `QBitTaskOptionsUpdate`
  - `queuePriority`
  - `category`
  - `tags`

## controller 结构

建议按页面拆分 controller，与 Transmission 保持模式一致：

- `QBitTaskDetailController`
- `QBitTaskFilesController`
- `QBitTaskSourcesController`
- `QBitTaskPeersController`
- `QBitTaskOptionsController`

职责边界：

- 每页独立管理 loading / error / refresh
- 选项页额外管理 dirty state 与 save 流程
- 不把页面专属状态塞进 `TaskController`

## 数据边界

不要把以下字段继续塞进 `DownloadTask`：

- 连接 / 种子 / 节点 / 活动时间 / 剩余时间
- 损耗 / 流行度 / 下次汇报 / 最后完整可见
- 信息哈希 V1 / V2
- 分类 / 标签
- 来源统计（DHT / PeX / LSD）
- peer 状态标签、文件关联百分比
- 队列优先级 / 分类 / 标签编辑态

建议拆为：

- `QBitTaskDetail`
- `QBitTaskFileNode`
- `QBitTaskSource`
- `QBitTaskPeer`
- `QBitTaskOptions`
- `QBitTaskOptionsUpdate`

## 首版范围

首版包含：

- qBit 信息主页
- qBit 文件页只读目录树
- qBit 服务器页来源统计卡
- qBit 节点页高密度 peer 列表
- qBit 选项页三组可编辑设置

首版不包含：

- 文件勾选
- 文件优先级
- tracker / 来源管理操作
- 节点管理操作
- qBit 全量任务级选项

## 验收标准

- qBittorrent 详情主页沿用“信息页 + 子页入口”的产品结构。
- 信息主页尽量保留原生字段密度，不退化成过度精简版。
- 文件页为只读目录树，而不是扁平列表。
- 服务器页表达来源统计，而不是误做成 Transmission 风格 tracker 卡片。
- 节点页保留高密度 peer 信息。
- 选项页只开放队列优先级、分类、标签三组设置。
- qBit 专属字段不继续回填到 `DownloadTask`。
