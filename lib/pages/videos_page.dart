import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:share_plus/share_plus.dart';
import '../services/video_service.dart';
import '../services/socket_service.dart';
import 'upload_video_page.dart';
import 'user_profile_page.dart';
import '../widgets/mention_text_field.dart';

class VideosPage extends StatefulWidget {
  final Map<String, dynamic>? currentUser;
  final bool isVisible;
  final String? initialVideoId;

  const VideosPage({
    super.key,
    this.currentUser,
    this.isVisible = true,
    this.initialVideoId,
  });

  @override
  State<VideosPage> createState() => _VideosPageState();
}

class _VideosPageState extends State<VideosPage> 
    with WidgetsBindingObserver {
  // Simplified state management
  List<dynamic> _videos = [];
  bool _isLoading = false;
  bool _hasMore = true;
  int _currentPage = 1;
  final int _limit = 15; // Increased for better UX
  
  // Video management
  final PageController _pageController = PageController();
  int _currentVideoIndex = 0;
  final Map<int, VideoPlayerController?> _videoControllers = {};
  final Map<int, AudioPlayer?> _audioPlayers = {};
  
  // Socket listeners
  void Function(dynamic)? _videoCreatedListener;
  void Function(dynamic)? _videoLikedListener;
  void Function(dynamic)? _videoCommentedListener;
  void Function(dynamic)? _videoDeletedListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadVideos();
    _setupSocketListeners();
    
    if (widget.initialVideoId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _navigateToVideo(widget.initialVideoId!);
      });
    }
  }

  @override
  void didUpdateWidget(VideosPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible && !widget.isVisible) {
      _pauseCurrentVideo();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      _pauseCurrentVideo();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _disposeVideoControllers();
    _removeSocketListeners();
    _pageController.dispose();
    super.dispose();
  }

  // Simplified video management
  void _pauseCurrentVideo() {
    final currentController = _videoControllers[_currentVideoIndex];
    if (currentController?.value.isPlaying == true) {
      currentController!.pause();
    }
    _audioPlayers[_currentVideoIndex]?.pause();
  }

  void _disposeVideoControllers() {
    for (var controller in _videoControllers.values) {
      controller?.dispose();
    }
    _videoControllers.clear();
    for (var player in _audioPlayers.values) {
      player?.dispose();
    }
    _audioPlayers.clear();
  }

  // Simplified socket listeners
  void _setupSocketListeners() {
    final socketService = SocketService();
    final socket = socketService.socket;
    if (socket == null) return;

    _videoCreatedListener = (data) {
      if (!mounted) return;
      setState(() {
        _videos.insert(0, data['video']);
      });
      _showNewVideoNotification(data['video']);
    };

    _videoLikedListener = (data) {
      if (!mounted) return;
      _updateVideoInList(data['videoId'], (video) {
        video['likeCount'] = data['likeCount'];
        video['isLiked'] = data['isLiked'];
      });
    };

    _videoCommentedListener = (data) {
      if (!mounted) return;
      _updateVideoInList(data['videoId'], (video) {
        video['commentCount'] = data['commentCount'];
      });
    };

    _videoDeletedListener = (data) {
      if (!mounted) return;
      setState(() {
        _videos.removeWhere((video) => video['_id'] == data['videoId']);
      });
    };

    socket.on('video:created', _videoCreatedListener!);
    socket.on('video:liked', _videoLikedListener!);
    socket.on('video:commented', _videoCommentedListener!);
    socket.on('video:deleted', _videoDeletedListener!);
  }

  void _removeSocketListeners() {
    final socketService = SocketService();
    final socket = socketService.socket;
    if (socket == null) return;

    socket.off('videoCreated', _videoCreatedListener!);
    socket.off('videoLiked', _videoLikedListener!);
    socket.off('videoCommented', _videoCommentedListener!);
    socket.off('videoDeleted', _videoDeletedListener!);
  }

  void _updateVideoInList(String videoId, Function(Map<String, dynamic>) updater) {
    setState(() {
      final index = _videos.indexWhere((video) => video['_id'] == videoId);
      if (index != -1) {
        updater(_videos[index]);
      }
    });
  }

  void _showNewVideoNotification(Map<String, dynamic> video) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.videocam, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'New video: ${video['title'] ?? 'Check it out'}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.yellow,
          onPressed: () {
            _pageController.animateToPage(0, 
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut);
          },
        ),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
    );
  }

  // Simplified video loading
  Future<void> _loadVideos({bool refresh = false}) async {
    if (_isLoading) return;

    if (refresh) {
      setState(() {
        _currentPage = 1;
        _hasMore = true;
        _videos.clear();
        _disposeVideoControllers();
      });
    }

    if (!_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final result = await VideoService.getVideos(
        page: _currentPage,
        limit: _limit,
      );

      if (result['success'] && mounted) {
        final videos = result['videos'] as List;
        final pagination = result['pagination'];

        setState(() {
          if (refresh) {
            _videos = videos;
          } else {
            _videos.addAll(videos);
          }
          _hasMore = _currentPage < pagination['pages'];
          _currentPage++;
          _isLoading = false;
        });

        // Initialize video controller for the first video
        if (_videos.isNotEmpty) {
          await _initializeVideoController(0);
          if (_videos.length > 1) {
            _initializeVideoController(1);
          }
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading videos: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _initializeVideoController(int index) async {
    if (index >= _videos.length || _videoControllers[index] != null) return;

    final video = _videos[index];
    String? videoUrl = video['videoUrl'];
    if (videoUrl == null) return;
    if (videoUrl.startsWith('/')) {
      videoUrl = '${ApiService.baseApi}$videoUrl';
    }

    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(videoUrl));
      await controller.initialize();
      
      if (mounted) {
        setState(() {
          _videoControllers[index] = controller;
        });
        
        if (index == _currentVideoIndex) {
          controller.play();
        }
      }
    } catch (e) {
      debugPrint('Error initializing video controller: $e');
    }
  }

  void _onPageChanged(int index) {
    if (index == _currentVideoIndex) return;

    // Pause previous video
    _videoControllers[_currentVideoIndex]?.pause();
    _audioPlayers[_currentVideoIndex]?.pause();

    setState(() {
      _currentVideoIndex = index;
    });

    // Play current video
    _videoControllers[index]?.play();
    _audioPlayers[index]?.resume();

    // Preload next video
    if (index + 1 < _videos.length) {
      _initializeVideoController(index + 1);
    }

    // Load more videos if needed
    if (index >= _videos.length - 3 && _hasMore && !_isLoading) {
      _loadVideos();
    }
  }

  void _navigateToVideo(String videoId) {
    final index = _videos.indexWhere((video) => video['_id'] == videoId);
    if (index != -1) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  // Simplified UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // Main video feed
          RefreshIndicator(
            onRefresh: () => _loadVideos(refresh: true),
            backgroundColor: Colors.white,
            color: Theme.of(context).primaryColor,
            child: PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _videos.length,
              onPageChanged: _onPageChanged,
              physics: const BouncingScrollPhysics(),
              itemBuilder: (context, index) {
                final video = _videos[index];
                return VideoItemWidgetImproved(
                  video: video,
                  controller: _videoControllers[index],
                  audioPlayer: _audioPlayers[index],
                  isActive: index == _currentVideoIndex,
                  onLike: () => _toggleLike(index),
                  onComment: () => _showComments(index),
                  onShare: () => _shareVideo(video),
                  currentUserId: widget.currentUser?['_id'],
                  onProfileTap: () => _navigateToProfile(video),
                  onEdit: () => _editVideo(index),
                  onDelete: () => _deleteVideo(index),
                );
              },
            ),
          ),

          // Simplified top bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // App name
                    Text(
                      ApiService.appName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          Shadow(
                            color: Colors.black,
                            offset: Offset(0, 2),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),

                    // Action buttons
                    Row(
                      children: [
                        IconButton(
                          onPressed: () async {
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => UploadVideoPage(
                                  currentUser: widget.currentUser,
                                ),
                              ),
                            );
                            if (result == true && mounted) {
                              _loadVideos(refresh: true);
                            }
                          },
                          icon: const Icon(
                            Icons.add_box_outlined,
                            color: Colors.white,
                            size: 28,
                          ),
                          tooltip: 'Upload Video',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Loading indicator
          if (_isLoading && _videos.isEmpty)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  // Simplified action methods
  Future<void> _toggleLike(int index) async {
    final video = _videos[index];
    final videoId = video['_id'];
    final isLiked = video['isLiked'] ?? false;

    // Optimistic update
    setState(() {
      video['isLiked'] = !isLiked;
      video['likeCount'] = (video['likeCount'] ?? 0) + (isLiked ? -1 : 1);
    });

    try {
      final result = await VideoService.toggleLike(videoId);
      if (!result['success']) {
        // Revert on failure
        setState(() {
          video['isLiked'] = isLiked;
          video['likeCount'] = (video['likeCount'] ?? 0) + (isLiked ? 1 : -1);
        });
      }
    } catch (e) {
      debugPrint('Error toggling like: $e');
      // Revert on error
      setState(() {
        video['isLiked'] = isLiked;
        video['likeCount'] = (video['likeCount'] ?? 0) + (isLiked ? 1 : -1);
      });
    }
  }

  void _showComments(int index) {
    // Implement comments dialog
    showDialog(
      context: context,
      builder: (context) => CommentsDialog(
        video: _videos[index],
        currentUserId: widget.currentUser?['_id'],
      ),
    );
  }

  void _shareVideo(Map<String, dynamic> video) {
    Share.share(
      'Check out this video: ${video['title'] ?? 'Amazing video!'}',
      subject: 'Video from ${ApiService.appName}',
    );
  }

  void _navigateToProfile(Map<String, dynamic> video) {
    if (video['author']?['_id'] != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => UserProfilePage(
            userId: video['author']['_id'],
          ),
        ),
      );
    }
  }

  void _editVideo(int index) {
    final video = _videos[index];
    final videoId = video['_id'];
    final titleController = TextEditingController(text: video['title'] ?? '');
    final descriptionController = TextEditingController(text: video['description'] ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Edit Video', 
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel', 
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              final title = titleController.text.trim();
              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Title is required')),
                );
                return;
              }

              Navigator.pop(context);

              // Show loading
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              scaffoldMessenger.showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      CircularProgressIndicator(color: Colors.white),
                      SizedBox(width: 16),
                      Text('Updating video...'),
                    ],
                  ),
                  duration: Duration(minutes: 1),
                ),
              );

              final result = await VideoService.updateVideo(
                videoId: videoId,
                title: title,
                description: descriptionController.text.trim(),
              );

              scaffoldMessenger.hideCurrentSnackBar();

              if (result['success'] && mounted) {
                // Update video in list
                setState(() {
                  _videos[index]['title'] = title;
                  _videos[index]['description'] = descriptionController.text.trim();
                });

                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: const Text('Video updated successfully'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              } else {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(result['message'] ?? 'Failed to update video'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
            child: const Text('Save', style: TextStyle(color: Colors.blue)),
          ),
        ],
      ),
    );
  }

  void _deleteVideo(int index) {
    final video = _videos[index];
    final videoId = video['_id'];
    final title = video['title'] ?? 'this video';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: Text(
          'Delete Video', 
          style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
        ),
        content: Text(
          'Are you sure you want to delete "$title"? This action cannot be undone.',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel', 
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);

              // Show loading
              final scaffoldMessenger = ScaffoldMessenger.of(context);
              scaffoldMessenger.showSnackBar(
                SnackBar(
                  content: Row(
                    children: [
                      CircularProgressIndicator(
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                      const SizedBox(width: 16),
                      const Text('Deleting video...'),
                    ],
                  ),
                  duration: const Duration(minutes: 1),
                ),
              );

              final result = await VideoService.deleteVideo(videoId);

              scaffoldMessenger.hideCurrentSnackBar();

              if (result['success'] && mounted) {
                // Remove video from list
                setState(() {
                  _videos.removeAt(index);
                  _videoControllers[index]?.dispose();
                  _audioPlayers[index]?.dispose();
                  _videoControllers.remove(index);
                  _audioPlayers.remove(index);
                  
                  // Adjust current index if needed
                  if (_currentVideoIndex >= _videos.length) {
                    _currentVideoIndex = _videos.length - 1;
                  }
                });

                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: const Text('Video deleted successfully'),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              } else {
                scaffoldMessenger.showSnackBar(
                  SnackBar(
                    content: Text(result['message'] ?? 'Failed to delete video'),
                    backgroundColor: Theme.of(context).colorScheme.error,
                  ),
                );
              }
            },
            child: Text(
              'Delete', 
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

// Simplified video item widget
class VideoItemWidgetImproved extends StatefulWidget {
  final Map<String, dynamic> video;
  final VideoPlayerController? controller;
  final AudioPlayer? audioPlayer;
  final bool isActive;
  final VoidCallback onLike;
  final VoidCallback onComment;
  final VoidCallback onShare;
  final VoidCallback onProfileTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String? currentUserId;

  const VideoItemWidgetImproved({
    super.key,
    required this.video,
    required this.controller,
    this.audioPlayer,
    required this.isActive,
    required this.onLike,
    required this.onComment,
    required this.onShare,
    required this.onProfileTap,
    this.onEdit,
    this.onDelete,
    this.currentUserId,
  });

  @override
  State<VideoItemWidgetImproved> createState() => _VideoItemWidgetImprovedState();
}

class _VideoItemWidgetImprovedState extends State<VideoItemWidgetImproved> {
  bool _showPlayPause = false;
  bool _isMuted = false;
  Timer? _playPauseTimer;

  String? _resolveImageUrl(dynamic value) {
    if (value == null) return null;
    final String url = value.toString();
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('/')) {
      return '${ApiService.baseApi}$url';
    }
    return url;
  }

  @override
  void initState() {
    super.initState();
    _startPlayPauseTimer();
  }

  @override
  void didUpdateWidget(VideoItemWidgetImproved oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive && widget.controller?.value.isInitialized == true) {
        widget.controller!.play();
      } else if (!widget.isActive && widget.controller?.value.isPlaying == true) {
        widget.controller!.pause();
      }
    }
  }

  @override
  void dispose() {
    _playPauseTimer?.cancel();
    super.dispose();
  }

  void _startPlayPauseTimer() {
    _playPauseTimer?.cancel();
    _playPauseTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _showPlayPause = false;
        });
      }
    });
  }

  void _onTap() {
    setState(() {
      _showPlayPause = true;
    });
    _startPlayPauseTimer();

    if (widget.controller?.value.isInitialized == true) {
      if (widget.controller!.value.isPlaying) {
        widget.controller!.pause();
      } else {
        widget.controller!.play();
      }
    }
  }

  void _toggleMute() {
    setState(() {
      _isMuted = !_isMuted;
    });
    widget.controller?.setVolume(_isMuted ? 0.0 : 1.0);
  }

  void _showLikers() {
    final videoId = widget.video['_id'];
    if (videoId == null) return;
    showDialog(
      context: context,
      builder: (context) => LikersDialog(videoId: videoId as String),
    );
  }

  void _showMoreOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Edit option
            if (widget.onEdit != null)
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: Text(
                  'Edit Video', 
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onEdit!();
                },
              ),
            
            // Delete option
            if (widget.onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(
                  'Delete Video', 
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () {
                  Navigator.pop(context);
                  widget.onDelete!();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Video player
          if (widget.controller?.value.isInitialized == true)
            AspectRatio(
              aspectRatio: widget.controller!.value.aspectRatio,
              child: VideoPlayer(widget.controller!),
            )
          else
            Container(
              color: Colors.black,
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),

          // Play/Pause overlay
          if (_showPlayPause)
            Center(
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.controller?.value.isPlaying == true
                      ? Icons.pause
                      : Icons.play_arrow,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),

          // Video info overlay
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.8),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Author info
                  GestureDetector(
                    onTap: widget.onProfileTap,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: () {
                            final author = widget.video['author'] as Map<String, dynamic>?;
                            final raw = author?['profilePicture'] ?? author?['avatar'];
                            final resolved = _resolveImageUrl(raw);
                            return resolved != null ? NetworkImage(resolved) : null;
                          }(),
                          child: () {
                            final author = widget.video['author'] as Map<String, dynamic>?;
                            final raw = author?['profilePicture'] ?? author?['avatar'];
                            final resolved = _resolveImageUrl(raw);
                            return resolved == null ? const Icon(Icons.person, color: Colors.white) : null;
                          }(),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.video['author']?['name'] ?? 'Unknown',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Row(
                                children: [
                                  GestureDetector(
                                    onTap: _showLikers,
                                    child: Text(
                                      '${_formatNumber((widget.video['likeCount'] ?? widget.video['likes'] ?? 0) as int)} likes',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 14,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if ((widget.video['commentCount'] ?? 0) > 0)
                                    GestureDetector(
                                      onTap: widget.onComment,
                                      child: Text(
                                        '${_formatNumber((widget.video['commentCount'] ?? 0) as int)} comments',
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 14,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Video title
                  Text(
                    widget.video['title'] ?? '',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),

          // Action buttons
          Positioned(
            right: 16,
            bottom: 100,
            child: Column(
              children: [
                // Like button
                GestureDetector(
                  onTap: widget.onLike,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      widget.video['isLiked'] == true
                          ? Icons.favorite
                          : Icons.favorite_border,
                      color: widget.video['isLiked'] == true
                          ? Colors.red
                          : Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Comment button
                GestureDetector(
                  onTap: widget.onComment,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chat_bubble_outline,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Share button
                GestureDetector(
                  onTap: widget.onShare,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.3),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.share,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // More options button (only if user owns the video)
                if (widget.currentUserId != null &&
                    widget.video['author'] != null &&
                    widget.currentUserId == widget.video['author']['_id'] &&
                    (widget.onEdit != null || widget.onDelete != null))
                  GestureDetector(
                    onTap: _showMoreOptions,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.more_vert,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Mute button (offset below top bar to avoid overlap)
          Positioned(
            top: MediaQuery.of(context).padding.top + 56 + 8,
            right: 16,
            child: GestureDetector(
              onTap: _toggleMute,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isMuted ? Icons.volume_off : Icons.volume_up,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

// Simplified comments dialog
class CommentsDialog extends StatefulWidget {
  final Map<String, dynamic> video;
  final String? currentUserId;

  const CommentsDialog({
    super.key,
    required this.video,
    this.currentUserId,
  });

  @override
  State<CommentsDialog> createState() => _CommentsDialogState();
}

class _CommentsDialogState extends State<CommentsDialog> {
  final TextEditingController _commentController = TextEditingController();
  List<dynamic> _comments = [];
  bool _isLoading = false;
  List<String> _mentionedUserIds = [];

  String? _resolveImageUrl(dynamic value) {
    if (value == null) return null;
    final String url = value.toString();
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    if (url.startsWith('/')) {
      return '${ApiService.baseApi}$url';
    }
    return url;
  }

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadComments() async {
    setState(() => _isLoading = true);
    try {
      final result = await VideoService.getComments(widget.video['_id']);
      if (result['success'] && mounted) {
        setState(() {
          _comments = result['comments'] ?? [];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading comments: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    _commentController.clear();
    
    try {
      final result = await VideoService.addComment(
        widget.video['_id'],
        text,
        taggedUserIds: _mentionedUserIds,
      );
      if (result['success'] && mounted) {
        _loadComments();
      }
    } catch (e) {
      debugPrint('Error adding comment: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white24),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'Comments',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),
            
            // Comments list
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _comments.length,
                      itemBuilder: (context, index) {
                        final comment = _comments[index];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 16,
                                backgroundImage: () {
                                  final user = comment['user'] as Map<String, dynamic>?;
                                  final raw = user?['avatar'];
                                  final resolved = _resolveImageUrl(raw);
                                  return resolved != null ? NetworkImage(resolved) : null;
                                }(),
                                child: () {
                                  final user = comment['user'] as Map<String, dynamic>?;
                                  final raw = user?['avatar'];
                                  final resolved = _resolveImageUrl(raw);
                                  return resolved == null 
                                      ? Icon(
                                          Icons.person, 
                                          size: 16, 
                                          color: Theme.of(context).colorScheme.onSurface,
                                        ) 
                                      : null;
                                }(),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      comment['user']?['name'] ?? 'Unknown',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      comment['text'] ?? '',
                                      style: TextStyle(
                                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
            
            // Add comment
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.white24),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: MentionTextField(
                      controller: _commentController,
                      hintText: 'Add a comment...',
                      enabled: true,
                      onMentionsChanged: (users) {
                    // Store mentioned users for the comment
                    _mentionedUserIds = users
                        .map((u) => (u['_id'] ?? '').toString())
                        .where((id) => id.isNotEmpty)
                        .toList();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _addComment,
                    icon: const Icon(Icons.send, color: Colors.white),
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

// Dialog to show users who liked a video
class LikersDialog extends StatefulWidget {
  final String videoId;

  const LikersDialog({ super.key, required this.videoId });

  @override
  State<LikersDialog> createState() => _LikersDialogState();
}

class _LikersDialogState extends State<LikersDialog> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _likers = [];

  @override
  void initState() {
    super.initState();
    _loadLikers();
  }

  String? _resolveImageUrl(dynamic value) {
    if (value == null) return null;
    final String url = value.toString();
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    if (url.startsWith('/')) return '${ApiService.baseApi}$url';
    return url;
  }

  Future<void> _loadLikers() async {
    setState(() => _isLoading = true);
    try {
      final result = await VideoService.getVideo(widget.videoId);
      // Expect structure: { success, video: { likes: [{ user: <id|obj> }] } }
      final video = result['video'];
      final likes = video?['likes'] as List?;

      if (likes == null) {
        setState(() { _likers = []; _isLoading = false; });
        return;
      }

      final List<Map<String, dynamic>> users = [];

      // Collect ids to fetch where needed
      final List<String> missingUserIds = [];
      for (final like in likes) {
        final userField = (like as Map)['user'];
        if (userField is Map) {
          users.add(Map<String, dynamic>.from(userField));
        } else if (userField is String) {
          missingUserIds.add(userField);
        }
      }

      // Fetch missing user profiles in sequence (counts usually small)
      for (final id in missingUserIds) {
        try {
          final userRes = await ApiService.getUserById(id);
          final user = userRes['data']?['user'];
          if (user != null) users.add(Map<String, dynamic>.from(user));
        } catch (_) {}
      }

      setState(() {
        _likers = users;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.6,
        decoration: BoxDecoration(
          color: Colors.black87,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Colors.white24),
                ),
              ),
              child: Row(
                children: [
                  const Text(
                    'Liked by',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white),
                  ),
                ],
              ),
            ),

            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : (_likers.isEmpty
                      ? Center(
                          child: Text(
                            'No likes yet',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _likers.length,
                          itemBuilder: (context, index) {
                            final user = _likers[index];
                            final avatar = _resolveImageUrl(user['avatar'] ?? user['profilePicture']);
                            return ListTile(
                              leading: CircleAvatar(
                                radius: 18,
                                backgroundImage: avatar != null ? NetworkImage(avatar) : null,
                                child: avatar == null
                                    ? const Icon(Icons.person, size: 18, color: Colors.white)
                                    : null,
                              ),
                              title: Text(
                                user['name'] ?? 'Unknown',
                                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                              ),
                            );
                          },
                        )),
            ),
          ],
        ),
      ),
    );
  }
}
