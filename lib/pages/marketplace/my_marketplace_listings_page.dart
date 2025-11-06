import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../models/marketplace_item_model.dart';
import '../../services/marketplace_service.dart';
import '../../config/api_config.dart';
import 'marketplace_listing_detail_page.dart';
import 'create_marketplace_listing_page.dart';

class MyMarketplaceListingsPage extends StatefulWidget {
  const MyMarketplaceListingsPage({super.key});

  @override
  State<MyMarketplaceListingsPage> createState() => _MyMarketplaceListingsPageState();
}

class _MyMarketplaceListingsPageState extends State<MyMarketplaceListingsPage> {
  final MarketplaceService _marketplaceService = MarketplaceService();
  List<MarketplaceItem> _listings = [];
  bool _isLoading = false;
  String? _selectedStatus;

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  Future<void> _loadListings() async {
    setState(() => _isLoading = true);
    try {
      final result = await _marketplaceService.getMyListings(
        status: _selectedStatus,
      );
      setState(() {
        _listings = result['items'] as List<MarketplaceItem>;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
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

  Future<void> _deleteListing(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove Listing'),
        content: const Text('Are you sure you want to remove this listing?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _marketplaceService.deleteListing(id);
        _loadListings();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Listing removed')),
          );
        }
      } catch (e) {
        if (mounted) {
          String errorMessage = 'Error deleting listing';
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Listings'),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              setState(() {
                _selectedStatus = value == 'all' ? null : value;
              });
              _loadListings();
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'all', child: Text('All')),
              const PopupMenuItem(value: 'active', child: Text('Active')),
              const PopupMenuItem(value: 'pending', child: Text('Pending')),
              const PopupMenuItem(value: 'sold', child: Text('Sold')),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _listings.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('No listings yet'),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreateMarketplaceListingPage(),
                            ),
                          ).then((_) => _loadListings());
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('Create Listing'),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  itemCount: _listings.length,
                  itemBuilder: (context, index) {
                    final item = _listings[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: ListTile(
                        leading: item.images.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: '${ApiConfig.baseUrl}${item.images[0]}',
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey[200],
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey[200],
                                    child: const Icon(Icons.image_not_supported),
                                  ),
                                ),
                              )
                            : Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.image),
                              ),
                        title: Text(item.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('\$${item.price.toStringAsFixed(2)}'),
                            Text(
                              'Status: ${item.status.toUpperCase()}',
                              style: TextStyle(
                                color: item.status == 'active'
                                    ? Colors.green
                                    : item.status == 'sold'
                                        ? Colors.blue
                                        : Colors.orange,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        trailing: PopupMenuButton(
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'view',
                              child: Row(
                                children: [
                                  Icon(Icons.visibility),
                                  SizedBox(width: 8),
                                  Text('View'),
                                ],
                              ),
                            ),
                            if (item.status == 'pending' && item.purchasedById != null)
                              const PopupMenuItem(
                                value: 'confirm',
                                child: Row(
                                  children: [
                                    Icon(Icons.check_circle),
                                    SizedBox(width: 8),
                                    Text('Confirm Purchase'),
                                  ],
                                ),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Row(
                                children: [
                                  Icon(Icons.delete, color: Colors.red),
                                  SizedBox(width: 8),
                                  Text('Remove', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                          onSelected: (value) async {
                            if (value == 'view') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => MarketplaceListingDetailPage(
                                    listingId: item.id,
                                  ),
                                ),
                              );
                            } else if (value == 'confirm') {
                              if (!mounted) return;
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                await _marketplaceService.confirmPurchase(item.id);
                                _loadListings();
                                if (mounted) {
                                  messenger.showSnackBar(
                                    const SnackBar(content: Text('Purchase confirmed')),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  String errorMessage = 'Error confirming purchase';
                                  if (e is MarketplaceException) {
                                    errorMessage = e.userMessage;
                                  } else {
                                    errorMessage = e.toString().replaceAll('Exception: ', '');
                                  }
                                  messenger.showSnackBar(
                                    SnackBar(
                                      content: Text(errorMessage),
                                      backgroundColor: Colors.red,
                                      duration: const Duration(seconds: 4),
                                    ),
                                  );
                                }
                              }
                            } else if (value == 'delete') {
                              _deleteListing(item.id);
                            }
                          },
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MarketplaceListingDetailPage(
                                listingId: item.id,
                              ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const CreateMarketplaceListingPage(),
            ),
          ).then((_) => _loadListings());
        },
        icon: const Icon(Icons.add),
        label: const Text('Sell Item'),
      ),
    );
  }
}

