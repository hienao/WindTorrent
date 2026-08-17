import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('zh'),
  ];

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'WindTorrent'**
  String get appName;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @addTask.
  ///
  /// In en, this message translates to:
  /// **'Add Download'**
  String get addTask;

  /// No description provided for @downloaderManagement.
  ///
  /// In en, this message translates to:
  /// **'Downloader Management'**
  String get downloaderManagement;

  /// No description provided for @downloadersTab.
  ///
  /// In en, this message translates to:
  /// **'Downloaders'**
  String get downloadersTab;

  /// No description provided for @config.
  ///
  /// In en, this message translates to:
  /// **'Config'**
  String get config;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @taskList.
  ///
  /// In en, this message translates to:
  /// **'Task List'**
  String get taskList;

  /// No description provided for @taskDetail.
  ///
  /// In en, this message translates to:
  /// **'Task Details'**
  String get taskDetail;

  /// No description provided for @unnamedTask.
  ///
  /// In en, this message translates to:
  /// **'Unnamed Task'**
  String get unnamedTask;

  /// No description provided for @myDownloaders.
  ///
  /// In en, this message translates to:
  /// **'My Downloaders'**
  String get myDownloaders;

  /// No description provided for @manage.
  ///
  /// In en, this message translates to:
  /// **'Manage'**
  String get manage;

  /// No description provided for @data.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get data;

  /// No description provided for @taskStatusOverview.
  ///
  /// In en, this message translates to:
  /// **'Task Status Overview'**
  String get taskStatusOverview;

  /// No description provided for @taskTotalKicker.
  ///
  /// In en, this message translates to:
  /// **'Total {count} tasks'**
  String taskTotalKicker(int count);

  /// No description provided for @downloaderDistribution.
  ///
  /// In en, this message translates to:
  /// **'Downloader Distribution'**
  String get downloaderDistribution;

  /// No description provided for @totalDownloaders.
  ///
  /// In en, this message translates to:
  /// **'{count} downloaders'**
  String totalDownloaders(int count);

  /// No description provided for @tapDownloaderToManageTasks.
  ///
  /// In en, this message translates to:
  /// **'Tap a downloader to view or manage its tasks'**
  String get tapDownloaderToManageTasks;

  /// No description provided for @management.
  ///
  /// In en, this message translates to:
  /// **'Management'**
  String get management;

  /// No description provided for @addTaskButton.
  ///
  /// In en, this message translates to:
  /// **'Add Task'**
  String get addTaskButton;

  /// No description provided for @addFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Add from Clipboard'**
  String get addFromClipboard;

  /// No description provided for @clipboardEmpty.
  ///
  /// In en, this message translates to:
  /// **'Clipboard is empty'**
  String get clipboardEmpty;

  /// No description provided for @noValidLinkInClipboard.
  ///
  /// In en, this message translates to:
  /// **'No valid download link found in clipboard'**
  String get noValidLinkInClipboard;

  /// No description provided for @noDownloadersYet.
  ///
  /// In en, this message translates to:
  /// **'No downloaders added yet'**
  String get noDownloadersYet;

  /// No description provided for @addDownloaderHint.
  ///
  /// In en, this message translates to:
  /// **'Add Aria2, qBittorrent, or\nTransmission to start managing downloads'**
  String get addDownloaderHint;

  /// No description provided for @addDownloader.
  ///
  /// In en, this message translates to:
  /// **'Add Downloader'**
  String get addDownloader;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloading;

  /// No description provided for @seeding.
  ///
  /// In en, this message translates to:
  /// **'Seeding'**
  String get seeding;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @totalSpeed.
  ///
  /// In en, this message translates to:
  /// **'Total Speed'**
  String get totalSpeed;

  /// No description provided for @online.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get online;

  /// No description provided for @offline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offline;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @tasks.
  ///
  /// In en, this message translates to:
  /// **'{count} tasks'**
  String tasks(int count);

  /// No description provided for @generalSettings.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get generalSettings;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutWindTorrent.
  ///
  /// In en, this message translates to:
  /// **'About WindTorrent'**
  String get aboutWindTorrent;

  /// No description provided for @aboutSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Version info, open-source licenses, and acknowledgements'**
  String get aboutSubtitle;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @rateApp.
  ///
  /// In en, this message translates to:
  /// **'Rate App'**
  String get rateApp;

  /// No description provided for @rateAppDesc.
  ///
  /// In en, this message translates to:
  /// **'Enjoying WindTorrent? Give us a rating!'**
  String get rateAppDesc;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @switchOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get switchOn;

  /// No description provided for @switchOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get switchOff;

  /// No description provided for @selectDownloader.
  ///
  /// In en, this message translates to:
  /// **'Select Downloader'**
  String get selectDownloader;

  /// No description provided for @noDownloadersConfigured.
  ///
  /// In en, this message translates to:
  /// **'No downloaders configured, please add one first'**
  String get noDownloadersConfigured;

  /// No description provided for @enterLinkOrTorrent.
  ///
  /// In en, this message translates to:
  /// **'Enter Link or Torrent'**
  String get enterLinkOrTorrent;

  /// No description provided for @pasteHint.
  ///
  /// In en, this message translates to:
  /// **'Paste Magnet / HTTP / FTP link'**
  String get pasteHint;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @torrentFile.
  ///
  /// In en, this message translates to:
  /// **'Torrent File'**
  String get torrentFile;

  /// No description provided for @savePath.
  ///
  /// In en, this message translates to:
  /// **'Save Path'**
  String get savePath;

  /// No description provided for @defaultSavePath.
  ///
  /// In en, this message translates to:
  /// **'Default save path'**
  String get defaultSavePath;

  /// No description provided for @qbitBulkInputHint.
  ///
  /// In en, this message translates to:
  /// **'qBittorrent mode: one magnet link per line'**
  String get qbitBulkInputHint;

  /// No description provided for @loadingDefaultSavePath.
  ///
  /// In en, this message translates to:
  /// **'Loading default save path...'**
  String get loadingDefaultSavePath;

  /// No description provided for @startDownload.
  ///
  /// In en, this message translates to:
  /// **'Start Download'**
  String get startDownload;

  /// No description provided for @torrentFeatureInDev.
  ///
  /// In en, this message translates to:
  /// **'Torrent file feature is under development'**
  String get torrentFeatureInDev;

  /// No description provided for @pleaseSelectDownloader.
  ///
  /// In en, this message translates to:
  /// **'Please select a downloader first'**
  String get pleaseSelectDownloader;

  /// No description provided for @taskAddedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Task added successfully'**
  String get taskAddedSuccess;

  /// No description provided for @taskAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Task add failed, please check downloader status'**
  String get taskAddFailed;

  /// No description provided for @taskAddFailedWithError.
  ///
  /// In en, this message translates to:
  /// **'Task add failed: {error}'**
  String taskAddFailedWithError(String error);

  /// No description provided for @pleaseEnterUrl.
  ///
  /// In en, this message translates to:
  /// **'Please enter a download link'**
  String get pleaseEnterUrl;

  /// No description provided for @pleaseEnterValidUrl.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid download link'**
  String get pleaseEnterValidUrl;

  /// No description provided for @pathContainsInvalidChars.
  ///
  /// In en, this message translates to:
  /// **'Path contains invalid characters'**
  String get pathContainsInvalidChars;

  /// No description provided for @deleteDownloader.
  ///
  /// In en, this message translates to:
  /// **'Delete Downloader'**
  String get deleteDownloader;

  /// No description provided for @confirmDeleteDownloader.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this downloader?'**
  String get confirmDeleteDownloader;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @tapToAddDownloader.
  ///
  /// In en, this message translates to:
  /// **'Tap the button below to add a downloader'**
  String get tapToAddDownloader;

  /// Editor page title (add mode)
  ///
  /// In en, this message translates to:
  /// **'Add Downloader'**
  String get addDownloaderTitle;

  /// No description provided for @editDownloaderTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Downloader'**
  String get editDownloaderTitle;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @nameHint.
  ///
  /// In en, this message translates to:
  /// **'Give the downloader a name'**
  String get nameHint;

  /// No description provided for @pleaseEnterName.
  ///
  /// In en, this message translates to:
  /// **'Please enter a name'**
  String get pleaseEnterName;

  /// No description provided for @hostAddress.
  ///
  /// In en, this message translates to:
  /// **'Host Address'**
  String get hostAddress;

  /// No description provided for @hostExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. 192.168.1.100'**
  String get hostExample;

  /// No description provided for @pleaseEnterHost.
  ///
  /// In en, this message translates to:
  /// **'Please enter a host address'**
  String get pleaseEnterHost;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @portExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. 6800'**
  String get portExample;

  /// Editor form: port required validator
  ///
  /// In en, this message translates to:
  /// **'Please enter a port'**
  String get pleaseEnterPort;

  /// No description provided for @pleaseEnterValidPort.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid port number'**
  String get pleaseEnterValidPort;

  /// No description provided for @rpcSecret.
  ///
  /// In en, this message translates to:
  /// **'RPC Secret'**
  String get rpcSecret;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @addButton.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addButton;

  /// No description provided for @saveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get saveButton;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed, please check address, port and credentials'**
  String get connectionFailed;

  /// No description provided for @downloaderAddedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Downloader added successfully'**
  String get downloaderAddedSuccess;

  /// No description provided for @downloaderUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Downloader updated successfully'**
  String get downloaderUpdatedSuccess;

  /// No description provided for @downloaderServiceSettings.
  ///
  /// In en, this message translates to:
  /// **'{name} Service Settings'**
  String downloaderServiceSettings(String name);

  /// No description provided for @downloader.
  ///
  /// In en, this message translates to:
  /// **'Downloader'**
  String get downloader;

  /// No description provided for @downloaderNotExist.
  ///
  /// In en, this message translates to:
  /// **'Downloader does not exist'**
  String get downloaderNotExist;

  /// No description provided for @saveConfig.
  ///
  /// In en, this message translates to:
  /// **'Save Config'**
  String get saveConfig;

  /// No description provided for @enterSpeedLimit.
  ///
  /// In en, this message translates to:
  /// **'Enter speed limit'**
  String get enterSpeedLimit;

  /// No description provided for @notEnabled.
  ///
  /// In en, this message translates to:
  /// **'Not enabled'**
  String get notEnabled;

  /// No description provided for @pleaseEnterValidNumber.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid number'**
  String get pleaseEnterValidNumber;

  /// No description provided for @downloaderOfflineCannotFetchConfig.
  ///
  /// In en, this message translates to:
  /// **'Downloader is offline, unable to fetch configuration'**
  String get downloaderOfflineCannotFetchConfig;

  /// No description provided for @configSaveSuccess.
  ///
  /// In en, this message translates to:
  /// **'Configuration saved successfully'**
  String get configSaveSuccess;

  /// No description provided for @saveFailedRetry.
  ///
  /// In en, this message translates to:
  /// **'Save failed, please retry'**
  String get saveFailedRetry;

  /// No description provided for @loadConfigFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load configuration: {error}'**
  String loadConfigFailed(String error);

  /// No description provided for @saveFailedWithError.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String saveFailedWithError(String error);

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @downloadingTab.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloadingTab;

  /// No description provided for @waiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get waiting;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// No description provided for @completedTab.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedTab;

  /// No description provided for @searchTasks.
  ///
  /// In en, this message translates to:
  /// **'Search tasks...'**
  String get searchTasks;

  /// No description provided for @closeSearch.
  ///
  /// In en, this message translates to:
  /// **'Close Search'**
  String get closeSearch;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @noTasks.
  ///
  /// In en, this message translates to:
  /// **'No tasks yet'**
  String get noTasks;

  /// No description provided for @moreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get moreActions;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @copyLink.
  ///
  /// In en, this message translates to:
  /// **'Copy Link'**
  String get copyLink;

  /// No description provided for @fileInfoCard.
  ///
  /// In en, this message translates to:
  /// **'File Info'**
  String get fileInfoCard;

  /// No description provided for @downloadInfoCard.
  ///
  /// In en, this message translates to:
  /// **'Download Info'**
  String get downloadInfoCard;

  /// No description provided for @serverInfoCard.
  ///
  /// In en, this message translates to:
  /// **'Server Info'**
  String get serverInfoCard;

  /// No description provided for @taskId.
  ///
  /// In en, this message translates to:
  /// **'Task ID'**
  String get taskId;

  /// No description provided for @status.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get status;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @downloadSpeed.
  ///
  /// In en, this message translates to:
  /// **'Download Speed'**
  String get downloadSpeed;

  /// No description provided for @uploadSpeed.
  ///
  /// In en, this message translates to:
  /// **'Upload Speed'**
  String get uploadSpeed;

  /// No description provided for @downloaded.
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get downloaded;

  /// No description provided for @remainingTime.
  ///
  /// In en, this message translates to:
  /// **'Remaining Time'**
  String get remainingTime;

  /// No description provided for @downloaderLabel.
  ///
  /// In en, this message translates to:
  /// **'Downloader'**
  String get downloaderLabel;

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @tracker.
  ///
  /// In en, this message translates to:
  /// **'Tracker'**
  String get tracker;

  /// No description provided for @connections.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get connections;

  /// No description provided for @seeds.
  ///
  /// In en, this message translates to:
  /// **'Seeds'**
  String get seeds;

  /// No description provided for @peers.
  ///
  /// In en, this message translates to:
  /// **'Peers'**
  String get peers;

  /// No description provided for @confirmDeleteTask.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this task?'**
  String get confirmDeleteTask;

  /// No description provided for @pauseFeatureInDev.
  ///
  /// In en, this message translates to:
  /// **'Pause feature is under development'**
  String get pauseFeatureInDev;

  /// No description provided for @resumeFeatureInDev.
  ///
  /// In en, this message translates to:
  /// **'Resume feature is under development'**
  String get resumeFeatureInDev;

  /// No description provided for @deleteFeatureInDev.
  ///
  /// In en, this message translates to:
  /// **'Delete feature is under development'**
  String get deleteFeatureInDev;

  /// No description provided for @copyFeatureInDev.
  ///
  /// In en, this message translates to:
  /// **'Copy feature is under development'**
  String get copyFeatureInDev;

  /// No description provided for @downloaderStatusSemantics.
  ///
  /// In en, this message translates to:
  /// **'{name}, {type}, Status: {status}'**
  String downloaderStatusSemantics(String name, String type, String status);

  /// No description provided for @taskStatusSemantics.
  ///
  /// In en, this message translates to:
  /// **'{name}, Status: {status}, Progress: {progress}%'**
  String taskStatusSemantics(String name, String status, String progress);

  /// No description provided for @statCardSemantics.
  ///
  /// In en, this message translates to:
  /// **'{label}: {value}'**
  String statCardSemantics(String label, String value);

  /// No description provided for @noDownloaderHint.
  ///
  /// In en, this message translates to:
  /// **'No downloaders yet. Add Aria2, qBittorrent or Transmission to start managing downloads'**
  String get noDownloaderHint;

  /// Settings item: language
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Settings item: theme mode
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get themeMode;

  /// Theme mode option: follow system
  ///
  /// In en, this message translates to:
  /// **'Follow system'**
  String get themeModeSystem;

  /// Theme mode option: light
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeModeLight;

  /// Theme mode option: dark
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeModeDark;

  /// Theme mode picker dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Theme Mode'**
  String get selectThemeMode;

  /// Task detail: file info section title
  ///
  /// In en, this message translates to:
  /// **'File Info'**
  String get fileInfoSection;

  /// Task detail: download info section title
  ///
  /// In en, this message translates to:
  /// **'Download Info'**
  String get downloadInfoSection;

  /// Task detail: connection info section title
  ///
  /// In en, this message translates to:
  /// **'Connection Info'**
  String get connectionInfoSection;

  /// Task detail: file name label
  ///
  /// In en, this message translates to:
  /// **'File name'**
  String get fileName;

  /// Task detail: included file count label
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get fileCount;

  /// Task detail: current download speed label
  ///
  /// In en, this message translates to:
  /// **'Download speed'**
  String get currentDownloadSpeed;

  /// Task detail: current upload speed label
  ///
  /// In en, this message translates to:
  /// **'Upload speed'**
  String get currentUploadSpeed;

  /// Task detail: downloaded over total size label
  ///
  /// In en, this message translates to:
  /// **'Downloaded / Total'**
  String get downloadedOverTotal;

  /// Task detail: downloader name label
  ///
  /// In en, this message translates to:
  /// **'Downloader name'**
  String get downloaderName;

  /// Task detail: connection count label
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get connectionCount;

  /// Task list: formatted speed with value
  ///
  /// In en, this message translates to:
  /// **'Speed {value}'**
  String speedValue(String value);

  /// Snackbar when editing a deleted downloader
  ///
  /// In en, this message translates to:
  /// **'Downloader does not exist or has been deleted'**
  String get downloaderNotExistDeleted;

  /// Editor page title (edit mode)
  ///
  /// In en, this message translates to:
  /// **'Edit Downloader'**
  String get editDownloader;

  /// Editor page: basic info section title
  ///
  /// In en, this message translates to:
  /// **'Basic info'**
  String get basicInfo;

  /// Editor form: name field label
  ///
  /// In en, this message translates to:
  /// **'Downloader name'**
  String get downloaderNameField;

  /// Editor form: name validator
  ///
  /// In en, this message translates to:
  /// **'Please enter a downloader name'**
  String get pleaseEnterDownloaderName;

  /// Editor form: type field label
  ///
  /// In en, this message translates to:
  /// **'Downloader type'**
  String get downloaderTypeField;

  /// Editor form: host field label
  ///
  /// In en, this message translates to:
  /// **'Server address'**
  String get serverAddressField;

  /// Editor form: host validator
  ///
  /// In en, this message translates to:
  /// **'Please enter a server address'**
  String get pleaseEnterServerAddress;

  /// Editor form: port range validator
  ///
  /// In en, this message translates to:
  /// **'Invalid port'**
  String get portInvalid;

  /// Editor form: username field label
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get usernameField;

  /// Editor form: password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordField;

  /// Editor page: save button
  ///
  /// In en, this message translates to:
  /// **'Save Config'**
  String get saveConfigButton;

  /// Snackbar on successful connection
  ///
  /// In en, this message translates to:
  /// **'Connected successfully'**
  String get connectionSuccess;

  /// Snackbar: downloader version below minimum
  ///
  /// In en, this message translates to:
  /// **'Version too low: current {actual}, requires ≥ {min}'**
  String versionTooLow(String actual, String min);

  /// Snackbar: auth failed category
  ///
  /// In en, this message translates to:
  /// **'Authentication failed: please check username/password'**
  String get authFailedCheck;

  /// Snackbar: network error category
  ///
  /// In en, this message translates to:
  /// **'Cannot connect: please check address/port/network'**
  String get cannotConnect;

  /// Config page: unsupported downloader error
  ///
  /// In en, this message translates to:
  /// **'This downloader does not support configuration'**
  String get downloaderNotSupportConfig;

  /// Config page: kbps field validator
  ///
  /// In en, this message translates to:
  /// **'Please enter a non-negative number'**
  String get pleaseEnterNonNegativeNumber;

  /// Language option: follow system
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get languageSystem;

  /// Language option: English
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Language option: Chinese
  ///
  /// In en, this message translates to:
  /// **'中文'**
  String get languageChinese;

  /// Language option: Japanese
  ///
  /// In en, this message translates to:
  /// **'日本語'**
  String get languageJapanese;

  /// Language picker dialog title
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// Checkbox label for deleting files along with task
  ///
  /// In en, this message translates to:
  /// **'Also delete downloaded files'**
  String get deleteWithFiles;

  /// Login page title
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get login;

  /// Login page subtitle
  ///
  /// In en, this message translates to:
  /// **'Sign in to sync your data'**
  String get loginSubtitle;

  /// Register mode title/button text
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get registerAccount;

  /// Email address field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get emailAddress;

  /// Verification code field label
  ///
  /// In en, this message translates to:
  /// **'Verification code'**
  String get verificationCode;

  /// Optional nickname field label
  ///
  /// In en, this message translates to:
  /// **'Nickname (optional)'**
  String get nicknameOptional;

  /// Confirm password field label
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// Send verification code button text
  ///
  /// In en, this message translates to:
  /// **'Send code'**
  String get sendCode;

  /// Send verification code loading text
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get sendingCode;

  /// Snackbar text after verification code is sent successfully
  ///
  /// In en, this message translates to:
  /// **'Verification code sent'**
  String get verificationCodeSent;

  /// Send code countdown text
  ///
  /// In en, this message translates to:
  /// **'{seconds}s'**
  String sendCodeCountdown(int seconds);

  /// Terms notice on login page
  ///
  /// In en, this message translates to:
  /// **'By signing in, you agree to our Terms of Service and Privacy Policy'**
  String get loginTermsNotice;

  /// Generic login error message
  ///
  /// In en, this message translates to:
  /// **'Sign in failed, please try again'**
  String get loginError;

  /// Invalid email validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address'**
  String get emailAddressInvalid;

  /// Missing password validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get passwordRequired;

  /// Missing verification code validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter the verification code'**
  String get verificationCodeRequired;

  /// Password mismatch validation message
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordMismatch;

  /// Sign out button text
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// Sign out confirmation
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to sign out?'**
  String get confirmSignOut;

  /// Account section title
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// Label when user is not signed in
  ///
  /// In en, this message translates to:
  /// **'Not signed in'**
  String get notSignedIn;

  /// No description provided for @tapToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Tap to sign in'**
  String get tapToSignIn;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App settings and personalization options'**
  String get settingsSubtitle;

  /// VIP user role label
  ///
  /// In en, this message translates to:
  /// **'VIP User'**
  String get vipUser;

  /// Normal user role label
  ///
  /// In en, this message translates to:
  /// **'Normal User'**
  String get normalUser;

  /// No description provided for @my.
  ///
  /// In en, this message translates to:
  /// **'Mine'**
  String get my;

  /// No description provided for @enterLinkOrTorrentFile.
  ///
  /// In en, this message translates to:
  /// **'Enter a download link or choose a torrent file'**
  String get enterLinkOrTorrentFile;

  /// No description provided for @torrentReadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to read the torrent file. Please choose it again.'**
  String get torrentReadFailed;

  /// No description provided for @chooseTaskSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose task source'**
  String get chooseTaskSourceTitle;

  /// No description provided for @chooseTaskSourceMessage.
  ///
  /// In en, this message translates to:
  /// **'Both a link and a torrent file are present. Choose which one to use.'**
  String get chooseTaskSourceMessage;

  /// No description provided for @useLinkSource.
  ///
  /// In en, this message translates to:
  /// **'Use link'**
  String get useLinkSource;

  /// No description provided for @useTorrentSource.
  ///
  /// In en, this message translates to:
  /// **'Use torrent file'**
  String get useTorrentSource;

  /// No description provided for @selectedTorrentFile.
  ///
  /// In en, this message translates to:
  /// **'Selected: {fileName}'**
  String selectedTorrentFile(String fileName);

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @selectDownloaderStep.
  ///
  /// In en, this message translates to:
  /// **'1. Select Downloader'**
  String get selectDownloaderStep;

  /// No description provided for @selectDownloaderDesc.
  ///
  /// In en, this message translates to:
  /// **'Select a downloader for this task'**
  String get selectDownloaderDesc;

  /// No description provided for @downloadLinkStep.
  ///
  /// In en, this message translates to:
  /// **'2. Download Link'**
  String get downloadLinkStep;

  /// No description provided for @downloadLinkDesc.
  ///
  /// In en, this message translates to:
  /// **'Supports HTTP, HTTPS, Magnet links'**
  String get downloadLinkDesc;

  /// No description provided for @savePathStep.
  ///
  /// In en, this message translates to:
  /// **'3. Save Path'**
  String get savePathStep;

  /// No description provided for @savePathDesc.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use default path'**
  String get savePathDesc;

  /// No description provided for @optionalTag.
  ///
  /// In en, this message translates to:
  /// **'(Optional)'**
  String get optionalTag;

  /// No description provided for @selectTorrentFile.
  ///
  /// In en, this message translates to:
  /// **'Select torrent file'**
  String get selectTorrentFile;

  /// No description provided for @torrentUploadHint.
  ///
  /// In en, this message translates to:
  /// **'Supports .torrent file upload'**
  String get torrentUploadHint;

  /// No description provided for @selectFolder.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get selectFolder;

  /// No description provided for @checkForUpdates.
  ///
  /// In en, this message translates to:
  /// **'Check for Updates'**
  String get checkForUpdates;

  /// No description provided for @newVersionAvailable.
  ///
  /// In en, this message translates to:
  /// **'New version available'**
  String get newVersionAvailable;

  /// No description provided for @updateAvailableBadge.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailableBadge;

  /// No description provided for @upToDate.
  ///
  /// In en, this message translates to:
  /// **'You\'re up to date'**
  String get upToDate;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get updateAvailableTitle;

  /// No description provided for @updateAvailableMessage.
  ///
  /// In en, this message translates to:
  /// **'A newer WindTorrent version is available on Google Play.'**
  String get updateAvailableMessage;

  /// No description provided for @updateNow.
  ///
  /// In en, this message translates to:
  /// **'Update now'**
  String get updateNow;

  /// No description provided for @later.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get later;

  /// No description provided for @updateCheckUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check for updates'**
  String get updateCheckUnavailable;

  /// No description provided for @updateCheckNotSupported.
  ///
  /// In en, this message translates to:
  /// **'Automatic updates aren\'t supported on this build'**
  String get updateCheckNotSupported;

  /// No description provided for @supportSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Support & Share'**
  String get supportSectionTitle;

  /// No description provided for @appSectionTitle.
  ///
  /// In en, this message translates to:
  /// **'App'**
  String get appSectionTitle;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @privacyPolicyDesc.
  ///
  /// In en, this message translates to:
  /// **'View our privacy policy'**
  String get privacyPolicyDesc;

  /// No description provided for @contactDeveloper.
  ///
  /// In en, this message translates to:
  /// **'Contact Developer'**
  String get contactDeveloper;

  /// No description provided for @contactDeveloperDesc.
  ///
  /// In en, this message translates to:
  /// **'Send feedback via email'**
  String get contactDeveloperDesc;

  /// No description provided for @shareApp.
  ///
  /// In en, this message translates to:
  /// **'Share App'**
  String get shareApp;

  /// No description provided for @shareAppDesc.
  ///
  /// In en, this message translates to:
  /// **'Share with friends'**
  String get shareAppDesc;

  /// No description provided for @contactEmailSubject.
  ///
  /// In en, this message translates to:
  /// **'WindTorrent Feedback'**
  String get contactEmailSubject;

  /// No description provided for @openLinkFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to open link'**
  String get openLinkFailed;

  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'Share failed'**
  String get shareFailed;

  /// No description provided for @windTorrentConsole.
  ///
  /// In en, this message translates to:
  /// **'WindTorrent Console'**
  String get windTorrentConsole;

  /// No description provided for @downloadersOnlineRatio.
  ///
  /// In en, this message translates to:
  /// **'{onlineCount}/{totalCount} downloaders online'**
  String downloadersOnlineRatio(int onlineCount, int totalCount);

  /// No description provided for @waitingForDownloaderConnection.
  ///
  /// In en, this message translates to:
  /// **'Waiting for downloader connection'**
  String get waitingForDownloaderConnection;

  /// No description provided for @totalDownloadSpeed.
  ///
  /// In en, this message translates to:
  /// **'Total download speed'**
  String get totalDownloadSpeed;

  /// No description provided for @activeTasks.
  ///
  /// In en, this message translates to:
  /// **'Active tasks'**
  String get activeTasks;

  /// No description provided for @totalUploadSpeed.
  ///
  /// In en, this message translates to:
  /// **'Total upload speed'**
  String get totalUploadSpeed;

  /// No description provided for @viewTasks.
  ///
  /// In en, this message translates to:
  /// **'View tasks'**
  String get viewTasks;

  /// No description provided for @multiProtocolDownloaders.
  ///
  /// In en, this message translates to:
  /// **'Multi-protocol downloaders'**
  String get multiProtocolDownloaders;

  /// No description provided for @manageConfiguredDownloaders.
  ///
  /// In en, this message translates to:
  /// **'Manage configured downloaders'**
  String get manageConfiguredDownloaders;

  /// No description provided for @configuredDownloaders.
  ///
  /// In en, this message translates to:
  /// **'Configured downloaders'**
  String get configuredDownloaders;

  /// No description provided for @shareAppMessage.
  ///
  /// In en, this message translates to:
  /// **'Check out {appName}: {url}'**
  String shareAppMessage(String appName, String url);

  /// No description provided for @taskTorrentInfoSection.
  ///
  /// In en, this message translates to:
  /// **'Torrent Info'**
  String get taskTorrentInfoSection;

  /// No description provided for @taskTransferSection.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get taskTransferSection;

  /// No description provided for @taskDateSection.
  ///
  /// In en, this message translates to:
  /// **'Date'**
  String get taskDateSection;

  /// No description provided for @taskRuntimeSection.
  ///
  /// In en, this message translates to:
  /// **'Runtime'**
  String get taskRuntimeSection;

  /// No description provided for @taskMoreDetails.
  ///
  /// In en, this message translates to:
  /// **'More Details'**
  String get taskMoreDetails;

  /// No description provided for @taskFilesEntry.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get taskFilesEntry;

  /// No description provided for @taskTrackersEntry.
  ///
  /// In en, this message translates to:
  /// **'Trackers'**
  String get taskTrackersEntry;

  /// No description provided for @taskPeersEntry.
  ///
  /// In en, this message translates to:
  /// **'Peers'**
  String get taskPeersEntry;

  /// No description provided for @taskOptionsEntry.
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get taskOptionsEntry;

  /// No description provided for @taskOptionsShellSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Priority, bandwidth, ratio, and idle limits'**
  String get taskOptionsShellSubtitle;

  /// No description provided for @totalSize.
  ///
  /// In en, this message translates to:
  /// **'Total Size'**
  String get totalSize;

  /// No description provided for @privacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacy;

  /// No description provided for @creator.
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get creator;

  /// No description provided for @createdAt.
  ///
  /// In en, this message translates to:
  /// **'Created At'**
  String get createdAt;

  /// No description provided for @magnet.
  ///
  /// In en, this message translates to:
  /// **'Magnet'**
  String get magnet;

  /// No description provided for @totalDownloaded.
  ///
  /// In en, this message translates to:
  /// **'Total Downloaded'**
  String get totalDownloaded;

  /// No description provided for @availability.
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get availability;

  /// No description provided for @totalUploaded.
  ///
  /// In en, this message translates to:
  /// **'Total Uploaded'**
  String get totalUploaded;

  /// No description provided for @shareRatio.
  ///
  /// In en, this message translates to:
  /// **'Share Ratio'**
  String get shareRatio;

  /// No description provided for @averageSpeed.
  ///
  /// In en, this message translates to:
  /// **'Average Speed'**
  String get averageSpeed;

  /// No description provided for @addedAt.
  ///
  /// In en, this message translates to:
  /// **'Added'**
  String get addedAt;

  /// No description provided for @completedAt.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedAt;

  /// No description provided for @lastActivityAt.
  ///
  /// In en, this message translates to:
  /// **'Last Activity'**
  String get lastActivityAt;

  /// No description provided for @downloadDuration.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get downloadDuration;

  /// No description provided for @seedingDuration.
  ///
  /// In en, this message translates to:
  /// **'Seeding'**
  String get seedingDuration;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @transmissionNoFiles.
  ///
  /// In en, this message translates to:
  /// **'No files'**
  String get transmissionNoFiles;

  /// No description provided for @transmissionNoTrackers.
  ///
  /// In en, this message translates to:
  /// **'No trackers'**
  String get transmissionNoTrackers;

  /// No description provided for @transmissionNoPeers.
  ///
  /// In en, this message translates to:
  /// **'No peers'**
  String get transmissionNoPeers;

  /// No description provided for @transmissionTransferPriority.
  ///
  /// In en, this message translates to:
  /// **'Transfer Priority'**
  String get transmissionTransferPriority;

  /// No description provided for @transmissionBandwidth.
  ///
  /// In en, this message translates to:
  /// **'Bandwidth'**
  String get transmissionBandwidth;

  /// No description provided for @transmissionShareRatioLimit.
  ///
  /// In en, this message translates to:
  /// **'Share Ratio Limit'**
  String get transmissionShareRatioLimit;

  /// No description provided for @transmissionIdleLimit.
  ///
  /// In en, this message translates to:
  /// **'Idle Limit'**
  String get transmissionIdleLimit;

  /// No description provided for @transmissionPriorityLow.
  ///
  /// In en, this message translates to:
  /// **'Low'**
  String get transmissionPriorityLow;

  /// No description provided for @transmissionPriorityNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get transmissionPriorityNormal;

  /// No description provided for @transmissionPriorityHigh.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get transmissionPriorityHigh;

  /// No description provided for @transmissionLimitGlobal.
  ///
  /// In en, this message translates to:
  /// **'Global'**
  String get transmissionLimitGlobal;

  /// No description provided for @transmissionLimitDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get transmissionLimitDisabled;

  /// No description provided for @transmissionLimitCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get transmissionLimitCustom;

  /// No description provided for @transmissionHonorGlobalLimits.
  ///
  /// In en, this message translates to:
  /// **'Honor global bandwidth limits'**
  String get transmissionHonorGlobalLimits;

  /// No description provided for @transmissionDownloadLimit.
  ///
  /// In en, this message translates to:
  /// **'Download limit (KB/s)'**
  String get transmissionDownloadLimit;

  /// No description provided for @transmissionUploadLimit.
  ///
  /// In en, this message translates to:
  /// **'Upload limit (KB/s)'**
  String get transmissionUploadLimit;

  /// No description provided for @transmissionRatioValue.
  ///
  /// In en, this message translates to:
  /// **'Ratio value'**
  String get transmissionRatioValue;

  /// No description provided for @transmissionIdleMinutes.
  ///
  /// In en, this message translates to:
  /// **'Minutes'**
  String get transmissionIdleMinutes;

  /// No description provided for @transmissionTier.
  ///
  /// In en, this message translates to:
  /// **'Tier {tier}'**
  String transmissionTier(int tier);

  /// No description provided for @transmissionSeeds.
  ///
  /// In en, this message translates to:
  /// **'Seeds: {count}'**
  String transmissionSeeds(int count);

  /// No description provided for @transmissionLeeches.
  ///
  /// In en, this message translates to:
  /// **'Leeches: {count}'**
  String transmissionLeeches(int count);

  /// No description provided for @transmissionDownloads.
  ///
  /// In en, this message translates to:
  /// **'Downloads: {count}'**
  String transmissionDownloads(int count);

  /// No description provided for @transmissionDownloadSpeed.
  ///
  /// In en, this message translates to:
  /// **'DL: {speed}'**
  String transmissionDownloadSpeed(String speed);

  /// No description provided for @transmissionUploadSpeed.
  ///
  /// In en, this message translates to:
  /// **'UL: {speed}'**
  String transmissionUploadSpeed(String speed);

  /// qBit detail homepage: progress section title
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get qbitProgressSection;

  /// qBit detail homepage: HTTP sources section title
  ///
  /// In en, this message translates to:
  /// **'HTTP Sources'**
  String get qbitHttpSourcesSection;

  /// qBit detail homepage: servers entry card title
  ///
  /// In en, this message translates to:
  /// **'Servers'**
  String get qbitServersEntry;

  /// qBit detail homepage: options entry card title
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get qbitOptionsEntry;

  /// qBit detail homepage: options entry subtitle
  ///
  /// In en, this message translates to:
  /// **'Category & tags'**
  String get qbitOptionsSubtitle;

  /// qBit detail homepage: no HTTP sources
  ///
  /// In en, this message translates to:
  /// **'No HTTP sources'**
  String get qbitNoHttpSources;

  /// qBit sources page: empty state
  ///
  /// In en, this message translates to:
  /// **'No sources'**
  String get qbitNoSources;

  /// qBit peers page: empty state
  ///
  /// In en, this message translates to:
  /// **'No peers'**
  String get qbitNoPeers;

  /// qBit files page: empty state
  ///
  /// In en, this message translates to:
  /// **'No files'**
  String get qbitNoFiles;

  /// qBit options page: queue priority section
  ///
  /// In en, this message translates to:
  /// **'Queue priority'**
  String get qbitQueuePriorityTitle;

  /// qBit options page: queue action unchanged
  ///
  /// In en, this message translates to:
  /// **'No change'**
  String get qbitQueueActionUnchanged;

  /// qBit options page: queue action top
  ///
  /// In en, this message translates to:
  /// **'Top of queue'**
  String get qbitQueueActionTop;

  /// qBit options page: queue action increase
  ///
  /// In en, this message translates to:
  /// **'Move up'**
  String get qbitQueueActionIncrease;

  /// qBit options page: queue action decrease
  ///
  /// In en, this message translates to:
  /// **'Move down'**
  String get qbitQueueActionDecrease;

  /// qBit options page: queue action bottom
  ///
  /// In en, this message translates to:
  /// **'Bottom of queue'**
  String get qbitQueueActionBottom;

  /// qBit options page: category field label
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get qbitCategoryLabel;

  /// qBit options page: category field helper
  ///
  /// In en, this message translates to:
  /// **'Choose an existing category or type a new one'**
  String get qbitCategoryHelper;

  /// qBit options page: tags field label
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get qbitTagsLabel;

  /// qBit options page: tags field helper
  ///
  /// In en, this message translates to:
  /// **'Separate tags with commas'**
  String get qbitTagsHelper;

  /// qBit options page: save success feedback
  ///
  /// In en, this message translates to:
  /// **'Options saved'**
  String get qbitOptionsSaved;

  /// qBit detail: progress done percentage label
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get qbitDone;

  /// qBit detail: download speed label
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get qbitDownload;

  /// qBit detail: upload speed label
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get qbitUpload;

  /// qBit detail: estimated time of arrival label
  ///
  /// In en, this message translates to:
  /// **'ETA'**
  String get qbitEta;

  /// qBit detail: total downloaded label
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get qbitDownloaded;

  /// qBit detail: total uploaded label
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get qbitUploaded;

  /// qBit detail: share ratio label
  ///
  /// In en, this message translates to:
  /// **'Ratio'**
  String get qbitRatio;

  /// qBit detail: average download speed label
  ///
  /// In en, this message translates to:
  /// **'Avg download'**
  String get qbitAvgDownload;

  /// qBit detail: average upload speed label
  ///
  /// In en, this message translates to:
  /// **'Avg upload'**
  String get qbitAvgUpload;

  /// qBit detail: seeds count label
  ///
  /// In en, this message translates to:
  /// **'Seeds'**
  String get qbitSeeds;

  /// qBit detail: leechs count label
  ///
  /// In en, this message translates to:
  /// **'Leechs'**
  String get qbitLeechs;

  /// qBit detail: total size label
  ///
  /// In en, this message translates to:
  /// **'Total size'**
  String get qbitTotalSize;

  /// qBit detail: pieces label
  ///
  /// In en, this message translates to:
  /// **'Pieces'**
  String get qbitPieces;

  /// qBit detail: save path label
  ///
  /// In en, this message translates to:
  /// **'Save path'**
  String get qbitSavePath;

  /// qBit detail: torrent state label
  ///
  /// In en, this message translates to:
  /// **'State'**
  String get qbitState;

  /// qBit detail: file count entry subtitle
  ///
  /// In en, this message translates to:
  /// **'{count} files'**
  String qbitFileCount(int count);

  /// qBit detail: source count entry subtitle
  ///
  /// In en, this message translates to:
  /// **'{count} sources'**
  String qbitSourceCount(int count);

  /// qBit detail: peer count entry subtitle
  ///
  /// In en, this message translates to:
  /// **'{count} peers'**
  String qbitPeerCount(int count);

  /// qBit detail: HTTP source count
  ///
  /// In en, this message translates to:
  /// **'{count} HTTP source(s)'**
  String qbitHttpSourceCount(int count);

  /// qBit source card: peers count label
  ///
  /// In en, this message translates to:
  /// **'Peers'**
  String get qbitPeersLabel;

  /// qBit source card: seeds count label
  ///
  /// In en, this message translates to:
  /// **'Seeds'**
  String get qbitSeedsLabel;

  /// qBit source card: downloads count label
  ///
  /// In en, this message translates to:
  /// **'Downloads'**
  String get qbitDownloadsLabel;

  /// qBit source card: downloaded count label
  ///
  /// In en, this message translates to:
  /// **'Downloaded'**
  String get qbitDownloadedLabel;

  /// qBit peer row: file affinity label
  ///
  /// In en, this message translates to:
  /// **'file affinity'**
  String get qbitFileAffinity;

  /// qBit detail transfer: connections label
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get qbitConnections;

  /// qBit detail transfer: activity time label
  ///
  /// In en, this message translates to:
  /// **'Activity time'**
  String get qbitActivityTime;

  /// qBit detail transfer: seeding time label
  ///
  /// In en, this message translates to:
  /// **'Seeding time'**
  String get qbitSeedingTime;

  /// qBit detail transfer: queue priority label
  ///
  /// In en, this message translates to:
  /// **'Priority'**
  String get qbitPriority;

  /// qBit torrent info: pieces/blocks label
  ///
  /// In en, this message translates to:
  /// **'Blocks'**
  String get qbitBlocks;

  /// qBit torrent info: info hash v1 label
  ///
  /// In en, this message translates to:
  /// **'Info hash v1'**
  String get qbitInfoHashV1;

  /// qBit torrent info: info hash v2 label
  ///
  /// In en, this message translates to:
  /// **'Info hash v2'**
  String get qbitInfoHashV2;

  /// qBit detail: peer count summary
  ///
  /// In en, this message translates to:
  /// **'{active} active ({total} total)'**
  String qbitPeerSummary(int active, int total);

  /// qBit detail: not available fallback
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get qbitNotAvailable;

  /// qBit detail transfer: download speed limit label
  ///
  /// In en, this message translates to:
  /// **'DL limit'**
  String get qbitDlLimit;

  /// qBit detail transfer: upload speed limit label
  ///
  /// In en, this message translates to:
  /// **'UL limit'**
  String get qbitUpLimit;

  /// qBit detail transfer: availability/popularity label
  ///
  /// In en, this message translates to:
  /// **'Availability'**
  String get qbitAvailability;

  /// Aria2 detail: health/availability percentage
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get aria2Health;

  /// Aria2 detail ETA: when remaining time exceeds 1 day
  ///
  /// In en, this message translates to:
  /// **'> 1 day'**
  String get aria2OverOneDay;

  /// Aria2 options: max download speed label
  ///
  /// In en, this message translates to:
  /// **'Max Download (KB/s)'**
  String get aria2MaxDlSpeed;

  /// Aria2 options: max upload speed label
  ///
  /// In en, this message translates to:
  /// **'Max Upload (KB/s)'**
  String get aria2MaxUlSpeed;

  /// Aria2 options: max connections label
  ///
  /// In en, this message translates to:
  /// **'Max Connections'**
  String get aria2MaxConnections;

  /// Aria2 options: hint for unlimited value
  ///
  /// In en, this message translates to:
  /// **'0 = unlimited'**
  String get aria2Unlimited;

  /// Aria2 options: save success snackbar
  ///
  /// In en, this message translates to:
  /// **'Options saved'**
  String get aria2OptionsSaved;

  /// Aria2 servers page: empty state
  ///
  /// In en, this message translates to:
  /// **'No trackers'**
  String get aria2NoTrackers;

  /// Aria2 peer card: client label
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get aria2PeerClient;

  /// Aria2 peer card: status label
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get aria2PeerStatus;

  /// Aria2 peer status: remote is choking us
  ///
  /// In en, this message translates to:
  /// **'choking us'**
  String get aria2ChokingUs;

  /// Aria2 peer status: we are choking remote
  ///
  /// In en, this message translates to:
  /// **'we choke'**
  String get aria2WeChoke;

  /// Aria2 peer status: both sides unchoked
  ///
  /// In en, this message translates to:
  /// **'unchoke'**
  String get aria2Unchoke;

  /// Aria2 peer badge: seeder
  ///
  /// In en, this message translates to:
  /// **'SEED'**
  String get aria2Seeder;

  /// Aria2 peer badge: leecher
  ///
  /// In en, this message translates to:
  /// **'LEECH'**
  String get aria2Leech;

  /// Settings section: backup and restore group title
  ///
  /// In en, this message translates to:
  /// **'Backup & Restore'**
  String get backupRestore;

  /// Settings row title for WebDAV configuration
  ///
  /// In en, this message translates to:
  /// **'WebDAV Server'**
  String get webDavServer;

  /// WebDAV settings page subtitle
  ///
  /// In en, this message translates to:
  /// **'Configure the remote folder used for backup and restore'**
  String get webDavConfigSubtitle;

  /// WebDAV not configured subtitle
  ///
  /// In en, this message translates to:
  /// **'Not configured'**
  String get webDavNotConfigured;

  /// WebDAV root URL field label
  ///
  /// In en, this message translates to:
  /// **'Root URL'**
  String get webDavRootUrl;

  /// WebDAV remote directory field label
  ///
  /// In en, this message translates to:
  /// **'Remote directory'**
  String get webDavDirectory;

  /// WebDAV password or token field label
  ///
  /// In en, this message translates to:
  /// **'Password or app token'**
  String get webDavPasswordOrToken;

  /// Test WebDAV connection button text
  ///
  /// In en, this message translates to:
  /// **'Test'**
  String get testConnection;

  /// Test WebDAV connection loading text
  ///
  /// In en, this message translates to:
  /// **'Testing...'**
  String get testingConnection;

  /// Saving state label
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get saving;

  /// Invalid WebDAV URL validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid WebDAV URL'**
  String get webDavRootUrlInvalid;

  /// Missing WebDAV directory validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter the remote directory'**
  String get webDavDirectoryRequired;

  /// Missing username validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter the username'**
  String get usernameRequired;

  /// Missing WebDAV password validation message
  ///
  /// In en, this message translates to:
  /// **'Please enter the password or app token'**
  String get webDavPasswordRequired;

  /// Settings row: export backup to WebDAV
  ///
  /// In en, this message translates to:
  /// **'Back up to WebDAV'**
  String get backupToWebDav;

  /// Settings row: import backup from WebDAV
  ///
  /// In en, this message translates to:
  /// **'Restore from WebDAV'**
  String get restoreFromWebDav;

  /// Settings row subtitle when not signed in
  ///
  /// In en, this message translates to:
  /// **'Sign in to use backup'**
  String get signInToUseBackup;

  /// Settings row subtitle when WebDAV is not configured
  ///
  /// In en, this message translates to:
  /// **'Configure WebDAV to use backup'**
  String get configureWebDavToUseBackup;

  /// Settings row subtitle for backup row when signed in
  ///
  /// In en, this message translates to:
  /// **'Includes downloader addresses and credentials'**
  String get backupIncludesCredentials;

  /// Restore confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Confirm restore and replace'**
  String get confirmRestoreAndReplace;

  /// Restore confirmation dialog body
  ///
  /// In en, this message translates to:
  /// **'This will replace all current downloader configurations.'**
  String get restoreWillReplaceAllDownloaders;

  /// Settings row subtitle for restore row when signed in
  ///
  /// In en, this message translates to:
  /// **'A local rollback snapshot will be created before restore'**
  String get restoreCreatesRollbackSnapshot;

  /// Undo button text after a successful restore
  ///
  /// In en, this message translates to:
  /// **'Undo last restore'**
  String get undoLastRestore;

  /// Bottom sheet title for selecting a backup version
  ///
  /// In en, this message translates to:
  /// **'Select backup version'**
  String get selectBackupVersion;

  /// Empty state when no backup versions are found
  ///
  /// In en, this message translates to:
  /// **'No backups available'**
  String get noBackupsAvailable;

  /// Latest backup row title prefix
  ///
  /// In en, this message translates to:
  /// **'Latest backup'**
  String get latestBackupLabel;

  /// Latest backup badge label
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get latestBackupChip;

  /// Delete backup version dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete backup version?'**
  String get confirmDeleteBackupVersion;

  /// Delete backup version dialog body
  ///
  /// In en, this message translates to:
  /// **'This backup version will be permanently removed from WebDAV.'**
  String get deleteBackupVersionMessage;

  /// Shown while restore is in progress
  ///
  /// In en, this message translates to:
  /// **'Restoring...'**
  String get restoreInProgress;

  /// Shown while backup export is in progress
  ///
  /// In en, this message translates to:
  /// **'Backing up...'**
  String get backupInProgress;

  /// Backup time: less than 1 minute ago
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get backupTimeJustNow;

  /// Backup time: minutes ago
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String backupTimeMinutesAgo(int count);

  /// Backup time: hours ago
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String backupTimeHoursAgo(int count);

  /// Backup time: days ago
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String backupTimeDaysAgo(int count);

  /// Backup version subtitle: downloader count
  ///
  /// In en, this message translates to:
  /// **'{count} downloaders'**
  String backupDownloaderCount(int count);

  /// Snackbar after successful restore
  ///
  /// In en, this message translates to:
  /// **'Restore completed successfully'**
  String get restoreSuccess;

  /// Snackbar after successful backup export
  ///
  /// In en, this message translates to:
  /// **'Backup exported successfully'**
  String get exportSuccess;

  /// Forgot password link on login page
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// Reset password page title and submit button
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get resetPassword;

  /// Reset password page subtitle
  ///
  /// In en, this message translates to:
  /// **'Set a new password via email verification code'**
  String get resetPasswordSubtitle;

  /// New password field label
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// Confirm new password field label
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmNewPassword;

  /// Reset password success message
  ///
  /// In en, this message translates to:
  /// **'Password reset. Please log in with your new password.'**
  String get resetPasswordSuccess;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
