import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as html_parser;
import '../utils/app_logger.dart';

/// Service to extract metadata from URLs (title, description, image)
/// This enables rich link previews in posts and comments
class LinkMetadataService {
  static final LinkMetadataService _instance = LinkMetadataService._internal();
  final _logger = AppLogger();
  
  // Cache to avoid repeated requests for the same URL
  final Map<String, LinkMetadata> _cache = {};

  LinkMetadataService._internal();

  factory LinkMetadataService() {
    return _instance;
  }

  /// Extract metadata from a URL
  /// Returns [LinkMetadata] with title, description, image, and domain
  /// Uses Open Graph and Twitter Card meta tags when available
  Future<LinkMetadata> extractMetadata(String url) async {
    try {
      // Check cache first
      if (_cache.containsKey(url)) {
        return _cache[url]!;
      }

      _logger.info('🔍 Extracting metadata from: $url');
      
      // Validate URL
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }

      // Fetch the page
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => http.Response('', 408),
      );

      if (response.statusCode != 200) {
        _logger.warning('Failed to fetch $url: ${response.statusCode}');
        return _createFallbackMetadata(url);
      }

      final document = html_parser.parse(response.body);
      
      // Extract metadata from meta tags
      final title = _extractMetaTag(document, ['og:title', 'twitter:title', 'title']) 
        ?? _extractTitleTag(document);
      
      final description = _extractMetaTag(document, ['og:description', 'twitter:description', 'description'])
        ?? _extractMetaContent(document, 'description');
      
      final image = _extractMetaTag(document, ['og:image', 'twitter:image', 'image'])
        ?? _extractFaviconUrl(url);
      
      final domain = _extractDomain(url);

      final metadata = LinkMetadata(
        url: url,
        title: title,
        description: description,
        imageUrl: image,
        domain: domain,
      );

      // Cache the result
      _cache[url] = metadata;
      _logger.info('✅ Extracted metadata for: ${metadata.domain}');
      
      return metadata;
    } catch (e) {
      _logger.error('Error extracting metadata', error: e);
      return _createFallbackMetadata(url);
    }
  }

  /// Extract meta tag value from document
  String? _extractMetaTag(dynamic document, List<String> propertyNames) {
    try {
      for (final property in propertyNames) {
        final element = document.querySelector('meta[property="$property"], meta[name="$property"]');
        if (element != null) {
          final content = element.attributes['content'];
          if (content != null && content.isNotEmpty) {
            return content;
          }
        }
      }
    } catch (e) {
      _logger.debug('Error extracting meta tag: $e');
    }
    return null;
  }

  /// Extract title from title tag
  String? _extractTitleTag(dynamic document) {
    try {
      final titleElement = document.querySelector('title');
      if (titleElement != null && titleElement.text.isNotEmpty) {
        return titleElement.text;
      }
    } catch (e) {
      _logger.debug('Error extracting title: $e');
    }
    return null;
  }

  /// Extract meta content attribute
  String? _extractMetaContent(dynamic document, String name) {
    try {
      final element = document.querySelector('meta[name="$name"]');
      if (element != null) {
        return element.attributes['content'];
      }
    } catch (e) {
      _logger.debug('Error extracting meta content: $e');
    }
    return null;
  }

  /// Extract favicon URL from document
  String? _extractFaviconUrl(String baseUrl) {
    try {
      final uri = Uri.parse(baseUrl);
      final faviconUrl = '${uri.scheme}://${uri.host}/favicon.ico';
      return faviconUrl;
    } catch (e) {
      _logger.debug('Error extracting favicon: $e');
    }
    return null;
  }

  /// Extract domain from URL
  String _extractDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (e) {
      return 'Link';
    }
  }

  /// Create fallback metadata when extraction fails
  LinkMetadata _createFallbackMetadata(String url) {
    return LinkMetadata(
      url: url,
      title: url,
      description: 'Visit link',
      imageUrl: null,
      domain: _extractDomain(url),
    );
  }

  /// Clear cache
  void clearCache() {
    _cache.clear();
    _logger.info('🗑️ Link metadata cache cleared');
  }

  /// Clear specific URL from cache
  void clearCacheForUrl(String url) {
    _cache.remove(url);
  }
}

/// Model for link metadata
class LinkMetadata {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String domain;

  LinkMetadata({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    required this.domain,
  });

  @override
  String toString() => 'LinkMetadata(domain: $domain, title: $title)';
}
