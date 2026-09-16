class YoutubeVideo {
  YoutubeVideo._();

  static String? idFromUrl(String raw) {
    final input = raw.trim();
    if (input.isEmpty) return null;

    final uri = Uri.tryParse(input);
    if (uri == null) return null;

    final host = uri.host.replaceFirst('www.', '').replaceFirst('m.', '');
    if (host == 'youtu.be') {
      if (uri.pathSegments.isEmpty) return null;
      return _cleanId(uri.pathSegments.first);
    }

    if (host.contains('youtube.com')) {
      final v = uri.queryParameters['v'];
      if (v != null && v.isNotEmpty) return _cleanId(v);

      final segments = uri.pathSegments;
      if (segments.length >= 2 &&
          (segments.first == 'live' ||
              segments.first == 'embed' ||
              segments.first == 'shorts' ||
              segments.first == 'v')) {
        return _cleanId(segments[1]);
      }
    }

    final match = RegExp(r'(?:v=|/live/|/embed/|/shorts/|youtu\.be/)([A-Za-z0-9_-]{11})')
        .firstMatch(input);
    return match?.group(1);
  }

  static String embedUrl(String videoId) {
    return 'https://www.youtube.com/embed/$videoId'
        '?autoplay=1&playsinline=1&rel=0&modestbranding=1';
  }

  static String? _cleanId(String value) {
    final id = value.split('?').first.split('&').first;
    if (id.length < 8) return null;
    return id;
  }
}
