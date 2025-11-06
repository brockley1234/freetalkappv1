import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../utils/responsive_sizing_extension.dart';

/// Widget to display archived story highlights/collections
/// 
/// Shows a carousel of story collections with:
/// - Collection name and cover image
/// - Edit/delete options
/// - Share functionality
class StoryHighlightWidget extends StatefulWidget {
  final String userId;
  final VoidCallback? onHighlightTap;

  const StoryHighlightWidget({
    super.key,
    required this.userId,
    this.onHighlightTap,
  });

  @override
  State<StoryHighlightWidget> createState() => _StoryHighlightWidgetState();
}

class _StoryHighlightWidgetState extends State<StoryHighlightWidget> {
  late Future<List<dynamic>> _highlightsFuture;
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _loadHighlights();
  }

  void _loadHighlights() {
    _highlightsFuture = ApiService.getUserHighlights(widget.userId)
        .then<List<dynamic>>((result) {
          if (result['success']) {
            return result['data']['highlights'] ?? [];
          }
          return [];
        })
        .catchError((e) {
          debugPrint('❌ Error loading highlights: $e');
          return <dynamic>[];
        });
  }

  Future<void> _deleteHighlight(String highlightId) async {
    try {
      final result = await ApiService.deleteHighlight(highlightId);
      if (result['success'] && mounted) {
        setState(() {
          _loadHighlights();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Highlight deleted'),
            backgroundColor: Colors.green,
            duration: Duration(milliseconds: 800),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Error deleting highlight: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return FutureBuilder<List<dynamic>>(
      future: _highlightsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: SizedBox(
              height: 100,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.bookmark_border,
                  size: 48,
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 12),
                Text(
                  'No story highlights yet',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: responsive.fontMedium,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Archive your favorite stories to create highlights',
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: responsive.fontSmall,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final highlights = snapshot.data!;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with title and edit toggle
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: responsive.paddingMedium,
                vertical: responsive.paddingSmall,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Story Highlights',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  if (highlights.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _isEditing = !_isEditing;
                        });
                      },
                      child: Text(
                        _isEditing ? 'Done' : 'Edit',
                        style: TextStyle(
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: responsive.fontMedium,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Highlights carousel
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: EdgeInsets.symmetric(
                  horizontal: responsive.paddingMedium,
                ),
                itemCount: highlights.length,
                itemBuilder: (context, index) {
                  final highlight = highlights[index] as Map<String, dynamic>;
                  final name = highlight['name'] ?? 'Unnamed';
                  final storyCount = (highlight['stories'] as List?)?.length ?? 0;
                  final coverImage = highlight['coverImage'] as String?;

                  return Padding(
                    padding: EdgeInsets.only(right: responsive.paddingMedium),
                    child: _buildHighlightCard(
                      context: context,
                      name: name,
                      storyCount: storyCount,
                      coverImage: coverImage,
                      isEditing: _isEditing,
                      onDelete: () => _deleteHighlight(highlight['_id']),
                      onTap: () {
                        widget.onHighlightTap?.call();
                        // Navigate to highlight detail page
                        context.push('/highlight/${highlight['_id']}');
                      },
                      responsive: responsive,
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHighlightCard({
    required BuildContext context,
    required String name,
    required int storyCount,
    String? coverImage,
    required bool isEditing,
    required VoidCallback onDelete,
    required VoidCallback onTap,
    required ResponsiveSizing responsive,
  }) {
    return GestureDetector(
      onTap: isEditing ? null : onTap,
      onLongPress: isEditing ? onDelete : null,
      child: Stack(
        children: [
          // Highlight card
          Container(
            width: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(responsive.radiusLarge),
              border: Border.all(
                color: Colors.grey.shade300,
                width: 2,
              ),
              color: Colors.grey.shade100,
              image: coverImage != null
                  ? DecorationImage(
                      image: NetworkImage(coverImage),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: coverImage == null
                ? Center(
                    child: Icon(
                      Icons.bookmark_outline,
                      size: 32,
                      color: Colors.grey.shade400,
                    ),
                  )
                : null,
          ),

          // Overlay with info
          Container(
            width: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(responsive.radiusLarge),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.7),
                ],
              ),
            ),
            child: Padding(
              padding: EdgeInsets.all(responsive.paddingSmall),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: responsive.fontSmall,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '$storyCount ${storyCount == 1 ? "story" : "stories"}',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: responsive.fontXSmall,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Delete button (if editing)
          if (isEditing)
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onDelete,
                child: Container(
                  padding: EdgeInsets.all(responsive.paddingXSmall),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.close,
                    size: responsive.iconSmall,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
