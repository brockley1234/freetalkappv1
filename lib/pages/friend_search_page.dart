import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import '../services/secure_storage_service.dart';
import '../config/app_config.dart';
import '../utils/url_utils.dart';
import '../utils/app_logger.dart';
import '../utils/avatar_utils.dart';

class FriendSearchPage extends StatefulWidget {
  const FriendSearchPage({super.key});

  @override
  State<FriendSearchPage> createState() => _FriendSearchPageState();
}

class _FriendSearchPageState extends State<FriendSearchPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    // Cancel previous timer
    _debounceTimer?.cancel();

    final query = _searchController.text.trim();

    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
      });
      return;
    }

    // Debounce the search by 300ms
    _debounceTimer = Timer(const Duration(milliseconds: 300), () {
      _performSearch(query);
    });
  }

  Future<void> _performSearch(String query) async {
    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final token = await SecureStorageService().getAccessToken();

      final response = await http.get(
        Uri.parse(
          '${AppConfig.baseUrl}/user/search-followers?q=$query&limit=20',
        ),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        AppLogger().debug('🔍 Search response: $jsonData');
        AppLogger().debug('📊 Data field: ${jsonData['data']}');
        
        final users =
            (jsonData['data'] as List?)?.cast<Map<String, dynamic>>() ?? [];

        if (mounted) {
          setState(() {
            _searchResults = users;
            _isSearching = false;
          });
          AppLogger().info('✅ Found ${users.length} followers matching "$query"');
          if (users.isNotEmpty) {
            AppLogger().debug('👤 First user: ${users[0]}');
            AppLogger().debug('🖼️  Avatar: ${users[0]['avatar']}');
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _searchResults = [];
            _isSearching = false;
          });
        }
        AppLogger().error('Search failed: ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchResults = [];
          _isSearching = false;
        });
      }
      AppLogger().error('Search error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get responsive screen dimensions
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    // Calculate responsive sizing based on screen width
    final searchBarPadding = (screenWidth * 0.04).clamp(12.0, 24.0);
    final searchBorderRadius = (screenWidth * 0.06).clamp(20.0, 32.0);
    final hintFontSize = (screenWidth * 0.035).clamp(13.0, 16.0);
    final appBarTitleSize = (screenWidth * 0.05).clamp(16.0, 22.0);
    final appBarIconSize = (screenWidth * 0.06).clamp(20.0, 28.0);
    final contentPaddingH = (screenWidth * 0.05).clamp(16.0, 24.0);
    final contentPaddingV = (screenHeight * 0.015).clamp(12.0, 16.0);
    final prefixIconSize = (screenWidth * 0.05).clamp(18.0, 24.0);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.blue.shade400,
        title: Text(
          'Start Conversation',
          style: TextStyle(
            color: Colors.white,
            fontSize: appBarTitleSize,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: Colors.white,
            size: appBarIconSize,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search bar with responsive sizing
          Container(
            color: Colors.blue.shade400,
            padding: EdgeInsets.all(searchBarPadding),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search friends...',
                hintStyle: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: hintFontSize,
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: Colors.grey.shade600,
                  size: prefixIconSize,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(
                          Icons.clear,
                          size: (screenWidth * 0.04).clamp(16.0, 22.0),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchResults = [];
                            _hasSearched = false;
                          });
                        },
                      )
                    : null,
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(searchBorderRadius),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: contentPaddingH,
                  vertical: contentPaddingV,
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          // Results with responsive sizing
          Expanded(
            child: _isSearching
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: (screenWidth * 0.12).clamp(40.0, 50.0),
                          height: (screenWidth * 0.12).clamp(40.0, 50.0),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.5,
                          ),
                        ),
                        SizedBox(height: (screenHeight * 0.02).clamp(12.0, 20.0)),
                        Text(
                          'Searching...',
                          style: TextStyle(
                            fontSize: (screenWidth * 0.035).clamp(13.0, 16.0),
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  )
                : _searchResults.isEmpty && _hasSearched
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.person_search_outlined,
                              size: (screenWidth * 0.18).clamp(56.0, 72.0),
                              color: Colors.grey.shade300,
                            ),
                            SizedBox(height: (screenHeight * 0.02).clamp(12.0, 20.0)),
                            Text(
                              'No friends found',
                              style: TextStyle(
                                fontSize: (screenWidth * 0.04).clamp(16.0, 18.0),
                                fontWeight: FontWeight.w500,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(height: (screenHeight * 0.01).clamp(8.0, 12.0)),
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: (screenWidth * 0.08).clamp(16.0, 32.0),
                              ),
                              child: Text(
                                'Try searching for friends who follow you',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: (screenWidth * 0.032).clamp(13.0, 14.0),
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _searchResults.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.chat_bubble_outline,
                                  size: (screenWidth * 0.18).clamp(56.0, 72.0),
                                  color: Colors.grey.shade300,
                                ),
                                SizedBox(height: (screenHeight * 0.02).clamp(12.0, 20.0)),
                                Text(
                                  'Message your friends',
                                  style: TextStyle(
                                    fontSize: (screenWidth * 0.04).clamp(16.0, 18.0),
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                                SizedBox(height: (screenHeight * 0.01).clamp(8.0, 12.0)),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: (screenWidth * 0.08).clamp(16.0, 32.0),
                                  ),
                                  child: Text(
                                    'Type a friend\'s name to find them',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: (screenWidth * 0.032).clamp(13.0, 14.0),
                                      color: Colors.grey.shade500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            itemCount: _searchResults.length,
                            padding: EdgeInsets.symmetric(
                              vertical: (screenHeight * 0.01).clamp(8.0, 12.0),
                              horizontal: (screenWidth * 0.04).clamp(12.0, 16.0),
                            ),
                            itemBuilder: (context, index) {
                              final user = _searchResults[index];
                              return _buildUserTile(
                                  user, screenWidth, screenHeight);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserTile(
    Map<String, dynamic> user,
    double screenWidth,
    double screenHeight,
  ) {
    final name = user['name'] as String? ?? 'Unknown';
    final avatar = user['avatar'] as String?;

    // Responsive sizing based on screen width
    final avatarRadius = (screenWidth * 0.08).clamp(20.0, 32.0);
    final spacingH = (screenWidth * 0.03).clamp(12.0, 16.0);
    final tileMarginBottom = (screenHeight * 0.01).clamp(6.0, 12.0);
    final tilePaddingV = (screenHeight * 0.015).clamp(10.0, 16.0);
    final tilePaddingH = (screenWidth * 0.03).clamp(12.0, 16.0);
    final nameTextSize = (screenWidth * 0.037).clamp(14.0, 17.0);
    final subtextSize = (screenWidth * 0.032).clamp(11.0, 14.0);
    final arrowIconSize = (screenWidth * 0.04).clamp(14.0, 18.0);
    final borderRadius = (screenWidth * 0.04).clamp(12.0, 16.0);

    return Container(
      margin: EdgeInsets.only(bottom: tileMarginBottom),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Return selected user
            Navigator.pop(context, user);
          },
          borderRadius: BorderRadius.circular(borderRadius),
          child: Padding(
            padding: EdgeInsets.symmetric(
              vertical: tilePaddingV,
              horizontal: tilePaddingH,
            ),
            child: Row(
              children: [
                AvatarWithFallback(
                  name: name,
                  imageUrl: avatar,
                  radius: avatarRadius,
                  textStyle: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: avatarRadius * 0.75,
                  ),
                  getImageProvider: (url) => UrlUtils.getAvatarImageProvider(url),
                ),
                SizedBox(width: spacingH),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: nameTextSize,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: screenHeight * 0.004),
                      Text(
                        'Tap to message',
                        style: TextStyle(
                          fontSize: subtextSize,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios,
                  size: arrowIconSize,
                  color: Colors.grey.shade400,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}
