import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../utils/url_utils.dart';
import 'dart:async';

class VoiceMessageWidget extends StatefulWidget {
  final String audioUrl;
  final int? duration; // Duration in seconds
  final bool isSender;
  final List<double>? waveformData;

  const VoiceMessageWidget({
    super.key,
    required this.audioUrl,
    this.duration,
    required this.isSender,
    this.waveformData,
  });

  @override
  State<VoiceMessageWidget> createState() => _VoiceMessageWidgetState();
}

class _VoiceMessageWidgetState extends State<VoiceMessageWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlaying = false;
  bool _isLoading = false;
  Duration _currentPosition = Duration.zero;
  Duration _totalDuration = Duration.zero;
  StreamSubscription? _positionSubscription;
  StreamSubscription? _durationSubscription;
  StreamSubscription? _playerCompleteSubscription;

  @override
  void initState() {
    super.initState();
    _setupAudioPlayer();
  }

  void _setupAudioPlayer() {
    // Listen to player state changes
    _positionSubscription = _audioPlayer.onPositionChanged.listen((position) {
      if (mounted) {
        setState(() {
          _currentPosition = position;
        });
      }
    });

    _durationSubscription = _audioPlayer.onDurationChanged.listen((duration) {
      if (mounted) {
        setState(() {
          _totalDuration = duration;
        });
      }
    });

    _playerCompleteSubscription = _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _currentPosition = Duration.zero;
        });
      }
    });

    // Set total duration if provided
    if (widget.duration != null) {
      _totalDuration = Duration(seconds: widget.duration!);
    }
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();
    _durationSubscription?.cancel();
    _playerCompleteSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _togglePlayPause() async {
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
        setState(() {
          _isPlaying = false;
        });
      } else {
        setState(() {
          _isLoading = true;
        });

        final fullUrl = UrlUtils.getFullUrl(widget.audioUrl);

        if (_currentPosition == Duration.zero) {
          await _audioPlayer.play(UrlSource(fullUrl));
        } else {
          await _audioPlayer.resume();
        }

        setState(() {
          _isPlaying = true;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isPlaying = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to play voice message'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _totalDuration.inMilliseconds > 0
        ? _currentPosition.inMilliseconds / _totalDuration.inMilliseconds
        : 0.0;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: widget.isSender ? Colors.blue.shade100 : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Play/Pause button
          InkWell(
            onTap: _togglePlayPause,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: widget.isSender ? Colors.blue : Colors.grey.shade400,
                shape: BoxShape.circle,
              ),
              child: _isLoading
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          widget.isSender ? Colors.white : Colors.black87,
                        ),
                      ),
                    )
                  : Icon(
                      _isPlaying ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 24,
                    ),
            ),
          ),
          const SizedBox(width: 12),

          // Waveform or progress bar
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Waveform visualization
                if (widget.waveformData != null &&
                    widget.waveformData!.isNotEmpty)
                  SizedBox(
                    height: 30,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: List.generate(
                        widget.waveformData!.length.clamp(0, 40),
                        (index) {
                          final barIndex =
                              (index * widget.waveformData!.length / 40)
                                  .floor();
                          final amplitude = widget.waveformData![barIndex.clamp(
                              0, widget.waveformData!.length - 1)];
                          final isPlayed = progress > (index / 40);

                          return Container(
                            width: 2,
                            height: (amplitude * 30).clamp(4.0, 30.0),
                            decoration: BoxDecoration(
                              color: isPlayed
                                  ? (widget.isSender
                                      ? Colors.blue
                                      : Colors.grey.shade600)
                                  : Colors.grey.shade400,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          );
                        },
                      ),
                    ),
                  )
                else
                  // Simple progress bar if no waveform data
                  ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      backgroundColor: Colors.grey.shade300,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        widget.isSender ? Colors.blue : Colors.grey.shade600,
                      ),
                    ),
                  ),

                const SizedBox(height: 4),

                // Duration text
                Text(
                  _isPlaying || _currentPosition > Duration.zero
                      ? '${_formatDuration(_currentPosition)} / ${_formatDuration(_totalDuration)}'
                      : _formatDuration(_totalDuration),
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 8),

          // Microphone icon
          Icon(
            Icons.mic,
            size: 18,
            color: widget.isSender ? Colors.blue : Colors.grey.shade600,
          ),
        ],
      ),
    );
  }
}
