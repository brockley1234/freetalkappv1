// Web implementation for downloading files
import 'dart:typed_data';
import 'package:web/web.dart' as web;
import 'dart:js_interop';

class FileDownloader {
  static void downloadFile(Uint8List bytes, String fileName) {
    // Create a Blob from the bytes
    final blob = web.Blob([bytes.toJS].toJS);

    // Create a download URL
    final url = web.URL.createObjectURL(blob);

    // Create an anchor element and trigger download
    final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
    anchor.href = url;
    anchor.download = fileName;
    anchor.style.display = 'none';

    // Append to body, click, and remove
    web.document.body?.appendChild(anchor);
    anchor.click();
    web.document.body?.removeChild(anchor);

    // Revoke the object URL to free up memory
    web.URL.revokeObjectURL(url);
  }
}
