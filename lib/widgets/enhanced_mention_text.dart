import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/link_metadata_service.dart';
import '../utils/app_logger.dart';

/// Enhanced version of MentionText that also renders rich link previews
/// Displays URLs as expandable preview cards with metadata
class EnhancedMentionText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? mentionStyle;
  final TextStyle? urlStyle;
  final Function(String)? onMentionTap;
  final Function(String, String)? onMentionTapWithId;
  final Function(String)? onUrlTap;
  final int? maxLines;
  final TextOverflow? overflow;
  final Map<String, String>? mentionIdMap;
  final bool enableLinkPreviews; // New: Enable rich link previews
  final bool showLinkPreviewsBelowText; // New: Show previews below text instead of inline

  const EnhancedMentionText({
    super.key,
    required this.text,
    this.style,
    this.mentionStyle,
    this.urlStyle,
    this.onMentionTap,
    this.onMentionTapWithId,
    this.onUrlTap,
    this.maxLines,
    this.overflow,
    this.mentionIdMap,
    this.enableLinkPreviews = true,
    this.showLinkPreviewsBelowText = true,
  });

  @override
  State<EnhancedMentionText> createState() => _EnhancedMentionTextState();
}

class _EnhancedMentionTextState extends State<EnhancedMentionText> {
  final _logger = AppLogger();
  final _linkMetadataService = LinkMetadataService();
  final Map<String, LinkMetadata?> _linkMetadataCache = {};
  final Set<String> _loadingLinks = {};

  @override
  Widget build(BuildContext context) {
    final defaultStyle =
        widget.style ?? const TextStyle(fontSize: 16, color: Colors.black87);
    final defaultMentionStyle = widget.mentionStyle ??
        const TextStyle(
          fontSize: 16,
          color: Colors.blue,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        );
    final defaultUrlStyle = widget.urlStyle ??
        const TextStyle(
          fontSize: 16,
          color: Colors.blue,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        );

    // Parse the text for @mentions and URLs
    final spans = <InlineSpan>[];
    
    // Regex patterns
    final mentionRegex = RegExp(r'@([A-Za-z]+(?:\s+[A-Za-z]+)*)');
    final urlRegex = RegExp(
      r'(?:https?:\/\/|www\.)[^\s]+',
      multiLine: true,
      caseSensitive: false,
    );

    // Create a combined list of all matches with types
    final allMatches = <({int start, int end, String type, Match match})>[];

    for (final match in mentionRegex.allMatches(widget.text)) {
      allMatches.add((start: match.start, end: match.end, type: 'mention', match: match));
    }

    for (final match in urlRegex.allMatches(widget.text)) {
      allMatches.add((start: match.start, end: match.end, type: 'url', match: match));
    }

    // Sort by start position
    allMatches.sort((a, b) => a.start.compareTo(b.start));

    int lastIndex = 0;
    final extractedUrls = <String>[];

    for (final item in allMatches) {
      // Skip overlapping matches
      if (item.start < lastIndex) continue;

      // Add text before this match
      if (item.start > lastIndex) {
        spans.add(
          TextSpan(
            text: widget.text.substring(lastIndex, item.start),
            style: defaultStyle,
          ),
        );
      }

      if (item.type == 'mention') {
        // Handle mention
        final match = item.match;
        final mentionText = match.group(0)!;
        final userName = match.group(1)!;
        final userId = widget.mentionIdMap?[userName];

        spans.add(
          TextSpan(
            text: mentionText,
            style: defaultMentionStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                if (widget.onMentionTapWithId != null && userId != null) {
                  widget.onMentionTapWithId!(userName, userId);
                } else if (widget.onMentionTap != null) {
                  widget.onMentionTap!(userName);
                }
              },
          ),
        );
      } else if (item.type == 'url') {
        // Handle URL
        final urlText = item.match.group(0)!;
        var urlToOpen = urlText;

        // Add https:// if missing
        if (!urlToOpen.startsWith('http://') &&
            !urlToOpen.startsWith('https://')) {
          urlToOpen = 'https://$urlToOpen';
        }

        extractedUrls.add(urlToOpen);

        spans.add(
          TextSpan(
            text: urlText,
            style: defaultUrlStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                if (widget.onUrlTap != null) {
                  widget.onUrlTap!(urlToOpen);
                } else {
                  // Default: Try to launch the URL
                  try {
                    if (await canLaunchUrl(Uri.parse(urlToOpen))) {
                      await launchUrl(Uri.parse(urlToOpen),
                          mode: LaunchMode.externalApplication);
                    }
                  } catch (e) {
                    debugPrint('Error launching URL: $e');
                  }
                }
              },
          ),
        );
      }

      lastIndex = item.end;
    }

    // Add remaining text
    if (lastIndex < widget.text.length) {
      spans.add(
        TextSpan(
          text: widget.text.substring(lastIndex),
          style: defaultStyle,
        ),
      );
    }

    // Build the column with text and link previews
    if (widget.enableLinkPreviews && widget.showLinkPreviewsBelowText && extractedUrls.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Text with mentions and URLs
          RichText(
            text: TextSpan(children: spans),
            maxLines: widget.maxLines,
            overflow: widget.overflow ?? TextOverflow.visible,
          ),
          // Link previews below
          SizedBox(height: extractedUrls.isNotEmpty ? 8 : 0),
          ...extractedUrls.map((url) => _buildLinkPreview(url)),
        ],
      );
    } else {
      // Just render text without previews
      return RichText(
        text: TextSpan(children: spans),
        maxLines: widget.maxLines,
        overflow: widget.overflow ?? TextOverflow.visible,
      );
    }
  }

  /// Build a link preview widget for a URL
  Widget _buildLinkPreview(String url) {
    if (!_linkMetadataCache.containsKey(url)) {
      _loadingLinks.add(url);
      _linkMetadataService.extractMetadata(url).then((metadata) {
        if (mounted) {
          setState(() {
            _linkMetadataCache[url] = metadata;
            _loadingLinks.remove(url);
          });
        }
      }).catchError((e) {
        _logger.error('Error loading link preview for $url', error: e);
        if (mounted) {
          setState(() {
            _loadingLinks.remove(url);
          });
        }
      });
    }

    final metadata = _linkMetadataCache[url];
    final isLoading = _loadingLinks.contains(url);

    if (isLoading) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Container(
          height: 100,
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (metadata == null) {
      // Fallback to simple link if metadata extraction failed
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: _buildSimpleLinkPreview(url),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: _EnhancedLinkPreviewCard(
        metadata: metadata,
        onTap: () async {
          try {
            if (await canLaunchUrl(Uri.parse(url))) {
              await launchUrl(Uri.parse(url),
                  mode: LaunchMode.externalApplication);
            }
          } catch (e) {
            _logger.error('Error launching URL', error: e);
          }
        },
      ),
    );
  }

  /// Build a simple link preview when metadata extraction fails
  Widget _buildSimpleLinkPreview(String url) {
    final domain = Uri.parse(url).host.replaceFirst('www.', '');
    return GestureDetector(
      onTap: () async {
        try {
          if (await canLaunchUrl(Uri.parse(url))) {
            await launchUrl(Uri.parse(url),
                mode: LaunchMode.externalApplication);
          }
        } catch (e) {
          _logger.error('Error launching URL', error: e);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.link, color: Colors.blue.shade600, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    domain,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.blue.shade600,
                    ),
                  ),
                  Text(
                    url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.open_in_new, color: Colors.grey[400], size: 16),
          ],
        ),
      ),
    );
  }
}

/// Enhanced link preview card with better styling and visual hierarchy
class _EnhancedLinkPreviewCard extends StatefulWidget {
  final LinkMetadata metadata;
  final VoidCallback onTap;

  const _EnhancedLinkPreviewCard({
    required this.metadata,
    required this.onTap,
  });

  @override
  State<_EnhancedLinkPreviewCard> createState() =>
      _EnhancedLinkPreviewCardState();
}

class _EnhancedLinkPreviewCardState extends State<_EnhancedLinkPreviewCard> {
  bool _isHovering = false;

  @override
  Widget build(BuildContext context) {
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: isDarkMode ? Colors.grey[900] : Colors.white,
            border: Border.all(
              color: _isHovering
                  ? Colors.blue.shade400
                  : (isDarkMode ? Colors.grey[700]! : Colors.grey[300]!),
              width: _isHovering ? 2 : 1.5,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: _isHovering
                ? [
                    BoxShadow(
                      color: Colors.blue.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image section (if available)
                if (widget.metadata.imageUrl != null &&
                    widget.metadata.imageUrl!.isNotEmpty)
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                    ),
                    child: Image.network(
                      widget.metadata.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.grey[300],
                        child: Icon(Icons.image_not_supported,
                            color: Colors.grey[600]),
                      ),
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return Container(
                          color: Colors.grey[300],
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      },
                    ),
                  )
                else
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.blue.shade100,
                          Colors.blue.shade50,
                        ],
                      ),
                    ),
                    child: Icon(
                      Icons.language,
                      size: 40,
                      color: Colors.blue.shade400,
                    ),
                  ),

                // Content section
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Title
                        if (widget.metadata.title != null &&
                            widget.metadata.title!.isNotEmpty)
                          Expanded(
                            child: Text(
                              widget.metadata.title!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: isDarkMode
                                    ? Colors.grey[100]
                                    : Colors.grey[900],
                              ),
                            ),
                          ),

                        // Description
                        if (widget.metadata.description != null &&
                            widget.metadata.description!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              widget.metadata.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: isDarkMode
                                    ? Colors.grey[400]
                                    : Colors.grey[600],
                              ),
                            ),
                          ),

                        // Domain with icon
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Row(
                            children: [
                              Icon(Icons.link,
                                  size: 13,
                                  color: Colors.blue.shade500),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  widget.metadata.domain,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.blue.shade500,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Action icon
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Icon(
                    Icons.open_in_new,
                    color: _isHovering ? Colors.blue.shade500 : Colors.grey[400],
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
