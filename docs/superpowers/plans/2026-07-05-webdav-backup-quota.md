# WebDAV Backup Quota Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove automatic WebDAV backup deletion, enforce a signed-in maximum of three backups before upload, and keep signed-out backup/restore blocking in the settings UI.

**Architecture:** `DownloaderBackupService` becomes a pure backup storage orchestrator and no longer performs retention cleanup. `SettingsBackupController` performs the remote-count quota check and exposes an explicit quota state. `SettingsPage` remains the only layer that blocks signed-out backup/restore interactions and opens the existing backup-version sheet when the controller reports that the quota is full.

**Tech Stack:** Flutter 3.24.5, Provider `ChangeNotifier`, go_router, GetStorage, Flutter widget tests, `flutter test`.

---

## File Structure

- Modify `lib/services/downloader_backup_service.dart`
  - Remove automatic post-upload retention cleanup.
  - Remove the static retention helper because export no longer owns retention.
  - Keep explicit `listVersions()` and `deleteBackup()` operations.

- Modify `lib/features/settings/presentation/controllers/settings_backup_controller.dart`
  - Add `maxWebDavBackupVersions = 3`.
  - Add an explicit quota state, for example `backupLimitReached`.
  - Remove controller-level signed-in checks from export.
  - List remote versions before export and block upload at three or more versions.

- Modify `lib/features/settings/presentation/pages/settings_page.dart`
  - Keep signed-out backup and restore entry blocking in the UI handlers.
  - After export, open the backup-version sheet when `backupLimitReached` is true.
  - Extract the existing version-sheet code so both restore and quota-full export can reuse it.

- Modify `test/unit/services/downloader_backup_service_test.dart`
  - Replace tests that expect automatic deletion.
  - Assert export uploads and does not call `deleteBackup`.

- Modify `test/unit/features/settings/settings_backup_controller_test.dart`
  - Add controller quota tests.
  - Assert controller export does not check login state.

- Modify `test/widget/test_helpers.dart`
  - Add a `/login` test route so signed-out UI blocking can be asserted.
  - Extend `FakeSettingsBackupController` with call counters and quota-state controls.

- Modify `test/widget/settings_page_test.dart`
  - Add signed-out backup/restore blocking tests.
  - Add quota-full export sheet test.

---

### Task 1: Remove Automatic Cleanup From DownloaderBackupService

**Files:**
- Modify: `lib/services/downloader_backup_service.dart`
- Modify: `test/unit/services/downloader_backup_service_test.dart`

- [ ] **Step 1: Rewrite the service export test so automatic deletion is no longer expected**

In `test/unit/services/downloader_backup_service_test.dart`, replace the test named `exportBackup uploads bundle and deletes versions beyond newest two` with this test:

```dart
test('exportBackup uploads bundle and does not delete remote versions', () async {
  final controller = DownloaderController();
  controller.setTestDownloadersForTest(<Downloader>[_downloader()]);
  final storageApi = _FakeStorageApi(
    versionsToReturn: <DownloaderBackupVersion>[
      DownloaderBackupVersion(
        fileId: 'oldest',
        fileName: 'oldest.json',
        backupId: 'b1',
        createdAt: DateTime.parse('2026-07-01T00:00:00Z'),
        appVersion: '1.0.0',
        downloaderCount: 1,
        isLatest: false,
      ),
      DownloaderBackupVersion(
        fileId: 'old',
        fileName: 'old.json',
        backupId: 'b2',
        createdAt: DateTime.parse('2026-07-02T00:00:00Z'),
        appVersion: '1.0.0',
        downloaderCount: 1,
        isLatest: false,
      ),
      DownloaderBackupVersion(
        fileId: 'new',
        fileName: 'new.json',
        backupId: 'b3',
        createdAt: DateTime.parse('2026-07-03T00:00:00Z'),
        appVersion: '1.0.0',
        downloaderCount: 1,
        isLatest: true,
      ),
    ],
  );

  final service = _buildService(
    controller: controller,
    storageApi: storageApi,
  );
  await service.exportBackup();

  expect(storageApi.uploadedBundle, isNotNull);
  expect(storageApi.uploadedBundle!.downloaders.single.id, 'd1');
  expect(storageApi.deletedIds, isEmpty);
});
```

Delete the test named `pickFilesToDeleteBeforeUpload keeps newest two versions`.

- [ ] **Step 2: Run the focused service test and verify the expected failure**

Run:

```bash
flutter test test/unit/services/downloader_backup_service_test.dart
```

Expected: the rewritten export test fails because `storageApi.deletedIds` contains old backup ids while the current implementation still deletes old versions after upload.

- [ ] **Step 3: Replace `exportBackup()` with an upload-only implementation**

In `lib/services/downloader_backup_service.dart`, replace the full `exportBackup()` method with:

```dart
/// 导出当前下载器配置到远端存储。
Future<void> exportBackup() async {
  final now = DateTime.now().toUtc();
  final bundle = DownloaderBackupBundle(
    schemaVersion: DownloaderBackupBundle.supportedSchemaVersion,
    backupId: _buildBackupId(now),
    createdAt: now,
    appVersion: await _currentAppVersion(),
    userUid: _currentUser().uid,
    downloaders: _downloaderController.downloaders,
  );

  try {
    await _storageApi.uploadBackup(bundle);

    Log.i(
      'Backup exported: backupId=${bundle.backupId}, '
      'downloaderCount=${bundle.downloaders.length}',
    );

    await analyticsService.track(
      'downloader_backup_export_result',
      params: <String, Object>{
        'result': 'success',
        'downloader_count': bundle.downloaders.length,
      },
    );
  } catch (e) {
    await analyticsService.track(
      'downloader_backup_export_result',
      params: <String, Object>{'result': 'failure'},
    );
    rethrow;
  }
}
```

In the same file, delete the static method:

```dart
static List<DownloaderBackupVersion> pickFilesToDeleteBeforeUpload(
  List<DownloaderBackupVersion> versions,
) {
  final sorted = List<DownloaderBackupVersion>.from(versions)
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  if (sorted.length < 3) return const [];
  return sorted.take(sorted.length - 2).toList();
}
```

- [ ] **Step 4: Run service tests and verify they pass**

Run:

```bash
flutter test test/unit/services/downloader_backup_service_test.dart
```

Expected: PASS. The export test confirms upload still works and no remote backup is automatically deleted.

- [ ] **Step 5: Commit Task 1**

```bash
git add lib/services/downloader_backup_service.dart test/unit/services/downloader_backup_service_test.dart
git commit -m "fix(backup): stop auto-deleting webdav backups"
```

---

### Task 2: Add Controller Quota State And Pre-Upload Limit Check

**Files:**
- Modify: `lib/features/settings/presentation/controllers/settings_backup_controller.dart`
- Modify: `test/unit/features/settings/settings_backup_controller_test.dart`

- [ ] **Step 1: Extend the unit-test fake storage so tests can observe upload calls**

In `test/unit/features/settings/settings_backup_controller_test.dart`, update `_FakeStorageApi` by adding an uploaded bundle list and recording uploads:

```dart
class _FakeStorageApi implements BackupStorageApi {
  _FakeStorageApi({this.versions = const <DownloaderBackupVersion>[]});

  List<DownloaderBackupVersion> versions;

  final deletedIds = <String>[];
  final uploadedBundles = <DownloaderBackupBundle>[];

  @override
  Future<void> testConnection() async {}

  @override
  Future<List<DownloaderBackupVersion>> listVersions() async => versions;

  @override
  Future<void> uploadBackup(DownloaderBackupBundle bundle) async {
    uploadedBundles.add(bundle);
  }

  @override
  Future<List<int>> downloadBackup(String fileId) async => const <int>[];

  @override
  Future<void> deleteBackup(String fileId) async {
    deletedIds.add(fileId);
  }
}
```

- [ ] **Step 2: Add controller quota tests**

In the `SettingsBackupController` group in `test/unit/features/settings/settings_backup_controller_test.dart`, add these tests after `exportBackup requires config before exporting`:

```dart
test('exportBackup uploads when remote backup count is below limit', () async {
  final storageApi = _FakeStorageApi(
    versions: <DownloaderBackupVersion>[
      _version(fileId: 'f1', backupId: 'b1'),
      _version(fileId: 'f2', backupId: 'b2', isLatest: false),
    ],
  );
  final controller = _buildController(storageApi: storageApi);
  await controller.saveConfig(
    const WebDavConfig(
      rootUrl: 'https://dav.example.com/root/',
      remoteDirectory: 'WindWalker/Backups',
      username: 'alice',
      password: 'secret',
    ),
  );

  await controller.exportBackup();

  expect(storageApi.uploadedBundles, hasLength(1));
  expect(controller.backupLimitReached, isFalse);
  expect(controller.errorMessage, isNull);
});

test('exportBackup stops and lists backups when remote backup count reaches limit', () async {
  final storageApi = _FakeStorageApi(
    versions: <DownloaderBackupVersion>[
      _version(fileId: 'f1', backupId: 'b1'),
      _version(fileId: 'f2', backupId: 'b2', isLatest: false),
      _version(fileId: 'f3', backupId: 'b3', isLatest: false),
    ],
  );
  final controller = _buildController(storageApi: storageApi);
  await controller.saveConfig(
    const WebDavConfig(
      rootUrl: 'https://dav.example.com/root/',
      remoteDirectory: 'WindWalker/Backups',
      username: 'alice',
      password: 'secret',
    ),
  );

  await controller.exportBackup();

  expect(storageApi.uploadedBundles, isEmpty);
  expect(controller.backupLimitReached, isTrue);
  expect(controller.availableBackups, hasLength(3));
  expect(controller.lastOperationSummary, contains('上限'));
});

test('exportBackup does not enforce authentication in controller', () async {
  final storageApi = _FakeStorageApi();
  final controller = _buildController(
    storageApi: storageApi,
    authController: _FakeAuthController(authenticated: false),
  );
  await controller.saveConfig(
    const WebDavConfig(
      rootUrl: 'https://dav.example.com/root/',
      remoteDirectory: 'WindWalker/Backups',
      username: 'alice',
      password: 'secret',
    ),
  );

  await controller.exportBackup();

  expect(storageApi.uploadedBundles, hasLength(1));
  expect(controller.errorMessage, isNull);
});
```

Add this test after `deleteBackup removes version from local list`:

```dart
test('deleteBackup clears quota state when listed backup count drops below limit', () async {
  final controller = _buildController(
    storageApi: _FakeStorageApi(
      versions: <DownloaderBackupVersion>[
        _version(fileId: 'f1'),
        _version(fileId: 'f2', backupId: 'b2', isLatest: false),
        _version(fileId: 'f3', backupId: 'b3', isLatest: false),
      ],
    ),
  );
  await controller.saveConfig(
    const WebDavConfig(
      rootUrl: 'https://dav.example.com/root/',
      remoteDirectory: 'WindWalker/Backups',
      username: 'alice',
      password: 'secret',
    ),
  );
  await controller.exportBackup();

  await controller.deleteBackup(fileId: 'f1');

  expect(controller.backupLimitReached, isFalse);
  expect(controller.availableBackups, hasLength(2));
});
```

- [ ] **Step 3: Run controller tests and verify the expected failures**

Run:

```bash
flutter test test/unit/features/settings/settings_backup_controller_test.dart
```

Expected: FAIL because `backupLimitReached` does not exist, export still enforces login, and export does not do a pre-upload count check.

- [ ] **Step 4: Add quota fields and getters to SettingsBackupController**

In `lib/features/settings/presentation/controllers/settings_backup_controller.dart`, add these members near the other private state fields:

```dart
  static const int maxWebDavBackupVersions = 3;

  bool _backupLimitReached = false;
```

Add this getter near the other public getters:

```dart
  bool get backupLimitReached => _backupLimitReached;
```

Change the existing `canUseBackup` getter to stop depending on login state:

```dart
  bool get canUseBackup => hasConfig;
```

- [ ] **Step 5: Replace the export method with quota-aware controller logic**

In `lib/features/settings/presentation/controllers/settings_backup_controller.dart`, replace the full `exportBackup()` method with:

```dart
Future<void> exportBackup() async {
  final service = _backupService;
  if (service == null) {
    _errorMessage = '备份服务未初始化';
    notifyListeners();
    return;
  }
  if (!hasConfig) {
    _errorMessage = '请先配置 WebDAV';
    notifyListeners();
    return;
  }

  _isExporting = true;
  _backupLimitReached = false;
  _errorMessage = null;
  _lastOperationSummary = null;
  notifyListeners();

  try {
    final versions = await service.listVersions();
    if (versions.length >= maxWebDavBackupVersions) {
      _availableBackups = versions;
      _backupLimitReached = true;
      _lastOperationSummary = '备份数量已达上限，请删除一个已有备份后再创建新备份';
      return;
    }

    await service.exportBackup();
    _lastOperationSummary = '已备份到 WebDAV';
  } on BackupException catch (e, st) {
    _errorMessage = _messageForBackupException(e);
    Log.e('exportBackup failed', error: e, stackTrace: st);
  } catch (e, st) {
    _errorMessage = '导出失败: $e';
    Log.e('exportBackup failed', error: e, stackTrace: st);
  } finally {
    _isExporting = false;
    notifyListeners();
  }
}
```

- [ ] **Step 6: Add quota-state clearing helpers**

In `lib/features/settings/presentation/controllers/settings_backup_controller.dart`, add this method after `clearError()`:

```dart
void clearBackupLimitReached() {
  if (!_backupLimitReached) {
    return;
  }
  _backupLimitReached = false;
  notifyListeners();
}
```

In the existing `deleteBackup()` success block, after `_availableBackups = ...toList();`, add:

```dart
      if (_availableBackups.length < maxWebDavBackupVersions) {
        _backupLimitReached = false;
      }
```

- [ ] **Step 7: Run controller tests and verify they pass**

Run:

```bash
flutter test test/unit/features/settings/settings_backup_controller_test.dart
```

Expected: PASS. Controller enforces the three-backup quota, exposes quota state, and no longer blocks export based on auth state.

- [ ] **Step 8: Commit Task 2**

```bash
git add lib/features/settings/presentation/controllers/settings_backup_controller.dart test/unit/features/settings/settings_backup_controller_test.dart
git commit -m "feat(backup): enforce webdav backup quota in settings controller"
```

---

### Task 3: Wire Settings UI To Signed-Out Gate And Quota Sheet

**Files:**
- Modify: `lib/features/settings/presentation/pages/settings_page.dart`
- Modify: `test/widget/test_helpers.dart`
- Modify: `test/widget/settings_page_test.dart`

- [ ] **Step 1: Extend widget-test helpers**

In `test/widget/test_helpers.dart`, add a `/login` route to the test router after the `/settings` route:

```dart
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) =>
            const SizedBox(key: Key('login-page')),
      ),
```

In `FakeSettingsBackupController`, add these fields after `_fakeHasConfig`:

```dart
  bool _fakeBackupLimitReached = false;
  int exportCallCount = 0;
  int loadAvailableBackupsCallCount = 0;
  int restoreCallCount = 0;
```

Add this helper method after `seedAvailableBackups`:

```dart
  void seedQuotaReachedBackups(List<DownloaderBackupVersion> backups) {
    _seededBackups = backups;
    _fakeBackupLimitReached = true;
  }
```

Add this getter override near `availableBackups`:

```dart
  @override
  bool get backupLimitReached => _fakeBackupLimitReached;
```

Replace the fake async overrides with:

```dart
  @override
  Future<void> exportBackup() async {
    exportCallCount += 1;
    notifyListeners();
  }

  @override
  Future<void> loadAvailableBackups() async {
    loadAvailableBackupsCallCount += 1;
  }

  @override
  Future<void> restoreBackup({required String fileId}) async {
    restoreCallCount += 1;
  }

  @override
  Future<void> deleteBackup({required String fileId}) async {
    _seededBackups = (_seededBackups ?? <DownloaderBackupVersion>[])
        .where((backup) => backup.fileId != fileId)
        .toList();
    if ((_seededBackups ?? <DownloaderBackupVersion>[]).length <
        SettingsBackupController.maxWebDavBackupVersions) {
      _fakeBackupLimitReached = false;
    }
    notifyListeners();
  }

  @override
  void clearBackupLimitReached() {
    _fakeBackupLimitReached = false;
    notifyListeners();
  }
```

- [ ] **Step 2: Add widget tests for UI-only signed-out blocking and quota sheet**

In `test/widget/settings_page_test.dart`, add this helper function above `main()`:

```dart
DownloaderBackupVersion _backupVersion({
  required String fileId,
  required String backupId,
  bool isLatest = false,
}) {
  return DownloaderBackupVersion(
    fileId: fileId,
    fileName: '$backupId.json',
    backupId: backupId,
    createdAt: DateTime(2026, 6, 27, 10, 30),
    appVersion: '1.2.0',
    downloaderCount: 3,
    isLatest: isLatest,
  );
}
```

In the `SettingsPage Backup & Restore` group, add these tests:

```dart
testWidgets('signed-out backup tap routes to login and does not export', (
  tester,
) async {
  final backupController = FakeSettingsBackupController.signedOut();
  await tester.pumpWidget(
    createTestApp(
      downloaderController: downloaderController,
      settingsController: settingsController,
      authController: FakeAuthController(authenticated: false),
      settingsBackupController: backupController,
      initialLocation: '/settings',
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Back up to WebDAV'));
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('login-page')), findsOneWidget);
  expect(backupController.exportCallCount, 0);
});

testWidgets('signed-out restore tap routes to login and does not load backups', (
  tester,
) async {
  final backupController = FakeSettingsBackupController.signedOut();
  await tester.pumpWidget(
    createTestApp(
      downloaderController: downloaderController,
      settingsController: settingsController,
      authController: FakeAuthController(authenticated: false),
      settingsBackupController: backupController,
      initialLocation: '/settings',
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Restore from WebDAV'));
  await tester.pumpAndSettle();

  expect(find.byKey(const Key('login-page')), findsOneWidget);
  expect(backupController.loadAvailableBackupsCallCount, 0);
  expect(backupController.restoreCallCount, 0);
});

testWidgets('backup tap opens version sheet when quota is reached', (
  tester,
) async {
  final backupController = FakeSettingsBackupController.signedIn()
    ..seedQuotaReachedBackups([
      _backupVersion(fileId: 'f1', backupId: 'b1', isLatest: true),
      _backupVersion(fileId: 'f2', backupId: 'b2'),
      _backupVersion(fileId: 'f3', backupId: 'b3'),
    ]);
  await tester.pumpWidget(
    createTestApp(
      downloaderController: downloaderController,
      settingsController: settingsController,
      authController: FakeAuthController(authenticated: true),
      settingsBackupController: backupController,
      initialLocation: '/settings',
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.text('Back up to WebDAV'));
  await tester.pumpAndSettle();

  expect(backupController.exportCallCount, 1);
  expect(find.text('Select backup version'), findsOneWidget);
  expect(find.text('1.2.0 · 3 downloaders'), findsNWidgets(3));
});
```

- [ ] **Step 3: Run settings widget tests and verify expected failures**

Run:

```bash
flutter test test/widget/settings_page_test.dart
```

Expected: FAIL because `/login` route, fake quota hooks, `clearBackupLimitReached`, and quota-sheet opening have not all been wired yet.

- [ ] **Step 4: Extract the backup-version sheet in SettingsPage**

In `lib/features/settings/presentation/pages/settings_page.dart`, replace `_openBackupVersions()` with this version:

```dart
Future<void> _openBackupVersions(
  BuildContext context,
  AuthController auth,
  SettingsBackupController backup,
) async {
  if (!auth.isAuthenticated) {
    await context.push('/login');
    return;
  }
  if (!backup.hasConfig) {
    await context.push('/settings/webdav');
    return;
  }

  await backup.loadAvailableBackups();
  if (!context.mounted) {
    return;
  }

  await _showBackupVersionsSheet(context, backup);
}
```

Add this new method immediately after `_openBackupVersions()` and move the existing `showModalBottomSheet` body into it:

```dart
Future<void> _showBackupVersionsSheet(
  BuildContext context,
  SettingsBackupController backup,
) async {
  final l10n = AppLocalizations.of(context)!;
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    isScrollControlled: true,
    builder: (sheetContext) {
      final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.82;
      return ChangeNotifierProvider<SettingsBackupController>.value(
        value: backup,
        child: SafeArea(
          minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: NeoCard(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Consumer<SettingsBackupController>(
                builder: (context, backupState, _) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.selectBackupVersion,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      if (backupState.availableBackups.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: AppSpacing.lg,
                          ),
                          child: Center(child: Text(l10n.noBackupsAvailable)),
                        )
                      else
                        Flexible(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                for (final version
                                    in backupState.availableBackups) ...[
                                  _buildBackupVersionRow(
                                    context,
                                    backup: backupState,
                                    version: version,
                                  ),
                                  if (version !=
                                      backupState.availableBackups.last)
                                    const SizedBox(height: AppSpacing.sm),
                                ],
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );
    },
  );
}
```

- [ ] **Step 5: Open the version sheet after quota-full export**

In `lib/features/settings/presentation/pages/settings_page.dart`, replace the final line of `_handleBackupExport()`:

```dart
  await backup.exportBackup();
```

with:

```dart
  await backup.exportBackup();
  if (!context.mounted) {
    return;
  }
  if (backup.backupLimitReached) {
    await _showBackupVersionsSheet(context, backup);
    backup.clearBackupLimitReached();
  }
```

- [ ] **Step 6: Run settings widget tests and verify they pass**

Run:

```bash
flutter test test/widget/settings_page_test.dart
```

Expected: PASS. Signed-out taps route to login without calling controller backup/restore methods, and quota-full export opens the backup list.

- [ ] **Step 7: Commit Task 3**

```bash
git add lib/features/settings/presentation/pages/settings_page.dart test/widget/test_helpers.dart test/widget/settings_page_test.dart
git commit -m "feat(backup): show manual delete list at webdav quota"
```

---

### Task 4: Run Focused Regression Suite

**Files:**
- Verify only; no planned code modifications.

- [ ] **Step 1: Run all affected unit and widget tests**

Run:

```bash
flutter test test/unit/services/downloader_backup_service_test.dart test/unit/features/settings/settings_backup_controller_test.dart test/widget/settings_page_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run the full Flutter test suite**

Run:

```bash
flutter test
```

Expected: PASS. If unrelated pre-existing failures appear, record the failing test names and confirm they are unrelated before completing.

- [ ] **Step 3: Inspect git status**

Run:

```bash
git status --short
```

Expected: clean worktree after the three implementation commits.

