// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appName => 'WindTorrent';

  @override
  String get settings => '設定';

  @override
  String get addTask => 'ダウンロード追加';

  @override
  String get downloaderManagement => 'ダウンローダー管理';

  @override
  String get downloadersTab => 'ダウンローダー';

  @override
  String get config => '設定';

  @override
  String get edit => '編集';

  @override
  String get taskList => 'タスクリスト';

  @override
  String get taskDetail => 'タスク詳細';

  @override
  String get unnamedTask => '無名タスク';

  @override
  String get myDownloaders => 'マイダウンローダー';

  @override
  String get manage => '管理';

  @override
  String get data => '概要';

  @override
  String get taskStatusOverview => 'タスク状態の概要';

  @override
  String taskTotalKicker(int count) {
    return '合計 $count タスク';
  }

  @override
  String get downloaderDistribution => 'ダウンローダー分布';

  @override
  String totalDownloaders(int count) {
    return 'ダウンローダー $count 件';
  }

  @override
  String get tapDownloaderToManageTasks => 'ダウンローダーをタップしてタスクを表示または管理';

  @override
  String get management => '管理';

  @override
  String get addTaskButton => 'タスク追加';

  @override
  String get addFromClipboard => 'クリップボードから追加';

  @override
  String get clipboardEmpty => 'クリップボードが空です';

  @override
  String get noValidLinkInClipboard => 'クリップボードに有効なダウンロードリンクが見つかりません';

  @override
  String get noDownloadersYet => 'ダウンローダーが追加されていません';

  @override
  String get addDownloaderHint =>
      'Aria2、qBittorrent、または\nTransmission を追加してダウンロード管理を開始';

  @override
  String get addDownloader => 'ダウンローダーを追加';

  @override
  String get downloading => 'ダウンロード中';

  @override
  String get seeding => 'シード中';

  @override
  String get completed => '完了';

  @override
  String get totalSpeed => '合計速度';

  @override
  String get online => 'オンライン';

  @override
  String get offline => 'オフライン';

  @override
  String get error => 'エラー';

  @override
  String tasks(int count) {
    return '$count タスク';
  }

  @override
  String get generalSettings => '一般設定';

  @override
  String get about => 'について';

  @override
  String get aboutWindTorrent => 'WindTorrent について';

  @override
  String get aboutSubtitle => 'バージョン情報、OSS ライセンス、謝辞';

  @override
  String get version => 'バージョン';

  @override
  String get rateApp => 'アプリを評価';

  @override
  String get rateAppDesc => 'WindTorrentをお楽しみいただけていますか？評価をお願いします！';

  @override
  String get back => '戻る';

  @override
  String get switchOn => 'オン';

  @override
  String get switchOff => 'オフ';

  @override
  String get selectDownloader => 'ダウンローダーを選択';

  @override
  String get noDownloadersConfigured => 'ダウンローダーが設定されていません。先に追加してください';

  @override
  String get enterLinkOrTorrent => 'リンクまたはトレントを入力';

  @override
  String get pasteHint => 'Magnet / HTTP / FTP リンクを貼り付け';

  @override
  String get paste => '貼り付け';

  @override
  String get torrentFile => 'トレントファイル';

  @override
  String get savePath => '保存パス';

  @override
  String get defaultSavePath => 'デフォルトの保存パス';

  @override
  String get qbitBulkInputHint => 'qBittorrent モード：1 行に 1 つのマグネットリンク';

  @override
  String get loadingDefaultSavePath => 'デフォルトの保存パスを読み込み中...';

  @override
  String get startDownload => 'ダウンロード開始';

  @override
  String get torrentFeatureInDev => 'トレントファイル機能は開発中です';

  @override
  String get pleaseSelectDownloader => '先にダウンローダーを選択してください';

  @override
  String get taskAddedSuccess => 'タスクが追加されました';

  @override
  String get taskAddFailed => 'タスクの追加に失敗しました。ダウンローダーの状態を確認してください';

  @override
  String taskAddFailedWithError(String error) {
    return 'タスクの追加に失敗しました: $error';
  }

  @override
  String get pleaseEnterUrl => 'ダウンロードリンクを入力してください';

  @override
  String get pleaseEnterValidUrl => '有効なダウンロードリンクを入力してください';

  @override
  String get pathContainsInvalidChars => 'パスに無効な文字が含まれています';

  @override
  String get deleteDownloader => 'ダウンローダーを削除';

  @override
  String get confirmDeleteDownloader => 'このダウンローダーを削除してもよろしいですか？';

  @override
  String get cancel => 'キャンセル';

  @override
  String get delete => '削除';

  @override
  String get tapToAddDownloader => '下のボタンをタップしてダウンローダーを追加';

  @override
  String get addDownloaderTitle => 'ダウンローダーを追加';

  @override
  String get editDownloaderTitle => 'ダウンローダーを編集';

  @override
  String get name => '名前';

  @override
  String get nameHint => 'ダウンローダーに名前を付けてください';

  @override
  String get pleaseEnterName => '名前を入力してください';

  @override
  String get hostAddress => 'ホストアドレス';

  @override
  String get hostExample => '例: 192.168.1.100';

  @override
  String get pleaseEnterHost => 'ホストアドレスを入力してください';

  @override
  String get port => 'ポート';

  @override
  String get portExample => '例: 6800';

  @override
  String get pleaseEnterPort => 'ポートを入力してください';

  @override
  String get pleaseEnterValidPort => '有効なポート番号を入力してください';

  @override
  String get rpcSecret => 'RPCシークレット';

  @override
  String get optional => '任意';

  @override
  String get username => 'ユーザー名';

  @override
  String get password => 'パスワード';

  @override
  String get addButton => '追加';

  @override
  String get saveButton => '保存';

  @override
  String get connectionFailed => '接続に失敗しました。アドレス、ポート、認証情報を確認してください';

  @override
  String get downloaderAddedSuccess => 'ダウンローダーが追加されました';

  @override
  String get downloaderUpdatedSuccess => 'ダウンローダーが更新されました';

  @override
  String downloaderServiceSettings(String name) {
    return '$name サービス設定';
  }

  @override
  String get downloader => 'ダウンローダー';

  @override
  String get downloaderNotExist => 'ダウンローダーが存在しません';

  @override
  String get saveConfig => '設定を保存';

  @override
  String get enterSpeedLimit => '速度制限を入力';

  @override
  String get notEnabled => '無効';

  @override
  String get pleaseEnterValidNumber => '有効な数値を入力してください';

  @override
  String get downloaderOfflineCannotFetchConfig => 'ダウンローダーがオフラインです。設定を取得できません';

  @override
  String get configSaveSuccess => '設定が保存されました';

  @override
  String get saveFailedRetry => '保存に失敗しました。再試行してください';

  @override
  String loadConfigFailed(String error) {
    return '設定の読み込みに失敗しました: $error';
  }

  @override
  String saveFailedWithError(String error) {
    return '保存に失敗しました: $error';
  }

  @override
  String get retry => '再試行';

  @override
  String get all => 'すべて';

  @override
  String get downloadingTab => 'ダウンロード中';

  @override
  String get waiting => '待機中';

  @override
  String get paused => '一時停止';

  @override
  String get completedTab => '完了';

  @override
  String get searchTasks => 'タスクを検索...';

  @override
  String get closeSearch => '検索を閉じる';

  @override
  String get search => '検索';

  @override
  String get refresh => '更新';

  @override
  String get noTasks => 'タスクはまだありません';

  @override
  String get moreActions => 'その他の操作';

  @override
  String get pause => '一時停止';

  @override
  String get resume => '再開';

  @override
  String get copyLink => 'リンクをコピー';

  @override
  String get fileInfoCard => 'ファイル情報';

  @override
  String get downloadInfoCard => 'ダウンロード情報';

  @override
  String get serverInfoCard => 'サーバー情報';

  @override
  String get taskId => 'タスクID';

  @override
  String get status => 'ステータス';

  @override
  String get loading => '読み込み中...';

  @override
  String get progress => '進捗';

  @override
  String get downloadSpeed => 'ダウンロード速度';

  @override
  String get uploadSpeed => 'アップロード速度';

  @override
  String get downloaded => 'ダウンロード済み';

  @override
  String get remainingTime => '残り時間';

  @override
  String get downloaderLabel => 'ダウンローダー';

  @override
  String get unknown => '不明';

  @override
  String get tracker => 'トラッカー';

  @override
  String get connections => '接続数';

  @override
  String get seeds => 'シード数';

  @override
  String get peers => 'ピア数';

  @override
  String get confirmDeleteTask => 'このタスクを削除してもよろしいですか？';

  @override
  String get pauseFeatureInDev => '一時停止機能は開発中です';

  @override
  String get resumeFeatureInDev => '再開機能は開発中です';

  @override
  String get deleteFeatureInDev => '削除機能は開発中です';

  @override
  String get copyFeatureInDev => 'コピー機能は開発中です';

  @override
  String downloaderStatusSemantics(String name, String type, String status) {
    return '$name, $type, ステータス: $status';
  }

  @override
  String taskStatusSemantics(String name, String status, String progress) {
    return '$name, ステータス: $status, 進捗: $progress%';
  }

  @override
  String statCardSemantics(String label, String value) {
    return '$label: $value';
  }

  @override
  String get noDownloaderHint =>
      'ダウンローダーがまだありません。Aria2、qBittorrent、または Transmission を追加してダウンロード管理を開始してください';

  @override
  String get language => '言語';

  @override
  String get themeMode => 'テーマモード';

  @override
  String get themeModeSystem => 'システムに従う';

  @override
  String get themeModeLight => 'ライト';

  @override
  String get themeModeDark => 'ダーク';

  @override
  String get selectThemeMode => 'テーマモードを選択';

  @override
  String get fileInfoSection => 'ファイル情報';

  @override
  String get downloadInfoSection => 'ダウンロード情報';

  @override
  String get connectionInfoSection => '接続情報';

  @override
  String get fileName => 'ファイル名';

  @override
  String get fileCount => 'ファイル数';

  @override
  String get currentDownloadSpeed => '現在のダウンロード速度';

  @override
  String get currentUploadSpeed => '現在のアップロード速度';

  @override
  String get downloadedOverTotal => 'ダウンロード済み / 合計';

  @override
  String get downloaderName => 'ダウンローダー名';

  @override
  String get connectionCount => '接続数';

  @override
  String speedValue(String value) {
    return '速度 $value';
  }

  @override
  String get downloaderNotExistDeleted => 'ダウンローダーが存在しないか削除されました';

  @override
  String get editDownloader => 'ダウンローダーを編集';

  @override
  String get basicInfo => '基本情報';

  @override
  String get downloaderNameField => 'ダウンローダー名';

  @override
  String get pleaseEnterDownloaderName => 'ダウンローダー名を入力してください';

  @override
  String get downloaderTypeField => 'ダウンローダーの種類';

  @override
  String get serverAddressField => 'サーバーアドレス';

  @override
  String get pleaseEnterServerAddress => 'サーバーアドレスを入力してください';

  @override
  String get portInvalid => '無効なポートです';

  @override
  String get usernameField => 'ユーザー名';

  @override
  String get passwordField => 'パスワード';

  @override
  String get saveConfigButton => '設定を保存';

  @override
  String get connectionSuccess => '接続に成功しました';

  @override
  String versionTooLow(String actual, String min) {
    return 'バージョンが低すぎます：現在 $actual、≥$min が必要';
  }

  @override
  String get authFailedCheck => '認証失敗：ユーザー名/パスワードを確認してください';

  @override
  String get cannotConnect => '接続できません：アドレス/ポート/ネットワークを確認してください';

  @override
  String get downloaderNotSupportConfig => 'このダウンローダーは設定に対応していません';

  @override
  String get pleaseEnterNonNegativeNumber => '0 以上の数値を入力してください';

  @override
  String get languageSystem => 'システムに従う';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChinese => '中文';

  @override
  String get languageJapanese => '日本語';

  @override
  String get selectLanguage => '言語を選択';

  @override
  String get deleteWithFiles => 'ダウンロード済みファイルも削除';

  @override
  String get login => 'サインイン';

  @override
  String get loginSubtitle => 'サインインしてデータを同期';

  @override
  String get registerAccount => 'アカウント作成';

  @override
  String get emailAddress => 'メールアドレス';

  @override
  String get verificationCode => '認証コード';

  @override
  String get nicknameOptional => 'ニックネーム（任意）';

  @override
  String get confirmPassword => 'パスワード確認';

  @override
  String get sendCode => 'コード送信';

  @override
  String get sendingCode => '送信中...';

  @override
  String get verificationCodeSent => '認証コードを送信しました';

  @override
  String sendCodeCountdown(int seconds) {
    return '${seconds}s';
  }

  @override
  String get loginTermsNotice => 'サインインすることで、利用規約とプライバシーポリシーに同意したことになります';

  @override
  String get loginError => 'サインインに失敗しました。もう一度お試しください';

  @override
  String get emailAddressInvalid => '有効なメールアドレスを入力してください';

  @override
  String get passwordRequired => 'パスワードを入力してください';

  @override
  String get verificationCodeRequired => '認証コードを入力してください';

  @override
  String get passwordMismatch => 'パスワードが一致しません';

  @override
  String get signOut => 'サインアウト';

  @override
  String get confirmSignOut => 'サインアウトしてもよろしいですか？';

  @override
  String get account => 'アカウント';

  @override
  String get notSignedIn => '未サインイン';

  @override
  String get tapToSignIn => 'タップしてサインイン';

  @override
  String get settingsSubtitle => 'アプリ設定とパーソナライズ項目';

  @override
  String get vipUser => 'VIPユーザー';

  @override
  String get normalUser => '一般ユーザー';

  @override
  String get my => 'マイ';

  @override
  String get enterLinkOrTorrentFile => 'ダウンロードリンクを入力するか、トレントファイルを選択してください';

  @override
  String get torrentReadFailed => 'トレントファイルの読み取りに失敗しました。再度選択してください';

  @override
  String get chooseTaskSourceTitle => 'ソースを選択';

  @override
  String get chooseTaskSourceMessage =>
      'リンクとトレントファイルの両方が存在します。どちらを使用するか選択してください';

  @override
  String get useLinkSource => 'リンクを使用';

  @override
  String get useTorrentSource => 'トレントファイルを使用';

  @override
  String selectedTorrentFile(String fileName) {
    return '選択済み：$fileName';
  }

  @override
  String get remove => '削除';

  @override
  String get selectDownloaderStep => '1. ダウンローダーを選択';

  @override
  String get selectDownloaderDesc => 'このタスクに使用するダウンローダーを選択';

  @override
  String get downloadLinkStep => '2. ダウンロードリンク';

  @override
  String get downloadLinkDesc => 'HTTP、HTTPS、マグネットリンク対応';

  @override
  String get savePathStep => '3. 保存パス';

  @override
  String get savePathDesc => '空欄の場合はデフォルトパスを使用';

  @override
  String get optionalTag => '（任意）';

  @override
  String get selectTorrentFile => 'トレントファイルを選択';

  @override
  String get torrentUploadHint => '.torrent ファイルのアップロードに対応';

  @override
  String get selectFolder => '選択';

  @override
  String get checkForUpdates => '更新を確認';

  @override
  String get newVersionAvailable => '新しいバージョンがあります';

  @override
  String get updateAvailableBadge => '更新あり';

  @override
  String get upToDate => '最新バージョンです';

  @override
  String get updateAvailableTitle => '更新があります';

  @override
  String get updateAvailableMessage =>
      'Google Play に新しい WindTorrent バージョンがあります。';

  @override
  String get githubStableUpdateAvailableMessage =>
      'GitHub に新しい WindTorrent 正式版があります。';

  @override
  String get githubBetaUpdateAvailableMessage =>
      'GitHub に新しい WindTorrent ベータ版があります。';

  @override
  String get updateNow => '更新する';

  @override
  String get openGooglePlay => 'Google Play を開く';

  @override
  String get openGitHubRelease => 'GitHub を開く';

  @override
  String get later => 'あとで';

  @override
  String get updateCheckUnavailable => '更新を確認できませんでした';

  @override
  String get updateCheckNotSupported => 'このバージョンは自動更新に対応していません';

  @override
  String get supportSectionTitle => 'サポートと共有';

  @override
  String get appSectionTitle => 'アプリ';

  @override
  String get privacyPolicy => 'プライバシーポリシー';

  @override
  String get privacyPolicyDesc => 'プライバシーポリシーを表示';

  @override
  String get contactDeveloper => '開発者に連絡';

  @override
  String get contactDeveloperDesc => 'GitHub Issues で問題を報告';

  @override
  String get githubRepository => 'GitHub リポジトリ';

  @override
  String get shareApp => 'アプリを共有';

  @override
  String get shareAppDesc => '友達に共有';

  @override
  String get openLinkFailed => 'リンクを開けません';

  @override
  String get shareFailed => '共有に失敗しました';

  @override
  String get windTorrentConsole => 'WindTorrent コンソール';

  @override
  String downloadersOnlineRatio(int onlineCount, int totalCount) {
    return '$onlineCount/$totalCount 台のダウンローダーがオンライン';
  }

  @override
  String get waitingForDownloaderConnection => 'ダウンローダーの接続を待機中';

  @override
  String get totalDownloadSpeed => '合計ダウンロード速度';

  @override
  String get activeTasks => 'アクティブなタスク';

  @override
  String get totalUploadSpeed => '合計アップロード速度';

  @override
  String get viewTasks => 'タスクを表示';

  @override
  String get multiProtocolDownloaders => 'マルチプロトコルダウンローダー';

  @override
  String get manageConfiguredDownloaders => '設定済みダウンローダーを管理';

  @override
  String get configuredDownloaders => '設定済みダウンローダー';

  @override
  String shareAppMessage(String appName, String url) {
    return '$appNameをチェックしてみて：$url';
  }

  @override
  String get taskTorrentInfoSection => 'トレント情報';

  @override
  String get taskTransferSection => '転送';

  @override
  String get taskDateSection => '日付';

  @override
  String get taskRuntimeSection => '実行時間';

  @override
  String get taskMoreDetails => '詳細';

  @override
  String get taskFilesEntry => 'ファイル';

  @override
  String get taskTrackersEntry => 'トラッカー';

  @override
  String get taskPeersEntry => 'ピア';

  @override
  String get taskOptionsEntry => 'オプション';

  @override
  String get taskOptionsShellSubtitle => '優先度・帯域・比率・アイドル制限';

  @override
  String get totalSize => '合計サイズ';

  @override
  String get privacy => 'プライベート';

  @override
  String get creator => '作成者';

  @override
  String get createdAt => '作成日時';

  @override
  String get magnet => 'マグネット';

  @override
  String get totalDownloaded => '総ダウンロード量';

  @override
  String get availability => '可用性';

  @override
  String get totalUploaded => '総アップロード量';

  @override
  String get shareRatio => '共有比';

  @override
  String get averageSpeed => '平均速度';

  @override
  String get addedAt => '追加日時';

  @override
  String get completedAt => '完了日時';

  @override
  String get lastActivityAt => '最終アクティビティ';

  @override
  String get downloadDuration => 'ダウンロード時間';

  @override
  String get seedingDuration => 'シード時間';

  @override
  String get yes => 'はい';

  @override
  String get no => 'いいえ';

  @override
  String get transmissionNoFiles => 'ファイルなし';

  @override
  String get transmissionNoTrackers => 'トラッカーなし';

  @override
  String get transmissionNoPeers => 'ピアなし';

  @override
  String get transmissionTransferPriority => '転送優先度';

  @override
  String get transmissionBandwidth => '帯域';

  @override
  String get transmissionShareRatioLimit => '共有比制限';

  @override
  String get transmissionIdleLimit => 'アイドル制限';

  @override
  String get transmissionPriorityLow => '低';

  @override
  String get transmissionPriorityNormal => '通常';

  @override
  String get transmissionPriorityHigh => '高';

  @override
  String get transmissionLimitGlobal => 'グローバル';

  @override
  String get transmissionLimitDisabled => '無効';

  @override
  String get transmissionLimitCustom => 'カスタム';

  @override
  String get transmissionHonorGlobalLimits => 'グローバル帯域制限に従う';

  @override
  String get transmissionDownloadLimit => 'ダウンロード制限 (KB/s)';

  @override
  String get transmissionUploadLimit => 'アップロード制限 (KB/s)';

  @override
  String get transmissionRatioValue => '比率値';

  @override
  String get transmissionIdleMinutes => '分';

  @override
  String transmissionTier(int tier) {
    return 'ティア $tier';
  }

  @override
  String transmissionSeeds(int count) {
    return 'シード: $count';
  }

  @override
  String transmissionLeeches(int count) {
    return 'リーチ: $count';
  }

  @override
  String transmissionDownloads(int count) {
    return '完了: $count';
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
  String get qbitProgressSection => '進行状況';

  @override
  String get qbitHttpSourcesSection => 'HTTP ソース';

  @override
  String get qbitServersEntry => 'サーバー';

  @override
  String get qbitOptionsEntry => 'オプション';

  @override
  String get qbitOptionsSubtitle => 'カテゴリとタグ';

  @override
  String get qbitNoHttpSources => 'HTTP ソースなし';

  @override
  String get qbitNoSources => 'ソースなし';

  @override
  String get qbitNoPeers => 'ピアなし';

  @override
  String get qbitNoFiles => 'ファイルなし';

  @override
  String get qbitQueuePriorityTitle => 'キュー優先度';

  @override
  String get qbitQueueActionUnchanged => '変更なし';

  @override
  String get qbitQueueActionTop => '先頭へ';

  @override
  String get qbitQueueActionIncrease => '上へ';

  @override
  String get qbitQueueActionDecrease => '下へ';

  @override
  String get qbitQueueActionBottom => '末尾へ';

  @override
  String get qbitCategoryLabel => 'カテゴリ';

  @override
  String get qbitCategoryHelper => '既存のカテゴリを選択するか新規入力';

  @override
  String get qbitTagsLabel => 'タグ';

  @override
  String get qbitTagsHelper => 'カンマで区切って入力';

  @override
  String get qbitOptionsSaved => 'オプションを保存しました';

  @override
  String get qbitDone => '完了';

  @override
  String get qbitDownload => 'ダウンロード';

  @override
  String get qbitUpload => 'アップロード';

  @override
  String get qbitEta => '残り時間';

  @override
  String get qbitDownloaded => 'ダウンロード済み';

  @override
  String get qbitUploaded => 'アップロード済み';

  @override
  String get qbitRatio => '共有率';

  @override
  String get qbitAvgDownload => '平均DL';

  @override
  String get qbitAvgUpload => '平均UL';

  @override
  String get qbitSeeds => 'シード';

  @override
  String get qbitLeechs => 'リーチ';

  @override
  String get qbitTotalSize => '合計サイズ';

  @override
  String get qbitPieces => 'ピース';

  @override
  String get qbitSavePath => '保存先';

  @override
  String get qbitState => '状態';

  @override
  String qbitFileCount(int count) {
    return '$count ファイル';
  }

  @override
  String qbitSourceCount(int count) {
    return '$count ソース';
  }

  @override
  String qbitPeerCount(int count) {
    return '$count ピア';
  }

  @override
  String qbitHttpSourceCount(int count) {
    return '$count HTTP ソース';
  }

  @override
  String get qbitPeersLabel => 'ピア';

  @override
  String get qbitSeedsLabel => 'シード';

  @override
  String get qbitDownloadsLabel => 'DL数';

  @override
  String get qbitDownloadedLabel => 'DL済み';

  @override
  String get qbitFileAffinity => 'ファイル親和性';

  @override
  String get qbitConnections => '接続数';

  @override
  String get qbitActivityTime => 'アクティブ時間';

  @override
  String get qbitSeedingTime => 'シード時間';

  @override
  String get qbitPriority => '優先度';

  @override
  String get qbitBlocks => 'ブロック';

  @override
  String get qbitInfoHashV1 => 'Info hash v1';

  @override
  String get qbitInfoHashV2 => 'Info hash v2';

  @override
  String qbitPeerSummary(int active, int total) {
    return '$active アクティブ ($total 合計)';
  }

  @override
  String get qbitNotAvailable => 'N/A';

  @override
  String get qbitDlLimit => 'DL制限';

  @override
  String get qbitUpLimit => 'UL制限';

  @override
  String get qbitAvailability => '可用性';

  @override
  String get aria2Health => 'ヘルス';

  @override
  String get aria2OverOneDay => '1日以上';

  @override
  String get aria2MaxDlSpeed => '最大DL速度 (KB/s)';

  @override
  String get aria2MaxUlSpeed => '最大UL速度 (KB/s)';

  @override
  String get aria2MaxConnections => '最大接続数';

  @override
  String get aria2Unlimited => '0 = 無制限';

  @override
  String get aria2OptionsSaved => 'オプション保存済み';

  @override
  String get aria2NoTrackers => 'トラッカーなし';

  @override
  String get aria2PeerClient => 'クライアント';

  @override
  String get aria2PeerStatus => 'ステータス';

  @override
  String get aria2ChokingUs => 'チョーク中';

  @override
  String get aria2WeChoke => '自チョーク';

  @override
  String get aria2Unchoke => 'アンチョーク';

  @override
  String get aria2Seeder => 'シード';

  @override
  String get aria2Leech => 'リーチ';

  @override
  String get backupRestore => 'バックアップと復元';

  @override
  String get webDavServer => 'WebDAV サーバー';

  @override
  String get webDavConfigSubtitle => 'バックアップと復元に使うリモートフォルダを設定';

  @override
  String get webDavNotConfigured => '未設定';

  @override
  String get webDavRootUrl => 'ルート URL';

  @override
  String get webDavDirectory => 'リモートディレクトリ';

  @override
  String get webDavPasswordOrToken => 'パスワードまたはアプリトークン';

  @override
  String get testConnection => '接続テスト';

  @override
  String get testingConnection => 'テスト中...';

  @override
  String get saving => '保存中...';

  @override
  String get webDavRootUrlInvalid => '有効な WebDAV URL を入力してください';

  @override
  String get webDavDirectoryRequired => 'リモートディレクトリを入力してください';

  @override
  String get usernameRequired => 'ユーザー名を入力してください';

  @override
  String get webDavPasswordRequired => 'パスワードまたはアプリトークンを入力してください';

  @override
  String get backupToWebDav => 'WebDAV にバックアップ';

  @override
  String get restoreFromWebDav => 'WebDAV から復元';

  @override
  String get signInToUseBackup => 'バックアップを使うにはサインインしてください';

  @override
  String get configureWebDavToUseBackup => 'バックアップを使うには WebDAV を設定してください';

  @override
  String get backupIncludesCredentials => 'ダウンローダーのアドレスと認証情報を含みます';

  @override
  String get confirmRestoreAndReplace => '復元と置換を確認';

  @override
  String get restoreWillReplaceAllDownloaders => '現在のすべてのダウンローダー設定が置き換えられます。';

  @override
  String get restoreCreatesRollbackSnapshot => '復元前にローカルロールバックスナップショットが作成されます';

  @override
  String get undoLastRestore => '最後の復元を元に戻す';

  @override
  String get selectBackupVersion => 'バックアップバージョンを選択';

  @override
  String get noBackupsAvailable => '利用可能なバックアップがありません';

  @override
  String get latestBackupLabel => '最新バックアップ';

  @override
  String get latestBackupChip => '最新';

  @override
  String get confirmDeleteBackupVersion => 'バックアップを削除しますか？';

  @override
  String get deleteBackupVersionMessage => 'このバックアップは WebDAV から完全に削除されます。';

  @override
  String get restoreInProgress => '復元中...';

  @override
  String get backupInProgress => 'バックアップ中...';

  @override
  String get backupTimeJustNow => 'たった今';

  @override
  String backupTimeMinutesAgo(int count) {
    return '$count分前';
  }

  @override
  String backupTimeHoursAgo(int count) {
    return '$count時間前';
  }

  @override
  String backupTimeDaysAgo(int count) {
    return '$count日前';
  }

  @override
  String backupDownloaderCount(int count) {
    return '$count 台のダウンローダー';
  }

  @override
  String get restoreSuccess => '復元が完了しました';

  @override
  String get exportSuccess => 'バックアップが完了しました';

  @override
  String get forgotPassword => 'パスワードをお忘れですか？';

  @override
  String get resetPassword => 'パスワードリセット';

  @override
  String get resetPasswordSubtitle => 'メール認証コードで新しいパスワードを設定';

  @override
  String get newPassword => '新しいパスワード';

  @override
  String get confirmNewPassword => '新しいパスワード（確認）';

  @override
  String get resetPasswordSuccess => 'パスワードがリセットされました。新しいパスワードでログインしてください';
}
