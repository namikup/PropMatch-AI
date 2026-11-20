import 'report_downloader_stub.dart'
    if (dart.library.html) 'report_downloader_web.dart';

/// Provides safe file downloading for web environments with fallback for tests.
class CRMReportDownloader {
  static void downloadCsv({
    required String content,
    required String filename,
  }) {
    downloadReportPlatform(content: content, filename: filename);
  }
}
