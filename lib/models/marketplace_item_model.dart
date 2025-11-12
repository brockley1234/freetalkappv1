class MarketplaceItem {
  final String id;
  final String title;
  final String description;
  final String sellerId;
  final String? sellerName;
  final String? sellerAvatar;
  final String category;
  final String condition;
  final double price;
  final String currency;
  final List<String> images;
  final MarketplaceLocation? location;
  final bool shippingAvailable;
  final double shippingCost;
  final bool localPickupOnly;
  final int quantity;
  final String status;
  final String? purchasedById;
  final String? purchasedByName;
  final int views;
  final List<String> likes;
  final bool isLiked;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<String> tags;
  final double? distance; // Distance in kilometers from user's location (null if not calculated)

  MarketplaceItem({
    required this.id,
    required this.title,
    required this.description,
    required this.sellerId,
    this.sellerName,
    this.sellerAvatar,
    required this.category,
    required this.condition,
    required this.price,
    this.currency = 'USD',
    required this.images,
    this.location,
    this.shippingAvailable = false,
    this.shippingCost = 0,
    this.localPickupOnly = false,
    this.quantity = 1,
    this.status = 'active',
    this.purchasedById,
    this.purchasedByName,
    this.views = 0,
    this.likes = const [],
    this.isLiked = false,
    required this.createdAt,
    required this.updatedAt,
    this.tags = const [],
    this.distance,
  });

  factory MarketplaceItem.fromJson(Map<String, dynamic> json) {
    return MarketplaceItem(
      id: json['_id'] ?? json['id'],
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      sellerId: json['seller'] is String 
          ? json['seller'] as String
          : (json['seller'] as Map<String, dynamic>?)?['_id'] ?? 
            (json['seller'] as Map<String, dynamic>?)?['id'] ?? '',
      sellerName: json['seller'] is Map 
          ? (json['seller'] as Map<String, dynamic>)['name'] as String?
          : null,
      sellerAvatar: json['seller'] is Map 
          ? (json['seller'] as Map<String, dynamic>)['avatar'] as String?
          : null,
      category: json['category'] ?? 'other',
      condition: json['condition'] ?? 'good',
      price: (json['price'] ?? 0).toDouble(),
      currency: json['currency'] ?? 'USD',
      images: json['images'] != null 
          ? List<String>.from(json['images']) 
          : [],
      location: json['location'] != null 
          ? MarketplaceLocation.fromJson(json['location']) 
          : null,
      shippingAvailable: json['shippingAvailable'] ?? false,
      shippingCost: (json['shippingCost'] ?? 0).toDouble(),
      localPickupOnly: json['localPickupOnly'] ?? false,
      quantity: json['quantity'] ?? 1,
      status: json['status'] ?? 'active',
      purchasedById: json['purchasedBy'] is String 
          ? json['purchasedBy'] as String
          : (json['purchasedBy'] as Map<String, dynamic>?)?['_id'] ?? 
            (json['purchasedBy'] as Map<String, dynamic>?)?['id'],
      purchasedByName: json['purchasedBy'] is Map 
          ? (json['purchasedBy'] as Map<String, dynamic>)['name'] as String?
          : null,
      views: json['views'] ?? 0,
      likes: json['likes'] != null && json['likes'] is List
          ? List<String>.from((json['likes'] as List).map((like) {
              if (like is String) return like;
              if (like is Map) {
                final likeMap = like as Map<String, dynamic>?;
                return likeMap?['_id'] ?? likeMap?['id'] ?? '';
              }
              return '';
            }))
          : [],
      isLiked: json['isLiked'] ?? false,
      createdAt: json['createdAt'] != null 
          ? DateTime.parse(json['createdAt']) 
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt']) 
          : DateTime.now(),
      tags: json['tags'] != null 
          ? List<String>.from(json['tags']) 
          : [],
      distance: json['distance'] != null ? (json['distance'] as num).toDouble() : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'sellerId': sellerId,
      'category': category,
      'condition': condition,
      'price': price,
      'currency': currency,
      'images': images,
      'location': location?.toJson(),
      'shippingAvailable': shippingAvailable,
      'shippingCost': shippingCost,
      'localPickupOnly': localPickupOnly,
      'quantity': quantity,
      'status': status,
      'tags': tags,
    };
  }

  bool get isAvailable => status == 'active' && quantity > 0;
  double get totalPrice => price + (shippingAvailable ? shippingCost : 0);
  
  String get distanceDisplay {
    if (distance == null) return '';
    if (distance! < 1) {
      return '${(distance! * 1000).toStringAsFixed(0)}m away';
    } else if (distance! < 100) {
      return '${distance!.toStringAsFixed(1)}km away';
    } else {
      return '${distance!.toStringAsFixed(0)}km away';
    }
  }
  
  String get conditionDisplayName {
    switch (condition) {
      case 'new': return 'New';
      case 'like_new': return 'Like New';
      case 'excellent': return 'Excellent';
      case 'good': return 'Good';
      case 'fair': return 'Fair';
      case 'poor': return 'Poor';
      default: return condition;
    }
  }
  
  String get categoryDisplayName {
    switch (category) {
      case 'electronics': return 'Electronics';
      case 'clothing': return 'Clothing';
      case 'furniture': return 'Furniture';
      case 'vehicles': return 'Vehicles';
      case 'books': return 'Books';
      case 'toys': return 'Toys';
      case 'sports': return 'Sports';
      case 'home': return 'Home & Garden';
      case 'tools': return 'Tools';
      case 'collectibles': return 'Collectibles';
      case 'other': return 'Other';
      default: return category;
    }
  }
}

class MarketplaceLocation {
  final String? city;
  final String? state;
  final String? country;
  final String? zipCode;
  final double? latitude;
  final double? longitude;

  MarketplaceLocation({
    this.city,
    this.state,
    this.country,
    this.zipCode,
    this.latitude,
    this.longitude,
  });

  factory MarketplaceLocation.fromJson(Map<String, dynamic> json) {
    return MarketplaceLocation(
      city: json['city'],
      state: json['state'],
      country: json['country'],
      zipCode: json['zipCode'],
      latitude: json['latitude']?.toDouble(),
      longitude: json['longitude']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'city': city,
      'state': state,
      'country': country,
      'zipCode': zipCode,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  String get displayString {
    final parts = <String>[];
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (state != null && state!.isNotEmpty) parts.add(state!);
    if (zipCode != null && zipCode!.isNotEmpty) parts.add(zipCode!);
    // City, state, and zip code are now required, so this should always have content
    return parts.isEmpty ? 'Location not specified' : parts.join(', ');
  }
}

