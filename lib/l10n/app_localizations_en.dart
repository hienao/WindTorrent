// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'WindTorrent';

  @override
  String get settings => 'Settings';

  @override
  String get addTask => 'Add Download';

  @override
  String get downloaderManagement => 'Downloader Management';

  @override
  String get downloadersTab => 'Downloaders';

  @override
  String get config => 'Config';

  @override
  String get edit => 'Edit';

  @override
  String get taskList => 'Task List';

  @override
  String get taskDetail => 'Task Details';

  @override
  String get unnamedTask => 'Unnamed Task';

  @override
  String get myDownloaders => 'My Downloaders';

  @override
  String get manage => 'Manage';

  @override
  String get data => 'Overview';

  @override
  String get taskStatusOverview => 'Task Status Overview';

  @override
  String taskTotalKicker(int count) {
    return 'Total $count tasks';
  }

  @override
  String get downloaderDistribution => 'Downloader Distribution';

  @override
  String totalDownloaders(int count) {
    return '$count downloaders';
  }

  @override
  String get tapDownloaderToManageTasks =>
      'Tap a downloader to view or manage its tasks';

  @override
  String get management => 'Management';

  @override
  String get addTaskButton => 'Add Task';

  @override
  String get addFromClipboard => 'Add from Clipboard';

  @override
  String get clipboardEmpty => 'Clipboard is empty';

  @override
  String get noValidLinkInClipboard =>
      'No valid download link found in clipboard';

  @override
  String get noDownloadersYet => 'No downloaders added yet';

  @override
  String get addDownloaderHint =>
      'Add Aria2, qBittorrent, or\nTransmission to start managing downloads';

  @override
  String get addDownloader => 'Add Downloader';

  @override
  String get downloading => 'Downloading';

  @override
  String get seeding => 'Seeding';

  @override
  String get completed => 'Completed';

  @override
  String get totalSpeed => 'Total Speed';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get error => 'Error';

  @override
  String tasks(int count) {
    return '$count tasks';
  }

  @override
  String get generalSettings => 'General';

  @override
  String get about => 'About';

  @override
  String get aboutWindTorrent => 'About WindTorrent';

  @override
  String get aboutSubtitle =>
      'Version info, open-source licenses, and acknowledgements';

  @override
  String get version => 'Version';

  @override
  String get rateApp => 'Rate App';

  @override
  String get rateAppDesc => 'Enjoying WindTorrent? Give us a rating!';

  @override
  String get back => 'Back';

  @override
  String get switchOn => 'On';

  @override
  String get switchOff => 'Off';

  @override
  String get selectDownloader => 'Select Downloader';

  @override
  String get noDownloadersConfigured =>
      'No downloaders configured, please add one first';

  @override
  String get enterLinkOrTorrent => 'Enter Link or Torrent';

  @override
  String get pasteHint => 'Paste Magnet / HTTP / FTP link';

  @override
  String get paste => 'Paste';

  @override
  String get torrentFile => 'Torrent File';

  @override
  String get savePath => 'Save Path';

  @override
  String get defaultSavePath => 'Default save path';

  @override
  String get qbitBulkInputHint => 'qBittorrent mode: one magnet link per line';

  @override
  String get loadingDefaultSavePath => 'Loading default save path...';

  @override
  String get startDownload => 'Start Download';

  @override
  String get torrentFeatureInDev => 'Torrent file feature is under development';

  @override
  String get pleaseSelectDownloader => 'Please select a downloader first';

  @override
  String get taskAddedSuccess => 'Task added successfully';

  @override
  String get taskAddFailed => 'Task add failed, please check downloader status';

  @override
  String taskAddFailedWithError(String error) {
    return 'Task add failed: $error';
  }

  @override
  String get pleaseEnterUrl => 'Please enter a download link';

  @override
  String get pleaseEnterValidUrl => 'Please enter a valid download link';

  @override
  String get pathContainsInvalidChars => 'Path contains invalid characters';

  @override
  String get deleteDownloader => 'Delete Downloader';

  @override
  String get confirmDeleteDownloader =>
      'Are you sure you want to delete this downloader?';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get tapToAddDownloader => 'Tap the button below to add a downloader';

  @override
  String get addDownloaderTitle => 'Add Downloader';

  @override
  String get editDownloaderTitle => 'Edit Downloader';

  @override
  String get name => 'Name';

  @override
  String get nameHint => 'Give the downloader a name';

  @override
  String get pleaseEnterName => 'Please enter a name';

  @override
  String get hostAddress => 'Host Address';

  @override
  String get hostExample => 'e.g. 192.168.1.100';

  @override
  String get pleaseEnterHost => 'Please enter a host address';

  @override
  String get port => 'Port';

  @override
  String get portExample => 'e.g. 6800';

  @override
  String get pleaseEnterPort => 'Please enter a port';

  @override
  String get pleaseEnterValidPort => 'Please enter a valid port number';

  @override
  String get rpcSecret => 'RPC Secret';

  @override
  String get optional => 'Optional';

  @override
  String get username => 'Username';

  @override
  String get password => 'Password';

  @override
  String get addButton => 'Add';

  @override
  String get saveButton => 'Save';

  @override
  String get connectionFailed =>
      'Connection failed, please check address, port and credentials';

  @override
  String get downloaderAddedSuccess => 'Downloader added successfully';

  @override
  String get downloaderUpdatedSuccess => 'Downloader updated successfully';

  @override
  String downloaderServiceSettings(String name) {
    return '$name Service Settings';
  }

  @override
  String get downloader => 'Downloader';

  @override
  String get downloaderNotExist => 'Downloader does not exist';

  @override
  String get saveConfig => 'Save Config';

  @override
  String get enterSpeedLimit => 'Enter speed limit';

  @override
  String get notEnabled => 'Not enabled';

  @override
  String get pleaseEnterValidNumber => 'Please enter a valid number';

  @override
  String get downloaderOfflineCannotFetchConfig =>
      'Downloader is offline, unable to fetch configuration';

  @override
  String get configSaveSuccess => 'Configuration saved successfully';

  @override
  String get saveFailedRetry => 'Save failed, please retry';

  @override
  String loadConfigFailed(String error) {
    return 'Failed to load configuration: $error';
  }

  @override
  String saveFailedWithError(String error) {
    return 'Save failed: $error';
  }

  @override
  String get retry => 'Retry';

  @override
  String get all => 'All';

  @override
  String get downloadingTab => 'Downloading';

  @override
  String get waiting => 'Waiting';

  @override
  String get paused => 'Paused';

  @override
  String get completedTab => 'Completed';

  @override
  String get searchTasks => 'Search tasks...';

  @override
  String get closeSearch => 'Close Search';

  @override
  String get search => 'Search';

  @override
  String get refresh => 'Refresh';

  @override
  String get noTasks => 'No tasks yet';

  @override
  String get moreActions => 'More actions';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get copyLink => 'Copy Link';

  @override
  String get fileInfoCard => 'File Info';

  @override
  String get downloadInfoCard => 'Download Info';

  @override
  String get serverInfoCard => 'Server Info';

  @override
  String get taskId => 'Task ID';

  @override
  String get status => 'Status';

  @override
  String get loading => 'Loading...';

  @override
  String get progress => 'Progress';

  @override
  String get downloadSpeed => 'Download Speed';

  @override
  String get uploadSpeed => 'Upload Speed';

  @override
  String get downloaded => 'Downloaded';

  @override
  String get remainingTime => 'Remaining Time';

  @override
  String get downloaderLabel => 'Downloader';

  @override
  String get unknown => 'Unknown';

  @override
  String get tracker => 'Tracker';

  @override
  String get connections => 'Connections';

  @override
  String get seeds => 'Seeds';

  @override
  String get peers => 'Peers';

  @override
  String get confirmDeleteTask => 'Are you sure you want to delete this task?';

  @override
  String get pauseFeatureInDev => 'Pause feature is under development';

  @override
  String get resumeFeatureInDev => 'Resume feature is under development';

  @override
  String get deleteFeatureInDev => 'Delete feature is under development';

  @override
  String get copyFeatureInDev => 'Copy feature is under development';

  @override
  String downloaderStatusSemantics(String name, String type, String status) {
    return '$name, $type, Status: $status';
  }

  @override
  String taskStatusSemantics(String name, String status, String progress) {
    return '$name, Status: $status, Progress: $progress%';
  }

  @override
  String statCardSemantics(String label, String value) {
    return '$label: $value';
  }

  @override
  String get noDownloaderHint =>
      'No downloaders yet. Add Aria2, qBittorrent or Transmission to start managing downloads';

  @override
  String get language => 'Language';

  @override
  String get themeMode => 'Theme mode';

  @override
  String get themeModeSystem => 'Follow system';

  @override
  String get themeModeLight => 'Light';

  @override
  String get themeModeDark => 'Dark';

  @override
  String get selectThemeMode => 'Select Theme Mode';

  @override
  String get fileInfoSection => 'File Info';

  @override
  String get downloadInfoSection => 'Download Info';

  @override
  String get connectionInfoSection => 'Connection Info';

  @override
  String get fileName => 'File name';

  @override
  String get fileCount => 'Files';

  @override
  String get currentDownloadSpeed => 'Download speed';

  @override
  String get currentUploadSpeed => 'Upload speed';

  @override
  String get downloadedOverTotal => 'Downloaded / Total';

  @override
  String get downloaderName => 'Downloader name';

  @override
  String get connectionCount => 'Connections';

  @override
  String speedValue(String value) {
    return 'Speed $value';
  }

  @override
  String get downloaderNotExistDeleted =>
      'Downloader does not exist or has been deleted';

  @override
  String get editDownloader => 'Edit Downloader';

  @override
  String get basicInfo => 'Basic info';

  @override
  String get downloaderNameField => 'Downloader name';

  @override
  String get pleaseEnterDownloaderName => 'Please enter a downloader name';

  @override
  String get downloaderTypeField => 'Downloader type';

  @override
  String get serverAddressField => 'Server address';

  @override
  String get pleaseEnterServerAddress => 'Please enter a server address';

  @override
  String get portInvalid => 'Invalid port';

  @override
  String get usernameField => 'Username';

  @override
  String get passwordField => 'Password';

  @override
  String get saveConfigButton => 'Save Config';

  @override
  String get connectionSuccess => 'Connected successfully';

  @override
  String versionTooLow(String actual, String min) {
    return 'Version too low: current $actual, requires ≥ $min';
  }

  @override
  String get authFailedCheck =>
      'Authentication failed: please check username/password';

  @override
  String get cannotConnect =>
      'Cannot connect: please check address/port/network';

  @override
  String get downloaderNotSupportConfig =>
      'This downloader does not support configuration';

  @override
  String get pleaseEnterNonNegativeNumber =>
      'Please enter a non-negative number';

  @override
  String get languageSystem => 'Follow System';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '中文';

  @override
  String get languageJapanese => '日本語';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get deleteWithFiles => 'Also delete downloaded files';

  @override
  String get login => 'Sign In';

  @override
  String get loginSubtitle => 'Sign in to sync your data';

  @override
  String get registerAccount => 'Create Account';

  @override
  String get emailAddress => 'Email';

  @override
  String get verificationCode => 'Verification code';

  @override
  String get nicknameOptional => 'Nickname (optional)';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get sendCode => 'Send code';

  @override
  String get sendingCode => 'Sending...';

  @override
  String get verificationCodeSent => 'Verification code sent';

  @override
  String sendCodeCountdown(int seconds) {
    return '${seconds}s';
  }

  @override
  String get loginTermsNotice =>
      'By signing in, you agree to our Terms of Service and Privacy Policy';

  @override
  String get loginError => 'Sign in failed, please try again';

  @override
  String get emailAddressInvalid => 'Please enter a valid email address';

  @override
  String get passwordRequired => 'Please enter a password';

  @override
  String get verificationCodeRequired => 'Please enter the verification code';

  @override
  String get passwordMismatch => 'Passwords do not match';

  @override
  String get signOut => 'Sign Out';

  @override
  String get confirmSignOut => 'Are you sure you want to sign out?';

  @override
  String get account => 'Account';

  @override
  String get notSignedIn => 'Not signed in';

  @override
  String get tapToSignIn => 'Tap to sign in';

  @override
  String get settingsSubtitle => 'App settings and personalization options';

  @override
  String get vipUser => 'VIP User';

  @override
  String get normalUser => 'Normal User';

  @override
  String get my => 'Mine';

  @override
  String get enterLinkOrTorrentFile =>
      'Enter a download link or choose a torrent file';

  @override
  String get torrentReadFailed =>
      'Failed to read the torrent file. Please choose it again.';

  @override
  String get chooseTaskSourceTitle => 'Choose task source';

  @override
  String get chooseTaskSourceMessage =>
      'Both a link and a torrent file are present. Choose which one to use.';

  @override
  String get useLinkSource => 'Use link';

  @override
  String get useTorrentSource => 'Use torrent file';

  @override
  String selectedTorrentFile(String fileName) {
    return 'Selected: $fileName';
  }

  @override
  String get remove => 'Remove';

  @override
  String get selectDownloaderStep => '1. Select Downloader';

  @override
  String get selectDownloaderDesc => 'Select a downloader for this task';

  @override
  String get downloadLinkStep => '2. Download Link';

  @override
  String get downloadLinkDesc => 'Supports HTTP, HTTPS, Magnet links';

  @override
  String get savePathStep => '3. Save Path';

  @override
  String get savePathDesc => 'Leave empty to use default path';

  @override
  String get optionalTag => '(Optional)';

  @override
  String get selectTorrentFile => 'Select torrent file';

  @override
  String get torrentUploadHint => 'Supports .torrent file upload';

  @override
  String get selectFolder => 'Select';

  @override
  String get checkForUpdates => 'Check for Updates';

  @override
  String get newVersionAvailable => 'New version available';

  @override
  String get updateAvailableBadge => 'Update available';

  @override
  String get upToDate => 'You\'re up to date';

  @override
  String get updateAvailableTitle => 'Update available';

  @override
  String get updateAvailableMessage =>
      'A newer WindTorrent version is available on Google Play.';

  @override
  String get githubStableUpdateAvailableMessage =>
      'A newer stable WindTorrent version is available on GitHub.';

  @override
  String get githubBetaUpdateAvailableMessage =>
      'A newer WindTorrent Beta version is available on GitHub.';

  @override
  String get updateNow => 'Update now';

  @override
  String get openGooglePlay => 'Open Google Play';

  @override
  String get openGitHubRelease => 'Open GitHub';

  @override
  String get later => 'Later';

  @override
  String get updateCheckUnavailable => 'Couldn\'t check for updates';

  @override
  String get updateCheckNotSupported =>
      'Automatic updates aren\'t supported on this build';

  @override
  String get supportSectionTitle => 'Support & Share';

  @override
  String get appSectionTitle => 'App';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String get privacyPolicyDesc => 'View our privacy policy';

  @override
  String get contactDeveloper => 'Contact Developer';

  @override
  String get contactDeveloperDesc => 'Report issues on GitHub Issues';

  @override
  String get githubRepository => 'GitHub Repository';

  @override
  String get shareApp => 'Share App';

  @override
  String get shareAppDesc => 'Share with friends';

  @override
  String get openLinkFailed => 'Unable to open link';

  @override
  String get shareFailed => 'Share failed';

  @override
  String get windTorrentConsole => 'WindTorrent Console';

  @override
  String downloadersOnlineRatio(int onlineCount, int totalCount) {
    return '$onlineCount/$totalCount downloaders online';
  }

  @override
  String get waitingForDownloaderConnection =>
      'Waiting for downloader connection';

  @override
  String get totalDownloadSpeed => 'Total download speed';

  @override
  String get activeTasks => 'Active tasks';

  @override
  String get totalUploadSpeed => 'Total upload speed';

  @override
  String get viewTasks => 'View tasks';

  @override
  String get multiProtocolDownloaders => 'Multi-protocol downloaders';

  @override
  String get manageConfiguredDownloaders => 'Manage configured downloaders';

  @override
  String get configuredDownloaders => 'Configured downloaders';

  @override
  String shareAppMessage(String appName, String url) {
    return 'Check out $appName: $url';
  }

  @override
  String get taskTorrentInfoSection => 'Torrent Info';

  @override
  String get taskTransferSection => 'Transfer';

  @override
  String get taskDateSection => 'Date';

  @override
  String get taskRuntimeSection => 'Runtime';

  @override
  String get taskMoreDetails => 'More Details';

  @override
  String get taskFilesEntry => 'Files';

  @override
  String get taskTrackersEntry => 'Trackers';

  @override
  String get taskPeersEntry => 'Peers';

  @override
  String get taskOptionsEntry => 'Options';

  @override
  String get taskOptionsShellSubtitle =>
      'Priority, bandwidth, ratio, and idle limits';

  @override
  String get totalSize => 'Total Size';

  @override
  String get privacy => 'Privacy';

  @override
  String get creator => 'Creator';

  @override
  String get createdAt => 'Created At';

  @override
  String get magnet => 'Magnet';

  @override
  String get totalDownloaded => 'Total Downloaded';

  @override
  String get availability => 'Availability';

  @override
  String get totalUploaded => 'Total Uploaded';

  @override
  String get shareRatio => 'Share Ratio';

  @override
  String get averageSpeed => 'Average Speed';

  @override
  String get addedAt => 'Added';

  @override
  String get completedAt => 'Completed';

  @override
  String get lastActivityAt => 'Last Activity';

  @override
  String get downloadDuration => 'Download';

  @override
  String get seedingDuration => 'Seeding';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get transmissionNoFiles => 'No files';

  @override
  String get transmissionNoTrackers => 'No trackers';

  @override
  String get transmissionNoPeers => 'No peers';

  @override
  String get transmissionTransferPriority => 'Transfer Priority';

  @override
  String get transmissionBandwidth => 'Bandwidth';

  @override
  String get transmissionShareRatioLimit => 'Share Ratio Limit';

  @override
  String get transmissionIdleLimit => 'Idle Limit';

  @override
  String get transmissionPriorityLow => 'Low';

  @override
  String get transmissionPriorityNormal => 'Normal';

  @override
  String get transmissionPriorityHigh => 'High';

  @override
  String get transmissionLimitGlobal => 'Global';

  @override
  String get transmissionLimitDisabled => 'Disabled';

  @override
  String get transmissionLimitCustom => 'Custom';

  @override
  String get transmissionHonorGlobalLimits => 'Honor global bandwidth limits';

  @override
  String get transmissionDownloadLimit => 'Download limit (KB/s)';

  @override
  String get transmissionUploadLimit => 'Upload limit (KB/s)';

  @override
  String get transmissionRatioValue => 'Ratio value';

  @override
  String get transmissionIdleMinutes => 'Minutes';

  @override
  String transmissionTier(int tier) {
    return 'Tier $tier';
  }

  @override
  String transmissionSeeds(int count) {
    return 'Seeds: $count';
  }

  @override
  String transmissionLeeches(int count) {
    return 'Leeches: $count';
  }

  @override
  String transmissionDownloads(int count) {
    return 'Downloads: $count';
  }

  @override
  String transmissionDownloadSpeed(String speed) {
    return 'DL: $speed';
  }

  @override
  String transmissionUploadSpeed(String speed) {
    return 'UL: $speed';
  }

  @override
  String get qbitProgressSection => 'Progress';

  @override
  String get qbitHttpSourcesSection => 'HTTP Sources';

  @override
  String get qbitServersEntry => 'Servers';

  @override
  String get qbitOptionsEntry => 'Options';

  @override
  String get qbitOptionsSubtitle => 'Category & tags';

  @override
  String get qbitNoHttpSources => 'No HTTP sources';

  @override
  String get qbitNoSources => 'No sources';

  @override
  String get qbitNoPeers => 'No peers';

  @override
  String get qbitNoFiles => 'No files';

  @override
  String get qbitQueuePriorityTitle => 'Queue priority';

  @override
  String get qbitQueueActionUnchanged => 'No change';

  @override
  String get qbitQueueActionTop => 'Top of queue';

  @override
  String get qbitQueueActionIncrease => 'Move up';

  @override
  String get qbitQueueActionDecrease => 'Move down';

  @override
  String get qbitQueueActionBottom => 'Bottom of queue';

  @override
  String get qbitCategoryLabel => 'Category';

  @override
  String get qbitCategoryHelper =>
      'Choose an existing category or type a new one';

  @override
  String get qbitTagsLabel => 'Tags';

  @override
  String get qbitTagsHelper => 'Separate tags with commas';

  @override
  String get qbitOptionsSaved => 'Options saved';

  @override
  String get qbitDone => 'Done';

  @override
  String get qbitDownload => 'Download';

  @override
  String get qbitUpload => 'Upload';

  @override
  String get qbitEta => 'ETA';

  @override
  String get qbitDownloaded => 'Downloaded';

  @override
  String get qbitUploaded => 'Uploaded';

  @override
  String get qbitRatio => 'Ratio';

  @override
  String get qbitAvgDownload => 'Avg download';

  @override
  String get qbitAvgUpload => 'Avg upload';

  @override
  String get qbitSeeds => 'Seeds';

  @override
  String get qbitLeechs => 'Leechs';

  @override
  String get qbitTotalSize => 'Total size';

  @override
  String get qbitPieces => 'Pieces';

  @override
  String get qbitSavePath => 'Save path';

  @override
  String get qbitState => 'State';

  @override
  String qbitFileCount(int count) {
    return '$count files';
  }

  @override
  String qbitSourceCount(int count) {
    return '$count sources';
  }

  @override
  String qbitPeerCount(int count) {
    return '$count peers';
  }

  @override
  String qbitHttpSourceCount(int count) {
    return '$count HTTP source(s)';
  }

  @override
  String get qbitPeersLabel => 'Peers';

  @override
  String get qbitSeedsLabel => 'Seeds';

  @override
  String get qbitDownloadsLabel => 'Downloads';

  @override
  String get qbitDownloadedLabel => 'Downloaded';

  @override
  String get qbitFileAffinity => 'file affinity';

  @override
  String get qbitConnections => 'Connections';

  @override
  String get qbitActivityTime => 'Activity time';

  @override
  String get qbitSeedingTime => 'Seeding time';

  @override
  String get qbitPriority => 'Priority';

  @override
  String get qbitBlocks => 'Blocks';

  @override
  String get qbitInfoHashV1 => 'Info hash v1';

  @override
  String get qbitInfoHashV2 => 'Info hash v2';

  @override
  String qbitPeerSummary(int active, int total) {
    return '$active active ($total total)';
  }

  @override
  String get qbitNotAvailable => 'N/A';

  @override
  String get qbitDlLimit => 'DL limit';

  @override
  String get qbitUpLimit => 'UL limit';

  @override
  String get qbitAvailability => 'Availability';

  @override
  String get aria2Health => 'Health';

  @override
  String get aria2OverOneDay => '> 1 day';

  @override
  String get aria2MaxDlSpeed => 'Max Download (KB/s)';

  @override
  String get aria2MaxUlSpeed => 'Max Upload (KB/s)';

  @override
  String get aria2MaxConnections => 'Max Connections';

  @override
  String get aria2Unlimited => '0 = unlimited';

  @override
  String get aria2OptionsSaved => 'Options saved';

  @override
  String get aria2NoTrackers => 'No trackers';

  @override
  String get aria2PeerClient => 'Client';

  @override
  String get aria2PeerStatus => 'Status';

  @override
  String get aria2ChokingUs => 'choking us';

  @override
  String get aria2WeChoke => 'we choke';

  @override
  String get aria2Unchoke => 'unchoke';

  @override
  String get aria2Seeder => 'SEED';

  @override
  String get aria2Leech => 'LEECH';

  @override
  String get backupRestore => 'Backup & Restore';

  @override
  String get webDavServer => 'WebDAV Server';

  @override
  String get webDavConfigSubtitle =>
      'Configure the remote folder used for backup and restore';

  @override
  String get webDavNotConfigured => 'Not configured';

  @override
  String get webDavRootUrl => 'Root URL';

  @override
  String get webDavDirectory => 'Remote directory';

  @override
  String get webDavPasswordOrToken => 'Password or app token';

  @override
  String get testConnection => 'Test';

  @override
  String get testingConnection => 'Testing...';

  @override
  String get saving => 'Saving...';

  @override
  String get webDavRootUrlInvalid => 'Please enter a valid WebDAV URL';

  @override
  String get webDavDirectoryRequired => 'Please enter the remote directory';

  @override
  String get usernameRequired => 'Please enter the username';

  @override
  String get webDavPasswordRequired => 'Please enter the password or app token';

  @override
  String get backupToWebDav => 'Back up to WebDAV';

  @override
  String get restoreFromWebDav => 'Restore from WebDAV';

  @override
  String get signInToUseBackup => 'Sign in to use backup';

  @override
  String get configureWebDavToUseBackup => 'Configure WebDAV to use backup';

  @override
  String get backupIncludesCredentials =>
      'Includes downloader addresses and credentials';

  @override
  String get confirmRestoreAndReplace => 'Confirm restore and replace';

  @override
  String get restoreWillReplaceAllDownloaders =>
      'This will replace all current downloader configurations.';

  @override
  String get restoreCreatesRollbackSnapshot =>
      'A local rollback snapshot will be created before restore';

  @override
  String get undoLastRestore => 'Undo last restore';

  @override
  String get selectBackupVersion => 'Select backup version';

  @override
  String get noBackupsAvailable => 'No backups available';

  @override
  String get latestBackupLabel => 'Latest backup';

  @override
  String get latestBackupChip => 'Latest';

  @override
  String get confirmDeleteBackupVersion => 'Delete backup version?';

  @override
  String get deleteBackupVersionMessage =>
      'This backup version will be permanently removed from WebDAV.';

  @override
  String get restoreInProgress => 'Restoring...';

  @override
  String get backupInProgress => 'Backing up...';

  @override
  String get backupTimeJustNow => 'Just now';

  @override
  String backupTimeMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String backupTimeHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String backupTimeDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String backupDownloaderCount(int count) {
    return '$count downloaders';
  }

  @override
  String get restoreSuccess => 'Restore completed successfully';

  @override
  String get exportSuccess => 'Backup exported successfully';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get resetPassword => 'Reset Password';

  @override
  String get resetPasswordSubtitle =>
      'Set a new password via email verification code';

  @override
  String get newPassword => 'New Password';

  @override
  String get confirmNewPassword => 'Confirm New Password';

  @override
  String get resetPasswordSuccess =>
      'Password reset. Please log in with your new password.';
}
