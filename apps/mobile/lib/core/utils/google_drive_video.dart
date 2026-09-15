/// Helpers for publicly shared Google Drive video files.
class GoogleDriveVideo {
  GoogleDriveVideo._();

  static String? fileIdFromUrl(String url) {
    final patterns = [
      RegExp(r'/file/d/([a-zA-Z0-9_-]+)'),
      RegExp(r'[?&]id=([a-zA-Z0-9_-]+)'),
    ];
    for (final pattern in patterns) {
      final match = pattern.firstMatch(url);
      if (match != null) return match.group(1);
    }
    return null;
  }

  /// Google Drive embed player — works in WebView (unlike direct download URLs).
  static String previewUrl(String fileId) =>
      'https://drive.google.com/file/d/$fileId/preview';

  static String viewUrl(String fileId) =>
      'https://drive.google.com/file/d/$fileId/view';
}
