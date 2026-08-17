import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/core/utils/log.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_domain_store.dart';
import 'package:windwalker/models/aria2_realtime_snapshot.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/qbit_realtime_snapshot.dart';
import 'package:windwalker/models/transmission_realtime_snapshot.dart';
import 'package:windwalker/models/transmission_task_detail.dart';
import 'package:windwalker/services/aria2_service.dart';
import 'package:windwalker/services/qbit_service.dart';
import 'package:windwalker/services/transmission_service.dart';

/// 全局实时轮询协调器。
///
/// 唯一持有定时器的层。按下载器维度轮询 qBit `sync/maindata` 增量接口、
/// Transmission `torrent-get` 全量接口与 Aria2 JSON-RPC 全量接口，
/// 将 typed 快照写入 [TaskDomainStore]（任务域单一事实来源），由 Store 通知下游消费方。
/// 页面与下游 controller（TaskController / DownloaderController）不再自起 timer，
/// 只从 TaskDomainStore 派生展示态。
///
/// 同时实现 [WidgetsBindingObserver] 以感知 App 生命周期：
/// 锁屏 / 进入后台时暂停轮询，恢复时清零退避状态并立即重连。
class RealtimeSyncController extends ChangeNotifier
    with WidgetsBindingObserver {
  RealtimeSyncController({
    Duration interval = const Duration(seconds: 5),
    this.qbitPollerFactory,
    this.transmissionPollerFactory,
    this.aria2PollerFactory,
  }) : _interval = interval;

  /// 轮询间隔（默认 5 秒）。
  final Duration _interval;

  /// 可注入的 qBit 轮询工厂。
  ///
  /// 接收 `(downloader, rid)`，返回 `/sync/maindata` 的原始 JSON（含 `rid`、
  /// `full_update`、增量 `torrents`、`torrents_removed` 等）。控制器据此做
  /// 精确的增量合并，避免 `fromJson` 默认值污染缺失字段。
  final Future<Map<String, dynamic>> Function(Downloader downloader, int rid)?
      qbitPollerFactory;

  /// 可注入的 Transmission 轮询工厂（返回全量 typed 快照）。
  final Future<TransmissionRealtimeSnapshot> Function(
      Downloader downloader)? transmissionPollerFactory;

  /// 可注入的 Aria2 轮询工厂（返回全量 typed 快照）。
  final Future<Aria2RealtimeSnapshot> Function(
      Downloader downloader)? aria2PollerFactory;

  DownloaderController? _downloaderController;

  /// 任务域单一事实来源。轮询结果只写入这里，不再直推下游 controller。
  TaskDomainStore? _taskDomainStore;

  /// 测试 / 启动期使用的下载器直绑入口，避免依赖 DownloaderController 的 init 时序。
  List<Downloader> _debugDownloaders = const [];

  final Map<String, Timer> _timers = {};
  final Map<String, bool> _inFlight = {};
  final Map<String, int> _failureCounts = {};
  static const int _maxConsecutiveFailures = 3;

  // 失败退避状态
  final Map<String, int> _consecutiveFailures = {};
  final Map<String, DateTime> _nextPollAt = {};
  static const _maxBackoff = Duration(seconds: 60);
  static const _baseBackoff = Duration(seconds: 5);

  // 缓存 service 实例，避免每轮重新握手
  final Map<String, QBitService> _qbitServices = {};
  final Map<String, TransmissionService> _transmissionServices = {};
  final Map<String, Aria2Service> _aria2Services = {};

  // qBit 增量轮询状态
  final Map<String, int> _qbitRidByDownloader = {};
  final Map<String, QBitRealtimeSnapshot> _qbitSnapshots = {};

  // Transmission 全量轮询状态
  final Map<String, TransmissionRealtimeSnapshot> _transmissionSnapshots = {};

  // Aria2 全量轮询状态
  final Map<String, Aria2RealtimeSnapshot> _aria2Snapshots = {};

  bool _started = false;
  bool _paused = false;

  @override
  void dispose() {
    if (_started) {
      WidgetsBinding.instance.removeObserver(this);
    }
    _cancelAllTimers();
    super.dispose();
  }

  void _cancelAllTimers() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  /// 绑定下载器列表来源。生产环境通过 `ChangeNotifierProxyProvider` 注入。
  void attach({
    required DownloaderController downloaderController,
  }) {
    _downloaderController = downloaderController;
    if (_started) {
      _syncTrackedDownloaders();
    }
  }

  /// 绑定任务域单一事实来源。轮询结果只写入这里。
  void attachStore(TaskDomainStore store) {
    _taskDomainStore = store;
  }

  /// 启动全局轮询。`HomeTabContainer` 初始化后调用一次。
  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _syncTrackedDownloaders();
  }

  /// 立即触发一次刷新（不等待 timer）。
  ///
  /// [downloaderId] 为 null 时刷新全部受追踪下载器；否则只刷新指定下载器。
  Future<void> refreshNow({String? downloaderId}) async {
    for (final downloader in _trackedDownloaders) {
      if (downloaderId != null && downloader.id != downloaderId) continue;
      await _pollDownloader(downloader, bypassBackoff: true);
    }
  }

  // ─── 只读选择器（供下游 controller / 页面派生展示态）──────────

  /// qBit 指定下载器的最新快照（无数据返回 null）。
  QBitRealtimeSnapshot? qbitSnapshot(String downloaderId) =>
      _qbitSnapshots[downloaderId];

  /// Transmission 指定下载器的最新快照（无数据返回 null）。
  TransmissionRealtimeSnapshot? transmissionSnapshot(String downloaderId) =>
      _transmissionSnapshots[downloaderId];

  /// Aria2 指定下载器的最新快照（无数据返回 null）。
  Aria2RealtimeSnapshot? aria2Snapshot(String downloaderId) =>
      _aria2Snapshots[downloaderId];

  /// 从全局 Transmission 快照派生指定任务的详情摘要。
  ///
  /// 供 Transmission 详情主页直接渲染，不再发起页面级轮询。
  /// 无快照或无对应任务时返回 null。
  TransmissionTaskDetail? transmissionDetail({
    required String downloaderId,
    required String taskId,
  }) {
    final torrent = _transmissionSnapshots[downloaderId]?.torrents[taskId];
    return torrent?.toDetail(downloaderId);
  }

  /// 从全局 qBit 快照派生指定任务的实时 torrent 态。
  ///
  /// 供 qBit 详情主页与首次加载的静态详情合并，渲染动态字段
  /// （进度/速度/已下载/已上传等）。
  QBitRealtimeTorrent? qbitTorrent({
    required String downloaderId,
    required String taskId,
  }) {
    return _qbitSnapshots[downloaderId]?.torrents[taskId];
  }

  // ─── 测试辅助 ────────────────────────────────────────────────

  /// 直接绑定下载器列表（测试 / 不经过 DownloaderController 的场景）。
  @visibleForTesting
  void debugBindDownloaders(List<Downloader> downloaders) {
    _debugDownloaders = List.unmodifiable(downloaders);
  }

  /// 当前受追踪的下载器 ID（仅 qBit / Transmission）。
  @visibleForTesting
  Set<String> get debugTrackedDownloaderIds =>
      _trackedDownloaders.map((d) => d.id).toSet();

  /// 对单个下载器执行一次轮询（测试用）。
  @visibleForTesting
  Future<void> debugPollOnce(Downloader downloader) =>
      _pollDownloader(downloader);

  /// 直接写入 Transmission 快照（测试用，供 selector 测试使用）。
  @visibleForTesting
  void debugSetTransmissionSnapshot(TransmissionRealtimeSnapshot snapshot) {
    _transmissionSnapshots[snapshot.downloaderId] = snapshot;
    notifyListeners();
  }

  // ─── App 生命周期感知 ────────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _onPaused();
      case AppLifecycleState.resumed:
        _onResumed();
      default:
        break;
    }
  }

  /// App 进入后台 / 锁屏：取消所有 Timer 避免后台请求触发假离线。
  void _onPaused() {
    if (_paused) return;
    _paused = true;
    Log.i('RealtimeSyncController: app paused, cancelling all timers');
    _cancelAllTimers();
  }

  /// App 恢复前台：清零退避状态，重建 Timer，立即触发一次全量刷新。
  void _onResumed() {
    if (!_paused) return;
    _paused = false;
    Log.i('RealtimeSyncController: app resumed, resetting backoff and '
        'refreshing all downloaders');
    _clearAllBackoffState();
    _syncTrackedDownloaders();
    unawaited(refreshNow());
  }

  /// 清零所有下载器的失败计数与退避状态，恢复即时轮询。
  @visibleForTesting
  void clearBackoffForTest() => _clearAllBackoffState();

  void _clearAllBackoffState() {
    _failureCounts.clear();
    _consecutiveFailures.clear();
    _nextPollAt.clear();
    _inFlight.clear();
  }

  // ─── 内部 ────────────────────────────────────────────────────

  List<Downloader> get _trackedDownloaders {
    final source = _downloaderController?.downloaders ?? _debugDownloaders;
    return source
        .where((d) => _supportsRealtimePolling(d.type))
        .toList(growable: false);
  }

  bool _supportsRealtimePolling(DownloaderType type) =>
      type == DownloaderType.qbittorrent ||
      type == DownloaderType.transmission ||
      type == DownloaderType.aria2;

  /// 同步 tracked 集合：移除已不存在的下载器 timer，为新下载器启动 timer。
  void _syncTrackedDownloaders() {
    final tracked = _trackedDownloaders;
    final trackedIds = tracked.map((d) => d.id).toSet();

    // 移除不再追踪的下载器
    for (final id in _timers.keys.toList()) {
      if (!trackedIds.contains(id)) {
        _timers.remove(id)?.cancel();
        _inFlight.remove(id);
        _failureCounts.remove(id);
        _consecutiveFailures.remove(id);
        _nextPollAt.remove(id);
        _qbitServices.remove(id);
        _transmissionServices.remove(id);
        _aria2Services.remove(id);
        _qbitRidByDownloader.remove(id);
        _qbitSnapshots.remove(id);
        _transmissionSnapshots.remove(id);
        _aria2Snapshots.remove(id);
      }
    }

    // 为新追踪的下载器启动 timer 并立即首次轮询
    for (final downloader in tracked) {
      if (_timers.containsKey(downloader.id)) continue;
      _timers[downloader.id] = Timer.periodic(_interval, (_) {
        unawaited(_pollDownloader(downloader));
      });
      unawaited(_pollDownloader(downloader));
    }
  }

  Future<void> _pollDownloader(Downloader downloader,
      {bool bypassBackoff = false}) async {
    // 退避检查：未到下次轮询时间则跳过（无 IO）
    if (!bypassBackoff) {
      final nextAt = _nextPollAt[downloader.id];
      if (nextAt != null && DateTime.now().isBefore(nextAt)) {
        return;
      }
    }

    // in-flight guard：上一轮未结束时跳过本轮
    if (_inFlight[downloader.id] == true) return;
    _inFlight[downloader.id] = true;

    try {
      switch (downloader.type) {
        case DownloaderType.qbittorrent:
          await _pollQBit(downloader);
          break;
        case DownloaderType.transmission:
          await _pollTransmission(downloader);
          break;
        case DownloaderType.aria2:
          await _pollAria2(downloader);
          break;
      }
      // 成功：清零退避状态
      _failureCounts[downloader.id] = 0;
      _consecutiveFailures.remove(downloader.id);
      _nextPollAt.remove(downloader.id);
    } catch (e, st) {
      _onPollFailure(downloader, e, st);
    } finally {
      _inFlight[downloader.id] = false;
    }
  }

  Future<void> _pollQBit(Downloader downloader) async {
    final previousRid = _qbitRidByDownloader[downloader.id] ?? 0;
    final raw = await (qbitPollerFactory != null
        ? qbitPollerFactory!(downloader, previousRid)
        : _defaultQBitPoller(downloader, previousRid));

    final newRid = (raw['rid'] as num?)?.toInt() ?? previousRid;
    final isFullUpdate = raw['full_update'] == true;

    final previous = _qbitSnapshots[downloader.id];
    final merged = (previous == null || isFullUpdate)
        ? QBitRealtimeSnapshot.fromJson(
            downloaderId: downloader.id, json: raw)
        : previous.mergeJson(raw);

    _qbitSnapshots[downloader.id] = merged;
    _qbitRidByDownloader[downloader.id] = newRid;
    _propagateQBit(downloader, merged);
    notifyListeners();
  }

  Future<void> _pollTransmission(Downloader downloader) async {
    final snapshot = await (transmissionPollerFactory != null
        ? transmissionPollerFactory!(downloader)
        : _defaultTransmissionPoller(downloader));

    _transmissionSnapshots[downloader.id] = snapshot;
    _propagateTransmission(downloader, snapshot);
    notifyListeners();
  }

  Future<void> _pollAria2(Downloader downloader) async {
    final snapshot = await (aria2PollerFactory != null
        ? aria2PollerFactory!(downloader)
        : _defaultAria2Poller(downloader));

    _aria2Snapshots[downloader.id] = snapshot;
    _propagateAria2(downloader, snapshot);
    notifyListeners();
  }

  /// 将 qBit 快照写入 TaskDomainStore（任务域单一事实来源）。
  void _propagateQBit(Downloader downloader, QBitRealtimeSnapshot snapshot) {
    _taskDomainStore?.applyQBitSnapshot(snapshot);
  }

  /// 将 Transmission 快照写入 TaskDomainStore（任务域单一事实来源）。
  void _propagateTransmission(
      Downloader downloader, TransmissionRealtimeSnapshot snapshot) {
    _taskDomainStore?.applyTransmissionSnapshot(snapshot);
  }

  /// 将 Aria2 快照写入 TaskDomainStore（任务域单一事实来源）。
  void _propagateAria2(
      Downloader downloader, Aria2RealtimeSnapshot snapshot) {
    _taskDomainStore?.applyAria2Snapshot(snapshot);
  }

  /// 单次轮询失败处理：累计失败次数，达到阈值标记下载器离线，计算退避时间。
  void _onPollFailure(Downloader downloader, Object e, StackTrace st) {
    final count = (_failureCounts[downloader.id] ?? 0) + 1;
    _failureCounts[downloader.id] = count;
    Log.e(
      'RealtimeSyncController: poll failure #$count for '
      '${downloader.id} (${downloader.type})',
      error: e,
      stackTrace: st,
    );

    if (count >= _maxConsecutiveFailures) {
      _taskDomainStore?.markDownloaderOffline(downloader.id);
    }

    // 指数退避：base × 2^failures，上限 _maxBackoff
    final failures = (_consecutiveFailures[downloader.id] ?? 0) + 1;
    _consecutiveFailures[downloader.id] = failures;
    final backoffMs = (_baseBackoff.inMilliseconds * (1 << (failures - 1)))
        .clamp(0, _maxBackoff.inMilliseconds);
    _nextPollAt[downloader.id] =
        DateTime.now().add(Duration(milliseconds: backoffMs));
  }

  /// 默认 qBit 轮询：走真实 service（返回原始 JSON 以保留增量语义）。
  ///
  /// 按 downloader ID 缓存 service 实例，复用内部 adapter/profile/session 缓存。
  Future<Map<String, dynamic>> _defaultQBitPoller(
      Downloader downloader, int rid) {
    final service = _qbitServices.putIfAbsent(
        downloader.id, () => QBitService(downloader));
    return service.getRealtimeMainData(rid: rid);
  }

  /// 默认 Transmission 轮询：走真实 service。
  ///
  /// 按 downloader ID 缓存 service 实例，复用内部 adapter 缓存。
  Future<TransmissionRealtimeSnapshot> _defaultTransmissionPoller(
      Downloader downloader) {
    final service = _transmissionServices.putIfAbsent(
        downloader.id, () => TransmissionService(downloader));
    return service.getRealtimeSnapshot();
  }

  /// 默认 Aria2 轮询：走真实 service（全量获取任务列表 + 全局统计）。
  ///
  /// 按 downloader ID 缓存 service 实例，复用 HTTP client。
  Future<Aria2RealtimeSnapshot> _defaultAria2Poller(Downloader downloader) {
    final service = _aria2Services.putIfAbsent(
        downloader.id, () => Aria2Service(downloader));
    return service.getRealtimeSnapshot();
  }
}
