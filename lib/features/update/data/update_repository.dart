import 'package:windwalker/core/config/build_channel_config.dart';
import 'package:windwalker/features/update/data/github_release_update_service.dart';
import 'package:windwalker/features/update/data/play_store_update_service.dart';
import 'package:windwalker/features/update/data/update_service.dart';
import 'package:windwalker/features/update/domain/update_check_result.dart';

abstract interface class UpdateRepository {
  UpdateSource get source;

  Future<UpdateCheckResult> checkForUpdate();

  Future<void> openUpdatePage(UpdateCheckResult result);
}

class ChannelUpdateRepository implements UpdateRepository {
  ChannelUpdateRepository(UpdateService service) : _service = service;

  factory ChannelUpdateRepository.forBuild(BuildChannelConfig config) {
    final service = switch (config.distributionChannel) {
      DistributionChannel.play => PlayStoreUpdateService(),
      DistributionChannel.github => GitHubReleaseUpdateService(
        releaseTrack: config.releaseTrack,
      ),
    };
    return ChannelUpdateRepository(service);
  }

  final UpdateService _service;

  @override
  UpdateSource get source => _service.source;

  @override
  Future<UpdateCheckResult> checkForUpdate() => _service.checkForUpdate();

  @override
  Future<void> openUpdatePage(UpdateCheckResult result) =>
      _service.openUpdatePage(result);
}
