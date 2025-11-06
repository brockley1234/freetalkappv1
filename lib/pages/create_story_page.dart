import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/api_service.dart';

class CreateStoryPage extends StatefulWidget {
  const CreateStoryPage({super.key});

  @override
  State<CreateStoryPage> createState() => _CreateStoryPageState();
}

class _CreateStoryPageState extends State<CreateStoryPage> {
  XFile? _selectedMedia;
  String _mediaType = ''; // 'image', 'video', or 'text'
  final TextEditingController _captionController = TextEditingController();
  final TextEditingController _textContentController = TextEditingController();
  Color _backgroundColor = Colors.black;
  bool _isUploading = false;
  int _selectedFontStyle = 0;
  final List<TextStyle> _fontStyles = [
    const TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.bold,
      fontFamily: 'Roboto',
    ),
    const TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w900,
      fontFamily: 'Roboto',
      letterSpacing: 2,
    ),
    const TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w300,
      fontFamily: 'Roboto',
      fontStyle: FontStyle.italic,
    ),
    const TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w500,
      fontFamily: 'Roboto',
      height: 1.5,
    ),
  ];

  @override
  void dispose() {
    _captionController.dispose();
    _textContentController.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(ImageSource source) async {
    try {
      // Always use gallery selection - camera filters removed
      final ImagePicker picker = ImagePicker();

      final String? mediaType = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Choose Media Type'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.image),
                  title: const Text('Image'),
                  onTap: () => Navigator.pop(context, 'image'),
                ),
                ListTile(
                  leading: const Icon(Icons.video_library),
                  title: const Text('Video'),
                  onTap: () => Navigator.pop(context, 'video'),
                ),
              ],
            ),
          );
        },
      );

      if (mediaType == null) return;
      if (!mounted) return;

      XFile? media;
      if (mediaType == 'image') {
        media = await picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1080,
          maxHeight: 1920,
          imageQuality: 85,
        );
      } else {
        media = await picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(seconds: 30),
        );
      }

      if (media != null) {
        setState(() {
          _selectedMedia = media;
          _mediaType = mediaType;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting media: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showPreviewDialog() async {
    return showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
            maxWidth: MediaQuery.of(context).size.width * 0.9,
          ),
          decoration: BoxDecoration(
            color: _mediaType == 'text' ? _backgroundColor : Colors.black,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Preview content
              Expanded(
                child: _mediaType == 'text'
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _textContentController.text,
                            textAlign: TextAlign.center,
                            style: _fontStyles[_selectedFontStyle].copyWith(
                              color: _backgroundColor.computeLuminance() > 0.5
                                  ? Colors.black
                                  : Colors.white,
                            ),
                          ),
                        ),
                      )
                    : _mediaType == 'image'
                        ? kIsWeb
                            ? Image.network(
                                _selectedMedia!.path,
                                fit: BoxFit.contain,
                              )
                            : Image.file(
                                File(_selectedMedia!.path),
                                fit: BoxFit.contain,
                              )
                        : const Center(
                            child: Icon(
                              Icons.play_circle_outline,
                              size: 64,
                              color: Colors.white,
                            ),
                          ),
              ),
              // Action buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white),
                        ),
                        child: const Text('Edit'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _createStory();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                        ),
                        child: const Text('Post'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createStory() async {
    // Validate based on story type
    if (_mediaType == 'text') {
      if (_textContentController.text.trim().isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter some text for your story'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
    } else if (_selectedMedia == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an image or video'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final result = await ApiService.createStory(
        mediaFile: _selectedMedia,
        caption: _captionController.text.trim(),
        backgroundColor:
            '#${_backgroundColor.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}',
        textContent: _textContentController.text.trim(),
        mediaType: _mediaType,
      );

      if (!mounted) return;
      setState(() => _isUploading = false);

      if (result['success'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Story created successfully!'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.pop(context, true); // Return true to indicate success
      } else {
        if (!mounted) return;
        
        // Parse error message for better UX
        String errorMessage = result['message'] ?? 'Failed to create story';
        String errorTitle = 'Story Creation Failed';
        IconData errorIcon = Icons.error_outline;
        
        // Provide specific error guidance based on error type
        if (errorMessage.contains('file') || errorMessage.contains('size') || errorMessage.contains('100')) {
          errorTitle = '📁 File Upload Error';
          errorMessage = 'File is too large. Maximum size is 100MB.';
          errorIcon = Icons.storage;
        } else if (errorMessage.contains('network') || errorMessage.contains('connection')) {
          errorTitle = '🌐 Network Error';
          errorMessage = 'Check your internet connection and try again.';
          errorIcon = Icons.cloud_off;
        } else if (errorMessage.contains('content') || errorMessage.contains('text') || errorMessage.contains('5000')) {
          errorTitle = '📝 Content Error';
          errorMessage = 'Text content must be under 5000 characters.';
          errorIcon = Icons.text_fields;
        } else if (errorMessage.contains('caption') || errorMessage.contains('500')) {
          errorTitle = '💬 Caption Error';
          errorMessage = 'Caption must be under 500 characters.';
          errorIcon = Icons.short_text;
        }
        
        // Show detailed error dialog
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            icon: Icon(errorIcon, color: Colors.red, size: 32),
            title: Text(errorTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(errorMessage),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Text(
                    'Error details: $errorMessage',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.orange.shade700,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isUploading = false);

      String errorMessage = e.toString();
      String errorTitle = '❌ Error Creating Story';
      IconData errorIcon = Icons.warning_amber;
      
      // Parse specific error types
      if (errorMessage.contains('No authentication token')) {
        errorTitle = '🔐 Authentication Error';
        errorMessage = 'You have been logged out. Please log in again.';
        errorIcon = Icons.lock;
      } else if (errorMessage.contains('Network')) {
        errorTitle = '🌐 Network Error';
        errorMessage = 'Unable to connect to the server. Check your internet connection.';
        errorIcon = Icons.cloud_off;
      } else if (errorMessage.contains('timeout')) {
        errorTitle = '⏱️ Request Timeout';
        errorMessage = 'The upload took too long. Please try again with a smaller file.';
        errorIcon = Icons.hourglass_empty;
      }
      
      // Show error dialog with actionable message
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(errorIcon, color: Colors.red, size: 32),
          title: Text(errorTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(errorMessage),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  'Technical: ${e.toString()}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red.shade700,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Dismiss'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Story'),
        actions: [
          if ((_selectedMedia != null || _mediaType == 'text') && !_isUploading)
            TextButton.icon(
              onPressed: _showPreviewDialog,
              icon: const Icon(Icons.visibility, color: Colors.blue),
              label: const Text(
                'Preview',
                style: TextStyle(
                  color: Colors.blue,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
        ],
      ),
      body: _selectedMedia == null && _mediaType != 'text'
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.add_photo_alternate,
                    size: 100,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Create a story',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _pickMedia(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Gallery'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      ElevatedButton.icon(
                        onPressed: () => _pickMedia(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Camera'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'or',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _mediaType = 'text';
                      });
                    },
                    icon: const Icon(Icons.text_fields),
                    label: const Text('Create Text Story'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      backgroundColor: Colors.purple,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Templates',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 120,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _buildTemplateCard(
                          'Good Morning ☀️',
                          Colors.orange,
                          Colors.white,
                        ),
                        _buildTemplateCard(
                          'Good Night 🌙',
                          Colors.indigo.shade900,
                          Colors.white,
                        ),
                        _buildTemplateCard(
                          'Feeling Blessed ✨',
                          Colors.purple,
                          Colors.white,
                        ),
                        _buildTemplateCard(
                          'New Goals 🎯',
                          Colors.teal,
                          Colors.white,
                        ),
                        _buildTemplateCard(
                          'Weekend Vibes 🎉',
                          Colors.pink,
                          Colors.white,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          : _isUploading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      ),
                      const SizedBox(height: 24),
                      const Text(
                        'Creating your story...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please wait while we upload your file',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Colors.blue.shade700,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Max file size: 100MB',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )
              : _mediaType == 'text'
                  ? _buildTextStoryEditor()
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Preview
                          Container(
                            height: 400,
                            color: _backgroundColor,
                            child: Center(
                              child: _mediaType == 'image'
                                  ? kIsWeb
                                      ? Image.network(
                                          _selectedMedia!.path,
                                          fit: BoxFit.contain,
                                        )
                                      : Image.file(
                                          File(_selectedMedia!.path),
                                          fit: BoxFit.contain,
                                        )
                                  : Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        kIsWeb
                                            ? Image.network(
                                                _selectedMedia!.path,
                                                fit: BoxFit.contain,
                                              )
                                            : Image.file(
                                                File(_selectedMedia!.path),
                                                fit: BoxFit.contain,
                                              ),
                                        const Icon(
                                          Icons.play_circle_outline,
                                          size: 64,
                                          color: Colors.white,
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          // Caption
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: TextField(
                              controller: _captionController,
                              decoration: const InputDecoration(
                                hintText: 'Add a caption...',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.text_fields),
                              ),
                              maxLength: 200,
                              maxLines: 3,
                            ),
                          ),

                          // Background color picker (for images only)
                          if (_mediaType == 'image')
                            Padding(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Background Color',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 12,
                                    children: [
                                      Colors.black,
                                      Colors.white,
                                      Colors.blue,
                                      Colors.purple,
                                      Colors.pink,
                                      Colors.red,
                                      Colors.orange,
                                      Colors.green,
                                    ].map((color) {
                                      return GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _backgroundColor = color;
                                          });
                                        },
                                        child: Container(
                                          width: 50,
                                          height: 50,
                                          decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: _backgroundColor == color
                                                  ? Colors.blue
                                                  : Colors.grey.shade300,
                                              width: _backgroundColor == color
                                                  ? 3
                                                  : 1,
                                            ),
                                          ),
                                          child: _backgroundColor == color
                                              ? const Icon(
                                                  Icons.check,
                                                  color: Colors.white,
                                                )
                                              : null,
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),

                          const SizedBox(height: 24),

                          // Change media button
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _selectedMedia = null;
                                  _mediaType = '';
                                });
                              },
                              icon: const Icon(Icons.refresh),
                              label: const Text('Change Media'),
                            ),
                          ),

                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildTemplateCard(String text, Color bgColor, Color textColor) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _mediaType = 'text';
          _backgroundColor = bgColor;
          _textContentController.text = text;
        });
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: textColor,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextStoryEditor() {
    final textColor =
        _backgroundColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;

    return Container(
      color: _backgroundColor,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: TextField(
                  controller: _textContentController,
                  maxLength: 500,
                  maxLines: null,
                  textAlign: TextAlign.center,
                  style: _fontStyles[_selectedFontStyle].copyWith(
                    color: textColor,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Type your story...',
                    hintStyle: TextStyle(
                      color: textColor.withValues(alpha: 0.5),
                    ),
                    border: InputBorder.none,
                  ),
                ),
              ),
            ),
          ),
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Font style selector
                const Text(
                  'Font Style',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(_fontStyles.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(
                            'Aa',
                            style: _fontStyles[index].copyWith(fontSize: 18),
                          ),
                          selected: _selectedFontStyle == index,
                          onSelected: (selected) {
                            setState(() {
                              _selectedFontStyle = index;
                            });
                          },
                        ),
                      );
                    }),
                  ),
                ),
                const SizedBox(height: 16),
                // Background color picker
                const Text(
                  'Background Color',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      Colors.black,
                      Colors.grey.shade800,
                      Colors.white,
                      Colors.blue,
                      Colors.purple,
                      Colors.pink,
                      Colors.red,
                      Colors.orange,
                      Colors.amber,
                      Colors.green,
                      Colors.teal,
                      Colors.indigo,
                    ].map((color) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _backgroundColor = color;
                            });
                          },
                          child: Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _backgroundColor == color
                                    ? Colors.blue
                                    : Colors.grey.shade300,
                                width: _backgroundColor == color ? 3 : 1,
                              ),
                            ),
                            child: _backgroundColor == color
                                ? Icon(
                                    Icons.check,
                                    color: color.computeLuminance() > 0.5
                                        ? Colors.black
                                        : Colors.white,
                                  )
                                : null,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                // Caption
                TextField(
                  controller: _captionController,
                  decoration: const InputDecoration(
                    hintText: 'Add a caption (optional)...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.text_fields),
                  ),
                  maxLength: 200,
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                // Cancel button
                OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      _mediaType = '';
                      _textContentController.clear();
                    });
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
