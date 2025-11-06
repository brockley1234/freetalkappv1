import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/video_service.dart';
import '../services/api_service.dart';
import 'music_selection_page.dart';

class UploadVideoPage extends StatefulWidget {
  final Map<String, dynamic>? currentUser;

  const UploadVideoPage({super.key, this.currentUser});

  @override
  State<UploadVideoPage> createState() => _UploadVideoPageState();
}

class _UploadVideoPageState extends State<UploadVideoPage> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedVideo;
  XFile? _selectedVideoWeb; // For web platform
  VideoPlayerController? _previewController;
  AudioPlayer? _previewAudioPlayer;
  bool _isUploading = false;

  // Audio track fields
  Map<String, dynamic>? _selectedAudioTrack;
  int _audioVolume = 100;
  bool _originalAudio =
      false; // Default to false so videos are muted and play with background music

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _previewController?.dispose();
    _previewAudioPlayer?.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    try {
      if (kIsWeb) {
        // For web, show a message about limitations
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Web video upload: Please use mobile app for best experience'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

      final XFile? pickedFile = await _picker.pickVideo(
        source: ImageSource.gallery,
      );

      if (pickedFile != null) {
        // Check file size (max 100MB)
        final fileSize = await pickedFile.length();
        if (fileSize > 100 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Video size must be less than 100MB'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        if (kIsWeb) {
          // For web, store XFile directly
          setState(() {
            _selectedVideoWeb = pickedFile;
          });

          // Initialize preview for web using network URL
          // Note: On web, the path is actually a blob URL
          _previewController = VideoPlayerController.networkUrl(
            Uri.parse(pickedFile.path),
          );
          await _previewController!.initialize();
          _previewController!.setLooping(true);
          _previewController!.play();
          setState(() {});
        } else {
          // For mobile/desktop
          final file = File(pickedFile.path);
          setState(() {
            _selectedVideo = file;
          });

          // Initialize preview
          _previewController = VideoPlayerController.file(file);
          await _previewController!.initialize();
          _previewController!.setLooping(true);
          _previewController!.play();
          setState(() {});
        }
      }
    } catch (e) {
      debugPrint('Error picking video: $e');
      if (mounted) {
        String errorMessage = 'Failed to pick video';
        if (kIsWeb) {
          errorMessage =
              'Video upload on web is limited. Please use the mobile app for uploading videos.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _selectMusic() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const MusicSelectionPage(),
      ),
    );

    if (result != null && mounted) {
      setState(() {
        _selectedAudioTrack = result;
        // Automatically mute original audio when a sound is selected
        _originalAudio = false;
      });

      // Update preview to use selected audio
      await _updatePreviewAudio();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text('Selected: ${result['title']} - Original audio muted'),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _updatePreviewAudio() async {
    if (_previewController == null ||
        !_previewController!.value.isInitialized) {
      return;
    }

    // Dispose existing audio player
    await _previewAudioPlayer?.dispose();
    _previewAudioPlayer = null;

    if (_selectedAudioTrack != null && !_originalAudio) {
      // Mute video and play selected audio
      _previewController!.setVolume(0.0);
      debugPrint('🔇 Video muted for preview');

      try {
        final audioPlayer = AudioPlayer();
        final audioUrl = _selectedAudioTrack!['url'];

        debugPrint('🎵 Attempting to load audio: $audioUrl');

        if (audioUrl != null && audioUrl.isNotEmpty) {
          // Handle both local and remote URLs
          if (audioUrl.startsWith('assets/')) {
            debugPrint('📁 Loading from assets');
            // Remove 'assets/' prefix for AssetSource
            final assetPath = audioUrl.replaceFirst('assets/', '');
            debugPrint('📁 Asset path: $assetPath');
            await audioPlayer.setSource(AssetSource(assetPath));
          } else if (audioUrl.startsWith('http://') ||
              audioUrl.startsWith('https://')) {
            debugPrint('🌐 Loading from URL: $audioUrl');
            await audioPlayer.setSourceUrl(audioUrl);
          } else {
            // Relative path - need to prepend base URL
            final fullUrl = '${ApiService.baseApi}$audioUrl';
            debugPrint('🌐 Loading from relative path: $fullUrl');
            await audioPlayer.setSourceUrl(fullUrl);
          }

          await audioPlayer.setReleaseMode(ReleaseMode.loop);
          await audioPlayer.setVolume(_audioVolume / 100.0);

          _previewAudioPlayer = audioPlayer;

          // Start playing audio
          await audioPlayer.resume();
          debugPrint('✅ Preview audio playing');
        }
      } catch (e) {
        debugPrint('⚠️ Failed to initialize preview audio: $e');
        // Fallback to original video audio
        _previewController!.setVolume(1.0);
      }
    } else if (_selectedAudioTrack != null && _originalAudio) {
      // Mix audio - lower video volume
      _previewController!.setVolume(0.5);
      debugPrint('🔉 Video volume lowered for mixing');

      try {
        final audioPlayer = AudioPlayer();
        final audioUrl = _selectedAudioTrack!['url'];

        debugPrint('🎵 Attempting to load audio for mixing: $audioUrl');

        if (audioUrl != null && audioUrl.isNotEmpty) {
          if (audioUrl.startsWith('assets/')) {
            debugPrint('📁 Loading from assets for mixing');
            // Remove 'assets/' prefix for AssetSource
            final assetPath = audioUrl.replaceFirst('assets/', '');
            debugPrint('📁 Asset path for mixing: $assetPath');
            await audioPlayer.setSource(AssetSource(assetPath));
          } else if (audioUrl.startsWith('http://') ||
              audioUrl.startsWith('https://')) {
            debugPrint('🌐 Loading from URL for mixing: $audioUrl');
            await audioPlayer.setSourceUrl(audioUrl);
          } else {
            // Relative path - need to prepend base URL
            final fullUrl = '${ApiService.baseApi}$audioUrl';
            debugPrint('🌐 Loading from relative path for mixing: $fullUrl');
            await audioPlayer.setSourceUrl(fullUrl);
          }

          await audioPlayer.setReleaseMode(ReleaseMode.loop);
          await audioPlayer.setVolume((_audioVolume / 100.0) * 0.5);

          _previewAudioPlayer = audioPlayer;

          // Start playing audio
          await audioPlayer.resume();
          debugPrint('✅ Preview audio playing (mixing mode)');
        }
      } catch (e) {
        debugPrint('⚠️ Failed to initialize preview audio: $e');
        _previewController!.setVolume(1.0);
      }
    } else {
      // Use original video audio only
      _previewController!.setVolume(1.0);
      debugPrint('🔊 Using original video audio');
    }
  }

  Future<void> _uploadVideo() async {
    if (_selectedVideo == null && _selectedVideoWeb == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a video'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    try {
      // For built-in tracks, don't send musicTrackId (it's not a MongoDB ID)
      // Only send it for server tracks that have a real MongoDB ObjectId
      final isBuiltInTrack = _selectedAudioTrack?['source'] == 'built-in' ||
          _selectedAudioTrack?['isBuiltIn'] == true;

      final result = await VideoService.uploadVideo(
        videoFile: kIsWeb ? null : _selectedVideo,
        videoXFile: kIsWeb ? _selectedVideoWeb : null,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isNotEmpty
            ? _descriptionController.text.trim()
            : null,
        // Audio track data
        // Only send musicTrackId for server tracks, not built-in tracks
        musicTrackId: isBuiltInTrack ? null : _selectedAudioTrack?['_id'],
        audioTitle: _selectedAudioTrack?['title'],
        audioArtist: _selectedAudioTrack?['artist'],
        audioUrl: _selectedAudioTrack?['url'],
        audioSource: _selectedAudioTrack?['source'],
        audioLicense: _selectedAudioTrack?['license'],
        originalAudio: _originalAudio,
        audioVolume: _audioVolume,
      );

      if (result['success'] && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Video uploaded successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        if (mounted) {
          final errorMsg = result['message'] ?? 'Failed to upload video';
          final errorDetails =
              result['error'] != null ? '\n${result['error']}' : '';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$errorMsg$errorDetails'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error uploading video: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading video: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Upload Video'),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_selectedVideo != null && !_isUploading)
            TextButton(
              onPressed: _uploadVideo,
              child: const Text(
                'Upload',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          if (_isUploading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(15.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Web warning
            if (kIsWeb)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade700),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Video upload on web has limitations. For best experience, use the mobile app.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.orange.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            // Video preview or selector
            GestureDetector(
              onTap: _isUploading ? null : _pickVideo,
              child: Container(
                height: 400,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(15),
                ),
                child: _selectedVideo == null && _selectedVideoWeb == null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.video_library_outlined,
                            size: 80,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 15),
                          Text(
                            'Select a video',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Max 5 minutes, 100MB',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[500],
                            ),
                          ),
                          if (kIsWeb) ...[
                            const SizedBox(height: 8),
                            Text(
                              '⚠️ Limited support on web',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      )
                    : _previewController != null &&
                            _previewController!.value.isInitialized
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(15),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                FittedBox(
                                  fit: BoxFit.cover,
                                  child: SizedBox(
                                    width: _previewController!.value.size.width,
                                    height:
                                        _previewController!.value.size.height,
                                    child: VideoPlayer(_previewController!),
                                  ),
                                ),
                                if (!_isUploading)
                                  Positioned(
                                    top: 10,
                                    right: 10,
                                    child: IconButton(
                                      onPressed: () {
                                        setState(() {
                                          _previewController?.dispose();
                                          _previewController = null;
                                          _selectedVideo = null;
                                          _selectedVideoWeb = null;
                                        });
                                      },
                                      icon: const Icon(Icons.close,
                                          color: Colors.white),
                                      style: IconButton.styleFrom(
                                        backgroundColor: Colors.black45,
                                      ),
                                    ),
                                  ),
                                Center(
                                  child: GestureDetector(
                                    onTap: () {
                                      if (_previewController!.value.isPlaying) {
                                        _previewController!.pause();
                                      } else {
                                        _previewController!.play();
                                      }
                                      setState(() {});
                                    },
                                    child: Container(
                                      width: 60,
                                      height: 60,
                                      decoration: const BoxDecoration(
                                        color: Colors.black45,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        _previewController!.value.isPlaying
                                            ? Icons.pause
                                            : Icons.play_arrow,
                                        color: Colors.white,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const Center(
                            child: CircularProgressIndicator(),
                          ),
              ),
            ),
            const SizedBox(height: 25),

            // Title input
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Title *',
                hintText: 'Enter video title',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
              ),
              maxLength: 200,
              enabled: !_isUploading,
            ),
            const SizedBox(height: 15),

            // Description input
            TextField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Description',
                hintText: 'Add a description (optional)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: Colors.blue, width: 2),
                ),
                alignLabelWithHint: true,
              ),
              maxLines: 4,
              maxLength: 2000,
              enabled: !_isUploading,
            ),
            const SizedBox(height: 20),

            // Music/Sound selection
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.music_note, color: Colors.blue.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Add Sound',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_selectedAudioTrack != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.purple.shade400,
                                  Colors.blue.shade400
                                ],
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.music_note,
                                color: Colors.white),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedAudioTrack!['title'] ?? 'Unknown',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _selectedAudioTrack!['artist'] ??
                                      'Unknown Artist',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 12,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, color: Colors.red),
                            onPressed: _isUploading
                                ? null
                                : () async {
                                    setState(() {
                                      _selectedAudioTrack = null;
                                      // Reset to use original audio when removing sound
                                      _originalAudio = true;
                                    });
                                    // Update preview to use original audio
                                    await _updatePreviewAudio();
                                  },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Checkbox(
                          value: _originalAudio,
                          onChanged: _isUploading
                              ? null
                              : (value) async {
                                  setState(() {
                                    _originalAudio = value ?? true;
                                  });
                                  // Update preview audio mix
                                  await _updatePreviewAudio();
                                },
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Keep original video audio'),
                              Text(
                                'Mix original audio with selected sound',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Sound Volume:'),
                        Expanded(
                          child: Slider(
                            value: _audioVolume.toDouble(),
                            min: 0,
                            max: 100,
                            divisions: 20,
                            label: '$_audioVolume%',
                            onChanged: _isUploading
                                ? null
                                : (value) {
                                    setState(() {
                                      _audioVolume = value.toInt();
                                    });
                                    // Update preview audio volume in real-time
                                    if (_previewAudioPlayer != null) {
                                      final volume = _originalAudio
                                          ? (value / 100.0) * 0.5
                                          : value / 100.0;
                                      _previewAudioPlayer!.setVolume(volume);
                                    }
                                  },
                          ),
                        ),
                        Text('$_audioVolume%'),
                      ],
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      onPressed: _isUploading ? null : _selectMusic,
                      icon: const Icon(Icons.library_music),
                      label: const Text('Browse Sounds'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Add trending music or original sounds to your video',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 25),

            // Upload button
            if (_selectedVideo != null || _selectedVideoWeb != null)
              ElevatedButton(
                onPressed: _isUploading ? null : _uploadVideo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: _isUploading
                    ? const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          ),
                          SizedBox(width: 15),
                          Text(
                            'Uploading...',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      )
                    : const Text(
                        'Upload Video',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
          ],
        ),
      ),
    );
  }
}
