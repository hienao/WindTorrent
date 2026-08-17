# aria2 RPC 接口说明

## 说明

这份文档用于补充当前仓库缺失的 aria2 API 资料，并明确记录：

- aria2 官方 RPC 文档入口
- 当前项目实际采用的调用方式
- 当前项目已使用的方法子集

## 官方文档

- aria2 manual: <https://aria2.github.io/manual/en/html/aria2c.html>
- RPC Interface: <https://aria2.github.io/manual/en/html/aria2c.html#rpc-interface>
- JSON-RPC using HTTP GET: <https://aria2.github.io/manual/en/html/aria2c.html#json-rpc-using-http-get>

## 当前项目实际采用的方式

当前项目 **没有** 使用官方文档中 `JSON-RPC using HTTP GET` 的调用形式。

当前实现使用的是：

- HTTP `POST`
- `Content-Type: application/json`
- JSON-RPC 2.0 request body
- RPC secret 通过 `params` 的第一个参数传递：`token:<secret>`

项目入口实现见：

- [lib/services/aria2_service.dart](/Volumes/Data/Code/GitHub/WindWalker/lib/services/aria2_service.dart)

请求形态示例：

```json
{
  "jsonrpc": "2.0",
  "method": "aria2.getVersion",
  "params": ["token:your-secret"],
  "id": 1
}
```

而官方文档里 `HTTP GET` 这一节描述的是另一种可选编码方式，例如：

```text
/jsonrpc?method=aria2.tellStatus&id=foo&params=BASE64_ENCODED_PARAMS
```

当前项目未使用这种 GET 编码方式。

## 当前项目使用到的方法

### 连接与版本

- `aria2.getVersion`
  - 用途：测试连接、读取服务端版本
  - 代码位置：[lib/services/aria2_service.dart](/Volumes/Data/Code/GitHub/WindWalker/lib/services/aria2_service.dart:26)

### 任务列表

- `aria2.tellActive`
- `aria2.tellWaiting`
- `aria2.tellStopped`
  - 用途：拼装下载器任务列表
  - 代码位置：[lib/services/aria2_service.dart](/Volumes/Data/Code/GitHub/WindWalker/lib/services/aria2_service.dart:90)

### 全局状态

- `aria2.getGlobalStat`
  - 用途：读取全局下载/上传状态
  - 代码位置：[lib/services/aria2_service.dart](/Volumes/Data/Code/GitHub/WindWalker/lib/services/aria2_service.dart:167)

### 添加任务

- `aria2.addUri`
  - 用途：添加 URL / magnet 下载
  - 代码位置：[lib/services/aria2_service.dart](/Volumes/Data/Code/GitHub/WindWalker/lib/services/aria2_service.dart:195)
- `aria2.addTorrent`
  - 用途：添加本地 `.torrent` 文件
  - 代码位置：[lib/services/aria2_service.dart](/Volumes/Data/Code/GitHub/WindWalker/lib/services/aria2_service.dart:173)

### 任务操作

- `aria2.pause`
- `aria2.unpause`
- `aria2.remove`
- `aria2.removeDownloadResult`
  - 用途：暂停、恢复、删除任务与清理任务记录
  - 代码位置：[lib/services/aria2_service.dart](/Volumes/Data/Code/GitHub/WindWalker/lib/services/aria2_service.dart:211)

### 速度配置

- `aria2.getGlobalOption`
- `aria2.changeGlobalOption`
  - 用途：读取和设置全局限速
  - 代码位置：[lib/services/aria2_service.dart](/Volumes/Data/Code/GitHub/WindWalker/lib/services/aria2_service.dart:237)

### 单任务详情

- `aria2.tellStatus`
  - 用途：获取单个任务详情
  - 代码位置：[lib/services/aria2_service.dart](/Volumes/Data/Code/GitHub/WindWalker/lib/services/aria2_service.dart:320)

## 当前项目字段风格

aria2 返回的数据字段以 camelCase / mixed style 为主，例如：

- `totalLength`
- `completedLength`
- `downloadSpeed`
- `uploadSpeed`

这一点和 Transmission 4.1.0+ 的 snake_case 风格不同，后续做协议兼容时不要直接复用 Transmission 的字段假设。

## 备注

- 当前仓库对 qBittorrent 和 Transmission 都保存了本地 API 文档，aria2 之前缺失，本文件用于补齐。
- 更细的“当前项目用到的方法摘录”见 [aria2-rpc-methods.md](./aria2-rpc-methods.md)。
- 更完整的“官方 RPC 方法目录 + 当前项目使用状态”也统一维护在 [aria2-rpc-methods.md](./aria2-rpc-methods.md)。
