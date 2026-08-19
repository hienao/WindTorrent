import 'package:windwalker/features/update/domain/update_check_result.dart';

abstract interface class UpdateService {
  UpdateSource get source;

  Future<UpdateCheckResult> checkForUpdate();

  Future<void> openUpdatePage(UpdateCheckResult result);
}
