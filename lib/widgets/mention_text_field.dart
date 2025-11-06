import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../utils/url_utils.dart';

class MentionTextField extends StatefulWidget {
  final TextEditingController controller;
  final String? hintText;
  final int? maxLines;
  final int? maxLength;
  final bool enabled;
  final Function(List<Map<String, dynamic>>)? onMentionsChanged;

  const MentionTextField({
    super.key,
    required this.controller,
    this.hintText,
    this.maxLines,
    this.maxLength,
    this.enabled = true,
    this.onMentionsChanged,
  });

  @override
  State<MentionTextField> createState() => _MentionTextFieldState();
}

class _MentionTextFieldState extends State<MentionTextField> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry; // no longer used; kept to minimize risk
  List<Map<String, dynamic>> _suggestions = [];
  int _mentionStart = -1;
  Timer? _debounceTimer;
  final List<Map<String, dynamic>> _mentionedUsers = [];
  String? _lastErrorMessage;
  bool _showInlineSuggestions = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _debounceTimer?.cancel();
    _removeOverlay(shouldNotify: false);
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final cursorPos = widget.controller.selection.baseOffset;

    // Find if we're in a mention context (after '@')
    if (cursorPos > 0 && cursorPos <= text.length) {
      // Look backwards from cursor to find '@'
      int atPos = -1;
      for (int i = cursorPos - 1; i >= 0; i--) {
        if (text[i] == '@') {
          // Check if there's a space or newline before @ (or it's at start)
          if (i == 0 || text[i - 1] == ' ' || text[i - 1] == '\n') {
            atPos = i;
            break;
          }
        } else if (text[i] == ' ' || text[i] == '\n') {
          // We hit a space before finding @, so we're not in a mention
          break;
        }
      }

      if (atPos != -1) {
        // We're in a mention context
        final query = text.substring(atPos + 1, cursorPos);

        // Only search if query doesn't contain spaces or special chars
        if (!query.contains(' ') && !query.contains('\n')) {
          _mentionStart = atPos;

          if (query.isEmpty) {
            // Just typed '@', show all followers
            _searchMentions('');
          } else if (query.isNotEmpty) {
            // Debounce search
            _debounceTimer?.cancel();
            _debounceTimer = Timer(const Duration(milliseconds: 300), () {
              _searchMentions(query);
            });
          }
          return;
        }
      }
    }

    // Not in a mention context, hide overlay
    _removeOverlay();
  }

  Future<void> _searchMentions(String query) async {
    if (!mounted) return;

    debugPrint('🔍 Searching mentions with query: "$query"');
    
    try {
      // Send empty query to get all followers when just typed '@'
      final result = await ApiService.searchForMention(query);
      
      debugPrint('🔍 Mention search result: ${result['success']}');
      debugPrint('🔍 Result data: ${result['data']}');
      if (result['message'] != null) {
        debugPrint('🔍 Message: ${result['message']}');
      }

      if (mounted && result['success'] == true) {
        final users = List<Map<String, dynamic>>.from(
          result['data']['users'] ?? [],
        );

        debugPrint('🔍 Found ${users.length} users');

        setState(() {
          _suggestions = users;
          _lastErrorMessage = null;
          _showInlineSuggestions = true;
        });
        debugPrint('🔍 Showing inline suggestions with ${users.length} users');
      } else {
        debugPrint('🔍 API call failed or returned error');
        if (mounted) {
          setState(() {
            _suggestions = [];
            _lastErrorMessage = (result['message'] as String?) ?? 'Unable to load mention suggestions.';
            _showInlineSuggestions = true;
          });
        }
      }
    } catch (e) {
      debugPrint('🔍 Error searching mentions: $e');
      // Show empty state instead of hiding
      if (mounted) {
        setState(() {
          _suggestions = [];
          _lastErrorMessage = 'Unable to load mention suggestions. Check your connection and login status.';
          _showInlineSuggestions = true;
        });
      }
    }
  }

  

  void _insertMention(Map<String, dynamic> user) {
    final text = widget.controller.text;
    final userName = user['name'] ?? 'Unknown';

    // Replace from @ to current cursor with @username
    final beforeMention = text.substring(0, _mentionStart);
    final afterMention = text.substring(widget.controller.selection.baseOffset);
    final newText = '$beforeMention@$userName $afterMention';

    widget.controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(
        offset: (beforeMention.length + userName.length + 2).toInt(),
      ),
    );

    // Add to mentioned users list
    if (!_mentionedUsers.any((u) => u['_id'] == user['_id'])) {
      _mentionedUsers.add(user);
      widget.onMentionsChanged?.call(_mentionedUsers);
    }

    _removeOverlay();
  }

  void _removeOverlay({bool shouldNotify = true}) {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (shouldNotify && mounted) {
      setState(() {
        _suggestions = [];
        _mentionStart = -1;
        _showInlineSuggestions = false;
      });
    } else {
      // If not mounted, just clear the data without setState
      _suggestions = [];
      _mentionStart = -1;
      _showInlineSuggestions = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(
      link: _layerLink,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: widget.controller,
            maxLines: widget.maxLines,
            maxLength: widget.maxLength,
            enabled: widget.enabled,
            decoration: InputDecoration(
              hintText: widget.hintText,
              border: InputBorder.none,
              counterText: '',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 16),
            ),
            style: const TextStyle(fontSize: 16),
          ),
          if (_showInlineSuggestions)
            Container(
              margin: const EdgeInsets.only(top: 8),
              constraints: const BoxConstraints(
                maxHeight: 200,
                minHeight: 50,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade400, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: _suggestions.isEmpty
                  ? Container(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        _lastErrorMessage ?? queryHintText(),
                        style: const TextStyle(color: Colors.grey),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      itemCount: _suggestions.length,
                      itemBuilder: (context, index) {
                        final user = _suggestions[index];
                        return InkWell(
                          onTap: () => _insertMention(user),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  backgroundColor: Colors.blue.shade100,
                                  backgroundImage: user['avatar'] != null
                                      ? NetworkImage(
                                          UrlUtils.getFullAvatarUrl(user['avatar']),
                                        )
                                      : null,
                                  child: user['avatar'] == null
                                      ? Text(
                                          (user['name'] ?? 'U')[0].toUpperCase(),
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue.shade700,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        user['name'] ?? 'Unknown',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 16,
                                          color: Colors.black87,
                                        ),
                                      ),
                                      if (user['email'] != null)
                                        Text(
                                          '@${user['email']?.split('@')[0] ?? ''}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.person_add,
                                  color: Colors.grey,
                                  size: 20,
                                ),
                              ],
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

  String queryHintText() {
    // Provide a clearer hint when no suggestions are available
    // Users can mention connections (followers or following)
    return 'No matches. You can mention people you follow or who follow you.';
  }
}
