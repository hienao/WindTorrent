import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_storage/get_storage.dart';
import 'package:windwalker/core/config/build_channel_config.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/download_task.dart';
import 'package:windwalker/features/tasks/presentation/controllers/task_controller.dart';
import 'package:windwalker/features/update/data/update_repository.dart';
import 'package:windwalker/features/update/domain/update_check_result.dart';
import 'package:windwalker/features/update/presentation/controllers/update_controller.dart';

class FakeUpdateRepository implements UpdateRepository {
  FakeUpdateRepository({required this.result});

  UpdateCheckResult result;
  int openUpdateCalls = 0;

  @override
  UpdateSource get source => UpdateSource.playStore;

  @override
  Future<UpdateCheckResult> checkForUpdate() async => result;

  @override
  Future<void> openUpdatePage(UpdateCheckResult result) async {
    openUpdateCalls++;
  }
}

final playStableConfig = BuildChannelConfig.parse(
  flavor: 'play',
  track: 'stable',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          (MethodCall methodCall) async {
            if (methodCall.method == 'getApplicationDocumentsDirectory') {
              return '/tmp/test_windwalker_update';
            }
            if (methodCall.method == 'getApplicationSupportDirectory') {
              return '/tmp/test_windwalker_update';
            }
            return null;
          },
        );
    await GetStorage.init();
  });

  setUp(() {
    // 隔离 GetStorage 单例：每个用例前清空容器内容，保持已初始化状态。
    // runSilentCheck 只读不写，但 openUpdatePage/dismissCurrentVersion 会写
    // last_update_prompt_at / day / dismissed_update_version_code，
    // 一旦后续用例调用写操作，用例顺序就会污染结果。
    GetStorage().erase();
  });

  test(
    'silent check exposes badge and dialog when no active downloads',
    () async {
      final repository = FakeUpdateRepository(
        result: const UpdateCheckResult.available(2026061501),
      );
      final tasks = TaskController();
      final controller = UpdateController(
        repository: repository,
        buildConfig: playStableConfig,
        storage: GetStorage(),
        taskController: tasks,
      );

      await controller.runSilentCheck(now: DateTime(2026, 6, 15, 10));

      expect(controller.hasUpdate, isTrue);
      expect(controller.shouldShowUpdateBadge, isTrue);
      expect(controller.shouldOfferUpdateDialog, isTrue);
    },
  );

  test(
    'silent check downgrades to badge when active downloads exist',
    () async {
      final repository = FakeUpdateRepository(
        result: const UpdateCheckResult.available(2026061501),
      );
      final tasks = TaskController();
      tasks.debugSetTasksForTest('d1', []);
      tasks.debugSetTasksForTest('d2', []);
      tasks.debugSetTasksForTest('downloading', [createTask('t1')]);

      final controller = UpdateController(
        repository: repository,
        buildConfig: playStableConfig,
        storage: GetStorage(),
        taskController: tasks,
      );

      await controller.runSilentCheck(now: DateTime(2026, 6, 15, 10));

      expect(controller.shouldShowUpdateBadge, isTrue);
      expect(controller.shouldOfferUpdateDialog, isFalse);
    },
  );

  test(
    'openUpdatePage consumes dialog opportunity for the rest of the session',
    () async {
      final repository = FakeUpdateRepository(
        result: const UpdateCheckResult.available(2026061501),
      );
      final tasks = TaskController();
      final controller = UpdateController(
        repository: repository,
        buildConfig: playStableConfig,
        storage: GetStorage(),
        taskController: tasks,
      );

      await controller.runSilentCheck(now: DateTime(2026, 6, 15, 10));

      // 初始满足所有条件，允许弹窗
      expect(controller.shouldOfferUpdateDialog, isTrue);

      // 用户点击“去更新”跳转商店，视为消费本次弹窗机会
      await controller.openUpdatePage();
      expect(repository.openUpdateCalls, 1);

      // 同一会话内不再重复 offer dialog
      expect(controller.shouldOfferUpdateDialog, isFalse);
    },
  );

  test(
    'dismissCurrentVersion suppresses dialog for the same available version',
    () async {
      const versionCode = 2026061501;
      final repository = FakeUpdateRepository(
        result: const UpdateCheckResult.available(versionCode),
      );
      final tasks = TaskController();
      final controller = UpdateController(
        repository: repository,
        buildConfig: playStableConfig,
        storage: GetStorage(),
        taskController: tasks,
      );

      await controller.runSilentCheck(now: DateTime(2026, 6, 15, 10));

      // 初始允许弹窗
      expect(controller.shouldOfferUpdateDialog, isTrue);

      // 用户点“稍后”：记录当前目标版本已被延后
      controller.dismissCurrentVersion(now: DateTime(2026, 6, 15, 10));

      // dismissedVersionCode 命中目标版本 → 不再 offer
      expect(controller.shouldOfferUpdateDialog, isFalse);
    },
  );

  test(
    'dialog stays suppressed inside cooldown window when version changes',
    () async {
      // 本用例隔离 cooldown 路径：dismissed 命中、dialogConsumedInSession 都必须被绕开，
      // 才能让决策落到 lastPromptAt + cooldown 这一支。
      //
      // 关键约束：dismissCurrentVersion 会把 _dialogConsumedInSession 置 true，
      // 这是 controller 实例级（= 单次 app 运行）状态，一旦置位本 session 内永不复位，
      // 会在 policy 中先于 cooldown 短路。因此跨时间点的复检必须新建 controller 实例
      // （模拟 app 重启），复用同一 GetStorage 容器以保留 lastPromptAt / dayKey /
      // dismissedVersionCode，从而真正落到 cooldown 判定。
      const dismissedVersion = 2026061501;
      const newVersion = 2026061502;
      final repository = FakeUpdateRepository(
        result: const UpdateCheckResult.available(dismissedVersion),
      );
      final tasks = TaskController();
      final storage = GetStorage();
      final t1 = DateTime(2026, 6, 15, 10);

      UpdateController newController() => UpdateController(
        repository: repository,
        buildConfig: playStableConfig,
        storage: storage,
        taskController: tasks,
      );

      // t1：首次检查，dismissedVersion 可弹
      var controller = newController();
      await controller.runSilentCheck(now: t1);
      expect(controller.shouldOfferUpdateDialog, isTrue);

      // 用户在 t1 点“稍后”，写入 dismissed(2026061501) + lastPrompt(t1) + dayKey(t1)
      controller.dismissCurrentVersion(now: t1);

      // 切换到新版本：dismissedVersionCode 不再匹配，强制走 cooldown 路径
      repository.result = const UpdateCheckResult.available(newVersion);

      // 模拟 app 重启（新实例），1 天后静默检查：cooldown(1d < 7d) 仍压制
      controller = newController();
      await controller.runSilentCheck(now: t1.add(const Duration(days: 1)));
      expect(controller.shouldOfferUpdateDialog, isFalse);

      // 再次重启，8 天后：cooldown 已过(8d ≥ 7d)，dayKey(t1) ≠ t1+8 天 dayKey → 放行
      controller = newController();
      await controller.runSilentCheck(now: t1.add(const Duration(days: 8)));
      expect(controller.shouldOfferUpdateDialog, isTrue);
    },
  );
}

DownloadTask createTask(String id) => DownloadTask(
  id: id,
  gid: id,
  name: id,
  downloaderId: 'd1',
  status: TaskStatus.downloading,
);
