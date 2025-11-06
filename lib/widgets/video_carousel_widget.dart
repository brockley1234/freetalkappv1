import 'package:flutter/material.dart';
import '../utils/url_utils.dart';
import 'video_player_widget.dart';

/// Multi-video carousel widget with horizontal swipe support
/// Displays multiple videos with dot indicators and counter
class VideoCarouselWidget extends StatefulWidget {
  final List<String> videoUrls;
  final List<String>? thumbnailUrls;
  final bool autoPlay;
  final VoidCallback? onVideoChanged;

  const VideoCarouselWidget({
    super.key,
    required this.videoUrls,
    this.thumbnailUrls,
    this.autoPlay = false,
    this.onVideoChanged,
  });

  @override
  State<VideoCarouselWidget> createState() => _VideoCarouselWidgetState();
}

class _VideoCarouselWidgetState extends State<VideoCarouselWidget> {
  late PageController _pageController;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentIndex = index;
    });
    widget.onVideoChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    if (widget.videoUrls.isEmpty) {
      return Container(
        height: screenHeight * 0.4,
        constraints: BoxConstraints(
          minHeight: 200,
          maxHeight: screenHeight * 0.6,
        ),
        color: Colors.grey.shade200,
        child: const Center(
          child: Text('No videos available'),
        ),
      );
    }

    // Single video - just show the player
    if (widget.videoUrls.length == 1) {
      return VideoPlayerWidget(
        videoUrl: UrlUtils.getFullVideoUrl(widget.videoUrls[0]),
        thumbnailUrl:
            widget.thumbnailUrls != null && widget.thumbnailUrls!.isNotEmpty
                ? UrlUtils.getFullImageUrl(widget.thumbnailUrls![0])
                : null,
        autoPlay: widget.autoPlay,
      );
    }

    // Multiple videos - show carousel with controls
    // Responsive badge and indicator sizing
    final badgePadding = screenWidth * 0.03;
    final badgeFontSize = (screenWidth * 0.035).clamp(11.0, 14.0).toDouble();
    final indicatorSize = (screenWidth * 0.02).clamp(6.0, 12.0).toDouble();
    final indicatorSpacing = (screenWidth * 0.01).clamp(4.0, 8.0).toDouble();
    final arrowSize = (screenWidth * 0.06).clamp(20.0, 32.0).toDouble();
    final arrowPadding = (screenWidth * 0.025).clamp(8.0, 12.0).toDouble();

    return Stack(
      children: [
        // Video carousel
        PageView.builder(
          controller: _pageController,
          onPageChanged: _onPageChanged,
          itemCount: widget.videoUrls.length,
          itemBuilder: (context, index) {
            final videoUrl = widget.videoUrls[index];
            final thumbnailUrl = widget.thumbnailUrls != null &&
                    index < widget.thumbnailUrls!.length
                ? widget.thumbnailUrls![index]
                : null;

            return VideoPlayerWidget(
              videoUrl: UrlUtils.getFullVideoUrl(videoUrl),
              thumbnailUrl: thumbnailUrl != null
                  ? UrlUtils.getFullImageUrl(thumbnailUrl)
                  : null,
              autoPlay: widget.autoPlay && index == 0,
            );
          },
        ),

        // Video counter badge (top-right) - Responsive
        Positioned(
          top: screenHeight * 0.02,
          right: screenWidth * 0.03,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(8),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: badgePadding,
              vertical: badgePadding * 0.5,
            ),
            child: Text(
              '${_currentIndex + 1}/${widget.videoUrls.length}',
              style: TextStyle(
                color: Colors.white,
                fontSize: badgeFontSize,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),

        // Dot indicators (bottom-center) - Responsive
        if (widget.videoUrls.length > 1)
          Positioned(
            bottom: screenHeight * 0.02,
            left: 0,
            right: 0,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  widget.videoUrls.length,
                  (index) => Container(
                    margin: EdgeInsets.symmetric(horizontal: indicatorSpacing),
                    width: _currentIndex == index
                        ? indicatorSize * 1.5
                        : indicatorSize,
                    height: indicatorSize,
                    decoration: BoxDecoration(
                      color: _currentIndex == index
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(indicatorSize / 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

        // Left arrow (if not on first video) - Responsive
        if (_currentIndex > 0 && widget.videoUrls.length > 1)
          Positioned(
            left: screenWidth * 0.03,
            top: 0,
            bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  _pageController.previousPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  padding: EdgeInsets.all(arrowPadding),
                  child: Icon(
                    Icons.arrow_back,
                    color: Colors.white,
                    size: arrowSize,
                  ),
                ),
              ),
            ),
          ),

        // Right arrow (if not on last video) - Responsive
        if (_currentIndex < widget.videoUrls.length - 1 &&
            widget.videoUrls.length > 1)
          Positioned(
            right: screenWidth * 0.03,
            top: 0,
            bottom: 0,
            child: Center(
              child: GestureDetector(
                onTap: () {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  padding: EdgeInsets.all(arrowPadding),
                  child: Icon(
                    Icons.arrow_forward,
                    color: Colors.white,
                    size: arrowSize,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
