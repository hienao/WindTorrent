import 'package:flutter/widgets.dart';
import 'package:windwalker/l10n/app_localizations.dart';
import 'package:windwalker/core/constants/app_constants.dart';

/// Extension on [DownloaderStatus] to provide localized labels.
extension DownloaderStatusL10n on DownloaderStatus {
  /// Returns the localized status label using the given [context].
  String localizedLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case DownloaderStatus.online:
        return l10n.online;
      case DownloaderStatus.offline:
        return l10n.offline;
      case DownloaderStatus.error:
        return l10n.error;
    }
  }
}

/// Extension on [TaskStatus] to provide localized labels.
extension TaskStatusL10n on TaskStatus {
  /// Returns the localized status label using the given [context].
  String localizedLabel(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    switch (this) {
      case TaskStatus.downloading:
        return l10n.downloading;
      case TaskStatus.waiting:
        return l10n.waiting;
      case TaskStatus.paused:
        return l10n.paused;
      case TaskStatus.seeding:
        return l10n.seeding;
      case TaskStatus.completed:
        return l10n.completed;
      case TaskStatus.removed:
        return '已移除';
      case TaskStatus.error:
        return l10n.error;
      case TaskStatus.unknown:
        return l10n.unknown;
    }
  }
}
