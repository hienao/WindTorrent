# Google Drive 下载器备份设计

日期：2026-06-27
状态：已在对话中确认，待评审

## 摘要

WindWalker 当前将下载器配置保存在本地 `GetStorage`，字段包含连接地址与认证信息。用户希望在设置页新增“备份到当前登录 Google 账号的 Drive”和“从当前登录 Google 账号恢复”的能力，并要求：

- 备份内容包含敏感凭据，支持一键完整恢复
- 恢复采用全量替换当前下载器列表
- 云端最多保留 2 个版本，超出时在新备份前删除最早版本
- 首次使用时复用当前 Google 登录，并按需追加 Drive 权限
- 恢复前自动生成本地回滚快照，必要时可撤销一次

本设计推荐把备份能力落在 Google Drive 的 `appDataFolder` 中，而不是用户可见目录。这样可以以最小权限保存高敏感备份，同时保持 app 内版本选择和恢复体验的一致性。

## 目标

- 在设置页提供稳定的下载器配置云备份与恢复能力。
- 复用现有 Google 登录链路，不引入第二套账号连接流程。
- 以最小权限将高敏感备份文件保存到 Google Drive 隐藏应用目录。
- 保证恢复流程对当前配置的覆盖行为明确、可确认、可回滚。
- 保持现有 `AuthController`、`SettingsController`、`DownloaderController` 的职责边界清晰。

## 非目标

- 本轮不支持把备份文件保存到用户可见的 Drive 普通目录。
- 本轮不做差异预览、冲突合并、按单个下载器选择性恢复。
- 本轮不备份任务列表、任务历史、应用主题、语言等非下载器配置数据。
- 本轮不支持多云存储目标，如 iCloud、Dropbox、本地文件导出。
- 本轮不做应用侧二次加密；安全边界以 Google 账号、Drive `appDataFolder` 和最小权限为主。

## 已确认决策

用户已在对话中确认以下约束：

- 备份文件必须包含 `host / port / secret / username / password` 等敏感凭据，以支持完整恢复。
- 恢复时直接全量替换当前下载器列表，而不是合并或差异处理。
- Drive 授权复用当前 Google 登录，在第一次使用备份功能时按需申请。
- 恢复前自动生成本地回滚快照，支持导错版本或写入失败时恢复。
- 备份文件保存到 Google Drive 隐藏应用目录，并由 app 内列出最近版本。

## 方案比较

### 方案 A：Google Drive `appDataFolder` + 两版本轮换

这是本次推荐并已确认的方案。

- 备份文件保存到 `appDataFolder`
- app 内列出最近两个版本
- 新备份前删除最早版本
- 恢复前本地生成一份回滚快照

优点：

- 权限最小，暴露面最小
- 不污染用户 Drive 根目录
- 版本策略简单，贴合“最多保留 2 个版本”的需求
- 对高敏感备份文件更稳妥

缺点：

- 用户无法在 Drive UI 中直接看到这些备份文件

### 方案 B：保存到用户可见 Drive 文件夹

- 如 `WindWalker Backups/`

优点：

- 用户可在 Drive 内手动查看、下载、删除

缺点：

- 误删、误分享、外部暴露风险更高
- 目录治理和权限边界更复杂

### 方案 C：`appDataFolder` + 额外索引清单文件

优点：

- 版本关系与元数据管理更强

缺点：

- 对仅保留两个版本的场景属于过度设计
- 实现与维护复杂度更高

## 总体架构

本功能新增独立的备份能力链，不把 Drive 逻辑塞进现有设置或认证控制器中。

### 新增模块

#### `lib/services/google_drive_backup_api.dart`

职责仅限于 Google Drive API 通信：

- 申请并确认 Drive scope
- 列出 `appDataFolder` 中 WindWalker 备份文件
- 上传备份文件
- 下载指定备份文件
- 删除指定备份文件

该层不关心下载器模型，不管理 UI 状态。

#### `lib/services/downloader_backup_service.dart`

职责为备份业务编排：

- 组装备份 JSON
- 读取云端版本列表并执行“两版本保留”策略
- 发起导出、导入与本地回滚
- 校验 `schemaVersion`
- 把导入结果交回 `DownloaderController`

该层抛出明确异常，不吞失败。

#### `lib/features/settings/presentation/controllers/settings_backup_controller.dart`

职责为设置页提供备份相关状态：

- `isExporting`
- `isImporting`
- `isLoadingVersions`
- `availableBackups`
- `errorMessage`
- `lastOperationSummary`
- `canUndoLastRestore`

该控制器只编排 UI 侧状态，不直接操作 Drive API。

### 现有模块边界

#### `AuthController`

继续只负责：

- 当前登录用户
- Google 登录状态
- 基础登录/登出行为

不直接承接 Drive 业务，只向备份功能提供登录态与用户标识。

#### `SettingsController`

继续只负责主题与语言，不混入备份状态。

#### `DownloaderController`

继续作为下载器配置唯一受控入口：

- 暴露当前下载器列表
- 保存到本地 `GetStorage`
- 新增“原子替换全部下载器”的专用入口

备份服务不直接写 `GetStorage`。

## 数据模型与备份文件格式

### 备份文件内容

备份文件采用完整 JSON，格式如下：

```json
{
  "schemaVersion": 1,
  "backupId": "20260627T143015Z_xxxxx",
  "createdAt": "2026-06-27T14:30:15Z",
  "appVersion": "1.1.1+2026062702",
  "user": {
    "uid": "google_uid"
  },
  "downloaders": [
    {
      "id": "...",
      "name": "...",
      "type": "aria2",
      "host": "...",
      "port": 6800,
      "secret": "...",
      "username": null,
      "password": null,
      "useHttps": false,
      "version": "..."
    }
  ]
}
```

### 字段设计说明

- `schemaVersion`
  用于未来格式升级。本轮固定为 `1`，不兼容版本直接失败。

- `backupId`
  独立于文件名的逻辑 ID，用于埋点、日志和回滚关联。

- `createdAt`
  用于云端版本展示与排序。

- `appVersion`
  用于在恢复列表中展示来源版本，也方便定位兼容问题。

- `user.uid`
  用于归属与上下文记录，不做强拦截条件。默认允许同一 Google 账号下恢复。

- `downloaders`
  只保存连接配置字段，不保存 `status / downloadSpeed / uploadSpeed / taskCount / taskStats` 等运行态数据。

### 文件命名

建议采用可排序格式：

`windwalker_downloaders_backup_2026-06-27T14-30-15Z.json`

这样在不下载文件内容的情况下，也能结合 `name + createdTime` 直接展示版本。

## 云端版本保留策略

云端最多保留 2 个版本。

### 导出流程

1. 列出 `appDataFolder` 中属于 WindWalker 的备份文件。
2. 按 `createdTime` 升序排序。
3. 若当前数量大于等于 2，则在上传前删除最早版本，直到只剩 1 个。
4. 上传新的备份文件。
5. 最终云端保留“上一个版本 + 当前版本”。

### 选择“先删后传”的原因

用户需求明确要求“超过的话备份前删除最早版本”。本设计遵循该行为，即使新上传失败，云端也至少还保留 1 个旧版本，不影响当前本地数据。

## 本地回滚与恢复策略

### 导入前快照

每次执行恢复前，先把当前本地下载器配置写入单独的回滚快照，例如：

- key: `downloaders_import_rollback_snapshot`
- value: 当前完整下载器 JSON、快照创建时间、来源 `backupId`

### 快照用途

- 用户导入错误版本后，可撤销上一次恢复
- 导入写入过程中失败时，可自动恢复
- 导入文件解析失败时，不会动到当前本地数据

### 快照保留策略

只保留 1 份最近快照，不参与云端两版本轮换规则。

### DownloaderController 原子替换入口

新增类似 `replaceAllDownloadersFromBackup(...)` 的受控入口：

1. 校验传入下载器列表
2. 一次性替换内存中的 `_downloaders`
3. 一次性写回 `GetStorage`
4. 成功后 `notifyListeners`
5. 若失败，立即恢复本地快照并抛出异常

该入口必须是导入成功写入本地的唯一通路。

## 设置页交互设计

### 入口结构

在 [settings_page.dart](/Volumes/Data/Code/GitHub/WindWalker/lib/features/settings/presentation/pages/settings_page.dart) 中新增“备份与恢复”分组，包含：

- `备份到 Google Drive`
- `从 Google Drive 恢复`

若用户未登录：

- 入口仍可见，但置灰
- 副文案提示“请先登录 Google 账号”

### 首次执行备份

流程如下：

1. 用户点击“备份到 Google Drive”
2. 若未登录，则引导先完成现有 Google 登录
3. 若已登录但未授权 Drive scope，则弹出用途说明并申请追加授权
4. 授权成功后立即执行备份
5. 备份成功后提示时间与成功状态
6. 失败则明确展示失败原因

### 首次 Drive 授权说明

授权前文案应明确说明：

- 仅用于保存 WindWalker 下载器备份
- 最多保留最近 2 个版本
- 备份内容包含连接配置与认证信息

### 恢复入口流程

用户点击“从 Google Drive 恢复”后：

1. 加载最近两个云端版本
2. 以底部弹层或二级页展示版本列表
3. 每个版本展示：
   - 备份时间
   - `appVersion`
   - 下载器数量
   - 是否为最新版本

不直接暴露原始文件名作为主信息。

### 恢复确认

用户选择某个版本后，弹出强确认对话框，明确告知：

- 将覆盖当前全部下载器配置
- 导入前会自动创建本地回滚快照
- 不会影响 Google Drive 中其他备份版本

确认主按钮文案建议为：

`确认恢复并替换`

### 恢复成功反馈

恢复成功后反馈：

- 已恢复的下载器数量
- 当前配置已被替换
- 本次会话可撤销上一次恢复

“撤销上次恢复”不作为常驻重入口，建议只在成功反馈后短时暴露，或在备份分组中作为次级辅助入口出现。

## 权限与安全边界

### 权限策略

- 复用当前 Google 登录
- 首次使用备份功能时按需追加 Drive scope
- 仅请求本功能所需的最小 Drive 权限

### 高敏感数据处理

备份文件包含：

- `host`
- `port`
- `secret`
- `username`
- `password`

因此必须满足：

- 文件只保存到 `appDataFolder`
- 不把敏感字段写入埋点
- 不把敏感字段写入日志
- 不在 UI 中回显备份 JSON 内容

本轮不额外引入应用侧二次加密，以控制实现复杂度；该风险通过 Google 账号保护、Drive 隐藏目录和最小权限控制。

## 错误处理

遵循项目现有 fail-fast 原则，不做静默降级。

### 必须显式暴露给 UI 的失败

- Drive 授权失败
- 云端版本列表读取失败
- 上传失败
- 下载失败
- JSON 解析失败
- `schemaVersion` 不兼容
- 本地全量替换失败
- 自动回滚失败

### 处理约束

- 导出失败不得影响当前本地下载器配置
- 下载或解析失败不得覆盖当前本地下载器配置
- 本地替换失败时必须立即尝试回滚
- 回滚若再次失败，必须进入显式错误态并记录日志

## 埋点与日志

### 建议埋点事件

- `downloader_backup_drive_auth_result`
  - 参数：`result`, `trigger`

- `downloader_backup_export_started`
  - 参数：`downloader_count`

- `downloader_backup_export_result`
  - 参数：`result`, `downloader_count`, `cloud_version_count_before`, `cloud_version_count_after`

- `downloader_backup_import_started`
  - 参数：`selected_backup_age_hours`

- `downloader_backup_import_result`
  - 参数：`result`, `imported_downloader_count`, `backup_age_hours`, `had_rollback_snapshot`

- `downloader_backup_rollback_result`
  - 参数：`result`, `source_backup_id`

所有埋点统一通过现有 `AnalyticsService`，禁止携带敏感字段。

### 日志约束

允许记录：

- `backupId`
- 文件 ID
- 时间戳
- 下载器数量
- 操作结果

禁止记录：

- `host`
- `secret`
- `username`
- `password`
- 原始 JSON 内容

## 测试策略

### 单元测试

- 备份 JSON 序列化与反序列化
- `schemaVersion` 不匹配时失败
- 两版本保留策略
- 导入前快照生成
- 本地替换失败后的自动回滚

### 控制器测试

- 未登录时备份入口状态
- 未授权时追加授权流程
- 导出成功/失败状态流转
- 恢复成功/失败状态流转
- 撤销上次恢复状态流转

### Widget 测试

- 设置页显示“备份与恢复”分组
- 未登录时入口置灰
- 恢复确认弹窗文案正确
- 云端版本列表仅展示最近版本信息

## 分阶段实施建议

### 第一阶段

- 增加 Drive API 层、备份 service、设置控制器
- 增加下载器全量替换入口
- 打通导出流程与两版本保留

### 第二阶段

- 打通恢复流程与本地回滚快照
- 增加“撤销上次恢复”
- 完成埋点与日志清理

### 第三阶段

- 补齐 Widget 测试和异常路径测试
- 视真实反馈再评估是否需要差异预览或应用侧加密

## 最终结论

本轮功能按以下方案落地：

- 使用 Google Drive `appDataFolder` 作为隐藏备份存储位置
- 复用现有 Google 登录，并在首次使用时追加 Drive 权限
- 备份文件保存完整下载器连接配置与敏感凭据
- 云端最多保留 2 个版本，并在新备份前删除最早版本
- 恢复采用全量替换当前下载器列表
- 恢复前自动生成 1 份本地回滚快照，支持失败回滚与一次撤销
- 新增独立备份 service、Drive API 层和 settings backup controller，保持现有控制器职责清晰

这个方案在安全边界、实现复杂度、用户心智和后续可扩展性之间取得了当前最合适的平衡。
