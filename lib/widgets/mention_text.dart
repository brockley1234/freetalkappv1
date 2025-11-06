import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class MentionText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? mentionStyle;
  final TextStyle? urlStyle; // New: Style for URLs
  final Function(String)? onMentionTap;
  final Function(String, String)? onMentionTapWithId; // userName, userId
  final Function(String)? onUrlTap; // New: Callback when URL is tapped
  final int? maxLines;
  final TextOverflow? overflow;
  final Map<String, String>? mentionIdMap; // Maps mention names to user IDs

  const MentionText({
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
  });

  @override
  Widget build(BuildContext context) {
    final defaultStyle =
        style ?? const TextStyle(fontSize: 16, color: Colors.black87);
    final defaultMentionStyle = mentionStyle ??
        const TextStyle(
          fontSize: 16,
          color: Colors.blue,
          fontWeight: FontWeight.w600,
          decoration: TextDecoration.underline,
        );
    final defaultUrlStyle = urlStyle ??
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

    for (final match in mentionRegex.allMatches(text)) {
      allMatches.add((start: match.start, end: match.end, type: 'mention', match: match));
    }

    for (final match in urlRegex.allMatches(text)) {
      allMatches.add((start: match.start, end: match.end, type: 'url', match: match));
    }

    // Sort by start position
    allMatches.sort((a, b) => a.start.compareTo(b.start));

    int lastIndex = 0;

    for (final item in allMatches) {
      // Skip overlapping matches
      if (item.start < lastIndex) continue;

      // Add text before this match
      if (item.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, item.start),
            style: defaultStyle,
          ),
        );
      }

      if (item.type == 'mention') {
        // Handle mention
        final match = item.match;
        final mentionText = match.group(0)!;
        final userName = match.group(1)!;
        final userId = mentionIdMap?[userName];

        spans.add(
          TextSpan(
            text: mentionText,
            style: defaultMentionStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () {
                if (onMentionTapWithId != null && userId != null) {
                  onMentionTapWithId!(userName, userId);
                } else if (onMentionTap != null) {
                  onMentionTap!(userName);
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

        spans.add(
          TextSpan(
            text: urlText,
            style: defaultUrlStyle,
            recognizer: TapGestureRecognizer()
              ..onTap = () async {
                if (onUrlTap != null) {
                  onUrlTap!(urlToOpen);
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
    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: defaultStyle));
    }

    return RichText(
      text: TextSpan(children: spans),
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
    );
  }
}
