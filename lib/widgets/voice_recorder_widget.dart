import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class VoiceRecorderWidget extends StatefulWidget {
  final Function(String filePath, int duration) onRecordingComplete;
  final VoidCallback onCancel;

  const VoiceRecorderWidget({
    super.key,
    required this.onRecordingComplete,
    required this.onCancel,
  });

  @override
  State<VoiceRecorderWidget> createState() => _VoiceRecorderWidgetState();
}

class _VoiceRecorderWidgetState extends State<VoiceRecorderWidget>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _audioRecorder = AudioRecorder();
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _timer;
  String? _audioPath;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _startRecording();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    _audioRecorder.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      debugPrint('🎤 === Starting recording process ===');

      // Request microphone permission (skip permission check on web)
      bool hasPermission = kIsWeb;

      if (!kIsWeb) {
        debugPrint('🎤 Requesting microphone permission...');
        hasPermission = await Permission.microphone.request().isGranted;
        debugPrint('🎤 Permission granted: $hasPermission');
      }

      if (hasPermission) {
        // For web, don't specify a path - the plugin will handle it
        // For mobile, get temporary directory
        if (!kIsWeb) {
          final directory = await getTemporaryDirectory();
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          _audioPath = '${directory.path}/voice_message_$timestamp.m4a';
          debugPrint('🎤 Mobile recording path: $_audioPath');
        }

        // Start recording
        if (kIsWeb) {
          // On web, generate a temporary filename
          final timestamp = DateTime.now().millisecondsSinceEpoch;
          _audioPath = 'voice_message_$timestamp.wav';
          debugPrint('🎤 Web recording filename: $_audioPath');

          await _audioRecorder.start(
            const RecordConfig(
              encoder: AudioEncoder.wav, // WAV works better on web
              bitRate: 128000,
              sampleRate: 44100,
            ),
            path: _audioPath!,
          );
        } else {
          // On mobile, specify full path
          await _audioRecorder.start(
            const RecordConfig(
              encoder: AudioEncoder.aacLc,
              bitRate: 128000,
              sampleRate: 44100,
            ),
            path: _audioPath!,
          );
        }

        debugPrint('🎤 Recording started successfully');

        setState(() {
          _isRecording = true;
        });

        // Start timer
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (mounted) {
            setState(() {
              _recordDuration = Duration(seconds: timer.tick);
            });
          }
        });
      } else {
        // Permission denied
        debugPrint('🎤 ❌ Microphone permission denied');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Microphone permission is required to record voice messages'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );
          widget.onCancel();
        }
      }
    } catch (e) {
      debugPrint('🎤 ❌ Error starting recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to start recording: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
        widget.onCancel();
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      _timer?.cancel();

      if (_isRecording) {
        debugPrint('🎤 Stopping recording...');
        final path = await _audioRecorder.stop();

        if (path == null) {
          debugPrint('🎤 ❌ Recording path is null');
          throw Exception('Failed to save recording');
        }

        if (!mounted) {
          debugPrint('🎤 ⚠️ Widget unmounted, canceling');
          return;
        }

        // Ensure minimum duration of 1 second
        final duration =
            _recordDuration.inSeconds > 0 ? _recordDuration.inSeconds : 1;

        debugPrint(
            '🎤 Recording stopped - Path: $path, Duration: $duration seconds');

        if (kIsWeb) {
          // On web, the path is the blob/file
          // Just pass it along - no file system check needed
          debugPrint('🎤 Web recording complete, sending...');
          widget.onRecordingComplete(path, duration);
        } else {
          // On mobile, verify file exists and has content
          final file = File(path);
          final exists = await file.exists();
          debugPrint('🎤 File exists: $exists');

          if (exists) {
            final fileSize = await file.length();
            debugPrint('🎤 File size: $fileSize bytes');

            if (fileSize > 0) {
              debugPrint('🎤 Mobile recording complete, sending...');
              widget.onRecordingComplete(path, duration);
            } else {
              debugPrint('🎤 ❌ Recording file is empty');
              throw Exception('Recording file is empty. Please try again.');
            }
          } else {
            debugPrint('🎤 ❌ Recording file not found at: $path');
            throw Exception('Recording file not found. Please try again.');
          }
        }
      } else {
        debugPrint('🎤 ⚠️ Not currently recording');
      }
    } catch (e) {
      debugPrint('🎤 ❌ Error stopping recording: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Failed to save recording: ${e.toString().replaceAll('Exception: ', '')}'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _cancelRecording() async {
    try {
      _timer?.cancel();

      if (_isRecording) {
        await _audioRecorder.stop();

        // Delete the recording file (only on mobile)
        if (!kIsWeb && _audioPath != null) {
          final file = File(_audioPath!);
          if (await file.exists()) {
            await file.delete();
          }
        }
      }

      widget.onCancel();
    } catch (e) {
      debugPrint('Error canceling recording: $e');
      widget.onCancel();
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Cancel button
          IconButton(
            onPressed: _cancelRecording,
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: 'Delete recording',
          ),

          const SizedBox(width: 8),

          // Recording indicator
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.red,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.withValues(
                          alpha: 0.3 + (_pulseController.value * 0.4)),
                      blurRadius: 8 + (_pulseController.value * 8),
                      spreadRadius: 2 + (_pulseController.value * 4),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(width: 12),

          // Timer
          Text(
            _formatDuration(_recordDuration),
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),

          const SizedBox(width: 12),

          // Waveform animation (simplified)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(20, (index) {
                final delay = index * 0.05;
                return AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    final value = (_pulseController.value + delay) % 1.0;
                    final height = 4.0 + (value * 20);
                    return Container(
                      width: 3,
                      height: height,
                      margin: const EdgeInsets.symmetric(horizontal: 1),
                      decoration: BoxDecoration(
                        color: Colors.blue,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    );
                  },
                );
              }),
            ),
          ),

          const SizedBox(width: 12),

          // Send button
          Container(
            decoration: const BoxDecoration(
              color: Colors.blue,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _stopRecording,
              icon: const Icon(Icons.send, color: Colors.white),
              tooltip: 'Send voice message',
            ),
          ),
        ],
      ),
    );
  }
}
