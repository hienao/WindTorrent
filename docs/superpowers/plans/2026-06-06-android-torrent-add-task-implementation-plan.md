# Android 种子文件添加任务 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 Android 添加任务页补齐 `.torrent` 文件提交流程，并同时支持 Aria2、qBittorrent、Transmission 三种下载器。

**Architecture:** 采用统一任务请求模型 `AddTaskRequest`，把“URL 提交”和“种子文件提交”收敛成同一个 controller / service 入口。页面只负责采集输入和冲突交互，下载器协议差异全部留在各自 service 中，并补上可测试的文件选择与 HTTP 请求边界。

**Tech Stack:** Flutter 3.24、Provider、go_router、http、file_picker、flutter_test、mockito

---

## 文件结构

### 新建文件

- `lib/models/add_task_request.dart`
  - 统一描述 URL / 种子两类添加任务请求。
- `lib/features/add_task/presentation/services/torrent_file_picker.dart`
  - 封装 Android `.torrent` 选择与字节读取，供页面使用并便于测试替换。
- `test/unit/add_task_request_test.dart`
  - 覆盖请求模型的来源校验。
- `test/unit/downloader_controller_add_task_test.dart`
  - 覆盖 controller 的统一提交行为。
- `test/unit/downloader_services_add_task_test.dart`
  - 覆盖三种下载器的任务创建协议映射。
- `test/widget/add_task_page_test.dart`
  - 覆盖页面种子选择、冲突选择和提交流程。

### 修改文件

- `pubspec.yaml`
  - 增加 `file_picker` 依赖。
- `lib/services/base_downloader_service.dart`
  - 增加统一 `addTask(AddTaskRequest request)` 契约。
- `lib/services/aria2_service.dart`
  - 实现 `aria2.addTorrent` 提交与可注入 HTTP client。
- `lib/services/qbit_service.dart`
  - 实现 multipart torrent 上传与可注入 HTTP client。
- `lib/services/transmission_service.dart`
  - 实现 `metainfo` 提交与可注入 HTTP client。
- `lib/features/downloaders/presentation/controllers/downloader_controller.dart`
  - 增加统一 `addTask(...)` 入口，保留旧 `addDownload(...)` 包装。
- `lib/features/add_task/presentation/pages/add_task_page.dart`
  - 增加种子状态、文件选择、冲突对话框、统一提交逻辑。
- `lib/l10n/app_zh.arb`
  - 增加中文文案。
- `lib/l10n/app_en.arb`
  - 增加英文文案。
- `lib/l10n/app_ja.arb`
  - 增加日文文案。
- `lib/l10n/app_localizations*.dart`
  - 由 `flutter gen-l10n` 生成。
- `test/widget/test_helpers.dart`
  - 为 `AddTaskPage` 提供测试路由 / mock controller 扩展。

---

### Task 1: 建立统一任务请求模型

**Files:**
- Create: `lib/models/add_task_request.dart`
- Create: `test/unit/add_task_request_test.dart`
- Modify: `test/unit/models_test.dart`

- [ ] **Step 1: 先写请求模型的失败测试**

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/models/add_task_request.dart';

void main() {
  group('AddTaskRequest', () {
    test('url 请求应被识别为合法来源', () {
      final request = AddTaskRequest(
        downloaderId: 'd1',
        url: 'magnet:?xt=urn:btih:test',
      );

      expect(request.hasUrlSource, isTrue);
      expect(request.hasTorrentSource, isFalse);
      expect(request.isValidSourceSelection, isTrue);
    });

    test('torrent 请求应被识别为合法来源', () {
      final request = AddTaskRequest(
        downloaderId: 'd1',
        torrentFileName: 'demo.torrent',
        torrentFileBytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(request.hasUrlSource, isFalse);
      expect(request.hasTorrentSource, isTrue);
      expect(request.isValidSourceSelection, isTrue);
    });

    test('同时存在 url 和 torrent 时应视为非法提交', () {
      final request = AddTaskRequest(
        downloaderId: 'd1',
        url: 'https://example.com/file.iso',
        torrentFileName: 'demo.torrent',
        torrentFileBytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(request.isValidSourceSelection, isFalse);
    });

    test('torrent 缺少文件名时应视为非法提交', () {
      final request = AddTaskRequest(
        downloaderId: 'd1',
        torrentFileBytes: Uint8List.fromList([1, 2, 3]),
      );

      expect(request.isValidSourceSelection, isFalse);
    });
  });
}
```

- [ ] **Step 2: 运行单测确认失败**

Run: `flutter test test/unit/add_task_request_test.dart`
Expected: FAIL，提示 `Target of URI doesn't exist: 'package:windwalker/models/add_task_request.dart'`

- [ ] **Step 3: 写最小模型实现**

```dart
import 'dart:typed_data';

class AddTaskRequest {
  final String downloaderId;
  final String? url;
  final Uint8List? torrentFileBytes;
  final String? torrentFileName;
  final String? savePath;

  const AddTaskRequest({
    required this.downloaderId,
    this.url,
    this.torrentFileBytes,
    this.torrentFileName,
    this.savePath,
  });

  bool get hasUrlSource => url != null && url!.trim().isNotEmpty;

  bool get hasTorrentSource =>
      torrentFileBytes != null &&
      torrentFileBytes!.isNotEmpty &&
      torrentFileName != null &&
      torrentFileName!.trim().isNotEmpty;

  bool get isValidSourceSelection => hasUrlSource != hasTorrentSource;

  AddTaskRequest copyWith({
    String? downloaderId,
    String? url,
    Uint8List? torrentFileBytes,
    String? torrentFileName,
    String? savePath,
    bool clearUrl = false,
    bool clearTorrent = false,
  }) {
    return AddTaskRequest(
      downloaderId: downloaderId ?? this.downloaderId,
      url: clearUrl ? null : (url ?? this.url),
      torrentFileBytes:
          clearTorrent ? null : (torrentFileBytes ?? this.torrentFileBytes),
      torrentFileName:
          clearTorrent ? null : (torrentFileName ?? this.torrentFileName),
      savePath: savePath ?? this.savePath,
    );
  }
}
```

- [ ] **Step 4: 把模型纳入现有模型测试入口**

```dart
import 'package:windwalker/models/add_task_request.dart';

test('AddTaskRequest copyWith 支持清空 torrent 来源', () {
  final request = AddTaskRequest(
    downloaderId: 'd1',
    torrentFileName: 'demo.torrent',
    torrentFileBytes: Uint8List.fromList([1, 2, 3]),
  );

  final cleared = request.copyWith(clearTorrent: true);

  expect(cleared.torrentFileName, isNull);
  expect(cleared.torrentFileBytes, isNull);
});
```

- [ ] **Step 5: 重新运行模型测试**

Run: `flutter test test/unit/add_task_request_test.dart test/unit/models_test.dart`
Expected: PASS

- [ ] **Step 6: 提交本任务**

```bash
git add lib/models/add_task_request.dart test/unit/add_task_request_test.dart test/unit/models_test.dart
git commit -m "feat: add unified add task request model"
```

---

### Task 2: 给 Service 层加统一入口和可测试 HTTP 边界

**Files:**
- Modify: `lib/services/base_downloader_service.dart`
- Modify: `lib/services/aria2_service.dart`
- Modify: `lib/services/qbit_service.dart`
- Modify: `lib/services/transmission_service.dart`

- [ ] **Step 1: 先声明统一 service 契约**

```dart
import 'package:windwalker/models/add_task_request.dart';

abstract class DownloaderService {
  final Downloader downloader;

  DownloaderService(this.downloader);

  Future<String> addTask(AddTaskRequest request);

  Future<String> addDownload(String url, {String? savePath});
}
```

- [ ] **Step 2: 为三个 service 增加可注入 `http.Client`**

```dart
class Aria2Service extends DownloaderService {
  final http.Client _client;

  Aria2Service(super.downloader, {http.Client? client})
      : _client = client ?? http.Client();
}

class QBitService extends DownloaderService {
  final http.Client _client;

  QBitService(super.downloader, {http.Client? client})
      : _client = client ?? http.Client();
}

class TransmissionService extends DownloaderService {
  final http.Client _client;

  TransmissionService(super.downloader, {http.Client? client})
      : _client = client ?? http.Client();
}
```

- [ ] **Step 3: 把现有 `http.get/post` 统一替换成 `_client.get/post/send`**

```dart
final response = await _client
    .post(
      Uri.parse(_rpcUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    )
    .timeout(const Duration(seconds: 30));
```

```dart
final response = await _client
    .get(Uri.parse(url), headers: _headers)
    .timeout(const Duration(seconds: 10));
```

```dart
final request = http.MultipartRequest(
  'POST',
  Uri.parse('$_baseUrl/api/v2/torrents/add'),
)
  ..headers.addAll(_headers)
  ..fields['savepath'] = savePath ?? ''
  ..files.add(
    http.MultipartFile.fromBytes(
      'torrents',
      requestModel.torrentFileBytes!,
      filename: requestModel.torrentFileName!,
    ),
  );

final streamed = await _client.send(request).timeout(const Duration(seconds: 30));
```

- [ ] **Step 4: 在各 service 中增加统一 `addTask(...)` 默认分流**

```dart
@override
Future<String> addTask(AddTaskRequest request) {
  if (request.hasUrlSource) {
    return addDownload(request.url!, savePath: request.savePath);
  }

  throw UnimplementedError('Torrent add flow must be implemented per service');
}
```

- [ ] **Step 5: 运行静态检查，确保重构没有语法错误**

Run: `flutter analyze`
Expected: PASS，或只剩与本任务无关的已有 warning

- [ ] **Step 6: 提交本任务**

```bash
git add lib/services/base_downloader_service.dart lib/services/aria2_service.dart lib/services/qbit_service.dart lib/services/transmission_service.dart
git commit -m "refactor: prepare downloader services for unified add task flow"
```

---

### Task 3: 实现三种下载器的 torrent 提交流程

**Files:**
- Modify: `lib/services/aria2_service.dart`
- Modify: `lib/services/qbit_service.dart`
- Modify: `lib/services/transmission_service.dart`
- Create: `test/unit/downloader_services_add_task_test.dart`

- [ ] **Step 1: 先写 service 协议映射测试**

```dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/add_task_request.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/services/aria2_service.dart';
import 'package:windwalker/services/qbit_service.dart';
import 'package:windwalker/services/transmission_service.dart';

void main() {
  test('Transmission torrent 提交应使用 metainfo', () async {
    late Map<String, dynamic> payload;

    final client = MockClient((request) async {
      payload = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(
        jsonEncode({
          'result': {
            'torrent_added': {'id': 7}
          }
        }),
        200,
      );
    });

    final service = TransmissionService(_transmissionDownloader(), client: client);

    final result = await service.addTask(
      AddTaskRequest(
        downloaderId: 'tx',
        torrentFileName: 'demo.torrent',
        torrentFileBytes: Uint8List.fromList([1, 2, 3]),
      ),
    );

    expect(result, '7');
    expect(payload['params']['metainfo'], base64Encode([1, 2, 3]));
  });
}
```

- [ ] **Step 2: 运行单测确认失败**

Run: `flutter test test/unit/downloader_services_add_task_test.dart`
Expected: FAIL，提示 `addTask` 未处理 torrent 或请求体字段不匹配

- [ ] **Step 3: 实现 Aria2 的 `aria2.addTorrent`**

```dart
@override
Future<String> addTask(AddTaskRequest request) async {
  if (request.hasUrlSource) {
    return addDownload(request.url!, savePath: request.savePath);
  }

  final result = await _call('aria2.addTorrent', [
    'token:$_secret',
    base64Encode(request.torrentFileBytes!),
    [],
    if (request.savePath != null) {'dir': request.savePath},
  ]);

  return result?.toString() ?? '';
}
```

- [ ] **Step 4: 实现 qBittorrent 的 multipart 上传**

```dart
@override
Future<String> addTask(AddTaskRequest requestModel) async {
  if (_sid == null) await _login();

  if (requestModel.hasUrlSource) {
    return addDownload(requestModel.url!, savePath: requestModel.savePath);
  }

  final request = http.MultipartRequest(
    'POST',
    Uri.parse('$_baseUrl/api/v2/torrents/add'),
  )
    ..headers.addAll(_headers)
    ..files.add(
      http.MultipartFile.fromBytes(
        'torrents',
        requestModel.torrentFileBytes!,
        filename: requestModel.torrentFileName!,
      ),
    );

  if (requestModel.savePath != null && requestModel.savePath!.isNotEmpty) {
    request.fields['savepath'] = requestModel.savePath!;
  }

  final response = await http.Response.fromStream(
    await _client.send(request).timeout(const Duration(seconds: 30)),
  );

  return response.statusCode == 200 ? 'ok' : '';
}
```

- [ ] **Step 5: 实现 Transmission 的 `metainfo` 提交**

```dart
@override
Future<String> addTask(AddTaskRequest request) async {
  if (request.hasUrlSource) {
    return addDownload(request.url!, savePath: request.savePath);
  }

  final result = await _call('torrent_add', {
    'metainfo': base64Encode(request.torrentFileBytes!),
    if (request.savePath != null) 'download_dir': request.savePath,
  });

  if (result is Map) {
    return result['torrent_added']?['id']?.toString() ??
        result['torrent_duplicate']?['id']?.toString() ??
        '';
  }
  return '';
}
```

- [ ] **Step 6: 跑通 service 测试**

Run: `flutter test test/unit/downloader_services_add_task_test.dart`
Expected: PASS

- [ ] **Step 7: 提交本任务**

```bash
git add lib/services/aria2_service.dart lib/services/qbit_service.dart lib/services/transmission_service.dart test/unit/downloader_services_add_task_test.dart
git commit -m "feat: add torrent submission flow for downloader services"
```

---

### Task 4: 在 Controller 层接入统一提交入口

**Files:**
- Modify: `lib/features/downloaders/presentation/controllers/downloader_controller.dart`
- Create: `test/unit/downloader_controller_add_task_test.dart`
- Modify: `test/widget/test_helpers.dart`

- [ ] **Step 1: 先写 controller 行为测试**

```dart
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/models/add_task_request.dart';
import 'package:windwalker/features/downloaders/presentation/controllers/downloader_controller.dart';

void main() {
  test('addTask 在没有来源时应直接失败', () async {
    final controller = DownloaderController();

    final result = await controller.addTask(
      const AddTaskRequest(downloaderId: 'missing-source'),
    );

    expect(result, '');
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/unit/downloader_controller_add_task_test.dart`
Expected: FAIL，提示 `addTask` 未定义

- [ ] **Step 3: 增加统一 `addTask(...)` 并保留旧包装**

```dart
Future<String> addTask(AddTaskRequest request) async {
  if (!request.isValidSourceSelection) {
    Log.e('addTask: 非法来源组合, downloaderId=${request.downloaderId}');
    return '';
  }

  final downloader = getDownloader(request.downloaderId);
  if (downloader == null) {
    Log.e('addTask: 下载器不存在, id=${request.downloaderId}');
    return '';
  }

  final service = _createService(downloader);
  if (service == null) {
    Log.e('addTask: 无法创建服务, type=${downloader.type}');
    return '';
  }

  try {
    final result = await service.addTask(request);
    if (result.isEmpty) {
      Log.e('addTask: 失败, downloader=${downloader.name}');
    } else {
      Log.i('addTask: 成功, downloader=${downloader.name}, result=$result');
    }
    return result;
  } catch (e) {
    Log.e('addTask: 异常', error: e);
    return '';
  }
}

@override
Future<String> addDownload(
  String downloaderId,
  String url, {
  String? savePath,
}) {
  return addTask(
    AddTaskRequest(
      downloaderId: downloaderId,
      url: url,
      savePath: savePath,
    ),
  );
}
```

- [ ] **Step 4: 让测试辅助 controller 覆盖新入口**

```dart
class MockDownloaderController extends DownloaderController {
  AddTaskRequest? lastAddTaskRequest;

  @override
  Future<String> addTask(AddTaskRequest request) async {
    lastAddTaskRequest = request;
    return 'mock-task-id';
  }
}
```

- [ ] **Step 5: 运行 controller 相关测试**

Run: `flutter test test/unit/downloader_controller_add_task_test.dart test/widget/home_page_test.dart test/widget/settings_page_test.dart`
Expected: PASS

- [ ] **Step 6: 提交本任务**

```bash
git add lib/features/downloaders/presentation/controllers/downloader_controller.dart test/unit/downloader_controller_add_task_test.dart test/widget/test_helpers.dart
git commit -m "feat: add unified add task entrypoint in downloader controller"
```

---

### Task 5: 实现 Android 种子选择和页面提交流程

**Files:**
- Modify: `pubspec.yaml`
- Create: `lib/features/add_task/presentation/services/torrent_file_picker.dart`
- Modify: `lib/features/add_task/presentation/pages/add_task_page.dart`
- Create: `test/widget/add_task_page_test.dart`
- Modify: `test/widget/test_helpers.dart`

- [ ] **Step 1: 先加文件选择依赖**

```yaml
dependencies:
  file_picker: ^10.1.9
```

- [ ] **Step 2: 新建文件选择封装，避免页面直接依赖插件**

```dart
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

class PickedTorrentFile {
  final String fileName;
  final Uint8List bytes;

  const PickedTorrentFile({
    required this.fileName,
    required this.bytes,
  });
}

class TorrentFilePicker {
  const TorrentFilePicker();

  Future<PickedTorrentFile?> pick() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['torrent'],
      withData: true,
    );

    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null || bytes.isEmpty) {
      return null;
    }

    return PickedTorrentFile(fileName: file.name, bytes: bytes);
  }
}
```

- [ ] **Step 3: 先写 AddTaskPage widget 测试**

```dart
testWidgets('选择种子后展示文件名', (tester) async {
  final controller = MockDownloaderController();
  final picker = FakeTorrentFilePicker(
    result: PickedTorrentFile(
      fileName: 'ubuntu.torrent',
      bytes: Uint8List.fromList([1, 2, 3]),
    ),
  );

  await tester.pumpWidget(
    createAddTaskTestApp(
      downloaderController: controller,
      torrentFilePicker: picker,
    ),
  );

  await tester.tap(find.text('选择 torrent 文件'));
  await tester.pumpAndSettle();

  expect(find.text('ubuntu.torrent'), findsOneWidget);
});
```

- [ ] **Step 4: 运行 widget 测试确认失败**

Run: `flutter test test/widget/add_task_page_test.dart`
Expected: FAIL，提示 `TorrentFilePicker` / `createAddTaskTestApp` / 页面新状态未实现

- [ ] **Step 5: 给 AddTaskPage 增加可注入 picker 和统一提交逻辑**

```dart
class AddTaskPage extends StatefulWidget {
  final String? initialUrl;
  final TorrentFilePicker? torrentFilePicker;

  const AddTaskPage({
    super.key,
    this.initialUrl,
    this.torrentFilePicker,
  });
}
```

```dart
Uint8List? _torrentBytes;
String? _torrentFileName;

TorrentFilePicker get _torrentFilePicker =>
    widget.torrentFilePicker ?? const TorrentFilePicker();
```

```dart
Future<void> _pickTorrentFile() async {
  final picked = await _torrentFilePicker.pick();
  if (!mounted || picked == null) return;

  setState(() {
    _torrentBytes = picked.bytes;
    _torrentFileName = picked.fileName;
  });
}
```

```dart
Future<AddTaskRequest?> _resolveRequestBeforeSubmit() async {
  final baseRequest = AddTaskRequest(
    downloaderId: _selectedDownloaderId!,
    url: _urlController.text.trim().isEmpty ? null : _urlController.text.trim(),
    torrentFileBytes: _torrentBytes,
    torrentFileName: _torrentFileName,
    savePath: _savePathController.text.trim().isEmpty
        ? null
        : _savePathController.text.trim(),
  );

  if (!baseRequest.hasUrlSource && !baseRequest.hasTorrentSource) {
    _showMessage(l10n.enterLinkOrTorrentFile);
    return null;
  }

  if (baseRequest.hasUrlSource && baseRequest.hasTorrentSource) {
    final useTorrent = await _showSourceChoiceDialog();
    if (useTorrent == null) return null;
    return useTorrent
        ? baseRequest.copyWith(clearUrl: true)
        : baseRequest.copyWith(clearTorrent: true);
  }

  return baseRequest;
}
```

- [ ] **Step 6: 在页面中接入 controller 的 `addTask(...)`**

```dart
final request = await _resolveRequestBeforeSubmit();
if (request == null) return;

final result = await context.read<DownloaderController>().addTask(request);
```

- [ ] **Step 7: 完成页面 UI 展示与移除逻辑**

```dart
if (_torrentFileName != null) ...[
  const SizedBox(height: 12),
  Row(
    children: [
      Expanded(
        child: Text(
          _torrentFileName!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      TextButton(
        onPressed: () {
          setState(() {
            _torrentBytes = null;
            _torrentFileName = null;
          });
        },
        child: Text(l10n.remove),
      ),
    ],
  ),
]
```

- [ ] **Step 8: 补齐测试辅助与 widget 测试**

```dart
Widget createAddTaskTestApp({
  required DownloaderController downloaderController,
  required TorrentFilePicker torrentFilePicker,
}) {
  final router = GoRouter(
    initialLocation: '/add-task',
    routes: [
      GoRoute(
        path: '/add-task',
        builder: (context, state) => AddTaskPage(
          torrentFilePicker: torrentFilePicker,
        ),
      ),
    ],
  );

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<DownloaderController>.value(
        value: downloaderController,
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}
```

- [ ] **Step 9: 运行页面测试**

Run: `flutter test test/widget/add_task_page_test.dart`
Expected: PASS

- [ ] **Step 10: 提交本任务**

```bash
git add pubspec.yaml lib/features/add_task/presentation/services/torrent_file_picker.dart lib/features/add_task/presentation/pages/add_task_page.dart test/widget/add_task_page_test.dart test/widget/test_helpers.dart
git commit -m "feat: add android torrent picker flow to add task page"
```

---

### Task 6: 补文案、生成本地化代码并完成回归验证

**Files:**
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_ja.arb`
- Modify: `lib/l10n/app_localizations.dart`
- Modify: `lib/l10n/app_localizations_zh.dart`
- Modify: `lib/l10n/app_localizations_en.dart`
- Modify: `lib/l10n/app_localizations_ja.dart`

- [ ] **Step 1: 在 ARB 中增加缺失文案**

```json
{
  "enterLinkOrTorrentFile": "请输入下载链接或选择 torrent 文件",
  "torrentReadFailed": "种子文件读取失败，请重新选择",
  "chooseTaskSourceTitle": "选择提交来源",
  "chooseTaskSourceMessage": "当前同时存在链接和种子文件，请选择本次下载要使用的来源",
  "useLinkSource": "使用链接",
  "useTorrentSource": "使用种子文件",
  "selectedTorrentFile": "已选择：{fileName}"
}
```

```json
{
  "enterLinkOrTorrentFile": "Enter a download link or choose a torrent file",
  "torrentReadFailed": "Failed to read the torrent file. Please choose it again.",
  "chooseTaskSourceTitle": "Choose task source",
  "chooseTaskSourceMessage": "Both a link and a torrent file are present. Choose which one to use.",
  "useLinkSource": "Use link",
  "useTorrentSource": "Use torrent file",
  "selectedTorrentFile": "Selected: {fileName}"
}
```

- [ ] **Step 2: 生成本地化代码**

Run: `flutter gen-l10n`
Expected: PASS，并更新 `lib/l10n/app_localizations*.dart`

- [ ] **Step 3: 跑完整相关测试集**

Run: `flutter test test/unit/add_task_request_test.dart test/unit/downloader_services_add_task_test.dart test/unit/downloader_controller_add_task_test.dart test/widget/add_task_page_test.dart test/unit/models_test.dart test/widget/home_page_test.dart test/widget/settings_page_test.dart`
Expected: PASS

- [ ] **Step 4: 跑静态检查**

Run: `flutter analyze`
Expected: PASS，或仅剩与本功能无关的已有 warning

- [ ] **Step 5: 做一次 Android 手工验证**

Run: `flutter run`
Expected:
- 能进入 `/add-task`
- 选择 `.torrent` 后显示文件名
- 链接与种子同时存在时弹二选一对话框
- 三种下载器分别能走到对应提交流程

- [ ] **Step 6: 提交收尾改动**

```bash
git add lib/l10n/app_zh.arb lib/l10n/app_en.arb lib/l10n/app_ja.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_zh.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_ja.dart
git commit -m "feat: finalize torrent add task localization and tests"
```

---

## 自检

### Spec 覆盖检查

- Android-only 范围：Task 5 与 Task 6 覆盖
- 统一任务载荷：Task 1 与 Task 4 覆盖
- 三种下载器种子提交流程：Task 3 覆盖
- 链接 / 种子冲突二选一：Task 5 覆盖
- 保存路径兼容：Task 3 与 Task 5 覆盖
- 错误提示与多语言：Task 5 与 Task 6 覆盖
- 单测 / widget test：Task 1、Task 3、Task 4、Task 5、Task 6 覆盖

### 占位符检查

- 计划中没有 `TODO`、`TBD`、`implement later` 之类占位项。
- 每个改动任务都给出了目标文件、命令和最小代码示例。

### 类型一致性检查

- 统一使用 `AddTaskRequest`
- 统一入口名称为 `addTask(...)`
- 页面状态统一使用 `_torrentBytes` / `_torrentFileName`
- 冲突清理统一使用 `copyWith(clearUrl: true)` 和 `copyWith(clearTorrent: true)`
