import 'dart:typed_data';

class PickedBackupFile {
  const PickedBackupFile({required this.fileName, required this.bytes});

  final String fileName;
  final Uint8List bytes;
}

abstract class BackupFileApi {
  Future<bool> saveBackup({required String fileName, required Uint8List bytes});

  Future<PickedBackupFile?> pickBackup();
}
