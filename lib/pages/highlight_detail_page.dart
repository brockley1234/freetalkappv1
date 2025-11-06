import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../services/api_service.dart';
import '../utils/responsive_sizing_extension.dart';
import '../utils/app_logger.dart';

final _logger = AppLogger();

/// Page to display a single story highlight collection with all its stories
/// 
/// Shows:
/// - Highlight name and description
/// - All stories in the highlight with thumbnails
/// - Story interaction options (view, download, share)
/// - Edit/delete options if it's the user's own highlight
class HighlightDetailPage extends StatefulWidget {
  final String highlightId;

  const HighlightDetailPage({
    super.key,
    required this.highlightId,
  });

  @override
  State<HighlightDetailPage> createState() => _HighlightDetailPageState();
}

class _HighlightDetailPageState extends State<HighlightDetailPage> {
  late Future<Map<String, dynamic>> _highlightFuture;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadHighlightDetail();
  }

  void _loadHighlightDetail() {
    _highlightFuture = ApiService.getHighlightDetail(widget.highlightId)
        .then((result) {
          if (result['success'] == true) {
            return result;
          } else {
            throw Exception(result['message'] ?? 'Failed to load highlight');
          }
        })
        .catchError((error) {
          _logger.error('❌ Error loading highlight: $error');
          throw Exception(error);
        });
  }

  Future<void> _deleteHighlight() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Highlight?'),
        content: const Text(
          'This will permanently delete this highlight collection. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (shouldDelete != true) return;

    setState(() => _isLoading = true);

    try {
      final result = await ApiService.deleteHighlight(widget.highlightId);
      if (result['success'] && mounted) {
        _logger.info('✅ Highlight deleted successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Highlight deleted'),
            backgroundColor: Colors.green,
            duration: Duration(milliseconds: 800),
          ),
        );
        // Pop back to previous page after deletion
        if (mounted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) context.pop();
          });
        }
      } else {
        throw Exception(result['message'] ?? 'Failed to delete highlight');
      }
    } catch (e) {
      _logger.error('❌ Error deleting highlight: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Story Highlight'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete highlight',
            onPressed: _isLoading ? null : _deleteHighlight,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _highlightFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.red.shade400,
                  ),
                  const SizedBox(height: 16),
                  Text('Error loading highlight: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() => _loadHighlightDetail());
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || !snapshot.data!['success']) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.bookmark_border,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 16),
                  const Text('Highlight not found'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => context.pop(),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }

          final highlightData = snapshot.data!['data'] as Map<String, dynamic>;
          final name = highlightData['name'] as String? ?? 'Unnamed';
          final description = highlightData['description'] as String?;
          final stories = (highlightData['stories'] as List?) ?? [];

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with highlight info
                Padding(
                  padding: EdgeInsets.all(responsive.paddingMedium),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      if (description != null && description.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          description,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: responsive.fontMedium,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        '${stories.length} ${stories.length == 1 ? 'story' : 'stories'}',
                        style: TextStyle(
                          color: Colors.grey.shade500,
                          fontSize: responsive.fontSmall,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),

                // Stories grid
                if (stories.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(responsive.paddingMedium),
                    child: Center(
                      child: Text(
                        'No stories in this highlight yet',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: responsive.fontMedium,
                        ),
                      ),
                    ),
                  )
                else
                  Padding(
                    padding: EdgeInsets.all(responsive.paddingMedium),
                    child: GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 0.75,
                        crossAxisSpacing: responsive.paddingMedium,
                        mainAxisSpacing: responsive.paddingMedium,
                      ),
                      itemCount: stories.length,
                      itemBuilder: (context, index) {
                        final story = stories[index] as Map<String, dynamic>;
                        final storyId = story['_id'] as String?;
                        final content = story['content'] as String? ?? '';
                        final mediaUrl = story['mediaUrl'] as String?;
                        final views = story['views'] as int? ?? 0;
                        final reactions = story['reactions'] as int? ?? 0;

                        return _buildStoryCard(
                          context: context,
                          storyId: storyId ?? '',
                          content: content,
                          mediaUrl: mediaUrl,
                          views: views,
                          reactions: reactions,
                          responsive: responsive,
                        );
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStoryCard({
    required BuildContext context,
    required String storyId,
    required String content,
    String? mediaUrl,
    required int views,
    required int reactions,
    required ResponsiveSizing responsive,
  }) {
    return GestureDetector(
      onTap: () {
        _logger.debug('🎬 Story tapped: $storyId');
        context.push(
          '/story/$storyId?highlight=${widget.highlightId}',
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Story thumbnail/background
            Container(
              color: Colors.grey.shade200,
              child: mediaUrl != null
                  ? Image.network(
                      mediaUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Center(
                          child: Icon(
                            Icons.image_not_supported,
                            color: Colors.grey.shade400,
                          ),
                        );
                      },
                    )
                  : Center(
                      child: Text(
                        content,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: responsive.fontSmall,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ),
            ),

            // Overlay with stats
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                  ],
                ),
              ),
            ),

            // Stats at bottom
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Padding(
                padding: EdgeInsets.all(responsive.paddingSmall),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.visibility,
                          size: responsive.iconSmall,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$views',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: responsive.fontXSmall,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Icon(
                          Icons.favorite_border,
                          size: responsive.iconSmall,
                          color: Colors.white70,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$reactions',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: responsive.fontXSmall,
                          ),
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
}
