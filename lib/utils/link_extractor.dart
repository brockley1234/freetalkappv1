/// Utility for extracting and managing links in text content
class LinkExtractor {
  /// Regular expression to match URLs
  static final RegExp urlRegex = RegExp(
    r'(?:https?:\/\/|www\.)[^\s]+',
    multiLine: true,
    caseSensitive: false,
  );

  /// Extract all URLs from text
  static List<String> extractUrls(String text) {
    final matches = urlRegex.allMatches(text);
    final urls = <String>[];

    for (final match in matches) {
      var url = match.group(0)!;

      // Add https:// if missing
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }

      urls.add(url);
    }

    return urls;
  }

  /// Get the first URL from text (primary link)
  static String? getFirstUrl(String text) {
    final urls = extractUrls(text);
    return urls.isNotEmpty ? urls.first : null;
  }

  /// Check if text contains any URLs
  static bool hasUrls(String text) {
    return urlRegex.hasMatch(text);
  }

  /// Extract domain from URL
  static String getDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (e) {
      return 'Link';
    }
  }

  /// Get domain name only (e.g., "xbox" from "www.xbox.com")
  static String getDomainName(String url) {
    try {
      final domain = getDomain(url);
      return domain.split('.').first;
    } catch (e) {
      return 'Link';
    }
  }

  /// Format URL for display
  static String formatUrlForDisplay(String url) {
    try {
      final uri = Uri.parse(url);
      return '${uri.host}${uri.path}';
    } catch (e) {
      return url;
    }
  }

  /// Remove protocol from URL
  static String removeProtocol(String url) {
    return url.replaceFirst(RegExp(r'^https?://'), '');
  }
}
