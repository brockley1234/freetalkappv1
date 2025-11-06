import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/marketplace_item_model.dart';
import '../../services/marketplace_service.dart';
import '../../config/api_config.dart';
import '../../utils/auth_storage.dart';
import '../../utils/permission_helper.dart';
import '../chat_page.dart';

class MarketplaceListingDetailPage extends StatefulWidget {
  final String listingId;

  const MarketplaceListingDetailPage({super.key, required this.listingId});

  @override
  State<MarketplaceListingDetailPage> createState() => _MarketplaceListingDetailPageState();
}

class _MarketplaceListingDetailPageState extends State<MarketplaceListingDetailPage> {
  final MarketplaceService _marketplaceService = MarketplaceService();
  MarketplaceItem? _item;
  bool _isLoading = true;
  String? _currentUserId;
  int _currentImageIndex = 0;
  final TextEditingController _inquiryController = TextEditingController();
  bool _isLiked = false;
  double? _userLatitude;
  double? _userLongitude;

  @override
  void initState() {
    super.initState();
    _loadListing();
    // Get location after widget is fully built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
    });
  }

  @override
  void dispose() {
    _inquiryController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      final hasPermission = await PermissionHelper.requestLocationPermission(
        context,
        purpose: 'show distance to this item',
      );
      if (!hasPermission) return;

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
        ),
      );

      setState(() {
        _userLatitude = position.latitude;
        _userLongitude = position.longitude;
      });

      // Reload listing with location to get distance
      await _loadListing();
    } catch (e) {
      // Silently fail - location is optional
    }
  }

  Future<void> _loadListing() async {
    setState(() => _isLoading = true);
    _currentUserId = await AuthStorage.getUserId();
    try {
      final item = await _marketplaceService.getListing(
        widget.listingId,
        latitude: _userLatitude,
        longitude: _userLongitude,
      );
      setState(() {
        _item = item;
        _isLiked = item.isLiked;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        String errorMessage = 'Error loading listing';
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
        Navigator.pop(context);
      }
    }
  }

  Future<void> _toggleLike() async {
    if (_item == null) return;
    try {
      final result = await _marketplaceService.toggleLike(_item!.id);
      setState(() {
        _isLiked = result['isLiked'] as bool;
        // Update item's likes count if needed
        if (_item != null) {
          _item = MarketplaceItem(
            id: _item!.id,
            title: _item!.title,
            description: _item!.description,
            sellerId: _item!.sellerId,
            sellerName: _item!.sellerName,
            sellerAvatar: _item!.sellerAvatar,
            category: _item!.category,
            condition: _item!.condition,
            price: _item!.price,
            currency: _item!.currency,
            images: _item!.images,
            location: _item!.location,
            shippingAvailable: _item!.shippingAvailable,
            shippingCost: _item!.shippingCost,
            localPickupOnly: _item!.localPickupOnly,
            quantity: _item!.quantity,
            status: _item!.status,
            purchasedById: _item!.purchasedById,
            purchasedByName: _item!.purchasedByName,
            views: _item!.views,
            likes: _item!.likes, // Will be updated from item refresh
            isLiked: _isLiked,
            createdAt: _item!.createdAt,
            updatedAt: _item!.updatedAt,
            tags: _item!.tags,
            distance: _item!.distance,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        String errorMessage = 'An error occurred';
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

  Future<void> _sendInquiry() async {
    if (_item == null || _inquiryController.text.trim().isEmpty) return;

    try {
      final conversationId = await _marketplaceService.sendInquiry(
        _item!.id,
        _inquiryController.text.trim(),
      );

      if (mounted) {
        _inquiryController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Inquiry sent! Check your messages.')),
        );
        
        // Create a Map representation of the seller for ChatPage
        final otherUserMap = {
          '_id': _item!.sellerId,
          'name': _item!.sellerName ?? 'Unknown',
          'avatar': _item!.sellerAvatar,
          'profilePicture': _item!.sellerAvatar,
        };
        
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatPage(
              conversationId: conversationId,
              otherUser: otherUserMap,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Error sending inquiry';
        String? details;
        if (e is MarketplaceException) {
          errorMessage = e.userMessage;
          if (e.details != null && e.details!['errors'] != null) {
            details = e.details!['errors'].toString();
          }
        } else {
          errorMessage = e.toString().replaceAll('Exception: ', '');
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  errorMessage,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                if (details != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    details,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _purchaseItem(String paymentMethod) async {
    if (_item == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Purchase Item'),
        content: Text('Purchase "${_item!.title}" for \$${_item!.totalPrice.toStringAsFixed(2)}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Purchase'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final result = await _marketplaceService.purchaseListing(_item!.id, paymentMethod);
      
      if (mounted) {
        if (paymentMethod == 'stripe' && result['clientSecret'] != null) {
          // Handle Stripe payment flow
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Payment intent created. Complete payment in Stripe.')),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Purchase request sent. Waiting for seller confirmation.')),
          );
        }
        _loadListing(); // Refresh to show updated status
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'An error occurred';
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

  void _showPurchaseOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Choose Payment Method', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.money),
              title: const Text('Cash (Local Pickup)'),
              subtitle: const Text('Pay in person when picking up'),
              onTap: () {
                Navigator.pop(context);
                _purchaseItem('cash');
              },
            ),
            if (_item?.shippingAvailable == true)
              ListTile(
                leading: const Icon(Icons.local_shipping),
                title: const Text('Stripe (Card Payment)'),
                subtitle: const Text('Pay securely with card'),
                onTap: () {
                  Navigator.pop(context);
                  _purchaseItem('stripe');
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Listing')),
        body: const Center(child: Text('Listing not found')),
      );
    }

    final isOwner = _currentUserId == _item!.sellerId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Marketplace'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              Share.share('Check out "${_item!.title}" on FreeTalk Marketplace!');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image carousel
            if (_item!.images.isNotEmpty)
              SizedBox(
                height: 300,
                child: PageView.builder(
                  itemCount: _item!.images.length,
                  controller: PageController(initialPage: _currentImageIndex),
                  onPageChanged: (index) {
                    setState(() => _currentImageIndex = index);
                  },
                  itemBuilder: (context, index) {
                    return CachedNetworkImage(
                      imageUrl: '${ApiConfig.baseUrl}${_item!.images[index]}',
                      fit: BoxFit.cover,
                      placeholder: (context, url) => Container(
                        color: Colors.grey[200],
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[200],
                        child: const Icon(Icons.image_not_supported),
                      ),
                    );
                  },
                ),
              ),
            if (_item!.images.length > 1)
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_item!.images.length, (index) {
                    return Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentImageIndex == index
                            ? Theme.of(context).primaryColor
                            : Colors.grey,
                      ),
                    );
                  }),
                ),
              ),

            // Info section
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and price
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          _item!.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        '\$${_item!.price.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Chip(
                        label: Text(_item!.categoryDisplayName),
                        avatar: const Icon(Icons.category, size: 18),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(_item!.conditionDisplayName),
                        avatar: const Icon(Icons.star, size: 18),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Description
                  const Text(
                    'Description',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _item!.description,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),

                  // Location
                  if (_item!.location != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, color: Theme.of(context).primaryColor),
                            const SizedBox(width: 8),
                            const Text(
                              'Location',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _item!.location!.displayString,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    if (_item!.location!.city != null ||
                                        _item!.location!.state != null)
                                      Text(
                                        _item!.location!.city != null &&
                                                _item!.location!.state != null
                                            ? '${_item!.location!.city}, ${_item!.location!.state}'
                                            : _item!.location!.city ?? _item!.location!.state ?? '',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              if (_item!.distance != null) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.near_me,
                                        size: 16,
                                        color: Colors.blue[700],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _item!.distanceDisplay,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.blue[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),

                  // Shipping info
                  if (_item!.shippingAvailable)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.local_shipping),
                            const SizedBox(width: 8),
                            Text('Shipping: \$${_item!.shippingCost.toStringAsFixed(2)}'),
                          ],
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  if (_item!.localPickupOnly)
                    const Row(
                      children: [
                        Icon(Icons.directions_walk),
                        SizedBox(width: 8),
                        Text('Local Pickup Only'),
                      ],
                    ),

                  // Seller info
                  const SizedBox(height: 16),
                  const Text(
                    'Seller',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundImage: _item!.sellerAvatar != null
                          ? CachedNetworkImageProvider('${ApiConfig.baseUrl}${_item!.sellerAvatar}')
                          : null,
                      child: _item!.sellerAvatar == null
                          ? const Icon(Icons.person)
                          : null,
                    ),
                    title: Text(_item!.sellerName ?? 'Unknown'),
                    subtitle: Text('${_item!.views} views'),
                  ),

                  // Status badge
                  if (_item!.status != 'active')
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.only(top: 16),
                      decoration: BoxDecoration(
                        color: Colors.orange[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.info),
                          const SizedBox(width: 8),
                          Text('Status: ${_item!.status.toUpperCase()}'),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isOwner
          ? null
          : _item!.isAvailable
              ? Container(
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
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Primary action buttons
                      Row(
                        children: [
                          // Message Seller button - Primary action
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Row(
                                      children: [
                                        Icon(Icons.message, color: Colors.blue),
                                        SizedBox(width: 8),
                                        Text('Message Seller'),
                                      ],
                                    ),
                                    content: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Ask ${_item!.sellerName ?? 'the seller'} about "${_item!.title}"',
                                          style: const TextStyle(fontWeight: FontWeight.bold),
                                        ),
                                        const SizedBox(height: 16),
                                        TextField(
                                          controller: _inquiryController,
                                          decoration: const InputDecoration(
                                            hintText: 'Hi! I\'m interested in this item. Could you tell me more about it?',
                                            border: OutlineInputBorder(),
                                            labelText: 'Your message',
                                          ),
                                          maxLines: 4,
                                          autofocus: true,
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          'This will start a conversation with the seller.',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          _inquiryController.clear();
                                          Navigator.pop(context);
                                        },
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed: () {
                                          if (_inquiryController.text.trim().isEmpty) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Please enter a message'),
                                              ),
                                            );
                                            return;
                                          }
                                          Navigator.pop(context);
                                          _sendInquiry();
                                        },
                                        icon: const Icon(Icons.send, size: 18),
                                        label: const Text('Send Message'),
                                      ),
                                    ],
                                  ),
                                );
                              },
                              icon: const Icon(Icons.message, size: 20),
                              label: const Text('Message Seller'),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                backgroundColor: Theme.of(context).primaryColor,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Like button
                          IconButton(
                            icon: Icon(_isLiked ? Icons.favorite : Icons.favorite_border),
                            color: _isLiked ? Colors.red : null,
                            onPressed: _toggleLike,
                            tooltip: _isLiked ? 'Unlike' : 'Like',
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Buy button - Secondary action
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _showPurchaseOptions,
                          icon: const Icon(Icons.shopping_cart),
                          label: Text('Buy Now - \$${_item!.totalPrice.toStringAsFixed(2)}'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              : Container(
                  padding: const EdgeInsets.all(16),
                  child: const Text(
                    'This item is no longer available',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),
    );
  }
}

