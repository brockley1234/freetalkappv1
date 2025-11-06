// Conditional export for file download based on platform
export 'file_download_stub.dart'
    if (dart.library.html) 'file_download_web.dart';
