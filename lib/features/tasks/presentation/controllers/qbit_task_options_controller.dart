import 'package:flutter/foundation.dart';
import 'package:windwalker/features/tasks/presentation/controllers/qbit_task_detail_controller.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/qbit_task_options.dart';
import 'package:windwalker/models/qbit_task_options_update.dart';
import 'package:windwalker/services/downloader_service_exception.dart';
import 'package:windwalker/services/qbit_service.dart';

/// qBit 选项子页面控制器。
///
/// 管理选项读模型（queue/category/tags/目录）、草稿态、保存态与脏检查。
/// 队列位置为 -1（任务不在队列中）时禁用队列动作。
/// 复用 [QBitServiceFactory] 注入点。
class QBitTaskOptionsController extends ChangeNotifier {
  QBitTaskOptionsController({
    QBitServiceFactory? serviceFactory,
    this.onTaskChanged,
  }) : _serviceFactory =
            serviceFactory ?? ((downloader) => QBitService(downloader));

  final QBitServiceFactory _serviceFactory;

  /// 任务变更后回调（接收 downloaderId）。
  ///
  /// 队列优先级即时动作 / 保存成功后调用，供页面触发
  /// `RealtimeSyncController.refreshNow(...)`，使变更结果回流到
  /// `TaskDomainStore`（任务域单一事实来源），保证跨页面同步。
  final void Function(String downloaderId)? onTaskChanged;
  QBitTaskOptions? _initial;
  QBitQueuePriorityAction _queueAction = QBitQueuePriorityAction.unchanged;
  String _categoryDraft = '';
  List<String> _tagDrafts = const [];
  bool _isLoading = false;
  bool _isSaving = false;
  bool _isApplyingQueueAction = false;
  String? _errorMessage;

  QBitQueuePriorityAction get queueAction => _queueAction;
  String get categoryDraft => _categoryDraft;
  List<String> get tagDrafts => _tagDrafts;
  List<String> get availableCategories =>
      List.unmodifiable(_initial?.availableCategories ?? const []);
  List<String> get availableTags =>
      List.unmodifiable(_initial?.availableTags ?? const []);
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isApplyingQueueAction => _isApplyingQueueAction;
  String? get errorMessage => _errorMessage;

  /// 队列位置 >= 0 时启用队列动作。
  bool get queueActionsEnabled => (_initial?.queuePosition ?? -1) >= 0;

  /// 加载当前选项读模型并初始化草稿。
  Future<void> load({
    required String taskId,
    required Downloader downloader,
    List<String>? availableCategories,
    List<String>? availableTags,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      final loaded = await _serviceFactory(downloader).getTaskOptions(taskId);
      _initial = loaded.copyWith(
        availableCategories:
            availableCategories ?? loaded.availableCategories,
        availableTags: availableTags ?? loaded.availableTags,
      );
      _queueAction = QBitQueuePriorityAction.unchanged;
      _categoryDraft = _initial!.category;
      _tagDrafts = List<String>.from(_initial!.tags);
    } on DownloaderServiceException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void updateQueueAction(QBitQueuePriorityAction value) {
    if (!queueActionsEnabled && value != QBitQueuePriorityAction.unchanged) {
      return;
    }
    _queueAction = value;
    notifyListeners();
  }

  Future<void> applyQueueActionNow({
    required String taskId,
    required Downloader downloader,
    required QBitQueuePriorityAction action,
  }) async {
    if (_initial == null ||
        !queueActionsEnabled ||
        action == QBitQueuePriorityAction.unchanged ||
        _isApplyingQueueAction) {
      return;
    }

    _isApplyingQueueAction = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _serviceFactory(downloader).updateTaskOptions(
        taskId,
        current: _initial!,
        update: QBitTaskOptionsUpdate(
          queueAction: action,
          category: _initial!.category,
          tags: _initial!.tags,
        ),
      );
      _queueAction = QBitQueuePriorityAction.unchanged;
      onTaskChanged?.call(downloader.id);
    } on DownloaderServiceException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isApplyingQueueAction = false;
      notifyListeners();
    }
  }

  void updateCategory(String value) {
    _categoryDraft = value.trim();
    notifyListeners();
  }

  void updateTags(List<String> value) {
    _tagDrafts = value;
    notifyListeners();
  }

  bool get isDirty =>
      _categoryDraft != (_initial?.category ?? '') ||
      !listEquals(_tagDrafts, _initial?.tags ?? const []);

  /// 保存差异（分类 / 标签）。成功后用草稿更新读模型并清除脏态；
  /// 失败保留用户输入便于重试。
  Future<void> save({
    required String taskId,
    required Downloader downloader,
  }) async {
    if (_initial == null || !isDirty) return;
    _isSaving = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _serviceFactory(downloader).updateTaskOptions(
        taskId,
        current: _initial!,
        update: QBitTaskOptionsUpdate(
          queueAction: QBitQueuePriorityAction.unchanged,
          category: _categoryDraft,
          tags: _tagDrafts,
        ),
      );
      _initial = _initial!.copyWith(
        category: _categoryDraft,
        tags: _tagDrafts,
        queuePosition: _initial!.queuePosition,
      );
      _queueAction = QBitQueuePriorityAction.unchanged;
      onTaskChanged?.call(downloader.id);
    } on DownloaderServiceException catch (e) {
      _errorMessage = e.message;
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }
}
