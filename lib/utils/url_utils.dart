import '../services/api_service.dart';
import 'package:flutter/material.dart';

/// URL utilities for handling both relative and absolute URLs
class UrlUtils {
  /// Get the full URL for an image/avatar
  /// If the URL is already absolute (starts with http:// or https://), return it as-is
  /// Otherwise, prepend the base URL
  static String getFullUrl(String? url) {
    if (url == null || url.isEmpty) {
      return '';
    }

    // Clean up the URL first
    String cleanedUrl = url.trim();

    // FIRST: Check if URL is already absolute (with proper protocol)
    if (cleanedUrl.startsWith('http://') || cleanedUrl.startsWith('https://')) {
      return cleanedUrl;
    }

    // SECOND: Fix malformed protocols (missing colon)
    // Pattern: https//example.com -> https://example.com
    if (cleanedUrl.startsWith('https//')) {
      return cleanedUrl.replaceFirst('https//', 'https://');
    } else if (cleanedUrl.startsWith('http//')) {
      return cleanedUrl.replaceFirst('http//', 'http://');
    }

    // THIRD: Fix case where base URL was already prepended to external URL
    // Examples:
    // - "https://freetalk.sitehttps//example.com" -> "https://example.com"
    // - "https://freetalk.sitehttps://example.com" -> "https://example.com"
    final baseUrlPattern = RegExp(r'https?://[^/]+/?(https?[:/]+.*)$');
    final baseUrlMatch = baseUrlPattern.firstMatch(cleanedUrl);
    if (baseUrlMatch != null) {
      // Extract the external URL part
      cleanedUrl = baseUrlMatch.group(1)!;

      // Fix malformed protocol (missing colon)
      if (cleanedUrl.startsWith('https//')) {
        cleanedUrl = cleanedUrl.replaceFirst('https//', 'https://');
      } else if (cleanedUrl.startsWith('http//')) {
        cleanedUrl = cleanedUrl.replaceFirst('http//', 'http://');
      }
      // If it already has proper protocol, return as-is
      return cleanedUrl;
    }

    // FOURTH: Handle standalone malformed protocol anywhere in string
    // Pattern: "...https//example.com" -> "https://example.com"
    if (cleanedUrl.contains('https//') || cleanedUrl.contains('http//')) {
      final malformedMatch =
          RegExp(r'(https?//[^/\s]+.*)').firstMatch(cleanedUrl);
      if (malformedMatch != null) {
        cleanedUrl = malformedMatch.group(1)!;

        // Fix the protocol
        if (cleanedUrl.startsWith('https//')) {
          cleanedUrl = cleanedUrl.replaceFirst('https//', 'https://');
        } else if (cleanedUrl.startsWith('http//')) {
          cleanedUrl = cleanedUrl.replaceFirst('http//', 'http://');
        }

        return cleanedUrl;
      }
    }

    // LAST: Otherwise, treat as relative URL and prepend the base URL
    // Remove leading slash if present to avoid double slashes
    final relativeUrl =
        cleanedUrl.startsWith('/') ? cleanedUrl.substring(1) : cleanedUrl;
    return '${ApiService.baseUrl}/$relativeUrl';
  }

  /// Get the full URL for a video
  static String getFullVideoUrl(String? url) {
    return getFullUrl(url);
  }

  /// Get the full URL for an avatar
  static String getFullAvatarUrl(String? url) {
    final fullUrl = getFullUrl(url);

    // Use proxy endpoint for external avatar URLs to bypass CORS
    if (fullUrl.startsWith('http://') &&
        !fullUrl.startsWith('${ApiService.baseUrl}/')) {
      // External URL - proxy through our backend
      return '${ApiService.baseUrl}/api/images/proxy?url=${Uri.encodeComponent(fullUrl)}';
    } else if (fullUrl.startsWith('https://') &&
        !fullUrl.startsWith('${ApiService.baseUrl}/')) {
      // External HTTPS URL - proxy through our backend
      return '${ApiService.baseUrl}/api/images/proxy?url=${Uri.encodeComponent(fullUrl)}';
    }

    // Internal URL or local - return as-is
    return fullUrl;
  }

  /// Get the full URL for a post image
  static String getFullImageUrl(String? url) {
    return getFullUrl(url);
  }

  /// Check if a URL is absolute (external)
  static bool isAbsoluteUrl(String? url) {
    if (url == null || url.isEmpty) {
      return false;
    }
    return url.startsWith('http://') || url.startsWith('https://');
  }

  /// Check if a URL is relative (internal/uploaded)
  static bool isRelativeUrl(String? url) {
    return !isAbsoluteUrl(url) && url != null && url.isNotEmpty;
  }

  /// Check if an avatar URL is a local asset (for bots and default avatars)
  /// Supports both 'assets/...' and '/assets/...' formats
  static bool isLocalAsset(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('assets/') || url.startsWith('/assets/');
  }

  /// Check if an avatar URL is a bot avatar API endpoint
  /// Bot avatars are served from /api/user/bot-avatar/{botId} endpoints
  static bool isBotAvatarEndpoint(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.contains('/api/user/bot-avatar/') ||
        url.startsWith('/api/user/bot-avatar/');
  }

  /// Get the appropriate ImageProvider for an avatar
  /// Handles:
  /// - Local assets (assets/... or /assets/...)
  /// - Bot avatar endpoints (/api/user/bot-avatar/...)
  /// - Network URLs (http://... https://...)
  static ImageProvider getAvatarImageProvider(String? url) {
    if (url == null || url.isEmpty) {
      return const AssetImage('assets/icon/default_avatar.jpg'); // Fallback
    }

    if (isLocalAsset(url)) {
      // Local asset (like bot avatars stored in assets folder)
      final assetPath = url.startsWith('/') ? url.substring(1) : url;
      return AssetImage(assetPath);
    } else if (isBotAvatarEndpoint(url)) {
      // Bot avatar API endpoint - treat as network image
      return NetworkImage(getFullAvatarUrl(url));
    } else {
      // Network URL or other paths
      return NetworkImage(getFullAvatarUrl(url));
    }
  }
}
