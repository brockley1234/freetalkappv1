import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';
import '../config/app_config.dart';
import '../utils/app_logger.dart';

class UserPhotosPage extends StatefulWidget {
  final String userId;
  final String userName;
  final bool isOwnProfile;

  const UserPhotosPage({
    super.key,
    required this.userId,
    required this.userName,
    this.isOwnProfile = false,
  });

  @override
  State<UserPhotosPage> createState() => _UserPhotosPageState();
}

class _UserPhotosPageState extends State<UserPhotosPage> {
  late List<dynamic> _photos = [];
  late bool _isLoading = true;
  late bool _isLoadingMore = false;
  late bool _hasMore = true;
  late int _currentPage = 1;
  final int _limit = 20;
  late bool _isUploading = false;
  String? _errorMessage;
  int _retryCount = 0;
  final int _maxRetries = 3;

  @override
  void initState() {
    super.initState();
    AppLogger.i('UserPhotosPage initialized for user: ${widget.userId}');
    _loadPhotos();
  }

  @override
  void dispose() {
    AppLogger.i('UserPhotosPage disposed');
    super.dispose();
  }

  Future<void> _loadPhotos({bool refresh = false}) async {
    if (refresh) {
      AppLogger.i('Refreshing photos');
      setState(() {
        _photos = [];
        _currentPage = 1;
        _hasMore = true;
        _isLoading = true;
        _errorMessage = null;
        _retryCount = 0;
      });
    } else {
      if (_isLoadingMore || !_hasMore) return;
      AppLogger.d('Loading more photos (page $_currentPage)');
      setState(() => _isLoadingMore = true);
    }

    try {
      final result = await ApiService.getUserPhotos(
        userId: widget.userId,
        page: _currentPage,
        limit: _limit,
      );

      if (result['success'] == true && result['data'] != null) {
        final List<dynamic> newPhotos = result['data']['photos'] ?? [];
        final pagination = result['data']['pagination'];

        AppLogger.i('Loaded ${newPhotos.length} photos (page $_currentPage)');

        if (!mounted) return;

        setState(() {
          if (refresh) {
            _photos = newPhotos;
          } else {
            _photos.addAll(newPhotos);
          }
          _currentPage++;
          _hasMore =
              pagination != null && pagination['page'] < pagination['pages'];
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = null;
          _retryCount = 0;
        });
      } else {
        final errorMsg =
            result['message'] ?? 'Failed to load photos. Please try again.';
        AppLogger.w('Photo load failed: $errorMsg');
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = errorMsg;
        });
      }
    } catch (e, stackTrace) {
      AppLogger.e('Error loading photos', error: e, st: stackTrace);

      if (!mounted) return;

      // Implement retry logic for network errors
      if (_retryCount < _maxRetries) {
        AppLogger.i('Retrying... (${_retryCount + 1}/$_maxRetries)');
        _retryCount++;
        await Future.delayed(const Duration(milliseconds: 500));
        _loadPhotos(refresh: refresh);
      } else {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
          _errorMessage = 'Network error. Please check your connection.';
        });
        _showErrorSnackbar(_errorMessage!);
      }
    }
  }

  Future<void> _uploadPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );

    if (image == null) {
      AppLogger.d('Photo upload cancelled by user');
      return;
    }
    if (!mounted) return;

    AppLogger.i('Photo selected: ${image.name}');

    // Show caption dialog
    String? caption;
    final shouldUpload = await showDialog<bool>(
      context: context,
      builder: (context) => _CaptionDialog(
        onSubmit: (text) {
          caption = text;
          Navigator.pop(context, true);
        },
      ),
    );

    if (shouldUpload != true) {
      AppLogger.d('Photo upload cancelled at caption stage');
      return;
    }
    if (!mounted) return;

    setState(() => _isUploading = true);

    try {
      AppLogger.i(
          'Uploading photo with caption: ${caption?.isNotEmpty ?? false}');

      final result = await ApiService.uploadPhoto(
        photoFile: image,
        caption: caption,
        visibility: 'followers',
      );

      if (!mounted) return;

      setState(() => _isUploading = false);

      if (result['success'] == true) {
        AppLogger.i('Photo uploaded successfully');
        _showSuccessSnackbar('Photo uploaded successfully!');
        // Refresh photos
        _loadPhotos(refresh: true);
      } else {
        final errorMsg =
            result['message'] ?? 'Failed to upload photo. Please try again.';
        AppLogger.w('Photo upload failed: $errorMsg');
        _showErrorSnackbar(errorMsg);
      }
    } catch (e, stackTrace) {
      AppLogger.e('Error uploading photo', error: e, st: stackTrace);

      if (!mounted) return;

      setState(() => _isUploading = false);
      _showErrorSnackbar('Error uploading photo. Please try again.');
    }
  }

  Future<void> _deletePhoto(String photoId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Photo'),
        content: const Text('Are you sure you want to delete this photo?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      AppLogger.d('Photo deletion cancelled');
      return;
    }
    if (!mounted) return;

    try {
      AppLogger.i('Deleting photo: $photoId');

      final result = await ApiService.deletePhoto(photoId);

      if (!mounted) return;

      if (result['success'] == true) {
        AppLogger.i('Photo deleted successfully');
        _showSuccessSnackbar('Photo deleted successfully');
        setState(() {
          _photos.removeWhere((photo) => photo['_id'] == photoId);
        });
      } else {
        final errorMsg =
            result['message'] ?? 'Failed to delete photo. Please try again.';
        AppLogger.w('Photo deletion failed: $errorMsg');
        _showErrorSnackbar(errorMsg);
      }
    } catch (e, stackTrace) {
      AppLogger.e('Error deleting photo', error: e, st: stackTrace);

      if (!mounted) return;
      _showErrorSnackbar('Error deleting photo. Please try again.');
    }
  }

  void _viewPhoto(Map<String, dynamic> photo) {
    if (!mounted) return;
    AppLogger.i('Viewing photo: ${photo['_id']}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _PhotoDetailPage(
          photo: photo,
          isOwnPhoto: widget.isOwnProfile,
          onDelete: () => _deletePhoto(photo['_id']),
        ),
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.userName}\'s Photos'),
        actions: [
          if (widget.isOwnProfile && !_isUploading)
            IconButton(
              icon: const Icon(Icons.add_photo_alternate),
              onPressed: _uploadPhoto,
              tooltip: 'Upload Photo',
            ),
          if (_isUploading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: widget.isOwnProfile && !_isUploading
          ? FloatingActionButton(
              onPressed: _uploadPhoto,
              tooltip: 'Upload Photo',
              child: const Icon(Icons.add_photo_alternate),
            )
          : null,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading photos...'),
          ],
        ),
      );
    }

    if (_errorMessage != null && _photos.isEmpty) {
      return _buildErrorState();
    }

    if (_photos.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () => _loadPhotos(refresh: true),
      child: NotificationListener<ScrollNotification>(
        onNotification: (ScrollNotification scrollInfo) {
          if (scrollInfo.metrics.pixels >=
              scrollInfo.metrics.maxScrollExtent - 200) {
            _loadPhotos();
          }
          return false;
        },
        child: GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemCount: _photos.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index >= _photos.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              );
            }

            final photo = _photos[index];
            return _buildPhotoTile(photo);
          },
        ),
      ),
    );
  }

  Widget _buildPhotoTile(Map<String, dynamic> photo) {
    final imageUrl = '${AppConfig.baseApi}${photo['imageUrl']}';

    return GestureDetector(
      onTap: () => _viewPhoto(photo),
      child: Hero(
        tag: 'photo_${photo['_id']}',
        child: Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              cacheWidth: 300,
              cacheHeight: 300,
              errorBuilder: (context, error, stackTrace) {
                AppLogger.d('Error loading photo: $error');
                return Container(
                  color: Colors.grey.shade300,
                  child: const Icon(
                    Icons.broken_image,
                    color: Colors.grey,
                    size: 40,
                  ),
                );
              },
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(
                  child: CircularProgressIndicator(
                    value: loadingProgress.expectedTotalBytes != null
                        ? loadingProgress.cumulativeBytesLoaded /
                            loadingProgress.expectedTotalBytes!
                        : null,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            'Failed to Load Photos',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _loadPhotos(refresh: true),
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 80,
            color: Colors.grey.shade300,
          ),
          const SizedBox(height: 16),
          Text(
            widget.isOwnProfile ? 'No photos yet' : 'No photos',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.isOwnProfile
                ? 'Upload your first photo!'
                : '${widget.userName} hasn\'t uploaded any photos',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
          ),
          if (widget.isOwnProfile) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _uploadPhoto,
              icon: const Icon(Icons.add_photo_alternate),
              label: const Text('Upload Photo'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CaptionDialog extends StatefulWidget {
  final Function(String) onSubmit;

  const _CaptionDialog({required this.onSubmit});

  @override
  State<_CaptionDialog> createState() => _CaptionDialogState();
}

class _CaptionDialogState extends State<_CaptionDialog> {
  late final TextEditingController _captionController = TextEditingController();

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Caption'),
      content: TextField(
        controller: _captionController,
        decoration: InputDecoration(
          hintText: 'Write a caption (optional)',
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          contentPadding: const EdgeInsets.all(12),
        ),
        maxLines: 3,
        maxLength: 500,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => widget.onSubmit(_captionController.text),
      ),
      actions: [
        TextButton(
          onPressed: () {
            AppLogger.d('Caption dialog cancelled');
            Navigator.pop(context, false);
          },
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            AppLogger.i(
                'Caption submitted: ${_captionController.text.length} chars');
            widget.onSubmit(_captionController.text);
          },
          child: const Text('Upload'),
        ),
      ],
    );
  }
}

class _PhotoDetailPage extends StatelessWidget {
  final Map<String, dynamic> photo;
  final bool isOwnPhoto;
  final VoidCallback onDelete;

  const _PhotoDetailPage({
    required this.photo,
    required this.isOwnPhoto,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final imageUrl = '${AppConfig.baseApi}${photo['imageUrl']}';
    final caption = photo['caption'] ?? '';
    final owner = photo['owner'] as Map<String, dynamic>;

    return Scaffold(
      appBar: AppBar(
        title: Text(owner['name'] ?? 'Photo'),
        actions: [
          if (isOwnPhoto)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                AppLogger.i('Delete button tapped for photo');
                onDelete();
                Navigator.pop(context);
              },
              tooltip: 'Delete Photo',
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _buildPhotoViewer(imageUrl),
          ),
          if (caption.isNotEmpty) _buildCaptionSection(owner, caption),
        ],
      ),
    );
  }

  Widget _buildPhotoViewer(String imageUrl) {
    return Center(
      child: Hero(
        tag: 'photo_${photo['_id']}',
        child: InteractiveViewer(
          panEnabled: true,
          scaleEnabled: true,
          minScale: 1.0,
          maxScale: 4.0,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            cacheWidth: 1920,
            cacheHeight: 1920,
            errorBuilder: (context, error, stackTrace) {
              AppLogger.e('Error loading photo detail', error: error);
              return const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.broken_image, size: 80, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('Failed to load image'),
                  ],
                ),
              );
            },
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildCaptionSection(Map<String, dynamic> owner, String caption) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildOwnerInfo(owner),
            const SizedBox(height: 8),
            Text(
              caption,
              style: const TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerInfo(Map<String, dynamic> owner) {
    final ownerName = owner['name'] ?? 'Unknown User';
    final ownerAvatar = owner['avatar'] as String?;

    return Row(
      children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: Colors.grey.shade200,
          backgroundImage: ownerAvatar != null && ownerAvatar.isNotEmpty
              ? NetworkImage(
                  '${AppConfig.baseApi}$ownerAvatar',
                )
              : null,
          child: ownerAvatar == null || ownerAvatar.isEmpty
              ? Text(
                  ownerName.isNotEmpty ? ownerName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 16),
                )
              : null,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            ownerName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
