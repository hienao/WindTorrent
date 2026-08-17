# Google Drive 下载器备份 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在设置页增加“备份到 Google Drive / 从 Google Drive 恢复”能力，支持完整下载器配置备份、云端仅保留最近 2 个版本、恢复前自动本地回滚快照，以及一次撤销恢复。

**Architecture:** 新增 `google_drive_backup_api.dart` 负责 Google Drive `appDataFolder` 授权与文件操作，新增 `downloader_backup_service.dart` 负责编排备份 JSON、两版本轮换、导入恢复和回滚快照，新增 `SettingsBackupController` 管理设置页备份状态。`DownloaderController` 继续作为下载器配置唯一写入口，新增原子全量替换和回滚快照入口，设置页通过 Provider 挂载新的控制器并暴露备份/恢复交互。

**Tech Stack:** Flutter 3.24.5、Provider、GetStorage、google_sign_in ^7.2.0、http ^1.1.0、Firebase Analytics、Flutter widget/unit tests

**Spec:** `/Volumes/Data/Code/GitHub/WindWalker/docs/superpowers/specs/2026-06-27-google-drive-downloader-backup-design.md`

---

## 文件结构总览

**新建文件：**
- `lib/features/settings/presentation/controllers/settings_backup_controller.dart` — 设置页备份状态与交互控制器
- `lib/models/downloader_backup_bundle.dart` — 备份 JSON 顶层模型
- `lib/models/downloader_backup_version.dart` — 云端备份版本摘要模型
- `lib/services/drive_auth_exception.dart` — Drive 授权 / API 异常定义
- `lib/services/google_drive_backup_api.dart` — `appDataFolder` 授权、列版本、上传、下载、删除
- `lib/services/downloader_backup_service.dart` — 备份业务编排、回滚快照、恢复执行
- `test/unit/models/downloader_backup_bundle_test.dart`
- `test/unit/services/google_drive_backup_api_test.dart`
- `test/unit/services/downloader_backup_service_test.dart`
- `test/unit/features/settings/settings_backup_controller_test.dart`

**修改文件：**
- `lib/app.dart` — 注册 `SettingsBackupController`
- `lib/features/settings/presentation/pages/settings_page.dart` — 增加“备份与恢复”分组、导出/恢复/撤销入口
- `lib/features/downloaders/presentation/controllers/downloader_controller.dart` — 增加导出源数据、原子全量替换、回滚快照入口
- `lib/features/auth/presentation/controllers/auth_controller.dart` — 暴露当前登录用户上下文给备份控制器使用（只读）
- `lib/services/firebase_auth_provider.dart` — 暴露按需追加 Drive scope 所需的授权能力
- `lib/services/auth_provider.dart` — 扩展认证抽象接口
- `lib/l10n/app_en.arb`
- `lib/l10n/app_zh.arb`
- `lib/l10n/app_ja.arb`
- `lib/l10n/app_localizations.dart`
- `lib/l10n/app_localizations_en.dart`
- `lib/l10n/app_localizations_zh.dart`
- `lib/l10n/app_localizations_ja.dart`
- `test/widget/settings_page_test.dart` — 覆盖新备份 UI
- `test/widget/test_helpers.dart` — 挂载 `SettingsBackupController` 测试桩

**实现约束：**
- 备份文件必须包含敏感凭据字段，但这些字段绝不能进入日志或埋点。
- 导入失败时不得破坏当前下载器配置。
- 所有关键失败路径都要 fail-fast，并进入明确 UI 错误态。
- 每个任务完成后都运行对应最小测试集，再提交。

---

### Task 1: 备份模型与 JSON 契约

**Files:**
- Create: `lib/models/downloader_backup_bundle.dart`
- Create: `lib/models/downloader_backup_version.dart`
- Test: `test/unit/models/downloader_backup_bundle_test.dart`

- [ ] **Step 1: 写失败测试，固定备份 JSON 契约**

```dart
// test/unit/models/downloader_backup_bundle_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/constants/app_constants.dart';
import 'package:windwalker/models/downloader.dart';
import 'package:windwalker/models/downloader_backup_bundle.dart';

void main() {
  group('DownloaderBackupBundle', () {
    final downloader = Downloader(
      id: 'd1',
      name: 'Home qBit',
      type: DownloaderType.qbittorrent,
      host: '192.168.1.3',
      port: 8080,
      username: 'admin',
      password: '123456',
      useHttps: false,
      version: '4.6.5',
    );

    test('toJson only persists connection fields', () {
      final bundle = DownloaderBackupBundle(
        schemaVersion: 1,
        backupId: '20260627T143015Z_abcde',
        createdAt: DateTime.parse('2026-06-27T14:30:15Z'),
        appVersion: '1.1.1+2026062702',
        userUid: 'uid-1',
        downloaders: [downloader],
      );

      final json = bundle.toJson();
      expect(json['schemaVersion'], 1);
      expect((json['downloaders'] as List).single['host'], '192.168.1.3');
      expect((json['downloaders'] as List).single.containsKey('status'), isFalse);
      expect((json['downloaders'] as List).single.containsKey('taskCount'), isFalse);
    });

    test('fromJson restores full downloader credentials', () {
      final bundle = DownloaderBackupBundle.fromJson({
        'schemaVersion': 1,
        'backupId': '20260627T143015Z_abcde',
        'createdAt': '2026-06-27T14:30:15Z',
        'appVersion': '1.1.1+2026062702',
        'user': {'uid': 'uid-1'},
        'downloaders': [
          {
            'id': 'd1',
            'name': 'Home qBit',
            'type': 'qbittorrent',
            'host': '192.168.1.3',
            'port': 8080,
            'username': 'admin',
            'password': '123456',
            'useHttps': false,
            'version': '4.6.5',
          },
        ],
      });

      expect(bundle.userUid, 'uid-1');
      expect(bundle.downloaders.single.password, '123456');
      expect(bundle.downloaders.single.type, DownloaderType.qbittorrent);
    });

    test('throws on unsupported schemaVersion', () {
      expect(
        () => DownloaderBackupBundle.fromJson({
          'schemaVersion': 2,
          'backupId': 'b1',
          'createdAt': '2026-06-27T14:30:15Z',
          'appVersion': '1.0.0',
          'user': {'uid': 'u1'},
          'downloaders': const [],
        }),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/unit/models/downloader_backup_bundle_test.dart`
Expected: FAIL，提示 `DownloaderBackupBundle` / `DownloaderBackupVersion` 未定义。

- [ ] **Step 3: 写最小模型实现**

```dart
// lib/models/downloader_backup_bundle.dart
import 'package:windwalker/models/downloader.dart';

class DownloaderBackupBundle {
  const DownloaderBackupBundle({
    required this.schemaVersion,
    required this.backupId,
    required this.createdAt,
    required this.appVersion,
    required this.userUid,
    required this.downloaders,
  });

  final int schemaVersion;
  final String backupId;
  final DateTime createdAt;
  final String appVersion;
  final String userUid;
  final List<Downloader> downloaders;

  static const supportedSchemaVersion = 1;

  factory DownloaderBackupBundle.fromJson(Map<String, dynamic> json) {
    final schemaVersion = json['schemaVersion'] as int;
    if (schemaVersion != supportedSchemaVersion) {
      throw FormatException('Unsupported schemaVersion: $schemaVersion');
    }

    return DownloaderBackupBundle(
      schemaVersion: schemaVersion,
      backupId: json['backupId'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      appVersion: json['appVersion'] as String,
      userUid: (json['user'] as Map<String, dynamic>)['uid'] as String,
      downloaders: (json['downloaders'] as List<dynamic>)
          .map((e) => Downloader.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'schemaVersion': schemaVersion,
        'backupId': backupId,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'appVersion': appVersion,
        'user': {'uid': userUid},
        'downloaders': downloaders.map((d) => d.toJson()).toList(),
      };
}
```

```dart
// lib/models/downloader_backup_version.dart
class DownloaderBackupVersion {
  const DownloaderBackupVersion({
    required this.fileId,
    required this.fileName,
    required this.backupId,
    required this.createdAt,
    required this.appVersion,
    required this.downloaderCount,
    required this.isLatest,
  });

  final String fileId;
  final String fileName;
  final String backupId;
  final DateTime createdAt;
  final String appVersion;
  final int downloaderCount;
  final bool isLatest;
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/unit/models/downloader_backup_bundle_test.dart`
Expected: PASS（3 tests）。

- [ ] **Step 5: 提交**

```bash
git add lib/models/downloader_backup_bundle.dart lib/models/downloader_backup_version.dart test/unit/models/downloader_backup_bundle_test.dart
git commit -m "feat(backup): add downloader backup bundle models"
```

---

### Task 2: 扩展 Google 登录授权抽象，支持 Drive scope

**Files:**
- Modify: `lib/services/auth_provider.dart`
- Modify: `lib/services/firebase_auth_provider.dart`
- Test: `test/unit/auth_controller_test.dart`

- [ ] **Step 1: 先补失败测试，锁定 Drive 授权抽象**

```dart
// test/unit/auth_controller_test.dart
test('AuthProvider exposes drive authorization hook', () async {
  final provider = _FakeDriveCapableAuthProvider();

  await provider.authorizeScopes(const ['https://www.googleapis.com/auth/drive.appdata']);

  expect(provider.lastAuthorizedScopes, contains('https://www.googleapis.com/auth/drive.appdata'));
});
```

```dart
class _FakeDriveCapableAuthProvider implements AuthProvider {
  List<String> lastAuthorizedScopes = const [];

  @override
  Future<void> authorizeScopes(List<String> scopes) async {
    lastAuthorizedScopes = List<String>.from(scopes);
  }

  @override
  Future<Map<String, String>> authorizationHeaders(List<String> scopes) async {
    lastAuthorizedScopes = List<String>.from(scopes);
    return {'Authorization': 'Bearer test-token'};
  }

  @override
  Stream<AuthUser?> authStateChanges() => const Stream.empty();
  @override
  Future<AuthUser?> getCurrentUser() async => null;
  @override
  Future<AuthUser> signInWithGoogle() async => throw UnimplementedError();
  @override
  Future<void> signOut() async {}
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/unit/auth_controller_test.dart`
Expected: FAIL，`authorizeScopes` / `authorizationHeaders` 未定义。

- [ ] **Step 3: 扩展认证接口与 FirebaseAuthProvider**

```dart
// lib/services/auth_provider.dart
abstract class AuthProvider {
  Stream<AuthUser?> authStateChanges();
  Future<AuthUser> signInWithGoogle();
  Future<void> signOut();
  Future<AuthUser?> getCurrentUser();

  Future<void> authorizeScopes(List<String> scopes);
  Future<Map<String, String>> authorizationHeaders(List<String> scopes);
}
```

```dart
// lib/services/firebase_auth_provider.dart
@override
Future<void> authorizeScopes(List<String> scopes) async {
  await _ensureInitialized();
  final user = _googleSignIn.currentUser ?? await _googleSignIn.authenticate();
  await user.authorizationClient.authorizationForScopes(scopes);
}

@override
Future<Map<String, String>> authorizationHeaders(List<String> scopes) async {
  await _ensureInitialized();
  final user = _googleSignIn.currentUser ?? await _googleSignIn.authenticate();
  final authorization = await user.authorizationClient.authorizationForScopes(scopes);
  if (authorization == null) {
    throw const app_auth.AuthFlowFailedException(
      reason: app_auth.AuthFailureReason.googleSignInError,
      providerCode: 'drive_scope_denied',
    );
  }
  return authorization.authHeaders;
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `flutter test test/unit/auth_controller_test.dart`
Expected: PASS，且原有 auth 测试无回归。

- [ ] **Step 5: 提交**

```bash
git add lib/services/auth_provider.dart lib/services/firebase_auth_provider.dart test/unit/auth_controller_test.dart
git commit -m "feat(auth): add Drive scope authorization hooks"
```

---

### Task 3: Drive API 层与两版本轮换

**Files:**
- Create: `lib/services/drive_auth_exception.dart`
- Create: `lib/services/google_drive_backup_api.dart`
- Test: `test/unit/services/google_drive_backup_api_test.dart`

- [ ] **Step 1: 写失败测试，固定 API 层输入输出**

```dart
// test/unit/services/google_drive_backup_api_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/models/downloader_backup_version.dart';
import 'package:windwalker/services/google_drive_backup_api.dart';

void main() {
  group('GoogleDriveBackupApi', () {
    test('buildBackupFileName is sortable', () {
      final name = GoogleDriveBackupApi.buildBackupFileName(
        DateTime.parse('2026-06-27T14:30:15Z'),
      );
      expect(name, 'windwalker_downloaders_backup_2026-06-27T14-30-15Z.json');
    });

    test('pickFilesToDelete keeps only newest one before upload', () {
      final versions = [
        DownloaderBackupVersion(
          fileId: '1',
          fileName: 'a.json',
          backupId: 'b1',
          createdAt: DateTime.parse('2026-06-25T00:00:00Z'),
          appVersion: '1.0.0',
          downloaderCount: 1,
          isLatest: false,
        ),
        DownloaderBackupVersion(
          fileId: '2',
          fileName: 'b.json',
          backupId: 'b2',
          createdAt: DateTime.parse('2026-06-26T00:00:00Z'),
          appVersion: '1.0.0',
          downloaderCount: 1,
          isLatest: false,
        ),
      ];

      final deletions = GoogleDriveBackupApi.pickFilesToDeleteBeforeUpload(versions);
      expect(deletions.map((e) => e.fileId), ['1']);
    });
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/unit/services/google_drive_backup_api_test.dart`
Expected: FAIL，`GoogleDriveBackupApi` 未定义。

- [ ] **Step 3: 增加 Drive API 最小实现**

```dart
// lib/services/drive_auth_exception.dart
class DriveAuthException implements Exception {
  const DriveAuthException(this.code, this.message);

  final String code;
  final String message;
}
```

```dart
// lib/services/google_drive_backup_api.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:windwalker/models/downloader_backup_version.dart';
import 'package:windwalker/services/auth_provider.dart';
import 'package:windwalker/services/drive_auth_exception.dart';

class GoogleDriveBackupApi {
  GoogleDriveBackupApi({
    required AuthProvider authProvider,
    required http.Client httpClient,
  })  : _authProvider = authProvider,
        _httpClient = httpClient;

  static const driveAppDataScope =
      'https://www.googleapis.com/auth/drive.appdata';
  static const _folderSpace = 'appDataFolder';
  static const _filePrefix = 'windwalker_downloaders_backup_';

  final AuthProvider _authProvider;
  final http.Client _httpClient;

  static String buildBackupFileName(DateTime createdAtUtc) {
    final iso = createdAtUtc.toUtc().toIso8601String().replaceAll(':', '-');
    return 'windwalker_downloaders_backup_${iso.replaceAll('.000', '')}.json';
  }

  static List<DownloaderBackupVersion> pickFilesToDeleteBeforeUpload(
    List<DownloaderBackupVersion> versions,
  ) {
    final sorted = List<DownloaderBackupVersion>.from(versions)
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (sorted.length < 2) return const [];
    return sorted.take(sorted.length - 1).toList();
  }

  Future<void> ensureAuthorized() async {
    await _authProvider.authorizeScopes(const [driveAppDataScope]);
  }

  Future<Map<String, String>> _headers() {
    return _authProvider.authorizationHeaders(const [driveAppDataScope]);
  }

  Future<List<DownloaderBackupVersion>> listVersions() async {
    final headers = await _headers();
    final uri = Uri.parse(
      'https://www.googleapis.com/drive/v3/files'
      '?spaces=$_folderSpace'
      '&fields=files(id,name,createdTime,description,appProperties)'
      '&q=name contains \'$_filePrefix\'',
    );
    final response = await _httpClient.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw DriveAuthException('drive_list_failed', response.body);
    }
    return _parseVersions(response.body);
  }

  Future<void> uploadBackup(DownloaderBackupBundle bundle) async {
    final headers = await _headers();
    final request = http.MultipartRequest(
      'POST',
      Uri.parse('https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart'),
    )
      ..headers.addAll(headers)
      ..fields['metadata'] = jsonEncode({
        'name': buildBackupFileName(bundle.createdAt),
        'parents': ['appDataFolder'],
        'appProperties': {
          'backupId': bundle.backupId,
          'appVersion': bundle.appVersion,
          'downloaderCount': bundle.downloaders.length.toString(),
        },
      })
      ..files.add(
        http.MultipartFile.fromString(
          'file',
          jsonEncode(bundle.toJson()),
          filename: buildBackupFileName(bundle.createdAt),
        ),
      );
    final streamed = await request.send();
    if (streamed.statusCode >= 300) {
      throw DriveAuthException('drive_upload_failed', streamed.reasonPhrase ?? '');
    }
  }

  Future<List<int>> downloadBackup(String fileId) async {
    final headers = await _headers();
    final uri = Uri.parse(
      'https://www.googleapis.com/drive/v3/files/$fileId?alt=media',
    );
    final response = await _httpClient.get(uri, headers: headers);
    if (response.statusCode != 200) {
      throw DriveAuthException('drive_download_failed', response.body);
    }
    return response.bodyBytes;
  }

  Future<void> deleteFile(String fileId) async {
    final headers = await _headers();
    final uri = Uri.parse('https://www.googleapis.com/drive/v3/files/$fileId');
    final response = await _httpClient.delete(uri, headers: headers);
    if (response.statusCode >= 300) {
      throw DriveAuthException('drive_delete_failed', response.body);
    }
  }
}
```

- [ ] **Step 4: 再补 list/upload/download/delete 的测试骨架并实现**

```dart
test('downloadBackup returns raw bytes', () async {
  final api = GoogleDriveBackupApi(
    authProvider: _FakeAuthProvider(),
    httpClient: MockClient((request) async {
      return http.Response.bytes(utf8.encode('{"ok":true}'), 200);
    }),
  );

  final bytes = await api.downloadBackup('file-1');
  expect(utf8.decode(bytes), '{"ok":true}');
});
```

Run: `flutter test test/unit/services/google_drive_backup_api_test.dart`
Expected: PASS，覆盖文件名、删除策略、下载、列表解析。

- [ ] **Step 5: 提交**

```bash
git add lib/services/drive_auth_exception.dart lib/services/google_drive_backup_api.dart test/unit/services/google_drive_backup_api_test.dart
git commit -m "feat(backup): add Google Drive backup API"
```

---

### Task 4: 备份服务与 DownloaderController 原子替换

**Files:**
- Create: `lib/services/downloader_backup_service.dart`
- Modify: `lib/features/downloaders/presentation/controllers/downloader_controller.dart`
- Test: `test/unit/services/downloader_backup_service_test.dart`
- Test: `test/unit/downloader_controller_gate_test.dart`

- [ ] **Step 1: 先写失败测试，锁定回滚与全量替换行为**

```dart
// test/unit/services/downloader_backup_service_test.dart
test('importBackup replaces all downloaders through controller', () async {
  final controller = _FakeDownloaderController([
    _buildDownloader(id: 'old'),
  ]);
  final service = _buildService(
    controller: controller,
    downloadedJson: {
      'schemaVersion': 1,
      'backupId': 'backup-1',
      'createdAt': '2026-06-27T14:30:15Z',
      'appVersion': '1.1.1+2026062702',
      'user': {'uid': 'uid-1'},
      'downloaders': [
        _buildDownloader(id: 'new').toJson(),
      ],
    },
  );

  await service.restoreBackup(fileId: 'file-1');

  expect(controller.downloaders.single.id, 'new');
  expect(controller.lastSnapshotBackupId, 'backup-1');
});

test('restore rollback snapshot recovers previous downloaders', () async {
  final controller = _FakeDownloaderController([_buildDownloader(id: 'before')]);
  controller.seedRollbackSnapshot(
    sourceBackupId: 'backup-1',
    downloaders: [_buildDownloader(id: 'before')],
  );

  await controller.restoreRollbackSnapshot();

  expect(controller.downloaders.single.id, 'before');
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/unit/services/downloader_backup_service_test.dart`
Expected: FAIL，`DownloaderBackupService` / `replaceAllDownloadersFromBackup` 未定义。

- [ ] **Step 3: 给 DownloaderController 加原子导出/替换/快照接口**

```dart
// lib/features/downloaders/presentation/controllers/downloader_controller.dart
List<Map<String, dynamic>> exportDownloadersForBackup() {
  return _downloaders.map((e) => e.toJson()).toList(growable: false);
}

Future<void> replaceAllDownloadersFromBackup({
  required List<Downloader> downloaders,
  required String sourceBackupId,
}) async {
  await saveRollbackSnapshot(sourceBackupId: sourceBackupId);
  _downloaders = List<Downloader>.from(downloaders);
  await _saveDownloaders();
  _notifySafely();
}

Future<void> saveRollbackSnapshot({required String sourceBackupId}) async {
  await _storage.write('downloaders_import_rollback_snapshot', {
    'sourceBackupId': sourceBackupId,
    'createdAt': DateTime.now().toUtc().toIso8601String(),
    'downloaders': _downloaders.map((e) => e.toJson()).toList(),
  });
}

Future<bool> restoreRollbackSnapshot() async {
  final json = _storage.read<Map>('downloaders_import_rollback_snapshot');
  if (json == null) return false;
  _downloaders = (json['downloaders'] as List<dynamic>)
      .map((e) => Downloader.fromJson(Map<String, dynamic>.from(e as Map)))
      .toList();
  await _saveDownloaders();
  _notifySafely();
  return true;
}
```

- [ ] **Step 4: 实现 DownloaderBackupService**

```dart
// lib/services/downloader_backup_service.dart
class DownloaderBackupService {
  DownloaderBackupService({
    required GoogleDriveBackupApi driveApi,
    required DownloaderController downloaderController,
    required AppUser Function() currentUser,
    required String Function() currentAppVersion,
  })  : _driveApi = driveApi,
        _downloaderController = downloaderController,
        _currentUser = currentUser,
        _currentAppVersion = currentAppVersion;

  Future<void> exportBackup() async {
    final now = DateTime.now().toUtc();
    final bundle = DownloaderBackupBundle(
      schemaVersion: DownloaderBackupBundle.supportedSchemaVersion,
      backupId: _buildBackupId(now),
      createdAt: now,
      appVersion: _currentAppVersion(),
      userUid: _currentUser().uid,
      downloaders: _downloaderController.downloaders,
    );

    final versions = await _driveApi.listVersions();
    for (final version in GoogleDriveBackupApi.pickFilesToDeleteBeforeUpload(versions)) {
      await _driveApi.deleteFile(version.fileId);
    }
    await _driveApi.uploadBackup(bundle);
  }

  Future<void> restoreBackup({required String fileId}) async {
    final bytes = await _driveApi.downloadBackup(fileId);
    final bundle = DownloaderBackupBundle.fromJson(
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
    );
    await _downloaderController.replaceAllDownloadersFromBackup(
      downloaders: bundle.downloaders,
      sourceBackupId: bundle.backupId,
    );
  }
}
```

- [ ] **Step 5: 运行测试确认通过**

Run:
- `flutter test test/unit/services/downloader_backup_service_test.dart`
- `flutter test test/unit/downloader_controller_gate_test.dart`

Expected: PASS，覆盖导出、恢复、回滚快照和全量替换。

- [ ] **Step 6: 提交**

```bash
git add lib/services/downloader_backup_service.dart lib/features/downloaders/presentation/controllers/downloader_controller.dart test/unit/services/downloader_backup_service_test.dart test/unit/downloader_controller_gate_test.dart
git commit -m "feat(backup): add restore service and atomic downloader replacement"
```

---

### Task 5: SettingsBackupController 与 Provider 挂载

**Files:**
- Create: `lib/features/settings/presentation/controllers/settings_backup_controller.dart`
- Modify: `lib/app.dart`
- Modify: `test/widget/test_helpers.dart`
- Test: `test/unit/features/settings/settings_backup_controller_test.dart`

- [ ] **Step 1: 写失败测试，固定控制器状态机**

```dart
// test/unit/features/settings/settings_backup_controller_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/features/settings/presentation/controllers/settings_backup_controller.dart';

void main() {
  test('exportBackup toggles isExporting and clears error on success', () async {
    final controller = SettingsBackupController(
      backupService: _FakeBackupService(),
      authController: _FakeSignedInAuthController(),
    );

    expect(controller.isExporting, isFalse);
    await controller.exportBackup();
    expect(controller.isExporting, isFalse);
    expect(controller.errorMessage, isNull);
    expect(controller.lastOperationSummary, contains('Google Drive'));
  });

  test('restoreBackup surfaces failure message', () async {
    final controller = SettingsBackupController(
      backupService: _ThrowingBackupService(),
      authController: _FakeSignedInAuthController(),
    );

    await controller.restoreBackup(fileId: 'file-1');

    expect(controller.errorMessage, isNotNull);
    expect(controller.isImporting, isFalse);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/unit/features/settings/settings_backup_controller_test.dart`
Expected: FAIL，`SettingsBackupController` 未定义。

- [ ] **Step 3: 实现控制器并挂到 app Provider**

```dart
// lib/features/settings/presentation/controllers/settings_backup_controller.dart
class SettingsBackupController extends ChangeNotifier {
  SettingsBackupController({
    required DownloaderBackupService backupService,
    required AuthController authController,
  })  : _backupService = backupService,
        _authController = authController;

  bool _isExporting = false;
  bool _isImporting = false;
  bool _isLoadingVersions = false;
  String? _errorMessage;
  String? _lastOperationSummary;
  List<DownloaderBackupVersion> _availableBackups = const [];

  bool get isExporting => _isExporting;
  bool get isImporting => _isImporting;
  bool get isLoadingVersions => _isLoadingVersions;
  String? get errorMessage => _errorMessage;
  String? get lastOperationSummary => _lastOperationSummary;
  List<DownloaderBackupVersion> get availableBackups => _availableBackups;
  bool get isSignedIn => _authController.isAuthenticated;

  Future<void> exportBackup() async { /* set state -> call service -> notify */ }
  Future<void> loadAvailableBackups() async { /* set state -> call service */ }
  Future<void> restoreBackup({required String fileId}) async { /* set state */ }
  Future<void> undoLastRestore() async { /* set state */ }
}
```

```dart
// lib/app.dart
ChangeNotifierProxyProvider2<AuthController, DownloaderController, SettingsBackupController>(
  create: (_) => SettingsBackupController(
    backupService: DownloaderBackupService(
      driveApi: GoogleDriveBackupApi(
        authProvider: context.read<AuthController>().authProvider,
        httpClient: http.Client(),
      ),
      downloaderController: context.read<DownloaderController>(),
      currentUser: () => context.read<AuthController>().user!,
      currentAppVersion: () => AppConstants.appVersion,
    ),
    authController: context.read<AuthController>(),
  ),
  update: (_, auth, downloaderController, previous) {
    return previous?..attach(authController: auth, downloaderController: downloaderController)
        ?? SettingsBackupController.build(auth, downloaderController);
  },
),
```

- [ ] **Step 4: 更新测试辅助挂载**

```dart
// test/widget/test_helpers.dart
SettingsBackupController? settingsBackupController,
...
ChangeNotifierProvider<SettingsBackupController>.value(
  value: settingsBackupController ?? FakeSettingsBackupController(),
),
```

- [ ] **Step 5: 运行测试确认通过**

Run:
- `flutter test test/unit/features/settings/settings_backup_controller_test.dart`
- `flutter test test/widget/settings_page_test.dart`

Expected: PASS，控制器状态机稳定，现有 settings widget 无 Provider 缺失错误。

- [ ] **Step 6: 提交**

```bash
git add lib/app.dart lib/features/settings/presentation/controllers/settings_backup_controller.dart test/widget/test_helpers.dart test/unit/features/settings/settings_backup_controller_test.dart
git commit -m "feat(settings): add backup controller provider"
```

---

### Task 6: 设置页 UI、文案、本地化与恢复交互

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_ja.arb`
- Modify: `lib/l10n/app_localizations*.dart`
- Modify: `test/widget/settings_page_test.dart`

- [ ] **Step 1: 写失败 widget 测试，锁定 UI**

```dart
// test/widget/settings_page_test.dart
testWidgets('shows backup and restore rows for signed-in user', (tester) async {
  await tester.pumpWidget(
    createTestApp(
      downloaderController: MockDownloaderController(),
      settingsController: SettingsController(),
      settingsBackupController: FakeSettingsBackupController.signedIn(),
      initialLocation: '/settings',
    ),
  );
  await tester.pumpAndSettle();

  expect(find.text('Backup & Restore'), findsOneWidget);
  expect(find.text('Back up to Google Drive'), findsOneWidget);
  expect(find.text('Restore from Google Drive'), findsOneWidget);
});

testWidgets('restore row opens confirmation dialog', (tester) async {
  final controller = FakeSettingsBackupController.signedIn()
    ..seedAvailableBackups([
      FakeBackupVersion.latest(),
    ]);

  await tester.pumpWidget(
    createTestApp(
      downloaderController: MockDownloaderController(),
      settingsController: SettingsController(),
      settingsBackupController: controller,
      initialLocation: '/settings',
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Restore from Google Drive'));
  await tester.pumpAndSettle();

  expect(find.text('Confirm restore and replace'), findsOneWidget);
});
```

- [ ] **Step 2: 运行测试确认失败**

Run: `flutter test test/widget/settings_page_test.dart`
Expected: FAIL，新增文案或交互不存在。

- [ ] **Step 3: 增加文案与设置页分组**

```json
// lib/l10n/app_en.arb
"backupRestore": "Backup & Restore",
"backupToGoogleDrive": "Back up to Google Drive",
"restoreFromGoogleDrive": "Restore from Google Drive",
"signInToUseBackup": "Sign in with Google to use backup",
"backupIncludesCredentials": "Includes downloader addresses and credentials",
"confirmRestoreAndReplace": "Confirm restore and replace",
"restoreWillReplaceAllDownloaders": "This will replace all current downloader configurations.",
"restoreCreatesRollbackSnapshot": "A local rollback snapshot will be created before restore.",
"undoLastRestore": "Undo last restore"
```

```dart
// lib/features/settings/presentation/pages/settings_page.dart
Consumer3<SettingsController, AuthController, SettingsBackupController>(
  builder: (context, settings, auth, backup, _) {
    ...
    NeoSettingRow(
      icon: Icons.cloud_upload_outlined,
      title: l10n.backupToGoogleDrive,
      subtitle: auth.isAuthenticated
          ? l10n.backupIncludesCredentials
          : l10n.signInToUseBackup,
      onTap: auth.isAuthenticated && !backup.isExporting
          ? () => backup.exportBackup()
          : null,
    ),
    NeoSettingRow(
      icon: Icons.cloud_download_outlined,
      title: l10n.restoreFromGoogleDrive,
      subtitle: auth.isAuthenticated
          ? backup.lastOperationSummary ?? l10n.restoreCreatesRollbackSnapshot
          : l10n.signInToUseBackup,
      onTap: auth.isAuthenticated && !backup.isImporting
          ? () => _showRestoreVersionsSheet(context, backup)
          : null,
    ),
```

- [ ] **Step 4: 实现版本列表与恢复确认**

```dart
Future<void> _showRestoreVersionsSheet(
  BuildContext context,
  SettingsBackupController backup,
) async {
  await backup.loadAvailableBackups();
  if (!context.mounted) return;

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) => NeoCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final version in backup.availableBackups)
            NeoSettingRow(
              icon: version.isLatest
                  ? Icons.history_toggle_off_rounded
                  : Icons.history_rounded,
              title: _formatBackupTime(ctx, version.createdAt),
              subtitle: '${version.appVersion} · ${version.downloaderCount}',
              onTap: () async {
                Navigator.pop(ctx);
                final confirmed = await _confirmRestore(context);
                if (confirmed == true) {
                  await backup.restoreBackup(fileId: version.fileId);
                }
              },
            ),
        ],
      ),
    ),
  );
}
```

- [ ] **Step 5: 生成本地化文件并跑 widget 测试**

Run:
- `flutter gen-l10n`
- `flutter test test/widget/settings_page_test.dart`

Expected: PASS，新增 2-4 个 settings rows，恢复确认弹窗可见。

- [ ] **Step 6: 提交**

```bash
git add lib/features/settings/presentation/pages/settings_page.dart lib/l10n/app_en.arb lib/l10n/app_zh.arb lib/l10n/app_ja.arb lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_zh.dart lib/l10n/app_localizations_ja.dart test/widget/settings_page_test.dart
git commit -m "feat(settings): add Google Drive backup and restore UI"
```

---

### Task 7: 埋点、日志护栏与收尾验证

**Files:**
- Modify: `lib/services/downloader_backup_service.dart`
- Modify: `lib/features/settings/presentation/controllers/settings_backup_controller.dart`
- Reuse: `lib/core/utils/log.dart`（仅复用现有安全日志能力，不新增敏感日志）
- Test: `test/unit/services/downloader_backup_service_test.dart`
- Test: `test/unit/features/settings/settings_backup_controller_test.dart`

- [ ] **Step 1: 为导出/恢复/回滚补失败测试**

```dart
test('exportBackup tracks success without sensitive params', () async {
  final analytics = FakeAnalyticsService();
  final service = _buildService(analytics: analytics);

  await service.exportBackup();

  expect(analytics.lastEventName, 'downloader_backup_export_result');
  expect(analytics.lastParams.containsKey('host'), isFalse);
  expect(analytics.lastParams.containsKey('password'), isFalse);
});

test('restore failure sets errorMessage and leaves current list untouched', () async {
  final controller = _FakeDownloaderController([_buildDownloader(id: 'old')]);
  final backup = _buildController(service: _ThrowingBackupService(), downloaderController: controller);

  await backup.restoreBackup(fileId: 'file-1');

  expect(controller.downloaders.single.id, 'old');
  expect(backup.errorMessage, isNotNull);
});
```

- [ ] **Step 2: 运行测试确认失败**

Run:
- `flutter test test/unit/services/downloader_backup_service_test.dart`
- `flutter test test/unit/features/settings/settings_backup_controller_test.dart`

Expected: FAIL，埋点或错误态断言未满足。

- [ ] **Step 3: 补埋点与安全日志**

```dart
// lib/services/downloader_backup_service.dart
await AnalyticsService.instance.track(
  'downloader_backup_export_result',
  params: <String, Object>{
    'result': 'success',
    'downloader_count': bundle.downloaders.length,
    'cloud_version_count_before': versions.length,
    'cloud_version_count_after': versions.length >= 2 ? 2 : versions.length + 1,
  },
);

Log.i(
  'Drive backup uploaded: backupId=${bundle.backupId}, downloaderCount=${bundle.downloaders.length}',
);
```

```dart
// lib/features/settings/presentation/controllers/settings_backup_controller.dart
try {
  _errorMessage = null;
  _isImporting = true;
  notifyListeners();
  await _backupService.restoreBackup(fileId: fileId);
  _lastOperationSummary = 'Restored from Google Drive just now';
} catch (e) {
  _errorMessage = 'Restore failed. Please try again.';
} finally {
  _isImporting = false;
  notifyListeners();
}
```

- [ ] **Step 4: 跑最小回归集**

Run:
- `flutter test test/unit/models/downloader_backup_bundle_test.dart`
- `flutter test test/unit/services/google_drive_backup_api_test.dart`
- `flutter test test/unit/services/downloader_backup_service_test.dart`
- `flutter test test/unit/features/settings/settings_backup_controller_test.dart`
- `flutter test test/widget/settings_page_test.dart`

Expected: PASS，且无敏感字段进入埋点参数。

- [ ] **Step 5: 提交**

```bash
git add lib/services/downloader_backup_service.dart lib/features/settings/presentation/controllers/settings_backup_controller.dart test/unit/services/downloader_backup_service_test.dart test/unit/features/settings/settings_backup_controller_test.dart
git commit -m "feat(backup): add analytics and harden restore flows"
```

---

## 自检清单

- Spec coverage:
  - `appDataFolder` 存储与最小 Drive 权限：Task 2, Task 3
  - 两版本保留：Task 3
  - 完整凭据备份 JSON：Task 1, Task 4
  - 全量替换恢复：Task 4
  - 本地回滚快照与撤销：Task 4, Task 5
  - 设置页入口与确认交互：Task 5
  - 埋点与安全日志：Task 7

- Placeholder scan:
  - 已清理所有未定稿占位词和空泛实现指令
  - 每个任务都给出了明确文件路径、测试入口和最小代码骨架

- Type consistency:
  - 模型统一使用 `DownloaderBackupBundle` / `DownloaderBackupVersion`
  - 控制器统一使用 `SettingsBackupController`
  - Drive 授权统一经 `AuthProvider.authorizeScopes` / `authorizationHeaders`
