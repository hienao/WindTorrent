import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:windwalker/features/backup/data/backup_file_api.dart';

class FilePickerBackupFileApi implements BackupFileApi {
  const FilePickerBackupFileApi();

  @override
  Future<bool> saveBackup({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final savedPath = await FilePicker.saveFile(
      dialogTitle: 'Export WindTorrent backup',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: const ['json'],
      bytes: bytes,
    );
    return savedPath != null;
  }

  @override
  Future<PickedBackupFile?> pickBackup() async {
    final result = await FilePicker.pickFiles(
      dialogTitle: 'Import WindTorrent backup',
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
    );
    final file = result?.files.singleOrNull;
    if (file == null) {
      return null;
    }
    final bytes = file.bytes;
    if (bytes == null) {
      throw const FormatException('The selected file could not be read');
    }
    return PickedBackupFile(fileName: file.name, bytes: bytes);
  }
}
