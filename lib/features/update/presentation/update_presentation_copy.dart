import 'package:windwalker/core/config/build_channel_config.dart';
import 'package:windwalker/features/update/domain/update_check_result.dart';
import 'package:windwalker/l10n/app_localizations.dart';

abstract final class UpdatePresentationCopy {
  static String availableMessage({
    required AppLocalizations l10n,
    required UpdateSource source,
    required ReleaseTrack releaseTrack,
  }) => switch ((source, releaseTrack)) {
    (UpdateSource.playStore, _) => l10n.updateAvailableMessage,
    (UpdateSource.githubRelease, ReleaseTrack.stable) =>
      l10n.githubStableUpdateAvailableMessage,
    (UpdateSource.githubRelease, ReleaseTrack.beta) =>
      l10n.githubBetaUpdateAvailableMessage,
  };

  static String actionLabel({
    required AppLocalizations l10n,
    required UpdateSource source,
  }) => switch (source) {
    UpdateSource.playStore => l10n.openGooglePlay,
    UpdateSource.githubRelease => l10n.openGitHubRelease,
  };
}
