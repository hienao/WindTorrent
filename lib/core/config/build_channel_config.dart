import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

enum DistributionChannel {
  play('play'),
  github('github');

  const DistributionChannel(this.analyticsValue);

  final String analyticsValue;
}

enum ReleaseTrack {
  stable('stable', sourceBranch: 'main'),
  beta('beta', sourceBranch: 'beta');

  const ReleaseTrack(this.analyticsValue, {required this.sourceBranch});

  final String analyticsValue;
  final String sourceBranch;
}

/// Immutable build identity shared by update routing and analytics.
///
/// Release builds must provide both values through the Android product flavor
/// and `APP_RELEASE_TRACK`. Debug/profile builds default to GitHub Beta so a
/// regular local run remains useful without release credentials.
class BuildChannelConfig {
  const BuildChannelConfig._({
    required this.distributionChannel,
    required this.releaseTrack,
  });

  factory BuildChannelConfig.parse({
    required String? flavor,
    required String? track,
    bool allowLocalDefaults = false,
  }) {
    final resolvedFlavor = switch (flavor) {
      'play' => DistributionChannel.play,
      'github' => DistributionChannel.github,
      null || '' when allowLocalDefaults => DistributionChannel.github,
      _ => throw StateError('Unsupported Android distribution flavor: $flavor'),
    };
    final resolvedTrack = switch (track) {
      'stable' => ReleaseTrack.stable,
      'beta' => ReleaseTrack.beta,
      null || '' when allowLocalDefaults => ReleaseTrack.beta,
      _ => throw StateError('Unsupported APP_RELEASE_TRACK: $track'),
    };

    if (resolvedFlavor == DistributionChannel.play &&
        resolvedTrack == ReleaseTrack.beta) {
      throw StateError('The play distribution does not support beta builds.');
    }

    return BuildChannelConfig._(
      distributionChannel: resolvedFlavor,
      releaseTrack: resolvedTrack,
    );
  }

  factory BuildChannelConfig.fromBuildEnvironment() {
    const releaseTrack = String.fromEnvironment('APP_RELEASE_TRACK');
    return BuildChannelConfig.parse(
      flavor: appFlavor,
      track: releaseTrack,
      allowLocalDefaults: !kReleaseMode,
    );
  }

  final DistributionChannel distributionChannel;
  final ReleaseTrack releaseTrack;

  bool get usesGooglePlay => distributionChannel == DistributionChannel.play;

  Map<String, Object> get analyticsParameters => <String, Object>{
    'distribution_channel': distributionChannel.analyticsValue,
    'release_track': releaseTrack.analyticsValue,
  };
}
