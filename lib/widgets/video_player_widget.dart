import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;
  final String? thumbnailUrl;
  final bool autoPlay;
  final VoidCallback? onVideoReady;
  final Function(String)? onDoubleTapLike; // Callback for double-tap like

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
    this.thumbnailUrl,
    this.autoPlay = false,
    this.onVideoReady,
    this.onDoubleTapLike,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget>
    with WidgetsBindingObserver, SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _showControls = true;
  double _currentSpeed = 1.0;
  bool _isMuted = false;
  int _videoKey = 0; // Key to force rebuild
  Timer? _hideTimer;
  bool _wasPlayingBeforePause = false;

  // Double-tap like animation
  late AnimationController _doubleTapController;
  late Animation<double> _doubleTapScale;
  late Animation<double> _doubleTapOpacity;
  bool _showHeartAnimation = false;
  DateTime? _lastTapTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isMuted = true; // Mute by default, for UI display

    // Initialize double-tap animation controller
    _doubleTapController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _doubleTapScale = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _doubleTapController, curve: Curves.elasticOut),
    );

    _doubleTapOpacity = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _doubleTapController, curve: Curves.easeInOut),
    );

    _initializeVideo();
    _startHideTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Pause video when app goes to background to save battery
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (_isInitialized && _controller.value.isPlaying) {
        _wasPlayingBeforePause = true;
        _controller.pause();
        debugPrint('🎬 Video paused - app backgrounded');
      }
    }
    // Resume video when app comes back to foreground (if it was playing)
    else if (state == AppLifecycleState.resumed) {
      if (_isInitialized && _wasPlayingBeforePause && widget.autoPlay) {
        _controller.play();
        _wasPlayingBeforePause = false;
        debugPrint('🎬 Video resumed - app foregrounded');
      }
    }
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _showControls && _controller.value.isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      debugPrint('Controls ${_showControls ? "shown" : "hidden"}');
      if (_showControls) {
        _startHideTimer();
      } else {
        _hideTimer?.cancel();
      }
    });
  }

  void _onVideoTap() {
    final now = DateTime.now();

    // Check if this is a double tap (within 300ms of last tap)
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!).inMilliseconds < 300) {
      // Double tap detected - show like animation
      _showDoubleTapLike();
      return;
    }

    // Single tap - toggle controls
    _lastTapTime = now;
    _toggleControls();
  }

  void _showDoubleTapLike() {
    setState(() {
      _showHeartAnimation = true;
    });

    // Trigger the callback to like the video/post
    widget.onDoubleTapLike?.call('like');

    // Play the animation
    _doubleTapController.forward().then((_) {
      if (mounted) {
        setState(() {
          _showHeartAnimation = false;
        });
        _doubleTapController.reset();
      }
    });

    debugPrint('Double-tap like triggered');
  }

  Future<void> _initializeVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.videoUrl),
      );
      await _controller.initialize();

      // Set to muted by default
      await _controller.setVolume(0.0);

      if (widget.autoPlay) {
        await _controller.play();
      }

      _controller.setLooping(true);

      setState(() {
        _isInitialized = true;
      });

      // Notify parent widget that video is ready
      widget.onVideoReady?.call();

      // Add listener for state changes
      _controller.addListener(() {
        if (mounted) {
          setState(() {});
        }
      });
    } catch (e) {
      debugPrint('Error initializing video: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _doubleTapController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (_controller.value.isPlaying) {
        _controller.pause();
      } else {
        _controller.play();
      }
    });
  }

  void _toggleFullscreen() async {
    // Save current state
    final wasPlaying = _controller.value.isPlaying;
    final currentPosition = _controller.value.position;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullscreenVideoPlayer(
          controller: _controller,
          videoUrl: widget.videoUrl,
        ),
      ),
    );

    // Force rebuild after returning from fullscreen
    if (mounted) {
      debugPrint('Returned from fullscreen, rebuilding video player');

      // Ensure orientation is back to portrait
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      // Small delay to allow orientation change to complete
      await Future.delayed(const Duration(milliseconds: 200));

      // Seek to current position to refresh texture
      await _controller.seekTo(currentPosition);

      // Restore playing state if needed
      if (wasPlaying) {
        await _controller.play();
      }

      // Force rebuild with new key
      setState(() {
        _videoKey++;
      });

      debugPrint('Video player rebuilt with key: $_videoKey');
    }
  }

  void _changeSpeed(double speed) {
    setState(() {
      _currentSpeed = speed;
      _controller.setPlaybackSpeed(speed);
    });
  }

  void _showSpeedOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Playback Speed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...[0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
              return ListTile(
                title: Text(
                  '${speed}x',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: _currentSpeed == speed
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _currentSpeed == speed ? Colors.blue : Colors.black,
                  ),
                ),
                selected: _currentSpeed == speed,
                selectedTileColor: Colors.blue.withValues(alpha: 0.1),
                onTap: () {
                  _changeSpeed(speed);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showVolumeSlider() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Volume',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    IconButton(
                      icon: Icon(
                        _controller.value.volume == 0
                            ? Icons.volume_off
                            : Icons.volume_up,
                        color: Colors.blue,
                      ),
                      onPressed: () {
                        // Quick toggle mute/unmute
                        setModalState(() {
                          if (_controller.value.volume == 0) {
                            _controller.setVolume(0.5);
                            _isMuted = false;
                          } else {
                            _controller.setVolume(0.0);
                            _isMuted = true;
                          }
                          setState(() {});
                        });
                      },
                    ),
                    Expanded(
                      child: Slider(
                        value: _controller.value.volume,
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        label: '${(_controller.value.volume * 100).round()}%',
                        onChanged: (value) {
                          setModalState(() {
                            _controller.setVolume(value);
                            _isMuted = value == 0;
                          });
                          setState(() {});
                        },
                      ),
                    ),
                    Text(
                      '${(_controller.value.volume * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Future<void> _downloadVideo() async {
    try {
      final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';

      if (kIsWeb) {
        // Web: Open in new tab for download
        final uri = Uri.parse(widget.videoUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Opening video for download'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        // Mobile/Desktop: Download to device

        // Request storage permission on Android
        if (Platform.isAndroid) {
          final status = await Permission.storage.request();
          if (!status.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Storage permission required to download videos',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        }

        // Show downloading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text('Downloading $fileName...'),
                ],
              ),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 30),
            ),
          );
        }

        // Download the file
        final response = await http.get(Uri.parse(widget.videoUrl));

        if (response.statusCode == 200) {
          // Get downloads directory
          Directory? directory;
          if (Platform.isAndroid) {
            directory = Directory('/storage/emulated/0/Download');
            if (!await directory.exists()) {
              directory = await getExternalStorageDirectory();
            }
          } else if (Platform.isIOS) {
            directory = await getApplicationDocumentsDirectory();
          } else {
            directory = await getDownloadsDirectory();
          }

          if (directory != null) {
            final filePath = '${directory.path}/$fileName';
            final file = File(filePath);
            await file.writeAsBytes(response.bodyBytes);

            if (mounted) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Video saved: $fileName'),
                  backgroundColor: Colors.green,
                  action: SnackBarAction(
                    label: 'Open',
                    textColor: Colors.white,
                    onPressed: () async {
                      final uri = Uri.file(filePath);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                  ),
                ),
              );
            }
          }
        } else {
          throw Exception('Download failed: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        height: MediaQuery.of(context).size.height * 0.4,
        constraints: BoxConstraints(
          minHeight: 200,
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Show thumbnail if available, otherwise show placeholder
            if (widget.thumbnailUrl != null && widget.thumbnailUrl!.isNotEmpty)
              Image.network(
                widget.thumbnailUrl!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: Colors.grey.shade800,
                  );
                },
              )
            else
              Container(
                color: Colors.grey.shade800,
              ),
            // Loading indicator
            const CircularProgressIndicator(color: Colors.white),
            // Play icon overlay
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: MediaQuery.of(context).size.width * 0.15,
              ),
            ),
          ],
        ),
      );
    }

    // Get responsive dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobileWeb = kIsWeb && screenWidth < 768;

    // Responsive sizing based on screen width and aspect ratio
    final iconSize = (screenWidth * 0.08).clamp(20.0, 32.0).toDouble();
    final buttonMinSize = (screenWidth * 0.11).clamp(36.0, 48.0).toDouble();
    final horizontalPadding = (screenWidth * 0.03).toDouble();
    final verticalPadding = (screenHeight * 0.015).toDouble();
    final fontSize = (screenWidth * 0.035).clamp(11.0, 14.0).toDouble();
    final speedIconSize = (screenWidth * 0.045).clamp(12.0, 18.0).toDouble();
    final speedFontSize = (screenWidth * 0.032).clamp(10.0, 13.0).toDouble();

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        color: Colors.black,
        child: AspectRatio(
          aspectRatio: _controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Video player
              Center(
                child: AspectRatio(
                  aspectRatio: _controller.value.aspectRatio,
                  child: VideoPlayer(
                    _controller,
                    key: ValueKey('video_player_$_videoKey'),
                  ),
                ),
              ),

              // Tap detection overlay (covers entire video area)
              Positioned.fill(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    key: ValueKey('video_tap_detector_$_videoKey'),
                    onTap: _onVideoTap,
                    behavior: HitTestBehavior.translucent,
                    child: const SizedBox.expand(),
                  ),
                ),
              ),

              // Center play button when paused
              if (!_controller.value.isPlaying)
                Center(
                  child: GestureDetector(
                    onTap: () {
                      _togglePlayPause();
                      _startHideTimer();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      padding: EdgeInsets.all(screenWidth * 0.04),
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: screenWidth * 0.15,
                      ),
                    ),
                  ),
                ),

              // Muted indicator badge (top-right corner)
              Positioned(
                top: screenHeight * 0.02,
                right: screenHeight * 0.02,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  padding: EdgeInsets.all(screenWidth * 0.02),
                  child: Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    color: _isMuted ? Colors.red : Colors.white,
                    size: screenWidth * 0.05,
                  ),
                ),
              ),

              // Double-tap like heart animation
              if (_showHeartAnimation)
                Center(
                  child: ScaleTransition(
                    scale: _doubleTapScale,
                    child: FadeTransition(
                      opacity: _doubleTapOpacity,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.3),
                          shape: BoxShape.circle,
                        ),
                        padding: EdgeInsets.all(screenWidth * 0.06),
                        child: Icon(
                          Icons.favorite,
                          color: Colors.red,
                          size: screenWidth * 0.2,
                        ),
                      ),
                    ),
                  ),
                ),

              // Bottom controls bar with responsive sizing
              if (_showControls)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.85),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Progress slider with responsive hit area
                        SizedBox(
                          height: (screenHeight * 0.08).clamp(24, 32),
                          child: VideoProgressIndicator(
                            _controller,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: Colors.blue,
                              bufferedColor: Colors.grey,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                        ),
                        SizedBox(height: screenHeight * 0.01),
                        // Full controls row - responsive wrapping for small screens
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              // Play/Pause button
                              SizedBox(
                                width: buttonMinSize,
                                height: buttonMinSize,
                                child: IconButton(
                                  icon: Icon(
                                    _controller.value.isPlaying
                                        ? Icons.pause
                                        : Icons.play_arrow,
                                    color: Colors.white,
                                    size: iconSize,
                                  ),
                                  onPressed: () {
                                    _togglePlayPause();
                                    _startHideTimer();
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(
                                    minWidth: buttonMinSize,
                                    minHeight: buttonMinSize,
                                  ),
                                ),
                              ),
                              SizedBox(width: screenWidth * 0.01),
                              // Time display - responsive visibility
                              if (!isMobileWeb || screenWidth > 380) ...[
                                Text(
                                  _formatDuration(_controller.value.position),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  ' / ',
                                  style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: fontSize - 2,
                                  ),
                                ),
                                Text(
                                  _formatDuration(_controller.value.duration),
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: fontSize,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                              const Spacer(),
                              // Speed control
                              InkWell(
                                onTap: () {
                                  _showSpeedOptions();
                                  _startHideTimer();
                                },
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: screenWidth * 0.025,
                                    vertical: screenHeight * 0.008,
                                  ),
                                  constraints: BoxConstraints(
                                    minWidth: buttonMinSize,
                                    minHeight: buttonMinSize,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.speed,
                                        color: Colors.white,
                                        size: speedIconSize,
                                      ),
                                      SizedBox(width: screenWidth * 0.008),
                                      Text(
                                        '${_currentSpeed}x',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: speedFontSize,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(width: screenWidth * 0.015),
                              // Volume button
                              SizedBox(
                                width: buttonMinSize,
                                height: buttonMinSize,
                                child: IconButton(
                                  icon: Icon(
                                    _isMuted
                                        ? Icons.volume_off
                                        : Icons.volume_up,
                                    color: Colors.white,
                                    size: iconSize - 4,
                                  ),
                                  onPressed: () {
                                    _showVolumeSlider();
                                    _startHideTimer();
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(
                                    minWidth: buttonMinSize,
                                    minHeight: buttonMinSize,
                                  ),
                                ),
                              ),
                              SizedBox(width: screenWidth * 0.01),
                              // Download button
                              SizedBox(
                                width: buttonMinSize,
                                height: buttonMinSize,
                                child: IconButton(
                                  icon: Icon(
                                    Icons.download,
                                    color: Colors.white,
                                    size: iconSize - 4,
                                  ),
                                  onPressed: () {
                                    _downloadVideo();
                                    _startHideTimer();
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(
                                    minWidth: buttonMinSize,
                                    minHeight: buttonMinSize,
                                  ),
                                ),
                              ),
                              SizedBox(width: screenWidth * 0.01),
                              // Fullscreen button
                              SizedBox(
                                width: buttonMinSize,
                                height: buttonMinSize,
                                child: IconButton(
                                  icon: Icon(
                                    Icons.fullscreen,
                                    color: Colors.white,
                                    size: iconSize - 4,
                                  ),
                                  onPressed: _toggleFullscreen,
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(
                                    minWidth: buttonMinSize,
                                    minHeight: buttonMinSize,
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
            ],
          ),
        ),
      ),
    );
  }
}

// Fullscreen video player widget
class _FullscreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  final String videoUrl;

  const _FullscreenVideoPlayer({
    required this.controller,
    required this.videoUrl,
  });

  @override
  State<_FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<_FullscreenVideoPlayer> {
  bool _showControls = true;
  Timer? _hideTimer;
  double _currentSpeed = 1.0;
  bool _isMuted = false;

  @override
  void initState() {
    super.initState();
    // Set landscape orientation for fullscreen
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Hide system UI for immersive experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

    // Add listener to rebuild when video state changes
    widget.controller.addListener(() {
      if (mounted) {
        setState(() {});
      }
    });

    // Get current speed and mute state
    _currentSpeed = widget.controller.value.playbackSpeed;
    _isMuted = widget.controller.value.volume == 0;

    // Start auto-hide timer
    _startHideTimer();
  }

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted && _showControls && widget.controller.value.isPlaying) {
        setState(() {
          _showControls = false;
        });
      }
    });
  }

  void _toggleControls() {
    setState(() {
      _showControls = !_showControls;
      debugPrint('Fullscreen controls ${_showControls ? "shown" : "hidden"}');
      if (_showControls) {
        _startHideTimer();
      } else {
        _hideTimer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    // Restore all orientations (allows portrait)
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    // Restore system UI
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  void _togglePlayPause() {
    setState(() {
      if (widget.controller.value.isPlaying) {
        widget.controller.pause();
      } else {
        widget.controller.play();
      }
    });
    _startHideTimer();
  }

  void _changeSpeed(double speed) {
    setState(() {
      _currentSpeed = speed;
      widget.controller.setPlaybackSpeed(speed);
    });
    _startHideTimer();
  }

  void _showSpeedOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Playback Speed',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...[0.5, 0.75, 1.0, 1.25, 1.5, 2.0].map((speed) {
              return ListTile(
                title: Text(
                  '${speed}x',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: _currentSpeed == speed
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: _currentSpeed == speed ? Colors.blue : Colors.black,
                  ),
                ),
                selected: _currentSpeed == speed,
                selectedTileColor: Colors.blue.withValues(alpha: 0.1),
                onTap: () {
                  _changeSpeed(speed);
                  Navigator.pop(context);
                },
              );
            }),
          ],
        ),
      ),
    );
  }

  void _showVolumeSlider() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Volume',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Icon(
                      widget.controller.value.volume == 0
                          ? Icons.volume_off
                          : Icons.volume_up,
                      color: Colors.blue,
                    ),
                    Expanded(
                      child: Slider(
                        value: widget.controller.value.volume,
                        min: 0.0,
                        max: 1.0,
                        divisions: 20,
                        label:
                            '${(widget.controller.value.volume * 100).round()}%',
                        onChanged: (value) {
                          setModalState(() {
                            widget.controller.setVolume(value);
                            _isMuted = value == 0;
                          });
                          setState(() {});
                        },
                      ),
                    ),
                    Text(
                      '${(widget.controller.value.volume * 100).round()}%',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
          );
        },
      ),
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));

    if (duration.inHours > 0) {
      return '$hours:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Future<void> _downloadVideo() async {
    try {
      final fileName = 'video_${DateTime.now().millisecondsSinceEpoch}.mp4';

      if (kIsWeb) {
        // Web: Open in new tab for download
        final uri = Uri.parse(widget.videoUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Opening video for download'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      } else {
        // Mobile/Desktop: Download to device

        // Request storage permission on Android
        if (Platform.isAndroid) {
          final status = await Permission.storage.request();
          if (!status.isGranted) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Storage permission required to download videos',
                  ),
                  backgroundColor: Colors.red,
                ),
              );
            }
            return;
          }
        }

        // Show downloading indicator
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text('Downloading $fileName...'),
                ],
              ),
              backgroundColor: Colors.blue,
              duration: const Duration(seconds: 30),
            ),
          );
        }

        // Download the file
        final response = await http.get(Uri.parse(widget.videoUrl));

        if (response.statusCode == 200) {
          // Get downloads directory
          Directory? directory;
          if (Platform.isAndroid) {
            directory = Directory('/storage/emulated/0/Download');
            if (!await directory.exists()) {
              directory = await getExternalStorageDirectory();
            }
          } else if (Platform.isIOS) {
            directory = await getApplicationDocumentsDirectory();
          } else {
            directory = await getDownloadsDirectory();
          }

          if (directory != null) {
            final filePath = '${directory.path}/$fileName';
            final file = File(filePath);
            await file.writeAsBytes(response.bodyBytes);

            if (mounted) {
              ScaffoldMessenger.of(context).clearSnackBars();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Video saved: $fileName'),
                  backgroundColor: Colors.green,
                  action: SnackBarAction(
                    label: 'Open',
                    textColor: Colors.white,
                    onPressed: () async {
                      final uri = Uri.file(filePath);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                  ),
                ),
              );
            }
          }
        } else {
          throw Exception('Download failed: ${response.statusCode}');
        }
      }
    } catch (e) {
      debugPrint('Download error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Download failed: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get screen dimensions for responsive layout
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobileWeb = kIsWeb && (screenWidth < 768 || screenHeight < 600);

    // Responsive sizing for fullscreen mode
    final iconSize = (screenWidth * 0.1).clamp(24.0, 40.0).toDouble();
    final buttonMinSize = (screenWidth * 0.12).clamp(40.0, 56.0).toDouble();
    final horizontalPadding = (screenWidth * 0.04).toDouble();
    final verticalPadding = (screenHeight * 0.025).toDouble();
    final fontSize = (screenWidth * 0.038).clamp(12.0, 16.0).toDouble();
    final speedPadding = (screenWidth * 0.03).toDouble();
    final speedIconSize = (screenWidth * 0.05).clamp(16.0, 24.0).toDouble();
    final spacing = (screenWidth * 0.02).clamp(6.0, 12.0).toDouble();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: AspectRatio(
          aspectRatio: widget.controller.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Video player
              Positioned.fill(child: VideoPlayer(widget.controller)),

              // Tap detection overlay (covers entire video area)
              Positioned.fill(
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    onTap: () {
                      debugPrint(
                        'Fullscreen center tapped - toggling controls',
                      );
                      _toggleControls();
                    },
                    behavior: HitTestBehavior.translucent,
                    child: Container(color: Colors.transparent),
                  ),
                ),
              ),

              // Center play button when paused (fullscreen)
              if (!widget.controller.value.isPlaying)
                Center(
                  child: GestureDetector(
                    onTap: _togglePlayPause,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.4),
                        shape: BoxShape.circle,
                      ),
                      padding: const EdgeInsets.all(20),
                      child: const Icon(
                        Icons.play_arrow,
                        color: Colors.white,
                        size: 80,
                      ),
                    ),
                  ),
                ),

              // Muted indicator badge (top-right corner) - fullscreen
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(10),
                  child: Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    color: _isMuted ? Colors.red : Colors.white,
                    size: 24,
                  ),
                ),
              ),

              // Dark overlay gradient for better control visibility
              if (_showControls)
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.3),
                        ],
                      ),
                    ),
                  ),
                ),

              // Bottom controls bar with all controls
              if (_showControls)
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Progress slider with larger hit area for mobile
                        SizedBox(
                          height: isMobileWeb ? 36 : 28,
                          child: VideoProgressIndicator(
                            widget.controller,
                            allowScrubbing: true,
                            colors: const VideoProgressColors(
                              playedColor: Colors.blue,
                              bufferedColor: Colors.grey,
                              backgroundColor: Colors.white24,
                            ),
                          ),
                        ),
                        SizedBox(height: isMobileWeb ? 12 : 8),
                        // Full controls row
                        Row(
                          children: [
                            // Play/Pause button
                            IconButton(
                              icon: Icon(
                                widget.controller.value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                                color: Colors.white,
                                size: iconSize,
                              ),
                              onPressed: _togglePlayPause,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(
                                minWidth: buttonMinSize,
                                minHeight: buttonMinSize,
                              ),
                            ),
                            SizedBox(width: spacing),
                            // Time display - hide on very small screens
                            if (!isMobileWeb || screenWidth > 500) ...[
                              Text(
                                _formatDuration(
                                    widget.controller.value.position),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                ' / ',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: fontSize - 1,
                                ),
                              ),
                              Text(
                                _formatDuration(
                                    widget.controller.value.duration),
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: fontSize,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                            const Spacer(),
                            // Speed control
                            InkWell(
                              onTap: _showSpeedOptions,
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: speedPadding,
                                  vertical: isMobileWeb ? 8 : 6,
                                ),
                                constraints: BoxConstraints(
                                  minWidth: buttonMinSize,
                                  minHeight: buttonMinSize,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.speed,
                                      color: Colors.white,
                                      size: speedIconSize,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${_currentSpeed}x',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: fontSize - 1,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(width: spacing + 4),
                            // Volume button
                            IconButton(
                              icon: Icon(
                                _isMuted ? Icons.volume_off : Icons.volume_up,
                                color: Colors.white,
                                size: iconSize - 4,
                              ),
                              onPressed: _showVolumeSlider,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(
                                minWidth: buttonMinSize,
                                minHeight: buttonMinSize,
                              ),
                            ),
                            SizedBox(width: spacing),
                            // Download button
                            IconButton(
                              icon: Icon(
                                Icons.download,
                                color: Colors.white,
                                size: iconSize - 4,
                              ),
                              onPressed: _downloadVideo,
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(
                                minWidth: buttonMinSize,
                                minHeight: buttonMinSize,
                              ),
                            ),
                            SizedBox(width: spacing),
                            // Exit fullscreen button
                            IconButton(
                              icon: Icon(
                                Icons.fullscreen_exit,
                                color: Colors.white,
                                size: iconSize - 4,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(
                                minWidth: buttonMinSize,
                                minHeight: buttonMinSize,
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
      ),
    );
  }
}
