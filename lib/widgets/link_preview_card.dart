import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/app_logger.dart';

/// A widget that displays a rich preview of a link
/// Shows title, description, image, and domain
/// Tapping the card opens the link
class LinkPreviewCard extends StatefulWidget {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? domain;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color borderColor;

  const LinkPreviewCard({
    super.key,
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.domain,
    this.onTap,
    this.backgroundColor = const Color(0xFFF5F5F5),
    this.borderColor = const Color(0xFFE0E0E0),
  });

  @override
  State<LinkPreviewCard> createState() => _LinkPreviewCardState();
}

class _LinkPreviewCardState extends State<LinkPreviewCard> {
  final _logger = AppLogger();
  bool _isHovering = false;

  Future<void> _openLink() async {
    try {
      var urlToOpen = widget.url;
      if (!urlToOpen.startsWith('http://') &&
          !urlToOpen.startsWith('https://')) {
        urlToOpen = 'https://$urlToOpen';
      }

      if (await canLaunchUrl(Uri.parse(urlToOpen))) {
        await launchUrl(Uri.parse(urlToOpen),
            mode: LaunchMode.externalApplication);
      } else {
        _logger.warning('Could not launch URL: $urlToOpen');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open link: $urlToOpen')),
          );
        }
      }
    } catch (e) {
      _logger.error('Error opening link', error: e);
    }
  }

  /// Extract domain from URL
  String _getDomain(String url) {
    try {
      final uri = Uri.parse(url);
      return uri.host.replaceFirst('www.', '');
    } catch (e) {
      return 'Link';
    }
  }

  @override
  Widget build(BuildContext context) {
    final domain = widget.domain ?? _getDomain(widget.url);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: GestureDetector(
        onTap: widget.onTap ?? _openLink,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: widget.backgroundColor,
            border: Border.all(
              color: _isHovering ? Colors.blue : widget.borderColor,
              width: _isHovering ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Row(
              children: [
                // Thumbnail image
                if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(8),
                      bottomLeft: Radius.circular(8),
                    ),
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrl!,
                      width: 120,
                      height: 120,
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        width: 120,
                        height: 120,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image, color: Colors.grey),
                      ),
                      errorWidget: (context, url, error) => Container(
                        width: 120,
                        height: 120,
                        color: Colors.grey[300],
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),

                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Title
                        if (widget.title != null && widget.title!.isNotEmpty)
                          Text(
                            widget.title!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),

                        const SizedBox(height: 4),

                        // Description
                        if (widget.description != null &&
                            widget.description!.isNotEmpty)
                          Text(
                            widget.description!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),

                        const SizedBox(height: 8),

                        // Domain
                        Row(
                          children: [
                            const Icon(Icons.link, size: 14, color: Colors.blue),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                domain,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Open icon
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.open_in_new,
                    color: _isHovering ? Colors.blue : Colors.grey,
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
