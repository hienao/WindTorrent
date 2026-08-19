import 'package:flutter_test/flutter_test.dart';
import 'package:windwalker/core/config/build_channel_config.dart';

void main() {
  group('BuildChannelConfig', () {
    test('supports Play Stable', () {
      final config = BuildChannelConfig.parse(flavor: 'play', track: 'stable');

      expect(config.distributionChannel, DistributionChannel.play);
      expect(config.releaseTrack, ReleaseTrack.stable);
      expect(config.analyticsParameters, <String, Object>{
        'distribution_channel': 'play',
        'release_track': 'stable',
      });
    });

    test('supports both GitHub tracks', () {
      final stable = BuildChannelConfig.parse(
        flavor: 'github',
        track: 'stable',
      );
      final beta = BuildChannelConfig.parse(flavor: 'github', track: 'beta');

      expect(stable.releaseTrack.sourceBranch, 'main');
      expect(beta.releaseTrack.sourceBranch, 'beta');
    });

    test('rejects Play Beta', () {
      expect(
        () => BuildChannelConfig.parse(flavor: 'play', track: 'beta'),
        throwsStateError,
      );
    });

    test('rejects missing release identity without local defaults', () {
      expect(
        () => BuildChannelConfig.parse(flavor: null, track: null),
        throwsStateError,
      );
    });

    test('uses GitHub Beta for local defaults', () {
      final config = BuildChannelConfig.parse(
        flavor: null,
        track: null,
        allowLocalDefaults: true,
      );

      expect(config.distributionChannel, DistributionChannel.github);
      expect(config.releaseTrack, ReleaseTrack.beta);
    });
  });
}
