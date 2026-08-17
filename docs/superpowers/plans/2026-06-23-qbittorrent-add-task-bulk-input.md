# qBittorrent 添加任务批量输入 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 让添加任务页在选中 `qBittorrent` 时切换为多行批量磁力输入模式，并在保存路径输入框为空时动态展示当前下载器的默认保存路径。

**Architecture:** 保持当前 Add Task 页面结构不变，只在 `qBittorrent` 选中态上叠加更强的输入模式和默认路径提示。服务端接线只扩展 qBittorrent facade 与 adapter；页面侧通过可注入的默认路径加载器实现可测试的异步 hint 更新，并用独立的小型归一化工具处理多行磁力输入。

**Tech Stack:** Flutter、Provider、go_router、qBittorrent WebUI API、flutter_test

---

## 文件结构

- 修改：`/Volumes/Data/Code/GitHub/WindWalker/lib/services/qbit/qbit_api_adapter.dart`
  - 为 qBittorrent facade / adapter 增加“读取默认保存路径”能力。
- 修改：`/Volumes/Data/Code/GitHub/WindWalker/lib/services/qbit/qbit_base_api_adapter.dart`
  - 实现 `/api/v2/app/defaultSavePath` 读取逻辑。
- 修改：`/Volumes/Data/Code/GitHub/WindWalker/lib/services/qbit_service.dart`
  - 暴露 qBittorrent 默认保存路径 facade 方法。
- 修改：`/Volumes/Data/Code/GitHub/WindWalker/test/unit/services/qbit/qbit_common_operations_test.dart`
  - 为 facade 默认路径读取补单元测试。

- 新建：`/Volumes/Data/Code/GitHub/WindWalker/lib/features/add_task/presentation/services/qbit_link_input_normalizer.dart`
  - 提供 qBittorrent 多行磁力输入归一化函数。
- 新建：`/Volumes/Data/Code/GitHub/WindWalker/test/unit/features/add_task/qbit_link_input_normalizer_test.dart`
  - 只测“按行 trim + 去空行 + 按 `\n` 拼回去”。

- 修改：`/Volumes/Data/Code/GitHub/WindWalker/lib/features/add_task/presentation/pages/add_task_page.dart`
  - 增加 qBittorrent 多行输入态、默认保存路径异步 hint 状态、提交前归一化。
- 修改：`/Volumes/Data/Code/GitHub/WindWalker/lib/l10n/app_zh.arb`
- 修改：`/Volumes/Data/Code/GitHub/WindWalker/lib/l10n/app_en.arb`
- 修改：`/Volumes/Data/Code/GitHub/WindWalker/lib/l10n/app_ja.arb`
  - 新增批量模式提示和默认路径加载中的文案。
- 修改（生成物）：`/Volumes/Data/Code/GitHub/WindWalker/lib/l10n/app_localizations.dart`
- 修改（生成物）：`/Volumes/Data/Code/GitHub/WindWalker/lib/l10n/app_localizations_zh.dart`
- 修改（生成物）：`/Volumes/Data/Code/GitHub/WindWalker/lib/l10n/app_localizations_en.dart`
- 修改（生成物）：`/Volumes/Data/Code/GitHub/WindWalker/lib/l10n/app_localizations_ja.dart`

- 修改：`/Volumes/Data/Code/GitHub/WindWalker/test/widget/test_helpers.dart`
  - 为 AddTaskPage 测试入口增加默认路径加载器注入能力。
- 修改：`/Volumes/Data/Code/GitHub/WindWalker/test/widget/add_task_page_test.dart`
  - 为 qBittorrent 多行模式、动态 hint、提交归一化、切换保护手填路径增加回归测试。

## 任务 1：补齐 qBittorrent 默认保存路径服务能力

**Files:**
- Modify: `/Volumes/Data/Code/GitHub/WindWalker/lib/services/qbit/qbit_api_adapter.dart`
- Modify: `/Volumes/Data/Code/GitHub/WindWalker/lib/services/qbit/qbit_base_api_adapter.dart`
- Modify: `/Volumes/Data/Code/GitHub/WindWalker/lib/services/qbit_service.dart`
- Test: `/Volumes/Data/Code/GitHub/WindWalker/test/unit/services/qbit/qbit_common_operations_test.dart`

- [ ] **Step 1: 先写失败的 facade 测试**

```dart
test('getDefaultSavePath reads dedicated default-save-path endpoint', () async {
  final client = MockClient((request) async {
    if (request.url.path.endsWith('/api/v2/auth/login')) {
      return http.Response('Ok.', 200,
          headers: {'set-cookie': 'SID=abc; Path=/'});
    }
    if (request.url.path.endsWith('/api/v2/app/version')) {
      return http.Response('v5.0.0', 200);
    }
    if (request.url.path.endsWith('/api/v2/app/webapiVersion')) {
      return http.Response('2.11.3', 200);
    }
    if (request.url.path.endsWith('/api/v2/app/defaultSavePath')) {
      return http.Response('/downloads/media', 200);
    }
    return http.Response('', 404);
  });

  final service = QBitService(qbit(), client: client);
  final path = await service.getDefaultSavePath();

  expect(path, '/downloads/media');
});
```

- [ ] **Step 2: 运行单测，确认接口还不存在时先失败**

Run:

```bash
flutter test test/unit/services/qbit/qbit_common_operations_test.dart
```

Expected:

```text
Compilation failed or test failed because QBitService.getDefaultSavePath / QBitApiAdapter.getDefaultSavePath is undefined.
```

- [ ] **Step 3: 最小实现 adapter 与 facade 方法**

在 `qbit_api_adapter.dart` 增加契约：

```dart
abstract class QBitApiAdapter {
  Future<List<DownloadTask>> getTasks();

  Future<Map<String, dynamic>> getGlobalStat();

  Future<String> addTask(AddTaskRequest request);

  Future<String> addDownload(String url, {String? savePath});

  Future<String> getDefaultSavePath();

  Future<void> pauseTask(String taskId);
  // ...
}
```

在 `qbit_base_api_adapter.dart` 实现：

```dart
@override
Future<String> getDefaultSavePath() async {
  final body = await session.getText('/api/v2/app/defaultSavePath');
  return body.trim();
}
```

在 `qbit_service.dart` 暴露 facade：

```dart
Future<String> getDefaultSavePath() async =>
    (await _resolveAdapter()).getDefaultSavePath();
```

- [ ] **Step 4: 重新运行 qBittorrent 公共操作单测**

Run:

```bash
flutter test test/unit/services/qbit/qbit_common_operations_test.dart
```

Expected:

```text
All tests passed!
```

- [ ] **Step 5: 提交这一组服务接线**

```bash
git add \
  lib/services/qbit/qbit_api_adapter.dart \
  lib/services/qbit/qbit_base_api_adapter.dart \
  lib/services/qbit_service.dart \
  test/unit/services/qbit/qbit_common_operations_test.dart
git commit -m "feat: add qbittorrent default save path api"
```

## 任务 2：抽出 qBittorrent 多行输入归一化工具

**Files:**
- Create: `/Volumes/Data/Code/GitHub/WindWalker/lib/features/add_task/presentation/services/qbit_link_input_normalizer.dart`
- Test: `/Volumes/Data/Code/GitHub/WindWalker/test/unit/features/add_task/qbit_link_input_normalizer_test.dart`

- [ ] **Step 1: 先写失败的归一化测试**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/features/add_task/presentation/services/qbit_link_input_normalizer.dart';

void main() {
  test('removes blank lines and trims each magnet line', () {
    final result = normalizeQBitBulkInput('''
      magnet:?xt=urn:btih:AAA

        magnet:?xt=urn:btih:BBB  

    ''');

    expect(result, 'magnet:?xt=urn:btih:AAA\\nmagnet:?xt=urn:btih:BBB');
  });

  test('returns empty string when all lines are blank', () {
    expect(normalizeQBitBulkInput(' \\n\\n  '), '');
  });
}
```

- [ ] **Step 2: 运行归一化单测，确认函数尚未实现**

Run:

```bash
flutter test test/unit/features/add_task/qbit_link_input_normalizer_test.dart
```

Expected:

```text
Compilation failed because normalizeQBitBulkInput is undefined.
```

- [ ] **Step 3: 用最小实现补齐归一化函数**

```dart
String normalizeQBitBulkInput(String raw) {
  final lines = raw
      .split('\n')
      .map((line) => line.trim())
      .where((line) => line.isNotEmpty);
  return lines.join('\n');
}
```

- [ ] **Step 4: 重新运行归一化测试**

Run:

```bash
flutter test test/unit/features/add_task/qbit_link_input_normalizer_test.dart
```

Expected:

```text
All tests passed!
```

- [ ] **Step 5: 提交归一化工具与测试**

```bash
git add \
  lib/features/add_task/presentation/services/qbit_link_input_normalizer.dart \
  test/unit/features/add_task/qbit_link_input_normalizer_test.dart
git commit -m "feat: add qbittorrent bulk link normalizer"
```

## 任务 3：实现 qBittorrent 专属 UI 与动态默认路径 hint

**Files:**
- Modify: `/Volumes/Data/Code/GitHub/WindWalker/lib/features/add_task/presentation/pages/add_task_page.dart`
- Modify: `/Volumes/Data/Code/GitHub/WindWalker/lib/l10n/app_zh.arb`
- Modify: `/Volumes/Data/Code/GitHub/WindWalker/lib/l10n/app_en.arb`
- Modify: `/Volumes/Data/Code/GitHub/WindWalker/lib/l10n/app_ja.arb`
- Modify: `/Volumes/Data/Code/GitHub/WindWalker/lib/l10n/app_localizations.dart`
- Modify: `/Volumes/Data/Code/GitHub/WindWalker/lib/l10n/app_localizations_zh.dart`
- Modify: `/Volumes/Data/Code/GitHub/WindWalker/lib/l10n/app_localizations_en.dart`
- Modify: `/Volumes/Data/Code/GitHub/WindWalker/lib/l10n/app_localizations_ja.dart`
- Modify: `/Volumes/Data/Code/GitHub/WindWalker/test/widget/test_helpers.dart`
- Test: `/Volumes/Data/Code/GitHub/WindWalker/test/widget/add_task_page_test.dart`

- [ ] **Step 1: 先写失败的 Widget 测试，锁定 qB 模式和动态 hint**

在 `add_task_page_test.dart` 增加至少这两个测试：

```dart
testWidgets('qBittorrent downloader shows bulk input mode and resolved save-path hint',
    (tester) async {
  final controller = MockDownloaderController()
    ..testDownloaders = [
      createTestDownloader(
        id: 'qb',
        name: 'Test qB',
        type: DownloaderType.qbittorrent,
      ),
    ];

  await tester.pumpWidget(
    createAddTaskTestApp(
      downloaderController: controller,
      defaultSavePathLoader: (_) async => '/downloads/media',
    ),
  );
  await tester.pump();
  await tester.pump();

  expect(find.text('qBittorrent 模式：一行一个磁力链接'), findsOneWidget);
  expect(find.text('/downloads/media'), findsOneWidget);

  final linkField = tester.widget<TextFormField>(
    find.byWidgetPredicate(
      (widget) => widget is TextFormField && widget.maxLines == 5,
    ),
  );
  expect(linkField.minLines, 5);
});

testWidgets('empty save-path field shows loading hint while default path is pending',
    (tester) async {
  final completer = Completer<String?>();
  final controller = MockDownloaderController()
    ..testDownloaders = [
      createTestDownloader(
        id: 'qb',
        name: 'Test qB',
        type: DownloaderType.qbittorrent,
      ),
    ];

  await tester.pumpWidget(
    createAddTaskTestApp(
      downloaderController: controller,
      defaultSavePathLoader: (_) => completer.future,
    ),
  );
  await tester.pump();

  expect(find.text('正在读取默认保存路径...'), findsOneWidget);

  completer.complete('/downloads/media');
  await tester.pump();
  await tester.pump();

  expect(find.text('/downloads/media'), findsOneWidget);
});
```

- [ ] **Step 2: 运行 Widget 测试，确认它们先失败**

Run:

```bash
flutter test test/widget/add_task_page_test.dart
```

Expected:

```text
FAIL because AddTaskPage has no defaultSavePathLoader parameter,
no qBittorrent bulk hint copy, and the link field is still single-line.
```

- [ ] **Step 3: 先补本地化文案与生成代码**

在 `app_zh.arb` / `app_en.arb` / `app_ja.arb` 增加：

```json
"qbitBulkInputHint": "qBittorrent 模式：一行一个磁力链接",
"loadingDefaultSavePath": "正在读取默认保存路径..."
```

英文与日文版本分别填入自然翻译，例如：

```json
"qbitBulkInputHint": "qBittorrent mode: one magnet link per line",
"loadingDefaultSavePath": "Loading default save path..."
```

然后生成本地化代码：

```bash
flutter gen-l10n
```

Expected:

```text
Synthetic package output updated without errors.
```

- [ ] **Step 4: 给测试入口增加默认路径加载器注入能力**

在 `test_helpers.dart` 的 `createAddTaskTestApp` 中加一个可选参数并透传给页面：

```dart
Widget createAddTaskTestApp({
  required DownloaderController downloaderController,
  TaskController? taskController,
  TorrentFilePicker? torrentFilePicker,
  Future<String?> Function(Downloader downloader)? defaultSavePathLoader,
}) {
  // ...
  GoRoute(
    path: 'add-task',
    builder: (context, state) => AddTaskPage(
      torrentFilePicker: torrentFilePicker,
      defaultSavePathLoader: defaultSavePathLoader,
    ),
  );
}
```

- [ ] **Step 5: 在页面里实现 qB 模式与动态 hint 状态**

在 `AddTaskPage` 中加注入点和状态字段：

```dart
class AddTaskPage extends StatefulWidget {
  final String? initialUrl;
  final TorrentFilePicker? torrentFilePicker;
  final Future<String?> Function(Downloader downloader)? defaultSavePathLoader;

  const AddTaskPage({
    super.key,
    this.initialUrl,
    this.torrentFilePicker,
    this.defaultSavePathLoader,
  });
}
```

```dart
String? _resolvedDefaultSavePath;
bool _isLoadingDefaultSavePath = false;
String? _defaultSavePathForDownloaderId;

bool _isQBitDownloader(Downloader? downloader) =>
    downloader?.type == DownloaderType.qbittorrent;
```

增加默认路径读取逻辑：

```dart
Future<String?> _fetchDefaultSavePath(Downloader downloader) async {
  if (widget.defaultSavePathLoader != null) {
    return widget.defaultSavePathLoader!(downloader);
  }
  if (downloader.type != DownloaderType.qbittorrent) return null;

  final path = await QBitService(downloader).getDefaultSavePath();
  return path.trim().isEmpty ? null : path.trim();
}

Future<void> _refreshDefaultSavePath(Downloader? downloader) async {
  if (!mounted) return;
  if (downloader == null || !_isQBitDownloader(downloader)) {
    setState(() {
      _isLoadingDefaultSavePath = false;
      _resolvedDefaultSavePath = null;
      _defaultSavePathForDownloaderId = downloader?.id;
    });
    return;
  }

  setState(() {
    _isLoadingDefaultSavePath = true;
    _resolvedDefaultSavePath = null;
    _defaultSavePathForDownloaderId = downloader.id;
  });

  try {
    final path = await _fetchDefaultSavePath(downloader);
    if (!mounted || _defaultSavePathForDownloaderId != downloader.id) return;
    setState(() {
      _resolvedDefaultSavePath = path;
      _isLoadingDefaultSavePath = false;
    });
  } catch (_) {
    if (!mounted || _defaultSavePathForDownloaderId != downloader.id) return;
    setState(() {
      _resolvedDefaultSavePath = null;
      _isLoadingDefaultSavePath = false;
    });
  }
}
```

让选择变化触发刷新，并把链接输入框切到多行：

```dart
void _selectDownloader(Downloader downloader) {
  if (_selectedDownloaderId == downloader.id) return;
  setState(() {
    _selectedDownloaderId = downloader.id;
  });
  unawaited(_refreshDefaultSavePath(downloader));
}
```

```dart
final isQBit = _isQBitDownloader(selectedDownloader);
```

```dart
if (isQBit) ...[
  Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(l10n.qbitBulkInputHint),
  ),
]
```

```dart
TextFormField(
  controller: _urlController,
  minLines: isQBit ? 5 : 1,
  maxLines: isQBit ? 5 : 1,
  decoration: InputDecoration(
    hintText: l10n.pasteHint,
    // ...
  ),
)
```

保存路径 hint 走计算值：

```dart
String _savePathHint(AppLocalizations l10n) {
  if (_savePathController.text.isNotEmpty) {
    return l10n.defaultSavePath;
  }
  if (_isLoadingDefaultSavePath) {
    return l10n.loadingDefaultSavePath;
  }
  return _resolvedDefaultSavePath ?? l10n.defaultSavePath;
}
```

- [ ] **Step 6: 重新运行 AddTaskPage Widget 测试**

Run:

```bash
flutter test test/widget/add_task_page_test.dart
```

Expected:

```text
All tests passed for qBittorrent bulk-mode UI and dynamic save-path hint.
```

- [ ] **Step 7: 提交 UI、多语言与测试入口修改**

```bash
git add \
  lib/features/add_task/presentation/pages/add_task_page.dart \
  lib/l10n/app_zh.arb \
  lib/l10n/app_en.arb \
  lib/l10n/app_ja.arb \
  lib/l10n/app_localizations.dart \
  lib/l10n/app_localizations_zh.dart \
  lib/l10n/app_localizations_en.dart \
  lib/l10n/app_localizations_ja.dart \
  test/widget/test_helpers.dart \
  test/widget/add_task_page_test.dart
git commit -m "feat: add qbittorrent bulk input mode ui"
```

## 任务 4：把 qBittorrent 提交前归一化与切换保护补齐

**Files:**
- Modify: `/Volumes/Data/Code/GitHub/WindWalker/lib/features/add_task/presentation/pages/add_task_page.dart`
- Test: `/Volumes/Data/Code/GitHub/WindWalker/test/widget/add_task_page_test.dart`

- [ ] **Step 1: 先写失败的 Widget 回归测试**

在 `add_task_page_test.dart` 追加两条关键回归：

```dart
testWidgets('submit with qBittorrent multiline input normalizes url before addTask',
    (tester) async {
  final controller = MockDownloaderController()
    ..testDownloaders = [
      createTestDownloader(
        id: 'qb',
        name: 'Test qB',
        type: DownloaderType.qbittorrent,
      ),
    ];
  final taskController = MockTaskController();

  await tester.pumpWidget(
    createAddTaskTestApp(
      downloaderController: controller,
      taskController: taskController,
      defaultSavePathLoader: (_) async => '/downloads/media',
    ),
  );
  await tester.pump();
  await tester.pump();

  await tester.enterText(
    find.byType(TextFormField).first,
    ' magnet:?xt=urn:btih:AAA\\n\\n magnet:?xt=urn:btih:BBB ',
  );

  await tester.tap(find.text('开始下载'));
  await tester.pumpAndSettle();

  expect(
    taskController.lastAddTaskRequest!.url,
    'magnet:?xt=urn:btih:AAA\\nmagnet:?xt=urn:btih:BBB',
  );
});

testWidgets('manual save path survives downloader switch', (tester) async {
  final controller = MockDownloaderController()
    ..testDownloaders = [
      createTestDownloader(
        id: 'qb',
        name: 'Test qB',
        type: DownloaderType.qbittorrent,
      ),
      createTestDownloader(
        id: 'aria',
        name: 'Test Aria2',
        type: DownloaderType.aria2,
      ),
    ];

  await tester.pumpWidget(
    createAddTaskTestApp(
      downloaderController: controller,
      defaultSavePathLoader: (downloader) async {
        if (downloader.id == 'qb') return '/downloads/media';
        return null;
      },
    ),
  );
  await tester.pump();
  await tester.pump();

  await tester.enterText(find.byType(TextFormField).last, '/custom/path');

  await tester.tap(find.text('Test qB'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Test Aria2'));
  await tester.pumpAndSettle();

  expect(find.text('/custom/path'), findsOneWidget);
});
```

- [ ] **Step 2: 运行 Widget 测试，确认提交逻辑尚未归一化**

Run:

```bash
flutter test test/widget/add_task_page_test.dart
```

Expected:

```text
FAIL because submitted url still contains blank lines / untrimmed spaces,
or save-path switching behavior is not yet locked down by implementation.
```

- [ ] **Step 3: 在提交前只对 qBittorrent 做归一化**

在 `AddTaskPage` 顶部引入工具：

```dart
import 'package:windwalker/features/add_task/presentation/services/qbit_link_input_normalizer.dart';
```

在 `_resolveRequestBeforeSubmit()` 里先拿到当前所选下载器，再计算最终 URL：

```dart
final downloader = context.read<DownloaderController>().getDownloader(
  _selectedDownloaderId!,
);

final rawUrl = _urlController.text;
final normalizedUrl = rawUrl.trim().isEmpty
    ? null
    : downloader?.type == DownloaderType.qbittorrent
        ? () {
            final value = normalizeQBitBulkInput(rawUrl);
            return value.isEmpty ? null : value;
          }()
        : rawUrl.trim();

final baseRequest = AddTaskRequest(
  downloaderId: _selectedDownloaderId!,
  url: normalizedUrl,
  torrentFileBytes: _torrentBytes,
  torrentFileName: _torrentFileName,
  savePath: _savePathController.text.trim().isEmpty
      ? null
      : _savePathController.text.trim(),
);
```

- [ ] **Step 4: 重新运行 AddTaskPage Widget 测试**

Run:

```bash
flutter test test/widget/add_task_page_test.dart
```

Expected:

```text
All tests passed, including qBittorrent submit normalization and save-path preservation.
```

- [ ] **Step 5: 跑本次变更涉及的完整回归集合**

Run:

```bash
flutter test test/unit/services/qbit/qbit_common_operations_test.dart
flutter test test/unit/features/add_task/qbit_link_input_normalizer_test.dart
flutter test test/widget/add_task_page_test.dart
```

Expected:

```text
All tests passed!
```

- [ ] **Step 6: 提交提交逻辑与最终回归**

```bash
git add \
  lib/features/add_task/presentation/pages/add_task_page.dart \
  test/widget/add_task_page_test.dart
git commit -m "feat: normalize qbittorrent bulk task submission"
```

## 计划自检

- Spec 覆盖：
  - qBittorrent 多行输入模式：任务 3
  - 动态默认保存路径 hint：任务 1 + 任务 3
  - 只对 qB 生效：任务 3 + 任务 4
  - 提交前按行 trim / 去空行：任务 2 + 任务 4
  - 切换下载器保护用户输入：任务 4
- Placeholder 扫描：
  - 本计划未使用 `TODO`、`TBD`、`later`、`appropriate` 之类占位描述。
- 类型一致性：
  - qB 服务方法统一命名为 `getDefaultSavePath`
  - 归一化函数统一命名为 `normalizeQBitBulkInput`
  - 页面注入点统一命名为 `defaultSavePathLoader`
