// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appName => 'WindTorrent';

  @override
  String get settings => '设置';

  @override
  String get addTask => '添加下载';

  @override
  String get downloaderManagement => '下载器管理';

  @override
  String get downloadersTab => '下载器';

  @override
  String get config => '配置';

  @override
  String get edit => '编辑';

  @override
  String get taskList => '任务列表';

  @override
  String get taskDetail => '任务详情';

  @override
  String get unnamedTask => '未命名任务';

  @override
  String get myDownloaders => '我的下载器';

  @override
  String get manage => '管理';

  @override
  String get data => '总览';

  @override
  String get taskStatusOverview => '任务状态总览';

  @override
  String taskTotalKicker(int count) {
    return '共 $count 个任务';
  }

  @override
  String get downloaderDistribution => '下载器分布';

  @override
  String totalDownloaders(int count) {
    return '共 $count 个下载器';
  }

  @override
  String get tapDownloaderToManageTasks => '点击下载器可查看或管理该下载器的任务';

  @override
  String get management => '管理';

  @override
  String get addTaskButton => '添加任务';

  @override
  String get addFromClipboard => '从剪贴板添加任务';

  @override
  String get clipboardEmpty => '剪贴板为空';

  @override
  String get noValidLinkInClipboard => '剪贴板中未检测到有效的下载链接';

  @override
  String get noDownloadersYet => '还没有添加下载器';

  @override
  String get addDownloaderHint =>
      '添加 Aria2、qBittorrent 或\nTransmission 开始管理下载任务';

  @override
  String get addDownloader => '添加下载器';

  @override
  String get downloading => '下载中';

  @override
  String get seeding => '做种中';

  @override
  String get completed => '已完成';

  @override
  String get totalSpeed => '总速度';

  @override
  String get online => '在线';

  @override
  String get offline => '离线';

  @override
  String get error => '错误';

  @override
  String tasks(int count) {
    return '$count 任务';
  }

  @override
  String get generalSettings => '通用设置';

  @override
  String get about => '关于';

  @override
  String get aboutWindTorrent => '关于 WindTorrent';

  @override
  String get aboutSubtitle => '版本信息、开源许可与致谢';

  @override
  String get version => '版本';

  @override
  String get rateApp => '给我们评分';

  @override
  String get rateAppDesc => '喜欢 WindTorrent？给我们一个好评吧！';

  @override
  String get back => '返回';

  @override
  String get switchOn => '开启';

  @override
  String get switchOff => '关闭';

  @override
  String get selectDownloader => '选择下载器';

  @override
  String get noDownloadersConfigured => '暂无已配置的下载器，请先添加下载器';

  @override
  String get enterLinkOrTorrent => '输入链接或种子';

  @override
  String get pasteHint => '粘贴 Magnet / HTTP / FTP 链接';

  @override
  String get paste => '粘贴';

  @override
  String get torrentFile => '种子文件';

  @override
  String get savePath => '保存路径';

  @override
  String get defaultSavePath => '默认保存路径';

  @override
  String get qbitBulkInputHint => 'qBittorrent 模式：一行一个磁力链接';

  @override
  String get loadingDefaultSavePath => '正在读取默认保存路径...';

  @override
  String get startDownload => '开始下载';

  @override
  String get torrentFeatureInDev => '种子文件功能开发中';

  @override
  String get pleaseSelectDownloader => '请先选择一个下载器';

  @override
  String get taskAddedSuccess => '任务添加成功';

  @override
  String get taskAddFailed => '任务添加失败，请检查下载器状态';

  @override
  String taskAddFailedWithError(String error) {
    return '任务添加失败: $error';
  }

  @override
  String get pleaseEnterUrl => '请输入下载链接';

  @override
  String get pleaseEnterValidUrl => '请输入有效的下载链接';

  @override
  String get pathContainsInvalidChars => '路径包含非法字符';

  @override
  String get deleteDownloader => '删除下载器';

  @override
  String get confirmDeleteDownloader => '确定要删除这个下载器吗？';

  @override
  String get cancel => '取消';

  @override
  String get delete => '删除';

  @override
  String get tapToAddDownloader => '点击下方按钮添加下载器';

  @override
  String get addDownloaderTitle => '添加下载器';

  @override
  String get editDownloaderTitle => '编辑下载器';

  @override
  String get name => '名称';

  @override
  String get nameHint => '给下载器起个名字';

  @override
  String get pleaseEnterName => '请输入名称';

  @override
  String get hostAddress => '主机地址';

  @override
  String get hostExample => '例如: 192.168.1.100';

  @override
  String get pleaseEnterHost => '请输入主机地址';

  @override
  String get port => '端口';

  @override
  String get portExample => '例如: 6800';

  @override
  String get pleaseEnterPort => '请输入端口';

  @override
  String get pleaseEnterValidPort => '请输入有效的端口号';

  @override
  String get rpcSecret => 'RPC 密钥';

  @override
  String get optional => '可选';

  @override
  String get username => '用户名';

  @override
  String get password => '密码';

  @override
  String get addButton => '添加';

  @override
  String get saveButton => '保存';

  @override
  String get connectionFailed => '连接失败，请检查地址、端口和认证信息';

  @override
  String get downloaderAddedSuccess => '下载器添加成功';

  @override
  String get downloaderUpdatedSuccess => '下载器更新成功';

  @override
  String downloaderServiceSettings(String name) {
    return '$name 服务设置';
  }

  @override
  String get downloader => '下载器';

  @override
  String get downloaderNotExist => '下载器不存在';

  @override
  String get saveConfig => '保存配置';

  @override
  String get enterSpeedLimit => '输入速度上限';

  @override
  String get notEnabled => '未启用';

  @override
  String get pleaseEnterValidNumber => '请输入有效的数值';

  @override
  String get downloaderOfflineCannotFetchConfig => '下载器离线，无法获取配置';

  @override
  String get configSaveSuccess => '配置保存成功';

  @override
  String get saveFailedRetry => '保存失败，请重试';

  @override
  String loadConfigFailed(String error) {
    return '加载配置失败: $error';
  }

  @override
  String saveFailedWithError(String error) {
    return '保存失败: $error';
  }

  @override
  String get retry => '重试';

  @override
  String get all => '全部';

  @override
  String get downloadingTab => '下载中';

  @override
  String get waiting => '等待中';

  @override
  String get paused => '已暂停';

  @override
  String get completedTab => '已完成';

  @override
  String get searchTasks => '搜索任务名称...';

  @override
  String get closeSearch => '关闭搜索';

  @override
  String get search => '搜索';

  @override
  String get refresh => '刷新';

  @override
  String get noTasks => '暂无任务';

  @override
  String get moreActions => '更多操作';

  @override
  String get pause => '暂停';

  @override
  String get resume => '恢复';

  @override
  String get copyLink => '复制链接';

  @override
  String get fileInfoCard => '文件信息卡片';

  @override
  String get downloadInfoCard => '下载信息';

  @override
  String get serverInfoCard => '服务器信息';

  @override
  String get taskId => '任务ID';

  @override
  String get status => '状态';

  @override
  String get loading => '加载中...';

  @override
  String get progress => '进度';

  @override
  String get downloadSpeed => '下载速度';

  @override
  String get uploadSpeed => '上传速度';

  @override
  String get downloaded => '已下载';

  @override
  String get remainingTime => '剩余时间';

  @override
  String get downloaderLabel => '下载器';

  @override
  String get unknown => '未知';

  @override
  String get tracker => 'Tracker';

  @override
  String get connections => '连接数';

  @override
  String get seeds => '种子数';

  @override
  String get peers => 'Peer数';

  @override
  String get confirmDeleteTask => '确定要删除这个任务吗？';

  @override
  String get pauseFeatureInDev => '暂停功能开发中';

  @override
  String get resumeFeatureInDev => '继续功能开发中';

  @override
  String get deleteFeatureInDev => '删除功能开发中';

  @override
  String get copyFeatureInDev => '复制功能开发中';

  @override
  String downloaderStatusSemantics(String name, String type, String status) {
    return '$name, $type, 状态: $status';
  }

  @override
  String taskStatusSemantics(String name, String status, String progress) {
    return '$name, 状态: $status, 进度: $progress%';
  }

  @override
  String statCardSemantics(String label, String value) {
    return '$label: $value';
  }

  @override
  String get noDownloaderHint =>
      '还没有添加下载器。添加 Aria2、qBittorrent 或 Transmission 开始管理下载任务';

  @override
  String get language => '语言';

  @override
  String get themeMode => '主题模式';

  @override
  String get themeModeSystem => '跟随系统';

  @override
  String get themeModeLight => '浅色';

  @override
  String get themeModeDark => '深色';

  @override
  String get selectThemeMode => '选择主题模式';

  @override
  String get fileInfoSection => '文件信息';

  @override
  String get downloadInfoSection => '下载信息';

  @override
  String get connectionInfoSection => '连接信息';

  @override
  String get fileName => '文件名';

  @override
  String get fileCount => '包含文件数';

  @override
  String get currentDownloadSpeed => '当前下载速度';

  @override
  String get currentUploadSpeed => '当前上传速度';

  @override
  String get downloadedOverTotal => '已下载 / 总大小';

  @override
  String get downloaderName => '下载器名称';

  @override
  String get connectionCount => '连接数';

  @override
  String speedValue(String value) {
    return '速度 $value';
  }

  @override
  String get downloaderNotExistDeleted => '下载器不存在或已被删除';

  @override
  String get editDownloader => '编辑下载器';

  @override
  String get basicInfo => '基础信息';

  @override
  String get downloaderNameField => '下载器名称';

  @override
  String get pleaseEnterDownloaderName => '请输入下载器名称';

  @override
  String get downloaderTypeField => '下载器类型';

  @override
  String get serverAddressField => '服务器地址';

  @override
  String get pleaseEnterServerAddress => '请输入服务器地址';

  @override
  String get portInvalid => '端口无效';

  @override
  String get usernameField => '用户名';

  @override
  String get passwordField => '密码';

  @override
  String get saveConfigButton => '保存配置';

  @override
  String get connectionSuccess => '连接成功';

  @override
  String versionTooLow(String actual, String min) {
    return '版本过低：当前 $actual，需 ≥$min';
  }

  @override
  String get authFailedCheck => '认证失败：请检查用户名/密码';

  @override
  String get cannotConnect => '无法连接：请检查地址/端口/网络';

  @override
  String get downloaderNotSupportConfig => '该下载器不支持配置';

  @override
  String get pleaseEnterNonNegativeNumber => '请输入非负整数';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '中文';

  @override
  String get languageJapanese => '日本語';

  @override
  String get selectLanguage => '选择语言';

  @override
  String get deleteWithFiles => '同时删除已下载的文件';

  @override
  String get login => '登录';

  @override
  String get loginSubtitle => '登录以同步您的数据';

  @override
  String get registerAccount => '注册账号';

  @override
  String get emailAddress => '邮箱';

  @override
  String get verificationCode => '验证码';

  @override
  String get nicknameOptional => '昵称（选填）';

  @override
  String get confirmPassword => '确认密码';

  @override
  String get sendCode => '发送验证码';

  @override
  String get sendingCode => '发送中...';

  @override
  String get verificationCodeSent => '验证码已发送';

  @override
  String sendCodeCountdown(int seconds) {
    return '${seconds}s';
  }

  @override
  String get loginTermsNotice => '登录即表示您同意我们的服务条款和隐私政策';

  @override
  String get loginError => '登录失败，请重试';

  @override
  String get emailAddressInvalid => '请输入有效的邮箱地址';

  @override
  String get passwordRequired => '请输入密码';

  @override
  String get verificationCodeRequired => '请输入验证码';

  @override
  String get passwordMismatch => '两次输入的密码不一致';

  @override
  String get signOut => '退出登录';

  @override
  String get confirmSignOut => '确定要退出登录吗？';

  @override
  String get account => '账户';

  @override
  String get notSignedIn => '未登录';

  @override
  String get tapToSignIn => '点击登录';

  @override
  String get settingsSubtitle => '应用设置与个性化选项';

  @override
  String get vipUser => 'VIP 用户';

  @override
  String get normalUser => '普通用户';

  @override
  String get my => '我的';

  @override
  String get enterLinkOrTorrentFile => '请输入下载链接或选择 torrent 文件';

  @override
  String get torrentReadFailed => '种子文件读取失败，请重新选择';

  @override
  String get chooseTaskSourceTitle => '选择提交来源';

  @override
  String get chooseTaskSourceMessage => '当前同时存在链接和种子文件，请选择本次下载要使用的来源';

  @override
  String get useLinkSource => '使用链接';

  @override
  String get useTorrentSource => '使用种子文件';

  @override
  String selectedTorrentFile(String fileName) {
    return '已选择：$fileName';
  }

  @override
  String get remove => '移除';

  @override
  String get selectDownloaderStep => '1. 选择下载器';

  @override
  String get selectDownloaderDesc => '选择用于下载此任务的下载器';

  @override
  String get downloadLinkStep => '2. 下载链接';

  @override
  String get downloadLinkDesc => '支持 HTTP、HTTPS、磁力链接';

  @override
  String get savePathStep => '3. 保存路径';

  @override
  String get savePathDesc => '留空则使用下载器默认路径';

  @override
  String get optionalTag => '（可选）';

  @override
  String get selectTorrentFile => '选择 torrent 文件';

  @override
  String get torrentUploadHint => '支持 .torrent 文件上传';

  @override
  String get selectFolder => '选择';

  @override
  String get checkForUpdates => '检查更新';

  @override
  String get newVersionAvailable => '发现新版本';

  @override
  String get updateAvailableBadge => '可更新';

  @override
  String get upToDate => '当前已是最新版本';

  @override
  String get updateAvailableTitle => '发现新版本';

  @override
  String get updateAvailableMessage => 'Google Play 上已有更新版本可用。';

  @override
  String get githubStableUpdateAvailableMessage => 'GitHub 上已有新的正式版本可用。';

  @override
  String get githubBetaUpdateAvailableMessage => 'GitHub 上已有新的 Beta 版本可用。';

  @override
  String get updateNow => '去更新';

  @override
  String get openGooglePlay => '前往 Google Play';

  @override
  String get openGitHubRelease => '前往 GitHub';

  @override
  String get later => '稍后';

  @override
  String get updateCheckUnavailable => '暂时无法检查更新';

  @override
  String get updateCheckNotSupported => '当前版本不支持自动检查更新';

  @override
  String get supportSectionTitle => '支持与分享';

  @override
  String get appSectionTitle => '应用';

  @override
  String get privacyPolicy => '隐私政策';

  @override
  String get privacyPolicyDesc => '查看我们的隐私政策';

  @override
  String get contactDeveloper => '联系开发者';

  @override
  String get contactDeveloperDesc => '通过 GitHub Issues 反馈问题';

  @override
  String get githubRepository => 'GitHub 项目';

  @override
  String get shareApp => '分享 App';

  @override
  String get shareAppDesc => '分享给朋友';

  @override
  String get openLinkFailed => '无法打开链接';

  @override
  String get shareFailed => '分享失败';

  @override
  String get windTorrentConsole => 'WindTorrent 控制台';

  @override
  String downloadersOnlineRatio(int onlineCount, int totalCount) {
    return '$onlineCount/$totalCount 下载器在线';
  }

  @override
  String get waitingForDownloaderConnection => '等待下载器连接';

  @override
  String get totalDownloadSpeed => '总下载速度';

  @override
  String get activeTasks => '活跃任务';

  @override
  String get totalUploadSpeed => '总上传速度';

  @override
  String get viewTasks => '查看任务';

  @override
  String get multiProtocolDownloaders => '多协议下载器';

  @override
  String get manageConfiguredDownloaders => '管理已配置的下载器';

  @override
  String get configuredDownloaders => '已配置下载器';

  @override
  String shareAppMessage(String appName, String url) {
    return '推荐你试试 $appName：$url';
  }

  @override
  String get taskTorrentInfoSection => '种子信息';

  @override
  String get taskTransferSection => '传输';

  @override
  String get taskDateSection => '日期';

  @override
  String get taskRuntimeSection => '运行时长';

  @override
  String get taskMoreDetails => '更多详情';

  @override
  String get taskFilesEntry => '文件';

  @override
  String get taskTrackersEntry => '服务器';

  @override
  String get taskPeersEntry => '节点';

  @override
  String get taskOptionsEntry => '选项';

  @override
  String get taskOptionsShellSubtitle => '优先级、带宽、分享率与闲置限制';

  @override
  String get totalSize => '总大小';

  @override
  String get privacy => '私有性';

  @override
  String get creator => '创建者';

  @override
  String get createdAt => '创建时间';

  @override
  String get magnet => '磁力链接';

  @override
  String get totalDownloaded => '总下载量';

  @override
  String get availability => '可用性';

  @override
  String get totalUploaded => '总上传量';

  @override
  String get shareRatio => '分享率';

  @override
  String get averageSpeed => '平均速度';

  @override
  String get addedAt => '添加时间';

  @override
  String get completedAt => '完成时间';

  @override
  String get lastActivityAt => '最近活动';

  @override
  String get downloadDuration => '下载时长';

  @override
  String get seedingDuration => '做种时长';

  @override
  String get yes => '是';

  @override
  String get no => '否';

  @override
  String get transmissionNoFiles => '暂无文件';

  @override
  String get transmissionNoTrackers => '暂无服务器';

  @override
  String get transmissionNoPeers => '暂无节点';

  @override
  String get transmissionTransferPriority => '传输优先级';

  @override
  String get transmissionBandwidth => '带宽';

  @override
  String get transmissionShareRatioLimit => '分享率限制';

  @override
  String get transmissionIdleLimit => '空闲限制';

  @override
  String get transmissionPriorityLow => '低';

  @override
  String get transmissionPriorityNormal => '正常';

  @override
  String get transmissionPriorityHigh => '高';

  @override
  String get transmissionLimitGlobal => '全局';

  @override
  String get transmissionLimitDisabled => '禁用';

  @override
  String get transmissionLimitCustom => '自定义';

  @override
  String get transmissionHonorGlobalLimits => '遵循全局带宽限制';

  @override
  String get transmissionDownloadLimit => '下载限速 (KB/s)';

  @override
  String get transmissionUploadLimit => '上传限速 (KB/s)';

  @override
  String get transmissionRatioValue => '比率值';

  @override
  String get transmissionIdleMinutes => '分钟';

  @override
  String transmissionTier(int tier) {
    return '层级 $tier';
  }

  @override
  String transmissionSeeds(int count) {
    return '做种: $count';
  }

  @override
  String transmissionLeeches(int count) {
    return '下载: $count';
  }

  @override
  String transmissionDownloads(int count) {
    return '已完成: $count';
  }

  @override
  String transmissionDownloadSpeed(String speed) {
    return '下载: $speed';
  }

  @override
  String transmissionUploadSpeed(String speed) {
    return '上传: $speed';
  }

  @override
  String get qbitProgressSection => '进度';

  @override
  String get qbitHttpSourcesSection => 'HTTP 源';

  @override
  String get qbitServersEntry => '服务器';

  @override
  String get qbitOptionsEntry => '选项';

  @override
  String get qbitOptionsSubtitle => '分类与标签';

  @override
  String get qbitNoHttpSources => '无 HTTP 源';

  @override
  String get qbitNoSources => '无来源';

  @override
  String get qbitNoPeers => '无节点';

  @override
  String get qbitNoFiles => '无文件';

  @override
  String get qbitQueuePriorityTitle => '队列优先级';

  @override
  String get qbitQueueActionUnchanged => '不变';

  @override
  String get qbitQueueActionTop => '置顶';

  @override
  String get qbitQueueActionIncrease => '上移';

  @override
  String get qbitQueueActionDecrease => '下移';

  @override
  String get qbitQueueActionBottom => '置底';

  @override
  String get qbitCategoryLabel => '分类';

  @override
  String get qbitCategoryHelper => '选择已有分类或输入新分类';

  @override
  String get qbitTagsLabel => '标签';

  @override
  String get qbitTagsHelper => '用逗号分隔多个标签';

  @override
  String get qbitOptionsSaved => '选项已保存';

  @override
  String get qbitDone => '完成';

  @override
  String get qbitDownload => '下载';

  @override
  String get qbitUpload => '上传';

  @override
  String get qbitEta => '剩余时间';

  @override
  String get qbitDownloaded => '已下载';

  @override
  String get qbitUploaded => '已上传';

  @override
  String get qbitRatio => '分享率';

  @override
  String get qbitAvgDownload => '平均下载';

  @override
  String get qbitAvgUpload => '平均上传';

  @override
  String get qbitSeeds => '做种';

  @override
  String get qbitLeechs => '下载中';

  @override
  String get qbitTotalSize => '总大小';

  @override
  String get qbitPieces => '分片';

  @override
  String get qbitSavePath => '保存路径';

  @override
  String get qbitState => '状态';

  @override
  String qbitFileCount(int count) {
    return '$count 个文件';
  }

  @override
  String qbitSourceCount(int count) {
    return '$count 个来源';
  }

  @override
  String qbitPeerCount(int count) {
    return '$count 个节点';
  }

  @override
  String qbitHttpSourceCount(int count) {
    return '$count 个 HTTP 源';
  }

  @override
  String get qbitPeersLabel => '节点';

  @override
  String get qbitSeedsLabel => '做种';

  @override
  String get qbitDownloadsLabel => '下载';

  @override
  String get qbitDownloadedLabel => '已下载';

  @override
  String get qbitFileAffinity => '文件关联';

  @override
  String get qbitConnections => '连接数';

  @override
  String get qbitActivityTime => '活动时间';

  @override
  String get qbitSeedingTime => '做种时间';

  @override
  String get qbitPriority => '优先级';

  @override
  String get qbitBlocks => '区块';

  @override
  String get qbitInfoHashV1 => '信息哈希值V1';

  @override
  String get qbitInfoHashV2 => '信息哈希值V2';

  @override
  String qbitPeerSummary(int active, int total) {
    return '$active 个活跃节点(总计$total个节点)';
  }

  @override
  String get qbitNotAvailable => 'N/A';

  @override
  String get qbitDlLimit => '限制下载';

  @override
  String get qbitUpLimit => '限制上传';

  @override
  String get qbitAvailability => '流行度';

  @override
  String get aria2Health => '健康度';

  @override
  String get aria2OverOneDay => '超过一天';

  @override
  String get aria2MaxDlSpeed => '最大下载速度 (KB/s)';

  @override
  String get aria2MaxUlSpeed => '最大上传速度 (KB/s)';

  @override
  String get aria2MaxConnections => '最大连接数';

  @override
  String get aria2Unlimited => '0 = 无限制';

  @override
  String get aria2OptionsSaved => '选项已保存';

  @override
  String get aria2NoTrackers => '无 Tracker';

  @override
  String get aria2PeerClient => '客户端';

  @override
  String get aria2PeerStatus => '状态';

  @override
  String get aria2ChokingUs => '阻塞中';

  @override
  String get aria2WeChoke => '我们阻塞';

  @override
  String get aria2Unchoke => '正常';

  @override
  String get aria2Seeder => '做种';

  @override
  String get aria2Leech => '下载';

  @override
  String get backupRestore => '备份与恢复';

  @override
  String get webDavServer => 'WebDAV 服务器';

  @override
  String get webDavConfigSubtitle => '配置用于备份与恢复的远端目录';

  @override
  String get webDavNotConfigured => '未配置';

  @override
  String get webDavRootUrl => '根地址';

  @override
  String get webDavDirectory => '远端目录';

  @override
  String get webDavPasswordOrToken => '密码或应用令牌';

  @override
  String get testConnection => '测试连接';

  @override
  String get testingConnection => '测试中...';

  @override
  String get saving => '保存中...';

  @override
  String get webDavRootUrlInvalid => '请输入有效的 WebDAV 地址';

  @override
  String get webDavDirectoryRequired => '请输入远端目录';

  @override
  String get usernameRequired => '请输入用户名';

  @override
  String get webDavPasswordRequired => '请输入密码或应用令牌';

  @override
  String get backupToWebDav => '备份到 WebDAV';

  @override
  String get restoreFromWebDav => '从 WebDAV 恢复';

  @override
  String get signInToUseBackup => '登录后可使用备份功能';

  @override
  String get configureWebDavToUseBackup => '请先配置 WebDAV';

  @override
  String get backupIncludesCredentials => '包含下载器地址和登录凭据';

  @override
  String get confirmRestoreAndReplace => '确认恢复并替换';

  @override
  String get restoreWillReplaceAllDownloaders => '此操作将替换当前所有下载器配置。';

  @override
  String get restoreCreatesRollbackSnapshot => '恢复前将创建本地回滚快照';

  @override
  String get undoLastRestore => '撤销上次恢复';

  @override
  String get selectBackupVersion => '选择备份版本';

  @override
  String get noBackupsAvailable => '暂无可用备份';

  @override
  String get latestBackupLabel => '最新备份';

  @override
  String get latestBackupChip => '最新';

  @override
  String get confirmDeleteBackupVersion => '删除备份版本？';

  @override
  String get deleteBackupVersionMessage => '该备份版本将从 WebDAV 中永久删除。';

  @override
  String get restoreInProgress => '正在恢复...';

  @override
  String get backupInProgress => '正在备份...';

  @override
  String get backupTimeJustNow => '刚刚';

  @override
  String backupTimeMinutesAgo(int count) {
    return '$count分钟前';
  }

  @override
  String backupTimeHoursAgo(int count) {
    return '$count小时前';
  }

  @override
  String backupTimeDaysAgo(int count) {
    return '$count天前';
  }

  @override
  String backupDownloaderCount(int count) {
    return '$count 个下载器';
  }

  @override
  String get restoreSuccess => '恢复成功';

  @override
  String get exportSuccess => '备份导出成功';

  @override
  String get forgotPassword => '忘记密码？';

  @override
  String get resetPassword => '重置密码';

  @override
  String get resetPasswordSubtitle => '通过邮箱验证码设置新密码';

  @override
  String get newPassword => '新密码';

  @override
  String get confirmNewPassword => '确认新密码';

  @override
  String get resetPasswordSuccess => '密码已重置，请使用新密码登录';
}
