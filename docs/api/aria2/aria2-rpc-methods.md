# aria2 RPC 方法摘录

## 说明

这份文档只摘录当前项目真正依赖的 aria2 RPC 方法与字段约定，便于对照：

- 官方 RPC 定义
- 当前项目的请求参数顺序
- 当前项目实际消费的返回字段

对应实现文件：

- [lib/services/aria2_service.dart](/Volumes/Data/Code/GitHub/WindWalker/lib/services/aria2_service.dart)

## 通用调用约定

### 传输方式

当前项目统一使用：

- `POST /jsonrpc`
- `Content-Type: application/json`
- JSON-RPC 2.0 body

### secret 传递方式

aria2 官方 RPC 支持把 secret 作为方法的可选首参数传入。当前项目统一使用：

```json
"params": ["token:<secret>", ...]
```

这和当前代码一致，见 [aria2_service.dart](/Volumes/Data/Code/GitHub/WindWalker/lib/services/aria2_service.dart:277)。

### 错误返回

aria2 官方文档说明，JSON-RPC 出错时返回 `error.code` 和 `error.message`。当前项目在 `_call()` 里统一把这类响应转成 `DownloaderServiceException`。

## 完整方法目录

下面按 aria2 官方 RPC methods 章节整理所有可通过 `HTTP POST + JSON-RPC 2.0 body` 调用的方法，并标明当前项目是否已使用。

| 方法 | 作用 | 当前项目 |
|---|---|---|
| `aria2.addUri` | 新增 URI / magnet 下载 | 已使用 |
| `aria2.addTorrent` | 新增 torrent 下载 | 已使用 |
| `aria2.addMetalink` | 新增 metalink 下载 | 未使用 |
| `aria2.remove` | 删除任务 | 已使用 |
| `aria2.forceRemove` | 强制删除任务 | 未使用 |
| `aria2.pause` | 暂停任务 | 已使用 |
| `aria2.pauseAll` | 暂停全部任务 | 未使用 |
| `aria2.forcePause` | 强制暂停任务 | 未使用 |
| `aria2.forcePauseAll` | 强制暂停全部任务 | 未使用 |
| `aria2.unpause` | 恢复任务 | 已使用 |
| `aria2.unpauseAll` | 恢复全部暂停任务 | 未使用 |
| `aria2.tellStatus` | 查询单任务详情 | 已使用 |
| `aria2.getUris` | 查询任务关联 URI | 未使用 |
| `aria2.getFiles` | 查询任务文件列表 | 未使用 |
| `aria2.getPeers` | 查询 BT peers | 未使用 |
| `aria2.getServers` | 查询服务端连接信息 | 未使用 |
| `aria2.tellActive` | 查询活跃任务 | 已使用 |
| `aria2.tellWaiting` | 查询等待任务 | 已使用 |
| `aria2.tellStopped` | 查询停止任务 | 已使用 |
| `aria2.changePosition` | 调整队列位置 | 未使用 |
| `aria2.changeUri` | 变更任务 URI | 未使用 |
| `aria2.getOption` | 读取单任务 option | 未使用 |
| `aria2.changeOption` | 修改单任务 option | 未使用 |
| `aria2.getGlobalOption` | 读取全局 option | 已使用 |
| `aria2.changeGlobalOption` | 修改全局 option | 已使用 |
| `aria2.getGlobalStat` | 读取全局统计 | 已使用 |
| `aria2.purgeDownloadResult` | 清理历史结果 | 未使用 |
| `aria2.removeDownloadResult` | 删除单个历史结果 | 已使用 |
| `aria2.getVersion` | 读取 aria2 版本与特性 | 已使用 |
| `aria2.getSessionInfo` | 读取 session 信息 | 未使用 |
| `aria2.shutdown` | 正常关闭 aria2 | 未使用 |
| `aria2.forceShutdown` | 强制关闭 aria2 | 未使用 |
| `aria2.saveSession` | 保存 session | 未使用 |
| `system.multicall` | 批量调用多个方法 | 未使用 |
| `system.listMethods` | 列出可用方法 | 未使用 |
| `system.listNotifications` | 列出通知类型 | 未使用 |

## 未使用方法的参考价值

虽然当前项目没有接入以下方法，但它们对未来功能开发比较有参考意义：

- `aria2.addMetalink`
  - 如果后续要支持 `.meta4` 或 metalink URL，可直接复用当前 `addTorrent` 的封装思路。
- `aria2.getOption` / `aria2.changeOption`
  - 适合未来做“单任务级别”的限速、Header、代理、选择文件等配置。
- `aria2.getFiles`
  - 适合未来做 BT 文件选择、分文件状态展示。
- `aria2.getPeers`
  - 适合未来做 BT peer 信息面板。
- `aria2.changePosition`
  - 适合未来做下载队列拖拽排序。
- `system.multicall`
  - 如果后续发现任务列表拉取接口过多，可以考虑批量请求以减少往返。
- `aria2.shutdown` / `aria2.forceShutdown`
  - 更偏运维能力，通常不建议直接暴露到普通用户 UI。

## 1. aria2.getVersion

### 官方签名

```text
aria2.getVersion([secret])
```

### 当前项目用途

- 测试连接
- 读取 aria2 服务端版本

### 当前项目请求

```json
{
  "jsonrpc": "2.0",
  "method": "aria2.getVersion",
  "params": ["token:<secret>"],
  "id": 1
}
```

### 当前项目依赖的返回字段

- `result.version`
- `result.enabledFeatures`

### 代码位置

- [aria2_service.dart:26](/Volumes/Data/Code/GitHub/WindWalker/lib/services/aria2_service.dart:26)

## 2. aria2.tellActive

### 官方签名

```text
aria2.tellActive([secret][, keys])
```

### 当前项目用途

- 获取活跃任务列表

### 当前项目请求字段

当前项目传入的 `keys`：

- `gid`
- `name`
- `totalLength`
- `completedLength`
- `downloadSpeed`
- `uploadSpeed`
- `files`
- `numSeeders`
- `status`
- `bittorrent`

### 当前项目依赖的返回字段

- `gid`
- `status`
- `totalLength`
- `completedLength`
- `downloadSpeed`
- `uploadSpeed`
- `files`
- `bittorrent`
- `numSeeders`

### 代码位置

- [aria2_service.dart:90](/Volumes/Data/Code/GitHub/WindWalker/lib/services/aria2_service.dart:90)

## 3. aria2.tellWaiting

### 官方签名

```text
aria2.tellWaiting([secret, ]offset, num[, keys])
```

### 当前项目用途

- 获取等待中任务

### 当前项目请求

- `offset = 0`
- `num = 100`
- `keys` 与 `tellActive` 相同

### 代码位置

- [aria2_service.dart:117](/Volumes/Data/Code/GitHub/WindWalker/lib/services/aria2_service.dart:117)

## 4. aria2.tellStopped

### 官方签名

```text
aria2.tellStopped([secret, ]offset, num[, keys])
```

### 当前项目用途

- 获取已停止 / 已完成任务

### 当前项目请求

- `offset = 0`
- `num = 100`
- `keys` 与 `tellActive` 相同

### 代码位置

- [aria2_service.dart:141](/Volumes/Data/Code/GitHub/WindWalker/lib/services/aria2_service.dart:141)

## 5. aria2.tellStatus

### 官方签名

```text
aria2.tellStatus([secret, ]gid[, keys])
```

### 当前项目用途

- 获取单个任务详情

### 当前项目请求字段

- `gid`
- `status`
- `totalLength`
- `completedLength`
- `downloadSpeed`
- `uploadSpeed`
- `files`
- `numSeeders`
- `bittorrent`

### 代码位置

- [aria2_service.dart:320](/Volumes/Data/Code/GitHub/WindWalker/lib/services/aria2_service.dart:320)

## 6. aria2.addUri

### 官方签名

```text
aria2.addUri([secret, ]uris[, options[, position]])
```

### 当前项目用途

- 添加普通 URL 下载
- 添加 magnet 下载

### 当前项目请求形态

```json
[
  "token:<secret>",
  ["<url>"],
  {"dir": "<savePath>"}
]
```

说明：

- 当前项目把单个 URL 包成 `uris` 数组传递
- 如果用户指定了保存目录，则通过 `options.dir` 传入
- 当前项目未使用 `position`

### 当前项目返回处理

- 直接把 `result` 当作任务 `gid`

### 代码位置

- [aria2_service.dart:195](/Volumes/Data/Code/GitHub/WindWalker/lib/services/aria2_service.dart:195)

## 7. aria2.addTorrent

### 官方签名

```text
aria2.addTorrent([secret, ]torrent[, uris[, options[, position]]])
```

### 当前项目用途

- 添加本地 `.torrent` 文件

### 当前项目请求形态

```json
[
  "token:<secret>",
  "<base64-torrent-bytes>",
  [],
  {"dir": "<savePath>"}
]
```

说明：

- 第 2 个参数是 base64 编码后的 torrent 内容
- 第 3 个参数当前固定传空数组 `[]`
- 如果用户指定保存目录，则通过 `options.dir` 传入
- 当前项目未使用 `position`

### 当前项目返回处理

- 直接把 `result` 当作任务 `gid`

### 代码位置

- [aria2_service.dart:173](/Volumes/Data/Code/GitHub/WindWalker/lib/services/aria2_service.dart:173)

## 8. aria2.pause / aria2.unpause

### 官方签名

```text
aria2.pause([secret, ]gid)
aria2.unpause([secret, ]gid)
```

### 当前项目用途

- 暂停任务
- 恢复任务

### 当前项目请求

```json
["token:<secret>", "<gid>"]
```

### 代码位置

- [aria2_service.dart:211](/Volumes/Data/Code/GitHub/WindWalker/lib/services/aria2_service.dart:211)

## 9. aria2.remove / aria2.removeDownloadResult

### 官方签名

```text
aria2.remove([secret, ]gid)
aria2.removeDownloadResult([secret, ]gid)
```

### 当前项目用途

- 删除任务
- 清理下载记录

### 当前项目处理逻辑

1. 先调用 `aria2.remove`
2. 再调用 `aria2.removeDownloadResult`
3. 若立即清理失败，等待 `500ms` 后重试一次

说明：

- 这里是项目自己的补偿逻辑，不是 aria2 官方协议要求

### 代码位置

- [aria2_service.dart:221](/Volumes/Data/Code/GitHub/WindWalker/lib/services/aria2_service.dart:221)

## 10. aria2.getGlobalStat

### 官方签名

```text
aria2.getGlobalStat([secret])
```

### 当前项目用途

- 获取全局下载器状态

### 当前项目依赖字段

- `downloadSpeed`
- `uploadSpeed`
- `numActive`
- `numWaiting`
- `numStopped`
- `numStoppedTotal`

说明：

- 官方文档说明这些值都是字符串；当前项目上层消费时会自行做数值转换

### 代码位置

- [aria2_service.dart:167](/Volumes/Data/Code/GitHub/WindWalker/lib/services/aria2_service.dart:167)

## 11. aria2.getGlobalOption

### 官方签名

```text
aria2.getGlobalOption([secret])
```

### 当前项目用途

- 获取全局限速配置

### 当前项目依赖字段

- `max-overall-download-limit`
- `max-overall-upload-limit`

### 当前项目换算规则

- aria2 返回值单位按字节字符串处理
- 当前项目转成 `KB/s` 后写入 `DownloaderSpeedConfig`

### 代码位置

- [aria2_service.dart:237](/Volumes/Data/Code/GitHub/WindWalker/lib/services/aria2_service.dart:237)

## 12. aria2.changeGlobalOption

### 官方签名

```text
aria2.changeGlobalOption([secret, ]options)
```

### 当前项目用途

- 设置全局下载 / 上传限速

### 当前项目请求字段

- `max-overall-download-limit`
- `max-overall-upload-limit`

### 当前项目换算规则

- UI / 领域层使用 `KB/s`
- 下发给 aria2 前乘以 `1024`
- 关闭限速时传 `"0"`

### 代码位置

- [aria2_service.dart:259](/Volumes/Data/Code/GitHub/WindWalker/lib/services/aria2_service.dart:259)

## 当前项目与官方 GET 示例的关系

aria2 官方文档确实提供了 `JSON-RPC using HTTP GET` 示例，但当前项目未使用这一形式。

官方 GET 形式：

```text
/jsonrpc?method=aria2.tellStatus&id=foo&params=BASE64_ENCODED_PARAMS
```

当前项目使用的是同样的 RPC 方法集合，但通过 `POST + JSON body` 发送。

## 未来开发建议

- 新增 aria2 能力时，优先从上面的“完整方法目录”里找现成 RPC 方法，而不是自己拼协议。
- 如果要加单任务配置、BT 文件选择、peers 面板、队列排序，这份文档里已经标出了最可能要用的方法入口。
- 只要仍然走 aria2 官方 RPC interface，大多数新增能力都可以继续沿用当前的 `_call(method, params)` 结构。

## 参考

- aria2 manual: <https://aria2.github.io/manual/en/html/aria2c.html>
- RPC methods: <https://aria2.github.io/manual/en/html/aria2c.html#rpc-interface>
- JSON-RPC using HTTP GET: <https://aria2.github.io/manual/en/html/aria2c.html#json-rpc-using-http-get>
