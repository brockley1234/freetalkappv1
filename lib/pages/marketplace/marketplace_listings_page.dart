import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/marketplace_item_model.dart';
import '../../services/marketplace_service.dart';
import '../../config/api_config.dart';
import '../../utils/permission_helper.dart';
import 'marketplace_listing_detail_page.dart';
import 'create_marketplace_listing_page.dart';
import 'my_marketplace_listings_page.dart';

class MarketplaceListingsPage extends StatefulWidget {
  const MarketplaceListingsPage({super.key});

  @override
  State<MarketplaceListingsPage> createState() => _MarketplaceListingsPageState();
}

class _MarketplaceListingsPageState extends State<MarketplaceListingsPage> with SingleTickerProviderStateMixin {
  final MarketplaceService _marketplaceService = MarketplaceService();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late TabController _tabController;

  // Location state
  double? _userLatitude;
  double? _userLongitude;
  bool _locationPermissionGranted = false;
  bool _isLoadingLocation = false;
  bool _hasRequestedLocation = false; // Track if we've already tried to request location

  // Listings state
  List<MarketplaceItem> _allListings = [];
  List<MarketplaceItem> _localListings = [];
  List<MarketplaceItem> _farAwayListings = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  int _currentPage = 1;
  bool _hasMore = true;

  // Tab state
  int _currentTabIndex = 0; // 0 = Local, 1 = Far Away

  // Filters
  String? _selectedCategory;
  String? _selectedCondition;
  double? _minPrice;
  double? _maxPrice;
  String _sortBy = 'createdAt';
  String _sortOrder = 'desc';

  static const double _localDistanceKm = 50.0; // Items within 50km are considered "local"

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    // Don't request location in initState - wait for widget to be mounted
    _loadListings();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Request location permission after widget is fully built (only once)
    if (!_hasRequestedLocation && !_locationPermissionGranted && !_isLoadingLocation) {
      _hasRequestedLocation = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _requestLocationPermission();
        }
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index != _currentTabIndex) {
      setState(() {
        _currentTabIndex = _tabController.index;
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    if (!mounted) return;
    
    setState(() => _isLoadingLocation = true);
    
    try {
      if (!mounted) return;
      
      // On web, skip permission_handler and use Geolocator directly
      // Geolocator handles browser permissions automatically
      bool hasPermission = false;
      
      if (kIsWeb) {
        // On web, Geolocator will request permission through browser API
        // We can directly try to get location
        hasPermission = true;
      } else {
        // On mobile, use PermissionHelper
        hasPermission = await PermissionHelper.requestLocationPermission(
          context,
          purpose: 'show you nearby marketplace items',
        );
      }

      if (!mounted) return;

      if (hasPermission) {
        await _getCurrentLocation();
      } else {
        setState(() {
          _locationPermissionGranted = false;
          _isLoadingLocation = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permission is required to see nearby items'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _locationPermissionGranted = false;
          _isLoadingLocation = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error requesting location: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      // On web, Geolocator.getCurrentPosition() will automatically request permission
      // On mobile, we need to check service and permission status first
      if (!kIsWeb) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location services are disabled. Please enable them to see local items.')),
            );
          }
          setState(() {
            _locationPermissionGranted = false;
            _isLoadingLocation = false;
          });
          return;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
          if (permission == LocationPermission.denied) {
            setState(() {
              _locationPermissionGranted = false;
              _isLoadingLocation = false;
            });
            return;
          }
        }

        if (permission == LocationPermission.deniedForever) {
          setState(() {
            _locationPermissionGranted = false;
            _isLoadingLocation = false;
          });
          return;
        }
      } else {
        // On web, check if we're on HTTPS or localhost (required for geolocation API)
        final uri = Uri.base;
        final isSecure = uri.scheme == 'https' || uri.host == 'localhost' || uri.host == '127.0.0.1';
        
        if (!isSecure) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location requires HTTPS. Marketplace will show all items without location filtering.'),
                duration: Duration(seconds: 4),
              ),
            );
          }
          setState(() {
            _locationPermissionGranted = false;
            _isLoadingLocation = false;
          });
          return;
        }
      }

      // Get current position (works on both web and mobile)
      // Use timeout to prevent hanging
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Location request timed out. Please try again.');
        },
      );

      setState(() {
        _userLatitude = position.latitude;
        _userLongitude = position.longitude;
        _locationPermissionGranted = true;
        _isLoadingLocation = false;
      });

      // Reload listings with location
      _refreshListings();
    } catch (e) {
      setState(() {
        _locationPermissionGranted = false;
        _isLoadingLocation = false;
      });
      
      // Provide user-friendly error messages
      String errorMessage = 'Unable to get location';
      
      if (kIsWeb) {
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('missing plugin') || errorString.contains('no implementation')) {
          errorMessage = 'Location feature is not available in this browser. Marketplace will show all items.';
        } else if (errorString.contains('permission denied') || errorString.contains('denied')) {
          errorMessage = 'Location permission denied. Please allow location access in your browser settings.';
        } else if (errorString.contains('timeout')) {
          errorMessage = 'Location request timed out. Please check your browser settings and try again.';
        } else {
          errorMessage = 'Location unavailable. Marketplace will show all items without location filtering.';
        }
      } else {
        final errorString = e.toString().toLowerCase();
        if (errorString.contains('permission denied')) {
          errorMessage = 'Location permission denied. Please enable location access in settings.';
        } else if (errorString.contains('timeout')) {
          errorMessage = 'Location request timed out. Please check your location settings.';
        } else {
          errorMessage = 'Error getting location: ${e.toString()}';
        }
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      if (!_isLoadingMore && _hasMore) {
        _loadMoreListings();
      }
    }
  }

  void _onSearchChanged() {
    // Debounce search
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted && _searchController.text == _searchController.text) {
        _refreshListings();
      }
    });
  }

  void _categorizeListings() {
    if (_userLatitude == null || _userLongitude == null) {
      // No location - show all items in both tabs
      _localListings = [];
      _farAwayListings = _allListings;
      return;
    }

    _localListings = [];
    _farAwayListings = [];

    for (var item in _allListings) {
      if (item.distance != null) {
        if (item.distance! <= _localDistanceKm) {
          _localListings.add(item);
        } else {
          _farAwayListings.add(item);
        }
      } else {
        // Items without location go to far away
        _farAwayListings.add(item);
      }
    }
  }

  Future<void> _loadListings({bool refresh = false}) async {
    if (refresh) {
      _currentPage = 1;
      _allListings = [];
      _localListings = [];
      _farAwayListings = [];
      _hasMore = true;
    }

    setState(() => _isLoading = refresh);

    try {
      final result = await _marketplaceService.getListings(
        page: _currentPage,
        limit: 20,
        search: _searchController.text.isNotEmpty ? _searchController.text : null,
        category: _selectedCategory == 'all' ? null : _selectedCategory,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        condition: _selectedCondition,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
        latitude: _userLatitude,
        longitude: _userLongitude,
        // Don't set maxDistance - we want all items to calculate distance
      );

      setState(() {
        if (refresh) {
          _allListings = result['items'] as List<MarketplaceItem>;
        } else {
          _allListings.addAll(result['items'] as List<MarketplaceItem>);
        }
        _hasMore = result['pagination']['page'] < result['pagination']['pages'];
        _isLoading = false;
        _isLoadingMore = false;
      });

      _categorizeListings();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _isLoadingMore = false;
      });
      if (mounted) {
        String errorMessage = 'Error loading listings';
        if (e is MarketplaceException) {
          errorMessage = e.userMessage;
        } else {
          errorMessage = e.toString().replaceAll('Exception: ', '');
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

  Future<void> _loadMoreListings() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
      _currentPage++;
    });

    await _loadListings();
  }

  Future<void> _refreshListings() async {
    await _loadListings(refresh: true);
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _FiltersBottomSheet(
        selectedCategory: _selectedCategory,
        selectedCondition: _selectedCondition,
        minPrice: _minPrice,
        maxPrice: _maxPrice,
        sortBy: _sortBy,
        sortOrder: _sortOrder,
        onApply: (category, condition, minPrice, maxPrice, sortBy, sortOrder) {
          setState(() {
            _selectedCategory = category;
            _selectedCondition = condition;
            _minPrice = minPrice;
            _maxPrice = maxPrice;
            _sortBy = sortBy;
            _sortOrder = sortOrder;
          });
          _refreshListings();
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.near_me, size: 18),
                  const SizedBox(width: 4),
                  Text('Local (${_localListings.length})'),
                ],
              ),
            ),
            Tab(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.public, size: 18),
                  const SizedBox(width: 4),
                  Text('Far Away (${_farAwayListings.length})'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_isLoadingLocation)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else if (!_locationPermissionGranted)
            IconButton(
              icon: const Icon(Icons.location_off),
              tooltip: 'Enable location to see local items',
              onPressed: _requestLocationPermission,
            ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFilters,
          ),
          IconButton(
            icon: const Icon(Icons.shopping_bag),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const MyMarketplaceListingsPage(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search marketplace...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _refreshListings();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          // Active filters
          if (_selectedCategory != null ||
              _selectedCondition != null ||
              _minPrice != null ||
              _maxPrice != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  if (_selectedCategory != null)
                    Chip(
                      label: Text('Category: $_selectedCategory'),
                      onDeleted: () {
                        setState(() => _selectedCategory = null);
                        _refreshListings();
                      },
                    ),
                  if (_selectedCondition != null)
                    Chip(
                      label: Text('Condition: $_selectedCondition'),
                      onDeleted: () {
                        setState(() => _selectedCondition = null);
                        _refreshListings();
                      },
                    ),
                  if (_minPrice != null || _maxPrice != null)
                    Chip(
                      label: Text(
                          'Price: \$${_minPrice ?? 0} - \$${_maxPrice ?? '∞'}'),
                      onDeleted: () {
                        setState(() {
                          _minPrice = null;
                          _maxPrice = null;
                        });
                        _refreshListings();
                      },
                    ),
                ],
              ),
            ),
          // Listings
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildListingsTab(_localListings, isLocal: true),
                _buildListingsTab(_farAwayListings, isLocal: false),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateMarketplaceListingPage(),
            ),
          ).then((_) => _refreshListings());
        },
        icon: const Icon(Icons.add),
        label: const Text('Sell Item'),
      ),
    );
  }

  Widget _buildListingsTab(List<MarketplaceItem> listings, {required bool isLocal}) {
    if (_isLoading && listings.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (listings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLocal ? Icons.near_me_outlined : Icons.public_outlined,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              isLocal
                  ? 'No local listings found'
                  : 'No listings found',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            if (isLocal && !_locationPermissionGranted) ...[
              const SizedBox(height: 8),
              const Text(
                'Enable location to see nearby items',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _requestLocationPermission,
                icon: const Icon(Icons.location_on),
                label: const Text('Enable Location'),
              ),
            ] else if (isLocal && _userLatitude == null) ...[
              const SizedBox(height: 8),
              const Text(
                'Getting your location...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _refreshListings,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refreshListings,
      child: GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.all(8),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 8,
          mainAxisSpacing: 8,
          childAspectRatio: 0.75,
        ),
        itemCount: listings.length + (_isLoadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == listings.length) {
            return const Center(child: CircularProgressIndicator());
          }
          return _MarketplaceItemCard(
            item: listings[index],
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MarketplaceListingDetailPage(
                    listingId: listings[index].id,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _MarketplaceItemCard extends StatelessWidget {
  final MarketplaceItem item;
  final VoidCallback onTap;

  const _MarketplaceItemCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            Expanded(
              flex: 3,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  CachedNetworkImage(
                    imageUrl: item.images.isNotEmpty
                        ? '${ApiConfig.baseUrl}${item.images[0]}'
                        : 'https://via.placeholder.com/300',
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.image_not_supported),
                    ),
                  ),
                  if (item.status != 'active')
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          item.status.toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  // Distance badge
                  if (item.distance != null)
                    Positioned(
                      bottom: 4,
                      left: 4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 12,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              item.distanceDisplay,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Info
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '\$${item.price.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                    Text(
                      item.conditionDisplayName,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FiltersBottomSheet extends StatefulWidget {
  final String? selectedCategory;
  final String? selectedCondition;
  final double? minPrice;
  final double? maxPrice;
  final String sortBy;
  final String sortOrder;
  final Function(String?, String?, double?, double?, String, String) onApply;

  const _FiltersBottomSheet({
    required this.selectedCategory,
    required this.selectedCondition,
    required this.minPrice,
    required this.maxPrice,
    required this.sortBy,
    required this.sortOrder,
    required this.onApply,
  });

  @override
  State<_FiltersBottomSheet> createState() => _FiltersBottomSheetState();
}

class _FiltersBottomSheetState extends State<_FiltersBottomSheet> {
  late String? _category;
  late String? _condition;
  late double? _minPrice;
  late double? _maxPrice;
  late String _sortBy;
  late String _sortOrder;
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _category = widget.selectedCategory;
    _condition = widget.selectedCondition;
    _minPrice = widget.minPrice;
    _maxPrice = widget.maxPrice;
    _sortBy = widget.sortBy;
    _sortOrder = widget.sortOrder;
    _minPriceController.text = _minPrice?.toString() ?? '';
    _maxPriceController.text = _maxPrice?.toString() ?? '';
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Filters', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  setState(() {
                    _category = null;
                    _condition = null;
                    _minPrice = null;
                    _maxPrice = null;
                    _sortBy = 'createdAt';
                    _sortOrder = 'desc';
                    _minPriceController.clear();
                    _maxPriceController.clear();
                  });
                },
                child: const Text('Clear All'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Category', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['all', 'electronics', 'clothing', 'furniture', 'vehicles', 'books', 'toys', 'sports', 'home', 'tools', 'collectibles', 'other']
                .map((cat) => FilterChip(
                      label: Text(cat == 'all' ? 'All' : cat.substring(0, 1).toUpperCase() + cat.substring(1)),
                      selected: _category == cat,
                      onSelected: (selected) {
                        setState(() => _category = selected ? cat : null);
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          const Text('Condition', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: ['new', 'like_new', 'excellent', 'good', 'fair', 'poor']
                .map((cond) => FilterChip(
                      label: Text(cond.split('_').map((e) => e[0].toUpperCase() + e.substring(1)).join(' ')),
                      selected: _condition == cond,
                      onSelected: (selected) {
                        setState(() => _condition = selected ? cond : null);
                      },
                    ))
                .toList(),
          ),
          const SizedBox(height: 16),
          const Text('Price Range', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Min Price',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: TextField(
                  controller: _maxPriceController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Max Price',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('Sort By', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              FilterChip(
                label: const Text('Newest'),
                selected: _sortBy == 'createdAt' && _sortOrder == 'desc',
                onSelected: (_) {
                  setState(() {
                    _sortBy = 'createdAt';
                    _sortOrder = 'desc';
                  });
                },
              ),
              FilterChip(
                label: const Text('Oldest'),
                selected: _sortBy == 'createdAt' && _sortOrder == 'asc',
                onSelected: (_) {
                  setState(() {
                    _sortBy = 'createdAt';
                    _sortOrder = 'asc';
                  });
                },
              ),
              FilterChip(
                label: const Text('Price: Low to High'),
                selected: _sortBy == 'price' && _sortOrder == 'asc',
                onSelected: (_) {
                  setState(() {
                    _sortBy = 'price';
                    _sortOrder = 'asc';
                  });
                },
              ),
              FilterChip(
                label: const Text('Price: High to Low'),
                selected: _sortBy == 'price' && _sortOrder == 'desc',
                onSelected: (_) {
                  setState(() {
                    _sortBy = 'price';
                    _sortOrder = 'desc';
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final minPrice = _minPriceController.text.isNotEmpty
                    ? double.tryParse(_minPriceController.text)
                    : null;
                final maxPrice = _maxPriceController.text.isNotEmpty
                    ? double.tryParse(_maxPriceController.text)
                    : null;
                widget.onApply(_category, _condition, minPrice, maxPrice, _sortBy, _sortOrder);
              },
              child: const Text('Apply Filters'),
            ),
          ),
        ],
      ),
    );
  }
}
