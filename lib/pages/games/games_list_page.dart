import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:math';
import '../../services/game_service.dart';
import '../../utils/app_logger.dart';
import 'tap_streak_game.dart';
import 'color_blast_game.dart';
import 'puzzle_rush_game.dart';
import 'chain_reaction_game.dart';
import 'rpg_adventure_game.dart';

/// Responsive sizing utility for games
class ResponsiveSizing {
  /// Get responsive padding based on screen width
  static EdgeInsets getPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 400) return const EdgeInsets.all(8);
    if (width < 600) return const EdgeInsets.all(12);
    if (width < 900) return const EdgeInsets.all(16);
    return const EdgeInsets.all(24);
  }

  /// Get responsive horizontal padding
  static EdgeInsets getHorizontalPadding(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 400) return const EdgeInsets.symmetric(horizontal: 8);
    if (width < 600) return const EdgeInsets.symmetric(horizontal: 12);
    if (width < 900) return const EdgeInsets.symmetric(horizontal: 16);
    return const EdgeInsets.symmetric(horizontal: 24);
  }

  /// Get responsive vertical padding
  static EdgeInsets getVerticalPadding(BuildContext context) {
    final height = MediaQuery.of(context).size.height;
    if (height < 600) return const EdgeInsets.symmetric(vertical: 8);
    if (height < 800) return const EdgeInsets.symmetric(vertical: 12);
    if (height < 1000) return const EdgeInsets.symmetric(vertical: 16);
    return const EdgeInsets.symmetric(vertical: 20);
  }

  /// Get responsive spacing between elements
  static double getSpacing(BuildContext context,
      {double small = 8, double medium = 16, double large = 24}) {
    final width = MediaQuery.of(context).size.width;
    if (width < 400) return small;
    if (width < 900) return medium;
    return large;
  }

  /// Get responsive font size
  static double getFontSize(BuildContext context,
      {double small = 12,
      double medium = 16,
      double large = 20,
      double xlarge = 28}) {
    final width = MediaQuery.of(context).size.width;
    if (width < 400) return small;
    if (width < 600) return medium;
    if (width < 900) return large;
    return xlarge;
  }

  /// Get responsive icon size
  static double getIconSize(BuildContext context,
      {double small = 24,
      double medium = 32,
      double large = 40,
      double xlarge = 48}) {
    final width = MediaQuery.of(context).size.width;
    if (width < 400) return small;
    if (width < 600) return medium;
    if (width < 900) return large;
    return xlarge;
  }

  /// Get responsive container height
  static double getContainerHeight(BuildContext context,
      {double small = 200, double medium = 280, double large = 360}) {
    final width = MediaQuery.of(context).size.width;
    if (width < 400) return small;
    if (width < 900) return medium;
    return large;
  }

  /// Get responsive button height
  static double getButtonHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 400) return 40;
    if (width < 600) return 48;
    return 56;
  }

  /// Get responsive input field height
  static double getInputHeight(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 400) return 40;
    if (width < 600) return 48;
    return 56;
  }

  /// Get responsive border radius
  static double getBorderRadius(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 400) return 8;
    if (width < 600) return 12;
    return 16;
  }

  /// Get responsive shadow blur
  static double getShadowBlur(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < 600) return 4;
    if (width < 900) return 6;
    return 8;
  }

  /// Check if small screen
  static bool isSmallScreen(BuildContext context) =>
      MediaQuery.of(context).size.width < 400;

  /// Check if medium screen
  static bool isMediumScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= 400 &&
      MediaQuery.of(context).size.width < 900;

  /// Check if large screen
  static bool isLargeScreen(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  /// Get screen width
  static double getScreenWidth(BuildContext context) {
    return MediaQuery.of(context).size.width;
  }

  /// Get screen height
  static double getScreenHeight(BuildContext context) {
    return MediaQuery.of(context).size.height;
  }

  /// Get device pixel ratio for crisp graphics
  static double getDevicePixelRatio(BuildContext context) {
    return MediaQuery.of(context).devicePixelRatio;
  }

  /// Get responsive game grid cell size (for game boards/grids)
  static double getGameGridCellSize(BuildContext context, {int columns = 4}) {
    final width = getScreenWidth(context);
    final padding = getPadding(context);
    final totalPadding = padding.left + padding.right;
    final spacing = getSpacing(context, small: 8, medium: 12, large: 16);
    final totalSpacing = spacing * (columns - 1);
    final cellSize = (width - totalPadding - totalSpacing) / columns;
    return cellSize.clamp(40, double.infinity);
  }

  /// Get responsive touch target size (minimum 48x48 for accessibility)
  static double getTouchTargetSize(BuildContext context) {
    final width = getScreenWidth(context);
    if (width < 375) {
      return 44.0; // Small phones can use 44 if necessary
    } else {
      return 48.0; // Standard accessibility requirement
    }
  }

  /// Get responsive game board size (playable area)
  static double getGameBoardSize(BuildContext context) {
    final width = getScreenWidth(context);
    final padding = getPadding(context);
    final totalPadding = padding.left + padding.right;
    return (width - totalPadding).clamp(200, 600);
  }

  /// Get responsive animation duration (longer for small screens for better feedback)
  static Duration getAnimationDuration(BuildContext context) {
    if (isSmallScreen(context)) {
      return const Duration(milliseconds: 300);
    } else if (isMediumScreen(context)) {
      return const Duration(milliseconds: 250);
    } else {
      return const Duration(milliseconds: 200);
    }
  }

  /// Get safe area padding (accounts for notches, status bars)
  static EdgeInsets getSafeAreaPadding(BuildContext context) {
    final viewPadding = MediaQuery.of(context).viewPadding;
    return EdgeInsets.only(
      top: viewPadding.top,
      bottom: viewPadding.bottom,
      left: viewPadding.left,
      right: viewPadding.right,
    );
  }

  /// Get responsive view insets (for keyboards, bottom sheets)
  static EdgeInsets getViewInsets(BuildContext context) {
    return MediaQuery.of(context).viewInsets;
  }

  /// Check if in landscape orientation
  static bool isLandscape(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.landscape;
  }

  /// Check if in portrait orientation
  static bool isPortrait(BuildContext context) {
    return MediaQuery.of(context).orientation == Orientation.portrait;
  }

  /// Get maximum content width (useful for centering content on large screens)
  static double getMaxContentWidth(BuildContext context) {
    final width = getScreenWidth(context);
    if (width < 500) {
      return width;
    } else if (width < 800) {
      return 700;
    } else if (width < 1200) {
      return 900;
    } else {
      return 1000;
    }
  }

  /// Get responsive line height for text
  static double getLineHeight(BuildContext context) {
    if (isSmallScreen(context)) {
      return 1.4;
    } else if (isMediumScreen(context)) {
      return 1.5;
    } else {
      return 1.6;
    }
  }

  /// Get responsive letter spacing
  static double getLetterSpacing(BuildContext context) {
    if (isSmallScreen(context)) {
      return 0.3;
    } else if (isMediumScreen(context)) {
      return 0.4;
    } else {
      return 0.5;
    }
  }
}

class GamesListPage extends StatefulWidget {
  const GamesListPage({super.key});

  @override
  State<GamesListPage> createState() => _GamesListPageState();
}

class _GamesListPageState extends State<GamesListPage>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  
  final TextEditingController _searchController = TextEditingController();
  String _selectedCategory = '';
  Timer? _searchDebounce;
  
  // Available game categories (not const to allow non-const values if needed)
  static final List<Map<String, dynamic>> _categories = [
    {'value': '', 'label': 'All Games', 'icon': Icons.apps, 'color': Colors.blue},
    {'value': 'action', 'label': 'Action', 'icon': Icons.flash_on, 'color': Colors.red},
    {'value': 'puzzle', 'label': 'Puzzle', 'icon': Icons.extension, 'color': Colors.purple},
    {'value': 'memory', 'label': 'Memory', 'icon': Icons.memory, 'color': Colors.orange},
    {'value': 'word', 'label': 'Word', 'icon': Icons.text_fields, 'color': Colors.teal},
    {'value': 'rpg', 'label': 'RPG', 'icon': Icons.videogame_asset, 'color': Colors.indigo},
  ];
  
  // Game data with categories
  final List<Map<String, dynamic>> _allGames = [
    {
      'title': 'Word Scramble',
      'description': 'Unscramble the words',
      'icon': Icons.shuffle,
      'color': Colors.purple,
      'gameName': 'word-scramble',
      'category': 'word',
      'isPopular': true,
      'plays': '12.5K',
    },
    {
      'title': 'Memory Match',
      'description': 'Match the pairs',
      'icon': Icons.memory,
      'color': Colors.orange,
      'gameName': 'memory-match',
      'category': 'memory',
      'isPopular': true,
      'plays': '8.3K',
    },
    {
      'title': 'Quick Tap',
      'description': 'Test your reflexes',
      'icon': Icons.flash_on,
      'color': Colors.red,
      'gameName': 'quick-tap',
      'category': 'action',
      'isPopular': true,
      'plays': '15.2K',
    },
    {
      'title': 'Number Guessing',
      'description': 'Guess the number',
      'icon': Icons.numbers,
      'color': Colors.teal,
      'gameName': 'number-guessing',
      'category': 'puzzle',
      'plays': '6.1K',
    },
    {
      'title': 'Tap Streak',
      'description': 'Tap to the beat! 🔥',
      'icon': Icons.electric_bolt,
      'color': Colors.cyan,
      'gameName': 'tap-streak',
      'category': 'action',
      'isPopular': true,
      'plays': '19.8K',
    },
    {
      'title': 'Color Blast',
      'description': 'Match colors fast! 🎨',
      'icon': Icons.palette,
      'color': Colors.purpleAccent,
      'gameName': 'color-blast',
      'category': 'puzzle',
      'plays': '9.4K',
    },
    {
      'title': 'Puzzle Rush',
      'description': 'Solve puzzles fast! 🧩',
      'icon': Icons.dashboard_customize,
      'color': Colors.indigo,
      'gameName': 'puzzle-rush',
      'category': 'puzzle',
      'plays': '7.2K',
    },
    {
      'title': 'Chain Reaction',
      'description': 'Build your chain! ⛓️',
      'icon': Icons.link,
      'color': Colors.deepPurple,
      'gameName': 'chain-reaction',
      'category': 'puzzle',
      'plays': '5.8K',
    },
    {
      'title': 'RPG Adventure',
      'description': 'Epic turn-based RPG! ⚔️',
      'icon': Icons.videogame_asset,
      'color': Colors.red.shade700,
      'gameName': 'rpg-adventure',
      'category': 'rpg',
      'isPopular': true,
      'plays': '14.6K',
    },
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(_fadeController);
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero)
            .animate(_slideController);

    _fadeController.forward();
    _slideController.forward();
  }
  
  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _searchController.dispose();
    _searchDebounce?.cancel();
    super.dispose();
  }

  // Get filtered games based on search and category
  List<Map<String, dynamic>> get _filteredGames {
    String searchQuery = _searchController.text.toLowerCase();
    return _allGames.where((game) {
      bool matchesSearch = searchQuery.isEmpty ||
          game['title'].toString().toLowerCase().contains(searchQuery) ||
          game['description'].toString().toLowerCase().contains(searchQuery);
      bool matchesCategory = _selectedCategory.isEmpty ||
          game['category'].toString() == _selectedCategory;
      return matchesSearch && matchesCategory;
    }).toList();
  }

  // Get popular games
  List<Map<String, dynamic>> get _popularGames =>
      _allGames.where((game) => game['isPopular'] == true).toList();

  // Search handler
  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
      setState(() {});
    });
  }

  // Category filter handler
  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  // Get play function based on game name
  void Function(BuildContext) _getPlayFunction(String gameName) {
    switch (gameName) {
      case 'word-scramble':
        return _playWordScramble;
      case 'memory-match':
        return _playMemoryMatch;
      case 'quick-tap':
        return _playQuickTap;
      case 'number-guessing':
        return _playNumberGuessing;
      case 'tap-streak':
        return _playTapStreak;
      case 'color-blast':
        return _playColorBlast;
      case 'puzzle-rush':
        return _playPuzzleRush;
      case 'chain-reaction':
        return _playChainReaction;
      case 'rpg-adventure':
        return _playRPGAdventure;
      default:
        return _playWordScramble;
    }
  }

  /// Returns responsive grid columns based on screen width
  int _getGridColumns(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 500) {
      return 2; // Mobile
    } else if (screenWidth < 800) {
      return 3; // Tablet
    } else {
      return 4; // Desktop
    }
  }

  /// Returns responsive padding based on screen size
  EdgeInsets _getResponsivePadding(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 500) {
      return const EdgeInsets.all(12);
    } else if (screenWidth < 800) {
      return const EdgeInsets.all(16);
    } else {
      return const EdgeInsets.all(24);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    final padding = _getResponsivePadding(context);
    final filteredGames = _filteredGames;
    final popularGames = _popularGames;
    final showPopular = _searchController.text.isEmpty && _selectedCategory.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Games'),
        centerTitle: true,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colorScheme.surface,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Search games...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: colorScheme.surfaceContainerHighest,
                ),
              ),
            ),

            // Category Filter
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final selected = _selectedCategory == cat['value'];

                  return FilterChip(
                    selected: selected,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          cat['icon'] as IconData,
                          size: 16,
                          color: selected ? colorScheme.onSecondaryContainer : null,
                        ),
                        const SizedBox(width: 4),
                        Text(cat['label'] as String),
                      ],
                    ),
                    onSelected: (value) => _onCategorySelected(cat['value'] as String),
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    selectedColor: colorScheme.secondaryContainer,
                    showCheckmark: false,
                  );
                },
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: padding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      FadeTransition(
                        opacity: _fadeAnimation,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Play & Win',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Enjoy fun games and earn rewards',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: isPortrait ? 24 : 16),

                      // Popular Games Section
                      if (showPopular && popularGames.isNotEmpty)
                        FadeTransition(
                          opacity: _fadeAnimation,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.trending_up, color: Colors.amber.shade700, size: 24),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Popular Games',
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 180,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: popularGames.length,
                                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                                  itemBuilder: (context, index) {
                                    final game = popularGames[index];
                                    return TweenAnimationBuilder<double>(
                                      tween: Tween(begin: 0.0, end: 1.0),
                                      duration: Duration(milliseconds: 300 + (index * 100)),
                                      curve: Curves.easeOut,
                                      builder: (context, value, child) {
                                        return Transform.scale(
                                          scale: value,
                                          child: Opacity(opacity: value, child: child),
                                        );
                                      },
                                      child: _buildPopularGameCard(context, game),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),
                            ],
                          ),
                        ),

                      // All Games Grid
                      SlideTransition(
                        position: _slideAnimation,
                        child: FadeTransition(
                          opacity: _fadeAnimation,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!showPopular) ...[
                                Text(
                                  _selectedCategory.isEmpty
                                      ? 'All Games'
                                      : 'Filtered Games',
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                              filteredGames.isEmpty
                                  ? _buildEmptyState(context)
                                  : GridView.count(
                                      crossAxisCount: _getGridColumns(context),
                                      crossAxisSpacing: isPortrait ? 12 : 16,
                                      mainAxisSpacing: isPortrait ? 12 : 16,
                                      shrinkWrap: true,
                                      physics: const NeverScrollableScrollPhysics(),
                                      children: filteredGames
                                          .map((game) => _buildGameCardFromData(context, game))
                                          .toList(),
                                    ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build popular game card
  Widget _buildPopularGameCard(BuildContext context, Map<String, dynamic> game) {

    return InkWell(
      onTap: () {
        final playFunction = _getPlayFunction(game['gameName']);
        playFunction(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 160,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              (game['color'] as Color).withValues(alpha: 0.8),
              game['color'] as Color,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  game['icon'] as IconData,
                  color: Colors.white,
                  size: 28,
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.play_arrow, color: Colors.white, size: 16),
                      const SizedBox(width: 4),
                      Text(
                        game['plays'] ?? '0',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Text(
              game['title'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              game['description'],
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // Build game card from data
  Widget _buildGameCardFromData(BuildContext context, Map<String, dynamic> game) {
    return _buildGameCard(
      title: game['title'],
      description: game['description'],
      icon: game['icon'] as IconData,
      color: game['color'] as Color,
      gameName: game['gameName'],
      onTap: () {
        final playFunction = _getPlayFunction(game['gameName']);
        playFunction(context);
      },
      onLeaderboardTap: () => _showLeaderboard(
        context,
        game['gameName'],
        game['title'],
      ),
    );
  }

  // Build empty state
  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'No games found',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try adjusting your search or filter',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  void _playPuzzleRush(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => const PuzzleRushGame(),
      ),
    );
  }

  void _playChainReaction(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => const ChainReactionGame(),
      ),
    );
  }

  Widget _buildGameCard({
    required String title,
    required String description,
    required IconData icon,
    required Color color,
    required String gameName,
    required VoidCallback onTap,
    required VoidCallback onLeaderboardTap,
  }) {
    return _GameCardAnimated(
      color: color,
      title: title,
      description: description,
      icon: icon,
      gameName: gameName,
      onTap: onTap,
      onLeaderboardTap: onLeaderboardTap,
    );
  }

  void _playWordScramble(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => const WordScrambleGame(),
      ),
    );
  }

  void _playMemoryMatch(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => const MemoryMatchGame(),
      ),
    );
  }

  void _playQuickTap(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => const QuickTapGame(),
      ),
    );
  }

  void _playNumberGuessing(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => const NumberGuessingGame(),
      ),
    );
  }

  void _playTapStreak(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => const TapStreakGame(),
      ),
    );
  }

  void _playColorBlast(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => const ColorBlastGame(),
      ),
    );
  }

  void _playRPGAdventure(BuildContext context) {
    Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (BuildContext context) => const RPGAdventureGame(),
      ),
    );
  }

  void _showLeaderboard(
    BuildContext context,
    String gameName,
    String gameTitle,
  ) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) => LeaderboardDialog(
        gameName: gameName,
        gameTitle: gameTitle,
      ),
    );
  }
}

// Leaderboard Dialog Widget
class LeaderboardDialog extends StatefulWidget {
  final String gameName;
  final String gameTitle;

  const LeaderboardDialog({
    required this.gameName,
    required this.gameTitle,
    super.key,
  });

  @override
  State<LeaderboardDialog> createState() => _LeaderboardDialogState();
}

class _LeaderboardDialogState extends State<LeaderboardDialog> {
  late Future<List<GameLeaderboardEntry>> _leaderboardFuture;
  late Future<({int? rank, int highScore, bool hasPlayed})> _userRankFuture;

  @override
  void initState() {
    super.initState();
    _leaderboardFuture = GameService.getLeaderboard(widget.gameName, limit: 10);
    _userRankFuture = GameService.getUserRank(widget.gameName);
  }

  /// Returns responsive dialog width based on screen size
  double _getDialogWidth(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 500) {
      return screenWidth * 0.9;
    } else if (screenWidth < 800) {
      return screenWidth * 0.8;
    } else {
      return 600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dialogWidth = _getDialogWidth(context);
    final isSmallScreen = MediaQuery.of(context).size.width < 500;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: dialogWidth,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Padding(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '🏆 Leaderboard',
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            widget.gameTitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: Colors.grey,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                    ),
                  ],
                ),
                SizedBox(height: isSmallScreen ? 16 : 20),

                // User's Current Rank
                FutureBuilder<({int? rank, int highScore, bool hasPlayed})>(
                  future: _userRankFuture,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      final rankData = snapshot.data!;
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.blue.shade50,
                              Colors.blue.shade100,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            Column(
                              children: [
                                Text(
                                  'Your Rank',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  rankData.rank != null
                                      ? '#${rankData.rank}'
                                      : '--',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              children: [
                                Text(
                                  'Your High Score',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  rankData.highScore.toString(),
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    } else if (snapshot.hasError) {
                      AppLogger()
                          .error('Failed to load user rank: ${snapshot.error}');
                      return const SizedBox.shrink();
                    }
                    return const SizedBox(height: 60);
                  },
                ),
                SizedBox(height: isSmallScreen ? 16 : 20),

                // Leaderboard List
                Text(
                  'Top 10 Players',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SizedBox(height: isSmallScreen ? 8 : 12),
                FutureBuilder<List<GameLeaderboardEntry>>(
                  future: _leaderboardFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: CircularProgressIndicator(),
                      );
                    }

                    if (snapshot.hasError) {
                      AppLogger().error(
                          'Failed to load leaderboard: ${snapshot.error}');
                      return Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Failed to load leaderboard',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            ElevatedButton(
                              onPressed: () => setState(() {
                                _leaderboardFuture = GameService.getLeaderboard(
                                  widget.gameName,
                                  limit: 10,
                                );
                              }),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      );
                    }

                    final leaderboard = snapshot.data ?? [];
                    if (leaderboard.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No scores yet'),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: leaderboard.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final entry = leaderboard[index];
                        final isMedal = index < 3;
                        const medals = ['🥇', '🥈', '🥉'];

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: isMedal
                                ? Border.all(
                                    color: Colors.amber.shade400,
                                    width: 2,
                                  )
                                : null,
                          ),
                          child: Row(
                            children: [
                              // Rank
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isMedal
                                      ? Colors.amber.shade100
                                      : Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    isMedal ? medals[index] : '#${index + 1}',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Name
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      entry.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      entry.difficulty.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Score
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  entry.highScore.toString(),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
                SizedBox(height: isSmallScreen ? 16 : 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade300,
                      foregroundColor: Colors.black,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Animated Game Card Widget
class _GameCardAnimated extends StatefulWidget {
  final Color color;
  final String title;
  final String description;
  final IconData icon;
  final String gameName;
  final VoidCallback onTap;
  final VoidCallback onLeaderboardTap;

  const _GameCardAnimated({
    required this.color,
    required this.title,
    required this.description,
    required this.icon,
    required this.gameName,
    required this.onTap,
    required this.onLeaderboardTap,
  });

  @override
  State<_GameCardAnimated> createState() => _GameCardAnimatedState();
}

class _GameCardAnimatedState extends State<_GameCardAnimated>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1, end: 1.05).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Get responsive icon size based on screen width
  double _getIconSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 400) {
      return 32;
    } else if (screenWidth < 800) {
      return 40;
    } else {
      return 48;
    }
  }

  /// Get responsive font size based on screen width
  double _getTitleFontSize(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth < 400) {
      return 14;
    } else if (screenWidth < 800) {
      return 16;
    } else {
      return 18;
    }
  }

  @override
  Widget build(BuildContext context) {
    final iconSize = _getIconSize(context);
    final titleFontSize = _getTitleFontSize(context);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: GestureDetector(
        onTap: widget.onTap,
        onTapDown: (_) => _controller.forward(),
        onTapUp: (_) => _controller.reverse(),
        onTapCancel: () => _controller.reverse(),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    widget.color.withValues(alpha: 0.7),
                    widget.color,
                  ],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onTap,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          widget.icon,
                          color: Colors.white,
                          size: iconSize,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: titleFontSize,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.description,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: titleFontSize * 0.75,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Leaderboard button
            Positioned(
              top: 8,
              right: 8,
              child: Container(
                constraints: const BoxConstraints(
                  minWidth: 48,
                  minHeight: 48,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onLeaderboardTap,
                    customBorder: const CircleBorder(),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Tooltip(
                        message: 'View leaderboard',
                        child: Icon(
                          Icons.leaderboard,
                          color: widget.color,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Word Scramble Game
class WordScrambleGame extends StatefulWidget {
  const WordScrambleGame({super.key});

  @override
  State<WordScrambleGame> createState() => _WordScrambleGameState();
}

class _WordScrambleGameState extends State<WordScrambleGame> {
  late List<Map<String, String>> words;
  late int currentWordIndex;
  late String scrambledWord;
  int score = 0;
  int correctAnswers = 0;
  bool gameOver = false;
  bool showDifficultyMenu = true;
  String difficulty = 'medium';
  TextEditingController answerController = TextEditingController();
  String message = '';
  bool showMessage = false;
  int timeRemaining = 30;
  late Timer? timerInstance;
  int currentStreak = 0;

  final Map<String, List<String>> wordsByDifficulty = {
    'easy': ['cat', 'dog', 'bird', 'fish', 'tree', 'house'],
    'medium': [
      'flutter',
      'coding',
      'challenge',
      'rewards',
      'victory',
      'success',
      'algorithm',
      'database'
    ],
    'hard': [
      'paradigm',
      'cryptography',
      'photosynthesis',
      'serendipity',
      'melancholy',
      'ephemeral',
      'juxtapose',
      'eloquent'
    ],
  };

  @override
  void initState() {
    super.initState();
  }

  void _startGame(String selectedDifficulty) {
    setState(() {
      showDifficultyMenu = false;
      difficulty = selectedDifficulty;
    });
    _initializeGame();
    _startTimer();
  }

  void _startTimer() {
    timerInstance = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          timeRemaining--;
        });
        if (timeRemaining <= 0) {
          timer.cancel();
          _gameOver();
        }
      }
    });
  }

  void _gameOver() {
    if (timerInstance != null) {
      timerInstance!.cancel();
    }
    setState(() {
      gameOver = true;
      message = 'Time\'s up!';
      showMessage = true;
    });
  }

  void _initializeGame() {
    final selectedWords = wordsByDifficulty[difficulty]!;
    words = selectedWords
        .map((word) => {
              'original': word,
              'scrambled': _scrambleWord(word),
            })
        .toList();
    currentWordIndex = 0;
    scrambledWord = words[0]['scrambled']!;
    score = 0;
    correctAnswers = 0;
    currentStreak = 0;
    gameOver = false;
    timeRemaining = difficulty == 'easy'
        ? 60
        : difficulty == 'medium'
            ? 45
            : 30;
    message = '';
    showMessage = false;
  }

  String _scrambleWord(String word) {
    List<String> chars = word.split('');
    chars.shuffle();
    return chars.join('');
  }

  void _checkAnswer() {
    String userAnswer = answerController.text.trim().toLowerCase();
    
    // Don't process empty answers
    if (userAnswer.isEmpty) {
      return;
    }
    
    // Don't process if already showing a message (waiting for next word)
    if (showMessage) {
      return;
    }
    
    String correctAnswer = words[currentWordIndex]['original']!.toLowerCase();

    if (userAnswer == correctAnswer) {
      int points = 10 + (currentStreak * 2); // Bonus for streak
      setState(() {
        score += points;
        correctAnswers++;
        currentStreak++;
        message = '✓ Correct! +$points points (Streak: $currentStreak)';
        showMessage = true;
      });

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          _nextWord();
        }
      });
    } else {
      setState(() {
        currentStreak = 0;
        message = '✗ Wrong! The answer is: $correctAnswer';
        showMessage = true;
      });

      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
          _nextWord();
        }
      });
    }
  }

  void _nextWord() {
    if (currentWordIndex < words.length - 1) {
      setState(() {
        currentWordIndex++;
        scrambledWord = words[currentWordIndex]['scrambled']!;
        answerController.clear();
        message = '';
        showMessage = false;
      });
    } else {
      _endGame();
    }
  }

  void _endGame() {
    if (timerInstance != null) {
      timerInstance!.cancel();
    }
    setState(() {
      gameOver = true;
      message = 'Game Complete!';
      showMessage = true;
    });
    _submitScore();
  }

  Future<void> _submitScore() async {
    try {
      final statistics = {
        'totalCorrect': correctAnswers,
        'totalWrong': words.length - correctAnswers,
        'accuracy': ((correctAnswers / words.length) * 100).toStringAsFixed(1),
      };

      await GameService.submitScore(
        'word-scramble',
        score,
        difficulty,
        statistics: statistics,
      );
    } catch (e) {
      AppLogger().error('Failed to submit word scramble score: $e');
    }
  }

  void _resetGame() {
    setState(() {
      showDifficultyMenu = true;
      _initializeGame();
    });
    answerController.clear();
  }

  @override
  void dispose() {
    answerController.dispose();
    timerInstance?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Word Scramble'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            timerInstance?.cancel();
            Navigator.pop(context);
          },
        ),
      ),
      body: showDifficultyMenu
          ? _buildDifficultyMenu()
          : SafeArea(
              child: Column(
                children: [
                  // Score and Stats
                  Padding(
                    padding: ResponsiveSizing.getPadding(context),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(
                          child: _buildStatCard('Score', score.toString()),
                        ),
                        SizedBox(width: ResponsiveSizing.getSpacing(context, small: 6, medium: 8, large: 12)),
                        Expanded(
                          child: _buildStatCard('Streak', currentStreak.toString()),
                        ),
                        SizedBox(width: ResponsiveSizing.getSpacing(context, small: 6, medium: 8, large: 12)),
                        Expanded(
                          child: _buildStatCard('Time', '${timeRemaining}s',
                              timeRemaining <= 10 ? Colors.red : Colors.purple),
                        ),
                      ],
                    ),
                  ),

                  // Game Content
                  Expanded(
                    child: gameOver ? _buildGameOverScreen() : _buildGameScreen(),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDifficultyMenu() {
    final padding = ResponsiveSizing.getHorizontalPadding(context);
    final spacing =
        ResponsiveSizing.getSpacing(context, small: 20, medium: 24, large: 32);
    final buttonWidth = ResponsiveSizing.isSmallScreen(context) ? 140.0 : 180.0;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: padding,
                child: Text(
                  'Select Difficulty',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveSizing.getFontSize(context,
                            small: 18, medium: 20, large: 24, xlarge: 28),
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: spacing),
              _buildDifficultyButton(
                'Easy',
                'Perfect for beginners',
                Colors.green,
                buttonWidth,
              ),
              SizedBox(
                  height: ResponsiveSizing.getSpacing(context,
                      small: 10, medium: 12, large: 16)),
              _buildDifficultyButton(
                'Medium',
                'Challenge yourself',
                Colors.purple,
                buttonWidth,
              ),
              SizedBox(
                  height: ResponsiveSizing.getSpacing(context,
                      small: 10, medium: 12, large: 16)),
              _buildDifficultyButton(
                'Hard',
                'Master level',
                Colors.red,
                buttonWidth,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyButton(
    String label,
    String desc,
    Color color,
    double width,
  ) {
    final borderRadius = ResponsiveSizing.getBorderRadius(context);
    final padding =
        ResponsiveSizing.getSpacing(context, small: 10, medium: 12, large: 14);
    final shadowBlur = ResponsiveSizing.getShadowBlur(context);

    return GestureDetector(
      onTap: () => _startGame(label.toLowerCase()),
      child: Container(
        width: width,
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.7), color],
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: shadowBlur,
            )
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: ResponsiveSizing.getFontSize(context,
                    small: 15, medium: 16, large: 18, xlarge: 20),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: ResponsiveSizing.getFontSize(context,
                    small: 11, medium: 12, large: 13, xlarge: 14),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameScreen() {
    final padding = ResponsiveSizing.getPadding(context);
    final spacing = ResponsiveSizing.getSpacing(context);
    final fontSize = ResponsiveSizing.getFontSize(context,
        small: 22, medium: 26, large: 32, xlarge: 38);
    final borderRadius = ResponsiveSizing.getBorderRadius(context);
    final buttonHeight = ResponsiveSizing.getButtonHeight(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            left: padding.left,
            right: padding.right,
            top: padding.top,
            bottom: MediaQuery.of(context).viewInsets.bottom + padding.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - padding.top - padding.bottom,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveSizing.isSmallScreen(context) ? 8 : padding.left,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: ResponsiveSizing.isSmallScreen(context) ? 8 : spacing),
                  Text(
                    'Unscramble the word:',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontSize: ResponsiveSizing.getFontSize(context,
                              small: 14, medium: 16, large: 18, xlarge: 20),
                          fontWeight: FontWeight.w600,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: spacing + 4),
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      maxWidth: ResponsiveSizing.isLargeScreen(context) ? 600 : double.infinity,
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: ResponsiveSizing.getSpacing(context, small: 8, medium: 12, large: 16),
                      vertical: ResponsiveSizing.getSpacing(context, small: 14, medium: 18, large: 22),
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade100,
                      borderRadius: BorderRadius.circular(borderRadius),
                      border: Border.all(color: Colors.purple, width: 2),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        scrambledWord.toUpperCase(),
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple,
                          letterSpacing: ResponsiveSizing.isSmallScreen(context) ? 1.5 : 2.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  SizedBox(height: spacing + 4),
                  if (showMessage)
                    Container(
                      width: double.infinity,
                      constraints: BoxConstraints(
                        maxWidth: ResponsiveSizing.isLargeScreen(context) ? 600 : double.infinity,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: ResponsiveSizing.getSpacing(context, small: 10, medium: 12, large: 14),
                        vertical: ResponsiveSizing.getSpacing(context, small: 10, medium: 12, large: 14),
                      ),
                      decoration: BoxDecoration(
                        color: message.startsWith('✓')
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                        borderRadius: BorderRadius.circular(borderRadius - 4),
                        border: Border.all(
                          color: message.startsWith('✓') ? Colors.green : Colors.red,
                          width: 1.5,
                        ),
                      ),
                      child: Text(
                        message,
                        style: TextStyle(
                          color: message.startsWith('✓') ? Colors.green.shade700 : Colors.red.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: ResponsiveSizing.getFontSize(context,
                              small: 12, medium: 13, large: 15, xlarge: 16),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    SizedBox(height: ResponsiveSizing.getSpacing(context, small: 12, medium: 16, large: 20)),
                  SizedBox(height: spacing),
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      maxWidth: ResponsiveSizing.isLargeScreen(context) ? 600 : double.infinity,
                    ),
                    child: TextField(
                      controller: answerController,
                      enabled: !showMessage && !gameOver,
                      decoration: InputDecoration(
                        hintText: 'Enter your answer',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                        filled: true,
                        fillColor: Colors.grey.shade100,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: ResponsiveSizing.getSpacing(context,
                              small: 14, medium: 16, large: 18),
                          vertical: ResponsiveSizing.getSpacing(context,
                              small: 12, medium: 14, large: 16),
                        ),
                        hintStyle: TextStyle(
                          fontSize: ResponsiveSizing.getFontSize(context,
                              small: 13, medium: 15, large: 16, xlarge: 16),
                        ),
                      ),
                      style: TextStyle(
                        fontSize: ResponsiveSizing.getFontSize(context,
                            small: 15, medium: 17, large: 18, xlarge: 18),
                      ),
                      textCapitalization: TextCapitalization.none,
                      onChanged: (_) => setState(() {}),
                      onSubmitted: (_) => _checkAnswer(),
                    ),
                  ),
                  SizedBox(height: spacing),
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      maxWidth: ResponsiveSizing.isLargeScreen(context) ? 600 : double.infinity,
                    ),
                    height: buttonHeight,
                    child: ElevatedButton(
                      onPressed: (answerController.text.trim().isEmpty || showMessage || gameOver)
                          ? null
                          : _checkAnswer,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade600,
                        disabledBackgroundColor: Colors.grey.shade400,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                      ),
                      child: Text(
                        'Submit',
                        style: TextStyle(
                          fontSize: ResponsiveSizing.getFontSize(context,
                              small: 15, medium: 17, large: 18, xlarge: 18),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: ResponsiveSizing.isSmallScreen(context) ? 8 : spacing),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGameOverScreen() {
    final padding = ResponsiveSizing.getPadding(context);
    final spacing = ResponsiveSizing.getSpacing(context);
    final borderRadius = ResponsiveSizing.getBorderRadius(context);
    final buttonHeight = ResponsiveSizing.getButtonHeight(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(
            left: padding.left,
            right: padding.right,
            top: padding.top,
            bottom: MediaQuery.of(context).viewInsets.bottom + padding.bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: constraints.maxHeight - padding.top - padding.bottom,
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: ResponsiveSizing.isSmallScreen(context) ? 8 : padding.left,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(height: ResponsiveSizing.isSmallScreen(context) ? 8 : spacing),
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      maxWidth: ResponsiveSizing.isLargeScreen(context) ? 600 : double.infinity,
                    ),
                    padding: EdgeInsets.all(ResponsiveSizing.getSpacing(context,
                        small: 14, medium: 18, large: 22)),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(borderRadius),
                      border: Border.all(color: Colors.green, width: 2),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '🎉 Game Complete! 🎉',
                          style: TextStyle(
                            fontSize: ResponsiveSizing.getFontSize(context,
                                small: 18, medium: 20, large: 24, xlarge: 28),
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: spacing),
                        Text(
                          'Final Score: $score',
                          style: TextStyle(
                            fontSize: ResponsiveSizing.getFontSize(context,
                                small: 16, medium: 18, large: 20, xlarge: 22),
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: ResponsiveSizing.getSpacing(context, small: 8, medium: 10, large: 12)),
                        Text(
                          'Correct Answers: $correctAnswers/${words.length}',
                          style: TextStyle(
                            fontSize: ResponsiveSizing.getFontSize(context,
                                small: 14, medium: 15, large: 17, xlarge: 18),
                            color: Colors.green.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        SizedBox(height: ResponsiveSizing.getSpacing(context, small: 8, medium: 10, large: 12)),
                        Text(
                          'Accuracy: ${((correctAnswers / words.length) * 100).toStringAsFixed(1)}%',
                          style: TextStyle(
                            fontSize: ResponsiveSizing.getFontSize(context,
                                small: 14, medium: 15, large: 17, xlarge: 18),
                            color: Colors.green.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: spacing),
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      maxWidth: ResponsiveSizing.isLargeScreen(context) ? 600 : double.infinity,
                    ),
                    height: buttonHeight,
                    child: ElevatedButton.icon(
                      onPressed: _resetGame,
                      icon: Icon(
                        Icons.refresh,
                        size: ResponsiveSizing.getFontSize(context, small: 16, medium: 18, large: 20, xlarge: 20),
                      ),
                      label: Text(
                        'Play Again',
                        style: TextStyle(
                          fontSize: ResponsiveSizing.getFontSize(context,
                              small: 15, medium: 17, large: 18, xlarge: 18),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.purple.shade600,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(borderRadius),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: ResponsiveSizing.isSmallScreen(context) ? 8 : spacing),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatCard(String label, String value, [Color? color]) {
    final theme = Theme.of(context);
    final displayColor = color ?? theme.colorScheme.primary;
    final padding = ResponsiveSizing.getSpacing(context, small: 8, medium: 10, large: 12);
    final borderRadius = ResponsiveSizing.getBorderRadius(context);
    final isSmallScreen = ResponsiveSizing.isSmallScreen(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? padding * 0.7 : padding,
        vertical: isSmallScreen ? padding * 0.6 : padding * 0.8,
      ),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: theme.cardTheme.shape is RoundedRectangleBorder
              ? (theme.cardTheme.shape as RoundedRectangleBorder).side.color
              : theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: ResponsiveSizing.getFontSize(context,
                  small: 9, medium: 10, large: 11, xlarge: 12),
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          SizedBox(height: isSmallScreen ? 2 : 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: ResponsiveSizing.getFontSize(context,
                    small: 13, medium: 16, large: 19, xlarge: 22),
                fontWeight: FontWeight.bold,
                color: displayColor,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// Memory Match Game
class MemoryMatchGame extends StatefulWidget {
  const MemoryMatchGame({super.key});

  @override
  State<MemoryMatchGame> createState() => _MemoryMatchGameState();
}

class _MemoryMatchGameState extends State<MemoryMatchGame> {
  late List<String> cards;
  late List<bool> revealed;
  late List<bool> matched;
  late List<int> selectedIndices;
  int score = 0;
  int moves = 0;
  bool gameOver = false;
  bool isProcessing = false;
  bool showDifficultyMenu = true;
  String difficulty = 'medium';

  final Map<String, List<String>> cardsByDifficulty = {
    'easy': ['🍎', '🍌', '🍊', '🍓'],
    'medium': ['�', '🍌', '🍊', '🍓', '�🍇', '🍉'],
    'hard': ['🍎', '🍌', '🍊', '🍓', '🍇', '🍉', '🍑', '🥝'],
  };

  @override
  void initState() {
    super.initState();
  }

  void _startGame(String selectedDifficulty) {
    setState(() {
      showDifficultyMenu = false;
      difficulty = selectedDifficulty;
    });
    _initializeGame();
  }

  void _initializeGame() {
    final selectedCardEmojis = cardsByDifficulty[difficulty]!;
    cards = [...selectedCardEmojis, ...selectedCardEmojis];
    cards.shuffle();
    revealed = List<bool>.filled(cards.length, false);
    matched = List<bool>.filled(cards.length, false);
    selectedIndices = [];
    score = 0;
    moves = 0;
    gameOver = false;
    isProcessing = false;
  }

  bool _checkWin() {
    return matched.every((m) => m);
  }

  void _cardTapped(int index) {
    if (matched[index] || isProcessing || revealed[index]) return;

    setState(() {
      revealed[index] = true;
      selectedIndices.add(index);
    });

    if (selectedIndices.length == 2) {
      isProcessing = true;
      moves++;
      final firstIndex = selectedIndices[0];
      final secondIndex = selectedIndices[1];

      if (cards[firstIndex] == cards[secondIndex]) {
        // Match found!
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              matched[firstIndex] = true;
              matched[secondIndex] = true;
              selectedIndices.clear();
              score += 20;
              isProcessing = false;

              if (_checkWin()) {
                gameOver = true;
                int bonusScore = (100 - moves * 5).clamp(0, 100);
                score += bonusScore;
                _submitScore();
              }
            });
          }
        });
      } else {
        // No match - flip back
        Future.delayed(const Duration(milliseconds: 1200), () {
          if (mounted) {
            setState(() {
              revealed[firstIndex] = false;
              revealed[secondIndex] = false;
              selectedIndices.clear();
              isProcessing = false;
            });
          }
        });
      }
    }
  }

  void _resetGame() {
    setState(() {
      showDifficultyMenu = true;
      _initializeGame();
    });
  }

  Future<void> _submitScore() async {
    try {
      final accuracy = ((matched.where((m) => m).length / matched.length) * 100)
          .toStringAsFixed(1);
      final statistics = {
        'totalCorrect': matched.where((m) => m).length ~/ 2,
        'moves': moves,
        'accuracy': accuracy,
      };

      await GameService.submitScore(
        'memory-match',
        score,
        difficulty,
        statistics: statistics,
      );
    } catch (e) {
      AppLogger().error('Failed to submit memory match score: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final padding = ResponsiveSizing.getPadding(context);
    final spacing = ResponsiveSizing.getSpacing(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Memory Match'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: showDifficultyMenu
          ? _buildDifficultyMenu()
          : Column(
              children: [
                // Score and Stats
                Padding(
                  padding: padding,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatCard('Score', score.toString(), Colors.orange),
                      _buildStatCard('Moves', moves.toString(), Colors.orange),
                      _buildStatCard(
                          'Pairs',
                          '${matched.where((m) => m).length ~/ 2}/${cards.length ~/ 2}',
                          Colors.orange),
                    ],
                  ),
                ),

                // Game Grid
                Expanded(
                  child: Padding(
                    padding: padding,
                    child: GridView.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: difficulty == 'hard' ? 4 : 3,
                        crossAxisSpacing: spacing,
                        mainAxisSpacing: spacing,
                      ),
                      itemCount: cards.length,
                      itemBuilder: (context, index) {
                        return _buildCardItem(index);
                      },
                    ),
                  ),
                ),

                // Game Over Screen
                if (gameOver)
                  Padding(
                    padding: padding,
                    child: Column(
                      children: [
                        Container(
                          padding: EdgeInsets.all(ResponsiveSizing.getSpacing(
                              context,
                              small: 14,
                              medium: 16,
                              large: 20)),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(
                                ResponsiveSizing.getBorderRadius(context)),
                            border: Border.all(color: Colors.green, width: 2),
                          ),
                          child: Column(
                            children: [
                              Text(
                                '🎉 You Won! 🎉',
                                style: TextStyle(
                                  fontSize: ResponsiveSizing.getFontSize(
                                      context,
                                      small: 18,
                                      medium: 20,
                                      large: 24,
                                      xlarge: 28),
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              SizedBox(height: spacing * 0.75),
                              Text(
                                'Final Score: $score | Moves: $moves',
                                style: TextStyle(
                                  fontSize: ResponsiveSizing.getFontSize(
                                      context,
                                      small: 14,
                                      medium: 16,
                                      large: 18,
                                      xlarge: 18),
                                  color: Colors.green.shade700,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: spacing * 0.75),
                        SizedBox(
                          width: double.infinity,
                          height: ResponsiveSizing.getButtonHeight(context),
                          child: ElevatedButton.icon(
                            onPressed: _resetGame,
                            icon: const Icon(Icons.refresh),
                            label: Text(
                              'Play Again',
                              style: TextStyle(
                                fontSize: ResponsiveSizing.getFontSize(context,
                                    small: 14,
                                    medium: 16,
                                    large: 18,
                                    xlarge: 18),
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange.shade600,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                    ResponsiveSizing.getBorderRadius(context)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  SizedBox(height: spacing * 0.5),
              ],
            ),
    );
  }

  Widget _buildDifficultyMenu() {
    final padding = ResponsiveSizing.getHorizontalPadding(context);
    final spacing =
        ResponsiveSizing.getSpacing(context, small: 20, medium: 24, large: 32);
    final buttonWidth = ResponsiveSizing.isSmallScreen(context) ? 140.0 : 180.0;

    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Padding(
                padding: padding,
                child: Text(
                  'Select Difficulty',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: ResponsiveSizing.getFontSize(context,
                            small: 18, medium: 20, large: 24, xlarge: 28),
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
              SizedBox(height: spacing),
              _buildDifficultyButtonMemory(
                'Easy',
                '4 card pairs',
                Colors.green,
                buttonWidth,
              ),
              SizedBox(
                  height: ResponsiveSizing.getSpacing(context,
                      small: 10, medium: 12, large: 16)),
              _buildDifficultyButtonMemory(
                'Medium',
                '6 card pairs',
                Colors.orange,
                buttonWidth,
              ),
              SizedBox(
                  height: ResponsiveSizing.getSpacing(context,
                      small: 10, medium: 12, large: 16)),
              _buildDifficultyButtonMemory(
                'Hard',
                '8 card pairs',
                Colors.red,
                buttonWidth,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyButtonMemory(
    String label,
    String desc,
    Color color,
    double width,
  ) {
    final borderRadius = ResponsiveSizing.getBorderRadius(context);
    final padding =
        ResponsiveSizing.getSpacing(context, small: 10, medium: 12, large: 14);
    final shadowBlur = ResponsiveSizing.getShadowBlur(context);

    return GestureDetector(
      onTap: () => _startGame(label.toLowerCase()),
      child: Container(
        width: width,
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.7), color],
          ),
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: shadowBlur,
            )
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: ResponsiveSizing.getFontSize(context,
                    small: 15, medium: 16, large: 18, xlarge: 20),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: ResponsiveSizing.getFontSize(context,
                    small: 11, medium: 12, large: 13, xlarge: 14),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCardItem(int index) {
    final borderRadius = ResponsiveSizing.getBorderRadius(context);
    final cardSize = _getResponsiveCardSize(context);
    final shadowBlur = ResponsiveSizing.getShadowBlur(context);

    return GestureDetector(
      onTap: () => _cardTapped(index),
      child: Container(
        width: cardSize,
        height: cardSize,
        decoration: BoxDecoration(
          color: matched[index]
              ? Colors.green.shade400
              : revealed[index]
                  ? Colors.orange.shade500
                  : Colors.orange.shade300,
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: shadowBlur,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: matched[index]
              ? Icon(
                  Icons.check,
                  color: Colors.white,
                  size: ResponsiveSizing.getIconSize(context,
                      small: 24, medium: 28, large: 32, xlarge: 40),
                )
              : revealed[index]
                  ? Text(
                      cards[index],
                      style: TextStyle(
                        fontSize: ResponsiveSizing.getFontSize(context,
                            small: 28, medium: 32, large: 36, xlarge: 44),
                      ),
                    )
                  : Text(
                      '?',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: ResponsiveSizing.getFontSize(context,
                            small: 28, medium: 32, large: 36, xlarge: 40),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
        ),
      ),
    );
  }

  double _getResponsiveCardSize(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final padding = ResponsiveSizing.getPadding(context);
    final spacing = ResponsiveSizing.getSpacing(context);
    final crossAxisCount = difficulty == 'hard' ? 4 : 3;

    final availableWidth = width -
        (padding.left + padding.right) -
        (spacing * (crossAxisCount - 1));
    return availableWidth / crossAxisCount;
  }

  Widget _buildStatCard(String label, String value, Color color) {
    final theme = Theme.of(context);
    final padding =
        ResponsiveSizing.getSpacing(context, small: 10, medium: 12, large: 14);
    final borderRadius = ResponsiveSizing.getBorderRadius(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: padding * 0.8,
      ),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: ResponsiveSizing.getFontSize(context,
                  small: 10, medium: 11, large: 12, xlarge: 13),
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: ResponsiveSizing.getFontSize(context,
                  small: 14, medium: 18, large: 20, xlarge: 22),
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Quick Tap Game
class QuickTapGame extends StatefulWidget {
  const QuickTapGame({super.key});

  @override
  State<QuickTapGame> createState() => _QuickTapGameState();
}

class _QuickTapGameState extends State<QuickTapGame> {
  late int targetNumber;
  late List<int> displayNumbers;
  int score = 0;
  int round = 1;
  bool gameOver = false;
  bool isProcessing = false;
  bool showDifficultyMenu = true;
  String difficulty = 'medium';
  String message = '';
  bool showMessage = false;
  late Stopwatch stopwatch;
  int reactionTime = 0;
  int totalReactionTime = 0;
  int bestReactionTime = 999999;

  @override
  void initState() {
    super.initState();
    stopwatch = Stopwatch();
  }

  void _startGame(String selectedDifficulty) {
    setState(() {
      showDifficultyMenu = false;
      difficulty = selectedDifficulty;
    });
    _initializeGame();
  }

  void _initializeGame() {
    score = 0;
    round = 1;
    gameOver = false;
    isProcessing = false;
    totalReactionTime = 0;
    bestReactionTime = 999999;
    stopwatch = Stopwatch();
    _generateNewRound();
  }

  void _generateNewRound() {
    int maxRounds = difficulty == 'easy'
        ? 5
        : difficulty == 'medium'
            ? 10
            : 15;

    if (round > maxRounds) {
      setState(() {
        gameOver = true;
        int avgReactionTime = totalReactionTime ~/ (round - 1);
        message = 'Game Over! Avg Reaction: ${avgReactionTime}ms';
        showMessage = true;
      });
      _submitScore();
      return;
    }

    // Generate a random target number
    targetNumber = 10 + Random().nextInt(90);

    // Generate 8 random numbers
    displayNumbers =
        List<int>.generate(8, (i) => Random().nextInt(100)).toList();

    // Make sure target is in the list
    displayNumbers[0] = targetNumber;
    displayNumbers.shuffle();

    setState(() {
      message = '';
      showMessage = false;
      isProcessing = false;
    });
    stopwatch.reset();
  }

  void _onNumberTap(int number) {
    if (isProcessing) return;

    if (!stopwatch.isRunning) {
      stopwatch.start();
    }

    isProcessing = true;

    if (number == targetNumber) {
      reactionTime = stopwatch.elapsedMilliseconds;
      totalReactionTime += reactionTime;
      if (reactionTime < bestReactionTime) {
        bestReactionTime = reactionTime;
      }

      int points = (500 - reactionTime ~/ 10).clamp(10, 500);
      score += points;

      setState(() {
        message = '✓ Correct! +$points points\nReaction: ${reactionTime}ms';
        showMessage = true;
      });

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            round++;
            _generateNewRound();
          });
        }
      });
    } else {
      setState(() {
        message = '✗ Wrong! Target was $targetNumber';
        showMessage = true;
      });

      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          setState(() {
            round++;
            _generateNewRound();
          });
        }
      });
    }
  }

  void _resetGame() {
    setState(() {
      showDifficultyMenu = true;
      _initializeGame();
    });
  }

  Future<void> _submitScore() async {
    try {
      final avgReactionTime = round > 1 ? totalReactionTime ~/ (round - 1) : 0;
      final statistics = {
        'rounds': _getMaxRounds(),
        'bestReactionTime': bestReactionTime > 999999 ? 0 : bestReactionTime,
        'avgReactionTime': avgReactionTime,
      };

      await GameService.submitScore(
        'quick-tap',
        score,
        difficulty,
        statistics: statistics,
      );
    } catch (e) {
      AppLogger().error('Failed to submit quick tap score: $e');
    }
  }

  int _getMaxRounds() {
    return difficulty == 'easy'
        ? 5
        : difficulty == 'medium'
            ? 10
            : 15;
  }

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = MediaQuery.of(context).size.width < 500;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quick Tap'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
          tooltip: 'Back',
        ),
      ),
      body: showDifficultyMenu
          ? _buildDifficultyMenu()
          : Column(
              children: [
                // Score and Stats
                Padding(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatCard('Score', score.toString(), Colors.red),
                      _buildStatCard(
                        'Round',
                        gameOver
                            ? '${_getMaxRounds()}/${_getMaxRounds()}'
                            : '$round/${_getMaxRounds()}',
                        Colors.red,
                      ),
                      _buildStatCard(
                        'Best Time',
                        bestReactionTime > 999999
                            ? '--'
                            : '$bestReactionTime ms',
                        Colors.red,
                      ),
                    ],
                  ),
                ),

                // Game Content
                if (!gameOver)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Tap the number:',
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                            SizedBox(height: isSmallScreen ? 16 : 24),
                            Container(
                              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                              decoration: BoxDecoration(
                                color: Colors.red.shade100,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.red,
                                  width: 2,
                                ),
                              ),
                              child: Text(
                                targetNumber.toString(),
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 48 : 60,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 20 : 32),
                            if (showMessage)
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: message.startsWith('✓')
                                      ? Colors.green.shade100
                                      : Colors.red.shade100,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: message.startsWith('✓')
                                        ? Colors.green
                                        : Colors.red,
                                  ),
                                ),
                                child: Text(
                                  message,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: message.startsWith('✓')
                                        ? Colors.green
                                        : Colors.red,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              )
                            else
                              SizedBox(height: isSmallScreen ? 36 : 48),
                            SizedBox(height: isSmallScreen ? 20 : 32),
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 4,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
                              ),
                              itemCount: displayNumbers.length,
                              itemBuilder: (context, index) {
                                return GestureDetector(
                                  onTap: isProcessing
                                      ? null
                                      : () =>
                                          _onNumberTap(displayNumbers[index]),
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade400,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Center(
                                      child: Text(
                                        displayNumbers[index].toString(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.green,
                                  width: 2,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '🎉 Game Complete! 🎉',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 20 : 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                                  SizedBox(height: isSmallScreen ? 12 : 16),
                                  Text(
                                    'Final Score: $score',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 18 : 20,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Rounds Completed: ${_getMaxRounds()}/${_getMaxRounds()}',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 16 : 18,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Best Reaction: ${bestReactionTime > 999999 ? "--" : "${bestReactionTime}ms"}',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 16 : 18,
                                      color: Colors.green.shade700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 16 : 24),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: _resetGame,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Play Again'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.red.shade600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildDifficultyMenu() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 500;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24),
              child: Text(
                'Select Difficulty',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: isSmallScreen ? 24 : 32),
            _buildDifficultyButton(
              'Easy',
              '5 rounds',
              Colors.green,
              isSmallScreen,
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            _buildDifficultyButton(
              'Medium',
              '10 rounds',
              Colors.orange,
              isSmallScreen,
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            _buildDifficultyButton(
              'Hard',
              '15 rounds',
              Colors.red,
              isSmallScreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyButton(
    String label,
    String desc,
    Color color,
    bool isSmallScreen,
  ) {
    return GestureDetector(
      onTap: () => _startGame(label.toLowerCase()),
      child: Container(
        width: isSmallScreen ? 160 : 200,
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.7), color],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
            )
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: isSmallScreen ? 11 : 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: isSmallScreen ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 10 : 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Number Guessing Game
class NumberGuessingGame extends StatefulWidget {
  const NumberGuessingGame({super.key});

  @override
  State<NumberGuessingGame> createState() => _NumberGuessingGameState();
}

class _NumberGuessingGameState extends State<NumberGuessingGame> {
  late int secretNumber;
  late int guesses;
  late int score;
  int round = 1;
  bool gameOver = false;
  bool showDifficultyMenu = true;
  String difficulty = 'medium';
  String message = '';
  bool showMessage = false;
  TextEditingController guessController = TextEditingController();
  int minRange = 1;
  int maxRange = 100;
  List<int> previousGuesses = [];

  @override
  void initState() {
    super.initState();
  }

  void _startGame(String selectedDifficulty) {
    setState(() {
      showDifficultyMenu = false;
      difficulty = selectedDifficulty;
    });
    _initializeGame();
  }

  void _initializeGame() {
    minRange = difficulty == 'easy'
        ? 1
        : difficulty == 'medium'
            ? 1
            : 1;
    maxRange = difficulty == 'easy'
        ? 50
        : difficulty == 'medium'
            ? 100
            : 1000;

    secretNumber = minRange + Random().nextInt(maxRange - minRange + 1);
    guesses = 0;
    score = 0;
    round = 1;
    gameOver = false;
    message = '';
    showMessage = false;
    previousGuesses = [];
    guessController.clear();
  }

  void _makeGuess() {
    String input = guessController.text.trim();
    if (input.isEmpty) {
      setState(() {
        message = 'Please enter a number';
        showMessage = true;
      });
      return;
    }

    int? guess = int.tryParse(input);
    if (guess == null || guess < minRange || guess > maxRange) {
      setState(() {
        message = 'Enter a number between $minRange and $maxRange';
        showMessage = true;
      });
      return;
    }

    setState(() {
      guesses++;
      previousGuesses.add(guess);
    });

    if (guess == secretNumber) {
      // Correct guess!
      int points = (1000 - guesses * 50).clamp(0, 1000);
      setState(() {
        score += points;
        message = '✓ Correct! Secret number was $secretNumber\n+$points points';
        showMessage = true;
      });

      Future.delayed(const Duration(milliseconds: 2000), () {
        if (mounted) {
          _nextRound();
        }
      });
    } else if (guess < secretNumber) {
      setState(() {
        message = '📈 Too low! Try higher';
        showMessage = true;
        guessController.clear();
      });
    } else {
      setState(() {
        message = '📉 Too high! Try lower';
        showMessage = true;
        guessController.clear();
      });
    }
  }

  void _nextRound() {
    if (round <
        (difficulty == 'easy'
            ? 3
            : difficulty == 'medium'
                ? 5
                : 7)) {
      setState(() {
        round++;
        _initializeGame();
        round = round; // Preserve round count
      });
    } else {
      _endGame();
    }
  }

  void _endGame() {
    setState(() {
      gameOver = true;
      message = 'Game Complete!';
      showMessage = true;
    });
    _submitScore();
  }

  Future<void> _submitScore() async {
    try {
      final avgGuesses =
          guesses > 0 ? (guesses / round).toStringAsFixed(1) : '0';
      final statistics = {
        'totalRounds': round - 1,
        'totalGuesses': guesses,
        'avgGuessesPerRound': avgGuesses,
      };

      await GameService.submitScore(
        'number-guessing',
        score,
        difficulty,
        statistics: statistics,
      );
    } catch (e) {
      AppLogger().error('Failed to submit number guessing score: $e');
    }
  }

  void _resetGame() {
    setState(() {
      showDifficultyMenu = true;
      _initializeGame();
    });
    guessController.clear();
  }

  @override
  void dispose() {
    guessController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Number Guessing'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: showDifficultyMenu
          ? _buildDifficultyMenu()
          : Column(
              children: [
                // Score and Stats
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _buildStatCard('Score', score.toString(), Colors.teal),
                      _buildStatCard('Round', '$round', Colors.teal),
                      _buildStatCard(
                          'Guesses', guesses.toString(), Colors.teal),
                    ],
                  ),
                ),

                // Game Content
                Expanded(
                  child: gameOver ? _buildGameOverScreen() : _buildGameScreen(),
                ),
              ],
            ),
    );
  }

  Widget _buildDifficultyMenu() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 500;

    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding:
                  EdgeInsets.symmetric(horizontal: isSmallScreen ? 16 : 24),
              child: Text(
                'Select Difficulty',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: isSmallScreen ? 24 : 32),
            _buildDifficultyButton(
              'Easy',
              '1-50, 3 rounds',
              Colors.green,
              isSmallScreen,
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            _buildDifficultyButton(
              'Medium',
              '1-100, 5 rounds',
              Colors.teal,
              isSmallScreen,
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            _buildDifficultyButton(
              'Hard',
              '1-1000, 7 rounds',
              Colors.red,
              isSmallScreen,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDifficultyButton(
    String label,
    String desc,
    Color color,
    bool isSmallScreen,
  ) {
    return GestureDetector(
      onTap: () => _startGame(label.toLowerCase()),
      child: Container(
        width: isSmallScreen ? 160 : 200,
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withValues(alpha: 0.7), color],
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.3),
              blurRadius: 8,
            )
          ],
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              desc,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: isSmallScreen ? 11 : 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameScreen() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 500;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Guess the number between $minRange and $maxRange',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: isSmallScreen ? 16 : 24),
            if (previousGuesses.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Previous guesses:',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: previousGuesses.map((guess) {
                        return Chip(
                          label: Text(guess.toString()),
                          backgroundColor: guess < secretNumber
                              ? Colors.blue.shade100
                              : Colors.red.shade100,
                        );
                      }).toList(),
                    ),
                  ],
                ),
              )
            else
              SizedBox(height: isSmallScreen ? 36 : 48),
            SizedBox(height: isSmallScreen ? 16 : 24),
            if (showMessage)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: message.startsWith('✓')
                      ? Colors.green.shade100
                      : Colors.blue.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: message.startsWith('✓') ? Colors.green : Colors.blue,
                  ),
                ),
                child: Text(
                  message,
                  style: TextStyle(
                    color: message.startsWith('✓') ? Colors.green : Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              )
            else
              SizedBox(height: isSmallScreen ? 36 : 48),
            SizedBox(height: isSmallScreen ? 16 : 24),
            TextField(
              controller: guessController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter your guess',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey.shade100,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: isSmallScreen ? 12 : 16,
                ),
              ),
              onSubmitted: (_) => _makeGuess(),
            ),
            SizedBox(height: isSmallScreen ? 12 : 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _makeGuess,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade600,
                ),
                child: const Text('Guess'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameOverScreen() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 500;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 24),
              decoration: BoxDecoration(
                color: Colors.teal.shade100,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.teal, width: 2),
              ),
              child: Column(
                children: [
                  Text(
                    '🎉 Game Complete! 🎉',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 20 : 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isSmallScreen ? 12 : 16),
                  Text(
                    'Final Score: $score',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 18 : 20,
                      color: Colors.teal.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Rounds: ${round - 1}',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      color: Colors.teal.shade700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Guesses: $guesses',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      color: Colors.teal.shade700,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isSmallScreen ? 16 : 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _resetGame,
                icon: const Icon(Icons.refresh),
                label: const Text('Play Again'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: isSmallScreen ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: theme.cardTheme.color ?? theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 10 : 12,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
