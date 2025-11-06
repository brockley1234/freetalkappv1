// Stub implementation for platforms that don't support web downloads
import 'dart:typed_data';

class FileDownloader {
  static void downloadFile(Uint8List bytes, String fileName) {
    throw UnsupportedError('File download not supported on this platform');
  }
}
