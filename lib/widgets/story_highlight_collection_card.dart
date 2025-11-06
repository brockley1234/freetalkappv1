import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/responsive_sizing.dart';

class StoryHighlightCollectionCard extends StatelessWidget {
  final Map<String, dynamic> collection;
  final VoidCallback? onTap;
  final Function(String storyId, String collectionName)? onAddStory;
  final Function(String storyId)? onRemoveStory;

  const StoryHighlightCollectionCard({
    super.key,
    required this.collection,
    this.onTap,
    this.onAddStory,
    this.onRemoveStory,
  });

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final collectionName = collection['name'] ?? 'Untitled';
    final storyCount = collection['count'] ?? 0;
    final cover = collection['cover'];
    final stories = List<Map<String, dynamic>>.from(
      collection['stories'] ?? []
    );

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(responsive.radiusLarge),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Cover image
            Expanded(
              flex: 3,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(responsive.radiusLarge),
                    topRight: Radius.circular(responsive.radiusLarge),
                  ),
                  color: Colors.grey[200],
                ),
                child: cover != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(responsive.radiusLarge),
                          topRight: Radius.circular(responsive.radiusLarge),
                        ),
                        child: Image.network(
                          '${ApiService.baseApi}$cover',
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => _buildDefaultCover(),
                        ),
                      )
                    : _buildStoryGridCover(stories),
              ),
            ),
            // Collection info
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.all(responsive.paddingMedium),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collectionName,
                      style: TextStyle(
                        fontSize: responsive.fontMedium,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: responsive.paddingXSmall),
                    Row(
                      children: [
                        Icon(
                          Icons.collections_bookmark,
                          size: responsive.iconSmall,
                          color: Colors.grey[600],
                        ),
                        SizedBox(width: responsive.paddingXSmall),
                        Text(
                          '$storyCount ${storyCount == 1 ? 'story' : 'stories'}',
                          style: TextStyle(
                            fontSize: responsive.fontSmall,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (onAddStory != null || onRemoveStory != null)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (onAddStory != null)
                            IconButton(
                              icon: Icon(
                                Icons.add_circle_outline,
                                size: responsive.iconSmall,
                                color: Theme.of(context).primaryColor,
                              ),
                              onPressed: () => _showAddStoryDialog(context),
                            ),
                          if (onRemoveStory != null && stories.isNotEmpty)
                            IconButton(
                              icon: Icon(
                                Icons.remove_circle_outline,
                                size: responsive.iconSmall,
                                color: Colors.red[600],
                              ),
                              onPressed: () => _showRemoveStoryDialog(context, stories),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultCover() {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue[400]!,
            Colors.purple[400]!,
          ],
        ),
      ),
      child: const Center(
        child: Icon(
          Icons.collections_bookmark,
          size: 40,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildStoryGridCover(List<Map<String, dynamic>> stories) {
    if (stories.isEmpty) {
      return _buildDefaultCover();
    }

    // Show a grid of the first 4 stories as cover
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: stories.length > 4 ? 4 : stories.length,
      itemBuilder: (context, index) {
        final story = stories[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(4),
          ),
          child: story['mediaType'] == 'image' && story['mediaUrl'] != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: Image.network(
                    '${ApiService.baseApi}${story['mediaUrl']}',
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey[300],
                      child: Icon(Icons.image, color: Colors.grey[600]),
                    ),
                  ),
                )
              : story['mediaType'] == 'video' && story['mediaUrl'] != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(
                        children: [
                          Image.network(
                            '${ApiService.baseApi}${story['mediaUrl']}',
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey[300],
                              child: Icon(Icons.videocam, color: Colors.grey[600]),
                            ),
                          ),
                          const Center(
                            child: Icon(
                              Icons.play_circle_filled,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      color: Colors.grey[300],
                      child: Icon(Icons.text_fields, color: Colors.grey[600]),
                    ),
        );
      },
    );
  }

  void _showAddStoryDialog(BuildContext context) {
    // This would typically show a dialog to select a story to add
    // For now, we'll show a placeholder
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Story to Collection'),
        content: const Text('This feature will allow you to select stories to add to this collection.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showRemoveStoryDialog(BuildContext context, List<Map<String, dynamic>> stories) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Story'),
        content: const Text('Select a story to remove from this collection.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ...stories.map((story) => ListTile(
            title: Text(story['caption'] ?? 'Untitled Story'),
            onTap: () {
              Navigator.pop(context);
              onRemoveStory?.call(story['_id']);
            },
          )),
        ],
      ),
    );
  }
}
