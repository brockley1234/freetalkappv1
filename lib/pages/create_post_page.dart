import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import '../services/api_service.dart';
import '../utils/url_utils.dart';
import '../utils/avatar_utils.dart';
import '../widgets/mention_text_field.dart';
import '../widgets/mention_guide_banner.dart';

class CreatePostBottomSheet extends StatefulWidget {
  final Map<String, dynamic>? currentUser;

  const CreatePostBottomSheet({super.key, this.currentUser});

  @override
  State<CreatePostBottomSheet> createState() => _CreatePostBottomSheetState();
}

class _CreatePostBottomSheetState extends State<CreatePostBottomSheet> {
  final TextEditingController _contentController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final List<XFile> _selectedMedia = [];
  final Map<int, bool> _isVideoMap = {}; // Track which media items are videos
  VideoPlayerController? _videoController;
  bool _isLoading = false;
  String? _error;
  final List<Map<String, dynamic>> _taggedUsers = [];

  @override
  void dispose() {
    _contentController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final List<XFile> images = await _picker.pickMultiImage(
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (images.isNotEmpty) {
        setState(() {
          final startIndex = _selectedMedia.length;
          _selectedMedia.addAll(images);
          // Mark all added items as images (not videos)
          for (int i = 0; i < images.length; i++) {
            _isVideoMap[startIndex + i] = false;
            debugPrint(
              'Added image at index ${startIndex + i}: ${images[i].name}, mimeType: ${images[i].mimeType}',
            );
          }
          _error = null;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to pick images: ${e.toString()}';
      });
    }
  }

  Future<void> _capturePhoto() async {
    try {
      final XFile? photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );

      if (photo != null) {
        setState(() {
          final index = _selectedMedia.length;
          _selectedMedia.add(photo);
          _isVideoMap[index] = false; // Mark as image
          _error = null;
          debugPrint(
            'Added photo from camera at index $index: ${photo.name}, mimeType: ${photo.mimeType}',
          );
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to capture photo: ${e.toString()}';
      });
    }
  }

  Future<void> _captureVideo() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(minutes: 5),
      );

      if (video != null) {
        // Dispose existing video controller if any
        await _videoController?.dispose();

        // Initialize new video controller
        final VideoPlayerController controller;
        if (kIsWeb) {
          controller = VideoPlayerController.networkUrl(Uri.parse(video.path));
        } else {
          controller = VideoPlayerController.file(File(video.path));
        }
        await controller.initialize();

        setState(() {
          final index = _selectedMedia.length;
          _selectedMedia.add(video);
          _isVideoMap[index] = true; // Mark as video
          _videoController = controller;
          _error = null;
          debugPrint(
            'Added video from camera at index $index: ${video.name}, mimeType: ${video.mimeType}',
          );
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to capture video: ${e.toString()}';
      });
    }
  }

  Future<void> _showMediaOptionsDialog() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library, color: Colors.green),
                  title: const Text('Choose Photo'),
                  subtitle: const Text('Select a photo from your device'),
                  onTap: () => Navigator.pop(context, 'choose_photo'),
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt, color: Colors.blue),
                  title: const Text('Take Photo'),
                  subtitle: const Text('Capture a photo with your camera'),
                  onTap: () => Navigator.pop(context, 'take_photo'),
                ),
                ListTile(
                  leading: const Icon(Icons.videocam, color: Colors.red),
                  title: const Text('Take Video'),
                  subtitle: const Text('Record a video with your camera'),
                  onTap: () => Navigator.pop(context, 'take_video'),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (result == null || !mounted) return;

    switch (result) {
      case 'choose_photo':
        await _pickImages();
        break;
      case 'take_photo':
        await _capturePhoto();
        break;
      case 'take_video':
        await _captureVideo();
        break;
    }
  }

  void _removeMedia(int index) {
    setState(() {
      _selectedMedia.removeAt(index);

      // If removing a video, dispose its controller
      if (_isVideoMap[index] == true) {
        _videoController?.dispose();
        _videoController = null;
      }

      // Remove from video map and re-index remaining items
      _isVideoMap.remove(index);
      final newMap = <int, bool>{};
      _isVideoMap.forEach((key, value) {
        if (key > index) {
          newMap[key - 1] = value;
        } else if (key < index) {
          newMap[key] = value;
        }
      });
      _isVideoMap.clear();
      _isVideoMap.addAll(newMap);
    });
  }

  void _showTagUsersDialog() {
    showDialog(
      context: context,
      builder: (context) => _TagUsersDialog(
        alreadyTagged: _taggedUsers,
        onUsersTagged: (users) {
          setState(() {
            _taggedUsers.clear();
            _taggedUsers.addAll(users);
          });
        },
      ),
    );
  }

  Future<void> _submitPost() async {
    final content = _contentController.text.trim();

    if (content.isEmpty && _selectedMedia.isEmpty) {
      setState(() {
        _error = 'Please add some content or media to your post';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final taggedUserIds =
          _taggedUsers.map((u) => u['_id'] as String).toList();

      final result = await ApiService.createPostWithMedia(
        content: content,
        mediaFiles: _selectedMedia,
        taggedUserIds: taggedUserIds.isNotEmpty ? taggedUserIds : null,
      );

      if (result['success'] == true) {
        if (mounted) {
          Navigator.pop(
            context,
            true,
          ); // Return true to indicate post was created
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Post created successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        setState(() {
          _error = result['message'] ?? 'Failed to create post';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to create post: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final userName = widget.currentUser?['name'] ?? 'User';
    final userAvatar = widget.currentUser?['avatar'];
    final userInitials = userName.isNotEmpty
        ? userName.split(' ').map((n) => n[0]).take(2).join().toUpperCase()
        : 'U';

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Create Post',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
                if (_isLoading)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
              ],
            ),
          ),

          // User info
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                  backgroundImage:
                      userAvatar != null && userAvatar.toString().isNotEmpty
                          ? UrlUtils.getAvatarImageProvider(userAvatar)
                          : null,
                  child: userAvatar == null || userAvatar.toString().isEmpty
                      ? Text(
                          userInitials,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Text(
                  userName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),

          // Content area
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Error message
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.errorContainer,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.onErrorContainer,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // Mention guide banner
                  MentionGuideBanner(
                    onDismiss: () {
                      // Banner dismissed
                    },
                  ),

                  const SizedBox(height: 8),

                  // Content text field with @mention support
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 12,
                            top: 8,
                            right: 12,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.info_outline,
                                size: 14,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Type @ to mention someone or use "Tag People" below',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.primary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(12),
                          child: MentionTextField(
                            controller: _contentController,
                            maxLines: 5,
                            maxLength: 5000,
                            hintText: "What's on your mind?",
                            enabled: !_isLoading,
                            onMentionsChanged: (mentionedUsers) {
                              // Automatically add mentioned users to tagged users
                              setState(() {
                                // Add mentioned users who aren't already tagged
                                for (final user in mentionedUsers) {
                                  if (!_taggedUsers.any(
                                    (u) => u['_id'] == user['_id'],
                                  )) {
                                    _taggedUsers.add(user);
                                  }
                                }
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Tagged users display
                  if (_taggedUsers.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _taggedUsers.map((user) {
                        return Chip(
                          avatar: CircleAvatar(
                            backgroundImage: user['avatar'] != null
                                ? NetworkImage(
                                    UrlUtils.getFullAvatarUrl(user['avatar']),
                                  )
                                : null,
                            child: user['avatar'] == null
                                ? Text(
                                    (user['name'] ?? 'U')[0].toUpperCase(),
                                    style: const TextStyle(fontSize: 12),
                                  )
                                : null,
                          ),
                          label: Text(user['name'] ?? 'Unknown'),
                          deleteIcon: const Icon(Icons.close, size: 18),
                          onDeleted: () {
                            setState(() {
                              _taggedUsers.remove(user);
                            });
                          },
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          deleteIconColor: Theme.of(context).colorScheme.onPrimaryContainer,
                          labelStyle: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // Media preview
                  if (_selectedMedia.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildMediaPreview(),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Add to post section
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
                ),
              ),
            ),
            child: Row(
              children: [
                const Text(
                  'Add to your post',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                ),
                const Spacer(),
                IconButton(
                  icon: Icon(
                    Icons.videocam,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  onPressed: _isLoading ? null : _showMediaOptionsDialog,
                  tooltip: 'Photo/Video',
                ),
                IconButton(
                  icon: Icon(
                    Icons.person_add_alt,
                    color: _taggedUsers.isNotEmpty
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  onPressed: _isLoading ? null : _showTagUsersDialog,
                  tooltip: 'Tag People',
                ),
              ],
            ),
          ),

          // Post button
          Padding(
            padding: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitPost,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).colorScheme.onPrimary,
                          ),
                        ),
                      )
                    : const Text(
                        'Post',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMediaPreview() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${_selectedMedia.length} ${_selectedMedia.length == 1 ? 'file' : 'files'} selected',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _selectedMedia.clear();
                    _videoController?.dispose();
                    _videoController = null;
                  });
                },
                child: const Text('Clear all'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 100,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _selectedMedia.length,
              itemBuilder: (context, index) {
                final media = _selectedMedia[index];
                // Check map first, then fallback to mime type detection
                bool isVideo = _isVideoMap[index] ?? false;

                // Fallback: check mime type if available
                if (!isVideo && media.mimeType != null) {
                  isVideo = media.mimeType!.startsWith('video/');
                }

                // Fallback: check file extension
                if (!isVideo && kIsWeb) {
                  final name = media.name.toLowerCase();
                  isVideo = name.endsWith('.mp4') ||
                      name.endsWith('.mov') ||
                      name.endsWith('.avi') ||
                      name.endsWith('.webm');
                }

                debugPrint(
                  'Displaying media $index: isVideo=$isVideo, name=${media.name}, mimeType=${media.mimeType}',
                );

                return Container(
                  width: 100,
                  margin: const EdgeInsets.only(right: 8),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: isVideo
                            ? _videoController != null
                                ? AspectRatio(
                                    aspectRatio:
                                        _videoController!.value.aspectRatio,
                                    child: VideoPlayer(_videoController!),
                                  )
                                : Container(
                                    color: Colors.black,
                                    child: const Icon(
                                      Icons.play_circle_outline,
                                      color: Colors.white,
                                      size: 48,
                                    ),
                                  )
                            : kIsWeb
                                ? Image.network(
                                    media.path,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[300],
                                        child: const Icon(
                                          Icons.broken_image,
                                          color: Colors.grey,
                                          size: 48,
                                        ),
                                      );
                                    },
                                  )
                                : Image.file(File(media.path),
                                    fit: BoxFit.cover),
                      ),
                      if (isVideo)
                        Positioned.fill(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(
                              Icons.play_circle_fill,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () => _removeMedia(index),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.close,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TagUsersDialog extends StatefulWidget {
  final List<Map<String, dynamic>> alreadyTagged;
  final Function(List<Map<String, dynamic>>) onUsersTagged;

  const _TagUsersDialog({
    required this.alreadyTagged,
    required this.onUsersTagged,
  });

  @override
  State<_TagUsersDialog> createState() => _TagUsersDialogState();
}

class _TagUsersDialogState extends State<_TagUsersDialog> {
  final TextEditingController _searchController = TextEditingController();
  final List<Map<String, dynamic>> _selectedUsers = [];
  List<Map<String, dynamic>> _allFollowers = [];
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isLoadingFollowers = true;

  @override
  void initState() {
    super.initState();
    _selectedUsers.addAll(widget.alreadyTagged);
    _loadFollowers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadFollowers() async {
    setState(() => _isLoadingFollowers = true);

    try {
      final result = await ApiService.getMyFollowers();
      if (result['success'] == true && mounted) {
        setState(() {
          _allFollowers = List<Map<String, dynamic>>.from(
            result['data']['followers'] ?? [],
          );
          _isLoadingFollowers = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _allFollowers = [];
          _isLoadingFollowers = false;
        });
      }
    }
  }

  Future<void> _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
      });
      return;
    }

    setState(() => _isSearching = true);

    try {
      // Filter followers based on search query
      final queryLower = query.toLowerCase();
      final filtered = _allFollowers.where((user) {
        final name = (user['name'] ?? '').toLowerCase();
        final email = (user['email'] ?? '').toLowerCase();
        return name.contains(queryLower) || email.contains(queryLower);
      }).toList();

      if (mounted) {
        setState(() {
          _searchResults = filtered;
          _isSearching = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
    }
  }

  void _toggleUser(Map<String, dynamic> user) {
    setState(() {
      final index = _selectedUsers.indexWhere((u) => u['_id'] == user['_id']);
      if (index >= 0) {
        _selectedUsers.removeAt(index);
      } else {
        _selectedUsers.add(user);
      }
    });
  }

  bool _isUserSelected(Map<String, dynamic> user) {
    return _selectedUsers.any((u) => u['_id'] == user['_id']);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600, maxWidth: 500),
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Text(
                    'Tag People',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Search field
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search people...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                ),
                onChanged: (value) {
                  _searchUsers(value);
                },
              ),
            ),

            // Selected users
            if (_selectedUsers.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                alignment: Alignment.centerLeft,
                child: Text(
                  'Tagged (${_selectedUsers.length})',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                height: 60,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _selectedUsers.length,
                  itemBuilder: (context, index) {
                    final user = _selectedUsers[index];
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      child: Chip(
                        avatar: CircleAvatar(
                          backgroundImage: user['avatar'] != null
                              ? NetworkImage(
                                  UrlUtils.getFullAvatarUrl(user['avatar']),
                                )
                              : null,
                          child: user['avatar'] == null
                              ? Text(
                                  (user['name'] ?? 'U')[0].toUpperCase(),
                                  style: const TextStyle(fontSize: 12),
                                )
                              : null,
                        ),
                        label: Text(user['name'] ?? 'Unknown'),
                        deleteIcon: const Icon(Icons.close, size: 18),
                        onDeleted: () => _toggleUser(user),
                      ),
                    );
                  },
                ),
              ),
              const Divider(height: 1),
            ],

            // Search results
            Expanded(
              child: _isLoadingFollowers
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text('Loading your followers...'),
                        ],
                      ),
                    )
                  : _isSearching
                      ? const Center(child: CircularProgressIndicator())
                      : _searchResults.isEmpty
                          ? Center(
                              child: Text(
                                _searchController.text.isEmpty
                                    ? (_allFollowers.isEmpty
                                        ? 'You have no followers to tag'
                                        : 'Search for followers to tag')
                                    : 'No followers found',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final user = _searchResults[index];
                                final isSelected = _isUserSelected(user);

                                return ListTile(
                                  leading: AvatarWithFallback(
                                    name: user['name'] ?? 'Unknown',
                                    imageUrl: user['avatar'],
                                    radius: 20,
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                    getImageProvider: (url) =>
                                        NetworkImage(UrlUtils.getFullAvatarUrl(url)),
                                  ),
                                  title: Text(
                                    user['name'] ?? 'Unknown',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600),
                                  ),
                                  subtitle: user['email'] != null
                                      ? Text(user['email'])
                                      : null,
                                  trailing: isSelected
                                      ? const Icon(
                                          Icons.check_circle,
                                          color: Colors.blue,
                                        )
                                      : const Icon(
                                          Icons.circle_outlined,
                                          color: Colors.grey,
                                        ),
                                  onTap: () => _toggleUser(user),
                                );
                              },
                            ),
            ),

            // Action buttons
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      widget.onUsersTagged(_selectedUsers);
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                    child: Text(
                      'Tag ${_selectedUsers.length} ${_selectedUsers.length == 1 ? "person" : "people"}',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
