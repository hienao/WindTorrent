/// qBittorrent API 代际。
///
/// 4.1–4.6.x 为 legacy（pause/resume 端点），5.0+ 为 modern（stop/start 端点）。
/// 由 [QBitVersionDetector] 根据服务端 `app/version` 推断，对用户透明。
enum QBitApiGeneration {
  v4Legacy,
  v5Modern,
}
