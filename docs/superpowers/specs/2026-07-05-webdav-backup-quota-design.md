# WebDAV 备份配额设计

日期：2026-07-05
状态：对话中已确认，待用户复核

## 摘要

WindWalker 的 WebDAV 备份流程不再自动删除旧备份。已登录用户最多保留 3 个 WebDAV 备份版本。当远端备份目录中已有 3 个或更多备份时，应用阻止本次新备份上传，展示现有备份列表，并让用户手动删除一个备份后再重试。

未登录用户不能从设置页使用 WebDAV 备份或恢复。这个登录门槛只属于 UI 层的产品限制；`SettingsBackupController` 和 `DownloaderBackupService` 不为这条规则额外增加登录或角色校验。

## 已确认决策

- 未登录用户不能发起 WebDAV 备份。
- 未登录用户不能发起 WebDAV 恢复。
- 未登录限制只在设置页 UI 层执行。
- 已登录用户最多保留 3 个 WebDAV 备份版本。
- 导出备份不再自动删除旧的远端备份。
- 达到配额时，不上传新备份。
- 达到配额时，应用列出现有备份，用户可手动删除其中一个。
- 手动删除仍允许删除任意列出的备份版本，包括最新版本，但必须先确认。

## 目标

- 移除 WebDAV 导出流程中的自动旧备份清理逻辑。
- 让用户自己决定删除哪个远端备份版本。
- 让 WebDAV 备份服务只关注存储操作：列表、上传、下载、删除。
- 将登录入口限制保留在设置页交互层。
- 让配额行为可以脱离 UI 导航进行测试。

## 非目标

- 不引入付费层级、VIP 层级或服务端订阅校验。
- 不在后端强制执行 WebDAV 备份配额。
- 不自动迁移或删除已有远端备份。
- 不提供恢复冲突合并 UI。
- 不修改备份 JSON schema。
- 不修改 WebDAV 配置存储方式。

## 当前行为

当前实现会先上传新备份，然后列出远端版本并删除旧文件，使远端只保留最新 2 个版本。设置页也会在未登录用户点击备份或恢复时跳转到登录。

新行为保留未登录 UI 限制，将已登录用户的策略从“自动保留最新 2 个”改为“手动管理最多 3 个”，并从导出流程中移除自动删除。

## 架构

### 设置页 UI

`SettingsPage` 继续负责未登录入口限制。

- 未登录时点击“备份到 WebDAV”，跳转登录页或展示现有登录要求。
- 未登录时点击“从 WebDAV 恢复”，执行同样的登录要求。
- 这些检查保留在页面级 handler 中，不放入 `SettingsBackupController`。
- 未登录时，备份和恢复行的副标题继续表达“需要登录”。

已登录用户导出备份并命中上限时，页面打开与恢复流程共用的备份版本列表 sheet。用户可以查看和删除现有备份。删除后不自动重试导出；用户需要再次点击“备份到 WebDAV”。

### SettingsBackupController

`SettingsBackupController` 负责备份配额检查，因为它已经协调导出状态和远端备份列表。控制器不决定未登录用户能否进入流程；`SettingsPage` 在调用控制器前处理这个入口限制。

引入控制器层常量或 getter：

- `maxWebDavBackupVersions = 3`

导出前，控制器执行：

1. 确认 WebDAV 配置已存在。
2. 调用 `DownloaderBackupService.listVersions()`。
3. 如果远端版本数小于 `3`，调用 `DownloaderBackupService.exportBackup()`。
4. 如果远端版本数大于或等于 `3`，把版本列表写入 `availableBackups`，设置明确的“配额已满”状态，不调用上传。

控制器不检查登录态来决定是否允许导出或恢复。未登录限制留在 `SettingsPage`。

使用明确状态信号，例如 `backupLimitReached` 或操作结果枚举。`SettingsPage` 不能通过匹配错误文案来判断是否命中配额。

### DownloaderBackupService

`DownloaderBackupService.exportBackup()` 不再在上传后删除远端备份。

它仍然负责：

- 构建 `DownloaderBackupBundle`。
- 读取当前应用版本。
- 在已登录生产路径中，通过注入的 `currentUser` 回调读取用户信息作为备份元数据。
- 通过 `BackupStorageApi.uploadBackup` 上传备份。
- 发送现有导出成功或失败埋点。

它停止负责：

- 上传后为了保留策略调用 `listVersions()`。
- 自动调用 `deleteBackup()`。
- 将保留策略 helper 作为导出行为的一部分。

服务保留 `listVersions()` 和 `deleteBackup()` 作为显式操作，供控制器和 UI 使用。

如果注入的 `currentUser` 无法提供备份元数据，服务可以继续 fail-fast 抛错；但服务本身不增加显式登录检查或配额检查。未登录产品限制只由 UI 层执行。

## 数据流

### 未登录备份或恢复

1. 用户在设置页点击备份或恢复。
2. `SettingsPage` 发现 `AuthController.isAuthenticated == false`。
3. 页面跳转登录页或展示现有登录要求。
4. 不调用控制器的备份或恢复方法。

### 已登录且低于上限时导出

1. 用户在设置页点击备份。
2. `SettingsPage` 因为用户已登录而允许操作。
3. `SettingsBackupController.exportBackup()` 校验 WebDAV 配置存在。
4. 控制器列出远端备份版本。
5. 如果已有 `0`、`1` 或 `2` 个版本，控制器调用 `DownloaderBackupService.exportBackup()`。
6. 服务上传新备份。
7. 不自动删除任何旧远端备份。
8. 控制器报告导出成功。

### 已登录且达到上限时导出

1. 用户在设置页点击备份。
2. 控制器列出远端备份版本。
3. 如果已有 `3` 个或更多版本，控制器把列表写入 `availableBackups`。
4. 控制器通过明确配额状态报告备份上限已达。
5. `SettingsPage` 打开备份版本列表 sheet。
6. 用户可以手动删除一个备份版本。
7. 删除后，用户可以再次点击备份。

### 手动删除

手动删除沿用当前流程：

1. 用户打开备份版本列表 sheet。
2. 用户点击某个版本的删除按钮。
3. UI 弹出确认。
4. 控制器调用 `DownloaderBackupService.deleteBackup(fileId: ...)`。
5. 控制器从 `availableBackups` 中移除已删除版本。

## 错误处理

- 导出前列表加载失败时，通过现有备份错误消息链路展示，不上传新备份。
- 上传失败继续通过现有导出错误链路展示。
- 手动删除失败继续通过现有删除错误链路展示。
- 达到备份上限不是存储失败，应使用用户可理解的提示，例如“备份数量已达上限，请删除一个已有备份后再创建新备份”。
- 项目的 fail-fast 规则保持不变：service/storage 异常传播到 controller，controller 写入 UI 可见错误状态。

## 埋点

保留现有导出成功和失败埋点。导出事件中的远端版本数量不应再暗示发生了自动清理。如果继续保留版本数量参数，应表达上传前观察到的数量，以及本次没有执行自动清理。

如果现有埋点词表能自然表达“配额已满且未上传”，可以将其记录为一种非上传导出结果。如果新增埋点会扩大实现范围，本次跳过。

## 测试

### 单元测试

更新 `test/unit/services/downloader_backup_service_test.dart`：

- 导出会上传备份，但不会调用 `deleteBackup`。
- 移除或改写所有期待自动删除旧备份的测试。

更新 `test/unit/features/settings/settings_backup_controller_test.dart`：

- 已登录且远端少于 3 个备份时，导出成功上传。
- 已登录且远端已有 3 个备份时，不上传。
- 已登录且远端已有 3 个备份时，填充 `availableBackups`。
- 删除一个列出的备份后，从 `availableBackups` 中移除。
- 控制器导出不再检查登录态。

### Widget 测试

更新设置页测试：

- 未登录点击备份时，在 UI 层被拦截，不调用控制器导出。
- 未登录点击恢复时，在 UI 层被拦截，不调用控制器列表或恢复。
- 已登录且导出命中配额时，打开备份版本列表 sheet。
- sheet 通过现有确认流程支持手动删除。

## 实现备注

- 改动范围只限 WebDAV 备份行为。
- 不添加订阅、VIP 或后端角色概念。
- 不修改备份文件格式。
- 使用小而明确的控制器状态表示“配额已满”，让页面无需匹配字符串即可打开列表 sheet。
- 保留现有 WebDAV 配置页和恢复确认 UI。
