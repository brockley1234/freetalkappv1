import 'package:flutter/material.dart';
import 'dart:async';
import '../services/api_service.dart';
import '../utils/url_utils.dart';

class MentionCommentInput extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final Function(String content, List<Map<String, dynamic>> mentionedUsers, String? gifUrl)
      onSubmit;
  final bool isSubmitting;
  final VoidCallback? onMentionDismissed;

  const MentionCommentInput({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmit,
    required this.isSubmitting,
    this.onMentionDismissed,
  });

  @override
  State<MentionCommentInput> createState() => _MentionCommentInputState();
}

class _MentionCommentInputState extends State<MentionCommentInput> {
  List<Map<String, dynamic>> _mentionSuggestions = [];
  bool _showMentions = false;
  int _atSymbolPosition = -1;
  Timer? _debounceTimer;
  List<Map<String, dynamic>> _mentionedUsers = [];
  late LayerLink _layerLink;
  OverlayEntry? _overlayEntry;
  String? _selectedGifUrl;

  @override
  void initState() {
    super.initState();
    _layerLink = LayerLink();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _debounceTimer?.cancel();
    _overlayEntry?.remove();
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;

    // Find if there's an @ symbol before the cursor
    int atPos = -1;
    for (int i = cursorPos - 1; i >= 0; i--) {
      if (text[i] == '@') {
        atPos = i;
        break;
      } else if (text[i] == ' ' || text[i] == '\n') {
        // Stop searching if we hit a space or newline before @
        break;
      }
    }

    if (atPos != -1 && cursorPos > atPos) {
      // We're in the middle of typing a mention
      final query = text.substring(atPos + 1, cursorPos).trim();

      // Only search if query is not empty and contains valid characters
      if (query.isNotEmpty &&
          query.length <= 50 &&
          !query.contains(' ') &&
          !query.contains('\n')) {
        _atSymbolPosition = atPos;
        _showMentionSuggestions(query);
      } else {
        _hideMentionSuggestions();
      }
    } else {
      _hideMentionSuggestions();
    }
  }

  void _showMentionSuggestions(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _searchUsers(query);
    });
  }

  void _hideMentionSuggestions() {
    _debounceTimer?.cancel();
    if (mounted) {
      setState(() {
        _showMentions = false;
        _mentionSuggestions = [];
      });
    }
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  Future<void> _searchUsers(String query) async {
    try {
      final result = await ApiService.searchUsers(query: query);
      if (result['success'] == true && mounted) {
        final users = List<Map<String, dynamic>>.from(
          result['data']['users'] ?? [],
        );

        setState(() {
          _mentionSuggestions = users;
          _showMentions = users.isNotEmpty;
        });

        if (_showMentions) {
          _showOverlay();
        } else {
          _overlayEntry?.remove();
          _overlayEntry = null;
        }
      }
    } catch (e) {
      debugPrint('Error searching users: $e');
      _hideMentionSuggestions();
    }
  }

  void _showOverlay() {
    _overlayEntry?.remove();

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        width: MediaQuery.of(context).size.width - 32,
        child: CompositedTransformFollower(
          link: _layerLink,
          showWhenUnlinked: false,
          offset: const Offset(0, 50),
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _mentionSuggestions.length,
                padding: EdgeInsets.zero,
                itemBuilder: (context, index) {
                  final user = _mentionSuggestions[index];
                  final isAlreadyMentioned = _mentionedUsers
                      .any((u) => u['_id'] == user['_id']);

                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundImage: user['avatar'] != null
                          ? UrlUtils.getAvatarImageProvider(user['avatar'])
                          : null,
                      child: user['avatar'] == null
                          ? Text(
                              (user['name'] ?? 'U')[0].toUpperCase(),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            )
                          : null,
                    ),
                    title: Text(
                      user['name'] ?? 'Unknown',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                    trailing: isAlreadyMentioned
                        ? const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 20,
                          )
                        : null,
                    onTap: isAlreadyMentioned
                        ? null
                        : () => _selectUser(user),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
  }

  void _selectUser(Map<String, dynamic> user) {
    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;

    // Replace the mention text with the selected user
    final mentionText = '@${user['name']}';
    final beforeMention = text.substring(0, _atSymbolPosition);
    final afterMention = text.substring(cursorPos);

    final newText = '$beforeMention$mentionText $afterMention';

    widget.controller.text = newText;
    widget.controller.selection = TextSelection.fromPosition(
      TextPosition(offset: beforeMention.length + mentionText.length + 1),
    );

    // Add user to mentioned list if not already there
    if (!_mentionedUsers.any((u) => u['_id'] == user['_id'])) {
      setState(() {
        _mentionedUsers.add(user);
      });
    }

    _hideMentionSuggestions();
  }

  Future<void> _pickGif() async {
    try {
      // Use GiphyGet to pick a GIF
      // Note: GiphyGet requires an API key, but we'll use our backend proxy
      // We'll create a custom GIF picker using our backend API
      final gif = await _showGifPicker();
      if (gif != null && mounted) {
        setState(() {
          _selectedGifUrl = gif;
        });
      }
    } catch (e) {
      debugPrint('Error picking GIF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load GIFs: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<String?> _showGifPicker() async {
    return await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _GifPickerBottomSheet(
        onGifSelected: (gifUrl) {
          Navigator.pop(context, gifUrl);
        },
      ),
    );
  }

  void _submitComment() {
    final content = widget.controller.text.trim();
    if (content.isNotEmpty || _selectedGifUrl != null) {
      widget.onSubmit(content, _mentionedUsers, _selectedGifUrl);
      // Clear mentioned users and GIF for next comment
      setState(() {
        _mentionedUsers = [];
        _selectedGifUrl = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Show mentioned users as chips if any
          if (_mentionedUsers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: _mentionedUsers.map((user) {
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundImage: user['avatar'] != null
                          ? UrlUtils.getAvatarImageProvider(user['avatar'])
                          : null,
                      child: user['avatar'] == null
                          ? Text(
                              (user['name'] ?? 'U')[0].toUpperCase(),
                              style: const TextStyle(fontSize: 10),
                            )
                          : null,
                    ),
                    label: Text(
                      user['name'] ?? 'Unknown',
                      style: const TextStyle(fontSize: 12),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () {
                      setState(() {
                        _mentionedUsers.removeWhere(
                          (u) => u['_id'] == user['_id'],
                        );
                      });
                    },
                    backgroundColor: Colors.blue.shade50,
                    deleteIconColor: Colors.blue.shade700,
                    labelStyle: TextStyle(
                      color: Colors.blue.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  );
                }).toList(),
              ),
            ),
          // Show selected GIF preview if any
          if (_selectedGifUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      _selectedGifUrl!,
                      width: 150,
                      height: 150,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 150,
                          height: 150,
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.error, color: Colors.red),
                        );
                      },
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedGifUrl = null;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.black54,
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
            ),
          // Comment input field
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              IconButton(
                onPressed: widget.isSubmitting ? null : _pickGif,
                icon: Icon(
                  Icons.gif_box_outlined,
                  color: _selectedGifUrl != null ? Colors.blue : Colors.grey.shade600,
                ),
                tooltip: 'Add GIF',
              ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: widget.focusNode,
                  maxLines: null,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Write a comment... (type @ to mention)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(24),
                      borderSide: const BorderSide(color: Colors.blue),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  enabled: !widget.isSubmitting,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: widget.isSubmitting ? null : _submitComment,
                icon: widget.isSubmitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
                color: Colors.blue,
                disabledColor: Colors.grey,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// GIF Picker Bottom Sheet Widget
class _GifPickerBottomSheet extends StatefulWidget {
  final Function(String gifUrl) onGifSelected;

  const _GifPickerBottomSheet({required this.onGifSelected});

  @override
  State<_GifPickerBottomSheet> createState() => _GifPickerBottomSheetState();
}

class _GifPickerBottomSheetState extends State<_GifPickerBottomSheet> {
  final TextEditingController _searchController = TextEditingController();
  List<dynamic> _gifs = [];
  bool _isLoading = false;
  bool _isSearching = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadTrendingGifs();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      final query = _searchController.text.trim();
      if (query.isEmpty) {
        _loadTrendingGifs();
      } else {
        _searchGifs(query);
      }
    });
  }

  Future<void> _loadTrendingGifs() async {
    setState(() {
      _isLoading = true;
      _isSearching = false;
    });

    try {
      final result = await ApiService.getTrendingGifs(limit: 25);
      debugPrint('📊 Trending GIFs response: ${result.toString()}');
      if (result['success'] == true && mounted) {
        final gifsList = result['data']?['gifs'] ?? [];
        debugPrint('📊 Found ${gifsList.length} GIFs');
        setState(() {
          _gifs = gifsList;
          _isLoading = false;
        });
      } else {
        debugPrint('❌ Failed to load trending GIFs: ${result['message'] ?? 'Unknown error'}');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load GIFs: ${result['message'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading trending GIFs: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading GIFs: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _searchGifs(String query) async {
    setState(() {
      _isLoading = true;
      _isSearching = true;
    });

    try {
      final result = await ApiService.searchGifs(query: query, limit: 25);
      debugPrint('📊 Search GIFs response: ${result.toString()}');
      if (result['success'] == true && mounted) {
        final gifsList = result['data']?['gifs'] ?? [];
        debugPrint('📊 Found ${gifsList.length} GIFs for query: $query');
        setState(() {
          _gifs = gifsList;
          _isLoading = false;
        });
      } else {
        debugPrint('❌ Failed to search GIFs: ${result['message'] ?? 'Unknown error'}');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to search GIFs: ${result['message'] ?? 'Unknown error'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error searching GIFs: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching GIFs: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getGifUrl(dynamic gif) {
    // Try to get the best quality GIF URL
    if (gif['images'] != null) {
      final images = gif['images'];
      // Prefer downsized (smaller file size, better for comments), then original, then fixed_height
      if (images['downsized'] != null && images['downsized']['url'] != null) {
        String url = images['downsized']['url'].toString();
        // Convert .webp to .gif if needed for better compatibility
        url = url.replaceAll('.webp', '.gif');
        return url;
      }
      if (images['original'] != null && images['original']['url'] != null) {
        String url = images['original']['url'].toString();
        url = url.replaceAll('.webp', '.gif');
        return url;
      }
      if (images['fixed_height'] != null && images['fixed_height']['url'] != null) {
        String url = images['fixed_height']['url'].toString();
        url = url.replaceAll('.webp', '.gif');
        return url;
      }
    }
    // Fallback: try direct URL field
    if (gif['url'] != null) {
      return gif['url'].toString().replaceAll('.webp', '.gif');
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Text(
                  'Select a GIF',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search GIFs...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // GIF grid
          Expanded(
            child: _isLoading && _gifs.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _gifs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.gif_box_outlined,
                              size: 64,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _isSearching
                                  ? 'No GIFs found'
                                  : 'No trending GIFs available',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                          childAspectRatio: 1.0,
                        ),
                        itemCount: _gifs.length,
                        itemBuilder: (context, index) {
                          final gif = _gifs[index];
                          final gifUrl = _getGifUrl(gif);
                          if (gifUrl.isEmpty) return const SizedBox.shrink();

                          return GestureDetector(
                            onTap: () {
                              widget.onGifSelected(gifUrl);
                            },
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                gifUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey.shade200,
                                    child: const Icon(Icons.error),
                                  );
                                },
                              ),
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
