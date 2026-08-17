# API 文档索引

## 说明

这里汇总当前仓库内保存的下载器 API 参考文档，方便开发时快速定位协议差异、版本分叉和当前项目实现依据。

## aria2

- [aria2-rpc.md](./aria2/aria2-rpc.md)
  - aria2 RPC 总览
  - 说明当前项目使用的是 `HTTP POST + JSON-RPC 2.0 body`
  - 明确没有使用官方 `HTTP GET` 编码形式
- [aria2-rpc-methods.md](./aria2/aria2-rpc-methods.md)
  - aria2 官方 RPC 方法目录
  - 当前项目已使用 / 未使用的方法状态
  - 当前项目依赖的参数顺序、返回字段和代码位置

官方参考：

- <https://aria2.github.io/manual/en/html/aria2c.html>
- <https://aria2.github.io/manual/en/html/aria2c.html#rpc-interface>

## qBittorrent

目录名当前保持仓库既有写法 `qbitorrent/`。

- [WebUI-API-(qBittorrent-v3.1.x).md](./qbitorrent/WebUI-API-(qBittorrent-v3.1.x).md)
- [WebUI-API-(qBittorrent-v3.2.0-v4.0.4).md](./qbitorrent/WebUI-API-(qBittorrent-v3.2.0-v4.0.4).md)
- [WebUI-API-(qBittorrent-4.1).md](./qbitorrent/WebUI-API-(qBittorrent-4.1).md)
- [WebUI-API-(qBittorrent-5.0).md](./qbitorrent/WebUI-API-(qBittorrent-5.0).md)

适用说明：

- 旧版与新版 WebUI API 有端点差异，尤其是任务控制接口
- 当前项目主要按较新的 API 约定实现

## Transmission

- [rpc-spec-pre-v4.1.0.md](./transmission/rpc-spec-pre-v4.1.0.md)
  - `4.1.0` 以下 legacy RPC 协议
- [rpc-spec-v4.1.0-plus.md](./transmission/rpc-spec-v4.1.0-plus.md)
  - `4.1.0+` JSON-RPC 2.0 + snake_case 协议

适用说明：

- `4.1.0+` 与 `4.1.0` 以下不只是版本差异，而是请求格式、方法名、字段名、响应载体都存在分叉
- 相关设计与实现计划可参考 `docs/superpowers/specs/` 与 `docs/superpowers/plans/` 中的 Transmission 双协议支持文档

## 使用建议

- 查“当前项目到底怎么调”：
  - 优先看对应语言下的本地导读文档，例如 `aria2/aria2-rpc.md`
- 查“未来要接某个能力该用哪个方法”：
  - 优先看方法摘录或官方版本文档，例如 `aria2/aria2-rpc-methods.md`
- 查“版本差异 / 协议分叉”：
  - qBittorrent 看不同版本 WebUI API 文档
  - Transmission 看 `pre-v4.1.0` 与 `v4.1.0-plus` 两份分叉文档
