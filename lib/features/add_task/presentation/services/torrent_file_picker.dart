import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

class PickedTorrentFile {
  final String fileName;
  final Uint8List bytes;

  const PickedTorrentFile({
    required this.fileName,
    required this.bytes,
  });
}

class TorrentFilePicker {
  const TorrentFilePicker();

  Future<PickedTorrentFile?> pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['torrent'],
      withData: true,
    );

    final file = result?.files.firstOrNull;
    final bytes = file?.bytes;
    if (file == null || bytes == null || bytes.isEmpty) {
      return null;
    }

    return PickedTorrentFile(fileName: file.name, bytes: bytes);
  }
}
