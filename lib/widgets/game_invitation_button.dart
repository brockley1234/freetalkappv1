import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/app_config.dart';
import '../services/secure_storage_service.dart';

/// Game invitation button for quick game challenges from chat input
/// Shows available games and sends game invitations
class GameInvitationButton extends StatefulWidget {
  final String conversationId;
  final String recipientUserId;
  final Function()? onGameInvitationSent;

  const GameInvitationButton({
    super.key,
    required this.conversationId,
    required this.recipientUserId,
    this.onGameInvitationSent,
  });

  @override
  State<GameInvitationButton> createState() => _GameInvitationButtonState();
}

class _GameInvitationButtonState extends State<GameInvitationButton> {
  bool _isLoading = false;

  final List<Map<String, dynamic>> _availableGames = [
    {
      'type': 'tic-tac-toe',
      'title': '🎯 Tic-Tac-Toe',
      'description': 'Classic 3x3 game',
      'emoji': '⭕',
    },
    {
      'type': 'connect-4',
      'title': '🔴 Connect 4',
      'description': 'Drop pieces to connect 4',
      'emoji': '🔵',
    },
    {
      'type': 'quick-fire',
      'title': '⚡ Quick Fire',
      'description': 'Speed challenge game',
      'emoji': '💥',
    },
  ];

  Future<void> _sendGameInvitation(String gameType) async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final token = await SecureStorageService().getAccessToken();
      if (token == null) {
        debugPrint('❌ [GameInvitation] No access token found');
        _showError('Authentication failed');
        setState(() => _isLoading = false);
        return;
      }

      debugPrint(
          '🎮 [GameInvitation] Sending $gameType invitation to ${widget.recipientUserId}');

      final url = '${AppConfig.baseUrl}/game-challenges';
      final payload = {
        'conversationId': widget.conversationId,
        'opponentId': widget.recipientUserId,
        'gameType': gameType,
      };

      debugPrint('🎮 [GameInvitation] Payload: $payload');

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Request timed out'),
      );

      debugPrint('🎮 [GameInvitation] Response status: ${response.statusCode}');
      debugPrint('🎮 [GameInvitation] Response body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        if (jsonData['success'] == true) {
          debugPrint('✅ [GameInvitation] Game invitation sent successfully');
          if (mounted) {
            setState(() => _isLoading = false);
            widget.onGameInvitationSent?.call();

            // Show success message
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('🎮 Game invitation sent!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );

            // Close the modal
            Navigator.of(context).pop();
          }
        } else {
          _showError(jsonData['message'] ?? 'Failed to send invitation');
        }
      } else if (response.statusCode == 400) {
        final jsonData = jsonDecode(response.body);
        _showError(jsonData['message'] ?? 'Invalid request');
      } else if (response.statusCode >= 500) {
        _showError('Server error (${response.statusCode})');
      } else {
        _showError('Failed to send game invitation');
      }
    } catch (e, st) {
      debugPrint('❌ [GameInvitation] Exception: $e');
      debugPrint('❌ [GameInvitation] StackTrace: $st');
      _showError('Error: ${e.toString().split('\n').first}');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _showGameSelectionModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      builder: (context) {
        final screenWidth = MediaQuery.of(context).size.width;
        final screenHeight = MediaQuery.of(context).size.height;
        final isSmallScreen = screenWidth < 600;
        final padding = isSmallScreen ? 12.0 : 20.0;
        final buttonSpacing = isSmallScreen ? 8.0 : 12.0;
        final headerFontSize = isSmallScreen ? 18.0 : 24.0;
        final titleFontSize = isSmallScreen ? 14.0 : 16.0;
        final descriptionFontSize = isSmallScreen ? 11.0 : 12.0;
        final emojiFontSize = isSmallScreen ? 20.0 : 24.0;
        final horizontalPadding = isSmallScreen ? 12.0 : 16.0;
        final verticalPadding = isSmallScreen ? 10.0 : 12.0;
        
        return Container(
          padding: EdgeInsets.all(padding),
          constraints: BoxConstraints(
            maxHeight: screenHeight * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: EdgeInsets.only(bottom: padding),
                child: Text(
                  '🎮 Challenge to a Game',
                  style: TextStyle(
                    fontSize: headerFontSize,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Game options
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _availableGames.map((game) {
                      return Padding(
                        padding: EdgeInsets.only(bottom: buttonSpacing),
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : () async {
                            await _sendGameInvitation(game['type']);
                          },
                          style: ElevatedButton.styleFrom(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                              vertical: verticalPadding,
                            ),
                            backgroundColor: Colors.blue,
                            disabledBackgroundColor: Colors.grey,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                game['emoji'],
                                style: TextStyle(fontSize: emojiFontSize),
                              ),
                              SizedBox(width: horizontalPadding * 0.75),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      game['title'],
                                      style: TextStyle(
                                        fontSize: titleFontSize,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    SizedBox(height: verticalPadding * 0.3),
                                    Text(
                                      game['description'],
                                      style: TextStyle(
                                        fontSize: descriptionFontSize,
                                        color: Colors.white70,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_isLoading)
                                SizedBox(
                                  width: emojiFontSize,
                                  height: emojiFontSize,
                                  child: const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor:
                                        AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),

              // Close button
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Challenge to a game',
      child: IconButton(
        icon: const Icon(Icons.sports_esports),
        onPressed: _isLoading ? null : _showGameSelectionModal,
        tooltip: '🎮 Challenge to game',
      ),
    );
  }
}
