import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../utils/responsive_sizing.dart';
import '../widgets/story_highlight_collection_card.dart';
import 'story_viewer_page.dart';

class StoryHighlightsPage extends StatefulWidget {
  final String? userId;
  
  const StoryHighlightsPage({
    super.key,
    this.userId,
  });

  @override
  State<StoryHighlightsPage> createState() => _StoryHighlightsPageState();
}

class _StoryHighlightsPageState extends State<StoryHighlightsPage> {
  List<Map<String, dynamic>> _collections = [];
  bool _isLoading = true;
  String? _currentUserId;
  String? _targetUserId;

  @override
  void initState() {
    super.initState();
    _initializeUser();
  }

  Future<void> _initializeUser() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id');
    _targetUserId = widget.userId ?? _currentUserId;
    await _loadHighlights();
  }

  Future<void> _loadHighlights() async {
    if (_targetUserId == null) return;

    setState(() => _isLoading = true);

    try {
      final response = await ApiService.getStoryHighlights(_targetUserId!);
      
      if (response['success'] == true && mounted) {
        setState(() {
          _collections = List<Map<String, dynamic>>.from(
            response['data']['collections'] ?? []
          );
          _isLoading = false;
        });
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint('Error loading highlights: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _addToHighlight(String storyId, String collectionName) async {
    try {
      final response = await ApiService.addStoryToHighlight(
        storyId: storyId,
        collectionName: collectionName,
      );

      if (response['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added to "$collectionName"'),
            backgroundColor: Colors.green,
          ),
        );
        _loadHighlights(); // Refresh the list
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to add to highlight'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
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

  Future<void> _removeFromHighlight(String storyId) async {
    try {
      final response = await ApiService.removeStoryFromHighlight(storyId);

      if (response['success'] == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Removed from highlights'),
            backgroundColor: Colors.green,
          ),
        );
        _loadHighlights(); // Refresh the list
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response['message'] ?? 'Failed to remove from highlight'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
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

  void _showCreateCollectionDialog() {
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create New Collection'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'Collection name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                Navigator.pop(context);
                // Collection will be created when first story is added
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Collection "$name" will be created when you add a story'),
                    backgroundColor: Colors.blue,
                  ),
                );
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final responsive = context.responsive;
    final isOwnProfile = _currentUserId == _targetUserId;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isOwnProfile ? 'My Highlights' : 'Highlights',
          style: TextStyle(fontSize: responsive.fontLarge),
        ),
        actions: [
          if (isOwnProfile)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showCreateCollectionDialog,
            ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    color: Theme.of(context).primaryColor,
                  ),
                  SizedBox(height: responsive.paddingMedium),
                  Text(
                    'Loading highlights...',
                    style: TextStyle(
                      fontSize: responsive.fontBase,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            )
          : _collections.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.collections_bookmark_outlined,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      SizedBox(height: responsive.paddingLarge),
                      Text(
                        isOwnProfile 
                            ? 'No highlights yet'
                            : 'No highlights available',
                        style: TextStyle(
                          fontSize: responsive.fontLarge,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      SizedBox(height: responsive.paddingSmall),
                      Text(
                        isOwnProfile
                            ? 'Create collections to organize your best stories'
                            : 'This user hasn\'t created any highlight collections yet',
                        style: TextStyle(
                          fontSize: responsive.fontBase,
                          color: Colors.grey[500],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (isOwnProfile) ...[
                        SizedBox(height: responsive.paddingLarge),
                        ElevatedButton.icon(
                          onPressed: _showCreateCollectionDialog,
                          icon: const Icon(Icons.add),
                          label: const Text('Create Collection'),
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: responsive.paddingLarge,
                              vertical: responsive.paddingMedium,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadHighlights,
                  child: GridView.builder(
                    padding: EdgeInsets.all(responsive.paddingMedium),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: responsive.paddingMedium,
                      mainAxisSpacing: responsive.paddingMedium,
                      childAspectRatio: 0.8,
                    ),
                    itemCount: _collections.length,
                    itemBuilder: (context, index) {
                      final collection = _collections[index];
                      return StoryHighlightCollectionCard(
                        collection: collection,
                        onTap: () => _viewCollection(collection),
                        onAddStory: isOwnProfile ? _addToHighlight : null,
                        onRemoveStory: isOwnProfile ? _removeFromHighlight : null,
                      );
                    },
                  ),
                ),
    );
  }

  void _viewCollection(Map<String, dynamic> collection) {
    final stories = List<Map<String, dynamic>>.from(
      collection['stories'] ?? []
    );

    if (stories.isEmpty) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => StoryViewerPage(
          userStories: stories,
          initialIndex: 0,
        ),
      ),
    );
  }
}
