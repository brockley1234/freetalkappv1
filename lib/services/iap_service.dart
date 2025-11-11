import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:in_app_purchase/in_app_purchase.dart';
import 'api_service.dart';

/// Compliant In-App Purchase Service for both iOS and Android
/// Follows Apple App Store and Google Play Store guidelines
///
/// IMPORTANT: This service handles the client-side purchase flow.
/// You MUST verify all purchases on your backend server before granting access.
///
/// NOTE: IAP is NOT supported on web platforms
class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  // Only initialize IAP on supported platforms (iOS/Android)
  InAppPurchase? _iap;
  InAppPurchase get iapInstance => _iap ?? InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  // Purchase state
  bool _isAvailable = false;
  bool _isInitializing = false;
  bool _isRestoring = false;
  List<ProductDetails> _products = [];
  final List<PurchaseDetails> _purchases = [];
  final Set<String> _verifyingPurchases = {}; // Track purchases being verified to prevent duplicates
  Set<String>? _purchaseIdsCache; // Cache purchase IDs for O(1) lookups

  // Product IDs - Must match App Store Connect and Play Console
  // Updated Product IDs (old ones were reserved by Apple after deletion)
  static const String premiumMonthly = 'com.freetalk.subscription.premium.monthly';
  static const String premiumYearly = 'com.freetalk.subscription.premium.yearly';
  static const String verifiedBadge = 'com.freetalk.verified_badge';
  static const String adFree = 'com.freetalk.ad_free';

  // All product IDs
  static const Set<String> productIds = {
    premiumMonthly,
    premiumYearly,
    verifiedBadge,
    adFree,
  };

  /// Initialize IAP service
  /// Web: Purchases are not supported (compliance) – IAP disabled
  /// Mobile: Sets up native IAP
  /// Performance: Prevents multiple simultaneous initializations
  Future<void> initialize() async {
    // Prevent multiple simultaneous initializations
    if (_isInitializing) {
      debugPrint('⏳ IAP initialization already in progress...');
      return;
    }

    if (_isAvailable && _iap != null) {
      debugPrint('✅ IAP already initialized');
      return;
    }

    _isInitializing = true;

    try {
      debugPrint('🛒 Initializing In-App Purchase service...');

      // Web is not allowed to process payments for digital goods (policy compliance)
      if (kIsWeb) {
        debugPrint('ℹ️ IAP is not supported on web. Purchases are disabled.');
        _isAvailable = false;
        _isInitializing = false;
        return;
      }

      // Initialize IAP instance for mobile platforms only
      _iap = InAppPurchase.instance;

      // Check if IAP is available with timeout
      _isAvailable = await _iap!.isAvailable().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          debugPrint('⚠️ IAP availability check timed out');
          return false;
        },
      );

      if (!_isAvailable) {
        debugPrint('⚠️ In-App Purchase not available on this device');
        _isInitializing = false;
        return;
      }

      debugPrint('✅ In-App Purchase is available');

      // Listen to purchase updates (only if not already subscribed)
      _subscription ??= _iap!.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => debugPrint('🛒 Purchase stream done'),
        onError: (error) {
          debugPrint('❌ Purchase stream error: $error');
          // Try to resubscribe on error
          _subscription?.cancel();
          _subscription = null;
          if (_iap != null) {
            _subscription = _iap!.purchaseStream.listen(
              _onPurchaseUpdate,
              onError: (e) => debugPrint('❌ Purchase stream error (retry): $e'),
            );
          }
        },
      );

      // Load products (non-blocking, lazy load - only when needed)
      // Don't load products on init to improve startup performance
      // Products will be loaded when user opens premium page

      // NOTE: Don't auto-restore on init - let user trigger it manually
      // This improves performance and prevents unnecessary network calls
      debugPrint('✅ IAP service initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing IAP service: $e');
    } finally {
      _isInitializing = false;
    }
  }

  // Cache product loading state to prevent redundant calls
  bool _isLoadingProducts = false;
  DateTime? _productsLoadTime;
  static const Duration _productsCacheDuration = Duration(hours: 1); // Cache products for 1 hour

  /// Load available products from stores
  /// Performance: Prevents concurrent loads and caches results
  Future<void> loadProducts({bool forceRefresh = false}) async {
    // Prevent concurrent product loading
    if (_isLoadingProducts) {
      debugPrint('⏳ Products already loading...');
      return;
    }

    // Return cached products if still valid
    if (!forceRefresh && 
        _products.isNotEmpty && 
        _productsLoadTime != null &&
        DateTime.now().difference(_productsLoadTime!) < _productsCacheDuration) {
      debugPrint('📦 Using cached products (${_products.length} products)');
      return;
    }

    try {
      if (!_isAvailable || _iap == null) {
        debugPrint('⚠️ IAP not available, cannot load products');
        return;
      }

      _isLoadingProducts = true;
      debugPrint('📦 Loading products...');

      final ProductDetailsResponse response =
          await _iap!.queryProductDetails(productIds).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Product loading timed out', const Duration(seconds: 10));
        },
      );

      if (response.error != null) {
        debugPrint('❌ Error loading products: ${response.error}');
        return;
      }

      if (response.productDetails.isEmpty) {
        debugPrint(
            '⚠️ No products found. Make sure products are configured in:');
        debugPrint('  - App Store Connect (for iOS)');
        debugPrint('  - Google Play Console (for Android)');
        return;
      }

      _products = response.productDetails;
      _productsLoadTime = DateTime.now();

      debugPrint('✅ Loaded ${_products.length} products:');
      for (final product in _products) {
        debugPrint('  - ${product.id}: ${product.title} (${product.price})');
      }
    } catch (e) {
      debugPrint('❌ Error loading products: $e');
    } finally {
      _isLoadingProducts = false;
    }
  }

  /// Purchase a product
  /// Web: Disabled for compliance
  /// Mobile: Uses native IAP
  Future<bool> purchaseProduct(String productId) async {
    try {
      if (!_isAvailable) {
        debugPrint('⚠️ IAP not available');
        return false;
      }

      // Web purchases are disabled to comply with store policies
      if (kIsWeb) {
        debugPrint('🚫 Purchases are disabled on web for compliance.');
        return false;
      }

      // Mobile IAP flow
      if (_iap == null) {
        debugPrint('⚠️ IAP not initialized');
        return false;
      }

      final product = _products.firstWhere(
        (p) => p.id == productId,
        orElse: () => throw Exception('Product not found: $productId'),
      );

      debugPrint('🛒 Initiating purchase: ${product.title}');

      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: product,
      );

      bool success;
      // Use buyNonConsumable for both subscriptions and one-time purchases
      // The in_app_purchase package handles platform differences automatically
      // iOS: buyNonConsumable works for subscriptions
      // Android: buyNonConsumable works for subscriptions and consumables
      success = await _iap!.buyNonConsumable(purchaseParam: purchaseParam);

      return success;
    } catch (e) {
      debugPrint('❌ Error purchasing product: $e');
      return false;
    }
  }

  // Web payment flow is intentionally removed to ensure policy compliance

  /// Open payment URL (handles web browser navigation)
  /// DISABLED: Stripe checkout is temporarily disabled
  // Future<bool> _openPaymentUrl(String url) async {
  //   try {
  //     debugPrint('🌐 Opening payment URL: $url');

  //     // Use url_launcher to open the Stripe checkout URL
  //     final Uri uri = Uri.parse(url);

  //     if (await canLaunchUrl(uri)) {
  //       await launchUrl(uri, mode: LaunchMode.externalApplication);
  //       return true;
  //     } else {
  //       debugPrint('❌ Could not launch payment URL');
  //       return false;
  //     }
  //   } catch (e) {
  //     debugPrint('❌ Error opening payment URL: $e');
  //     return false;
  //   }
  // }

  /// Handle purchase updates from the store
  void _onPurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    for (final PurchaseDetails purchaseDetails in purchaseDetailsList) {
      debugPrint('🛒 Purchase update: ${purchaseDetails.productID}');
      debugPrint('   Status: ${purchaseDetails.status}');

      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Purchase is pending (e.g., waiting for parent approval)
        debugPrint('⏳ Purchase pending: ${purchaseDetails.productID}');
        _onPurchasePending(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        // Purchase failed
        debugPrint('❌ Purchase error: ${purchaseDetails.error}');
        _onPurchaseError(purchaseDetails);
      } else if (purchaseDetails.status == PurchaseStatus.purchased ||
          purchaseDetails.status == PurchaseStatus.restored) {
        // Purchase successful or restored
        final isRestored = purchaseDetails.status == PurchaseStatus.restored;
        debugPrint('✅ Purchase ${isRestored ? "restored" : "successful"}: ${purchaseDetails.productID}');

        // CRITICAL: Verify purchase with backend BEFORE granting access
        // This applies to both new purchases and restored purchases
        final verified = await _verifyPurchaseWithBackend(purchaseDetails);

        if (verified) {
          _onPurchaseSuccess(purchaseDetails);
          if (isRestored) {
            debugPrint('✅ Restored purchase verified and activated: ${purchaseDetails.productID}');
          }
        } else {
          debugPrint('❌ Purchase verification failed for ${purchaseDetails.productID}');
          _onPurchaseError(purchaseDetails);
        }
      }

      // IMPORTANT: Complete the purchase
      // iOS requires this or purchases will remain in queue
      if (purchaseDetails.pendingCompletePurchase && _iap != null) {
        await _iap!.completePurchase(purchaseDetails);
        debugPrint('✅ Purchase completed: ${purchaseDetails.productID}');
      }
    }
  }

  /// Verify purchase with backend (REQUIRED for security)
  /// Performance: Prevents duplicate verifications
  Future<bool> _verifyPurchaseWithBackend(
      PurchaseDetails purchaseDetails) async {
    // Prevent duplicate verification of same purchase
    final purchaseKey = '${purchaseDetails.productID}_${purchaseDetails.transactionDate ?? ''}';
    if (_verifyingPurchases.contains(purchaseKey)) {
      debugPrint('⏳ Purchase already being verified: ${purchaseDetails.productID}');
      return false; // Wait for existing verification
    }

    try {
      _verifyingPurchases.add(purchaseKey);
      debugPrint('🔐 Verifying purchase with backend...');

      // Get verification data - works for both iOS and Android
      final verificationData =
          purchaseDetails.verificationData.localVerificationData;

      if (verificationData.isEmpty) {
        debugPrint('❌ No verification data available');
        return false;
      }

      // Get access token for authentication
      final token = await ApiService.getAccessToken();
      if (token == null) {
        debugPrint('❌ No access token available for verification');
        return false;
      }

      // Prepare request body based on platform
      final Map<String, dynamic> requestBody = {
        'platform': Platform.isIOS ? 'ios' : 'android',
        'productId': purchaseDetails.productID,
      };

      // Add platform-specific verification data
      if (Platform.isIOS) {
        requestBody['receipt'] = verificationData;
      } else if (Platform.isAndroid) {
        // Android uses purchase token and package name
        requestBody['purchaseToken'] = verificationData;
        requestBody['packageName'] =
            'com.freetalk.social'; // Your Android package name from build.gradle.kts
      }

      if (purchaseDetails.transactionDate != null) {
        requestBody['transactionDate'] = purchaseDetails.transactionDate;
      }

      // Send verification request to backend with timeout
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/iap/verify-purchase'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw TimeoutException('Purchase verification timed out', const Duration(seconds: 15));
        },
      );

      if (response.statusCode == 200) {
        final result = jsonDecode(response.body);
        debugPrint('✅ Backend verification successful: ${result['message']}');
        return result['success'] == true;
      } else {
        final error = jsonDecode(response.body);
        debugPrint('❌ Backend verification failed: ${error['message']}');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error verifying purchase: $e');
      return false;
    } finally {
      _verifyingPurchases.remove(purchaseKey);
    }
  }

  /// Handle successful purchase
  void _onPurchaseSuccess(PurchaseDetails purchaseDetails) {
    debugPrint(
        '✅ Purchase verified and completed: ${purchaseDetails.productID}');

    // Grant access to the purchased feature
    // This should be coordinated with your backend

      // Update local state (avoid duplicates)
      if (!_purchases.any((p) => p.productID == purchaseDetails.productID)) {
        _purchases.add(purchaseDetails);
        // Invalidate cache to force rebuild
        _purchaseIdsCache = null;
      }
  }

  /// Handle purchase error
  void _onPurchaseError(PurchaseDetails purchaseDetails) {
    debugPrint('❌ Purchase failed: ${purchaseDetails.productID}');
    // Show error to user
  }

  /// Handle pending purchase
  void _onPurchasePending(PurchaseDetails purchaseDetails) {
    debugPrint('⏳ Purchase pending: ${purchaseDetails.productID}');
    // Show pending state to user
  }

  /// Restore previous purchases (REQUIRED by Apple)
  /// This will trigger purchase updates through the stream, which will verify with backend
  /// Performance: Prevents concurrent restore operations, uses timeout
  Future<bool> restorePurchases() async {
    // Prevent concurrent restore operations
    if (_isRestoring) {
      debugPrint('⏳ Restore already in progress...');
      return false;
    }

    try {
      if (!_isAvailable || _iap == null) {
        debugPrint('⚠️ IAP not available');
        return false;
      }

      _isRestoring = true;
      debugPrint('🔄 Restoring purchases...');

      // Track purchases before restore to detect new ones
      final purchasesBefore = Set<String>.from(_purchases.map((p) => p.productID));
      // Invalidate cache before restore
      _purchaseIdsCache = null;

      // Call native restore - this will trigger purchase updates through the stream
      await _iap!.restorePurchases().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          debugPrint('⚠️ Restore purchases timed out');
          throw TimeoutException('Restore purchases timed out', const Duration(seconds: 30));
        },
      );

      debugPrint('✅ Restore purchases initiated - waiting for purchase updates...');
      
      // Wait for purchase updates with timeout (reduced from 2s to 1.5s for better performance)
      await Future.delayed(const Duration(milliseconds: 1500));
      
      // Check if any NEW purchases were restored (not just existing ones)
      final purchasesAfter = Set<String>.from(_purchases.map((p) => p.productID));
      final newPurchases = purchasesAfter.difference(purchasesBefore);
      
      if (newPurchases.isNotEmpty) {
        debugPrint('✅ Found ${newPurchases.length} restored purchase(s): ${newPurchases.join(", ")}');
        return true;
      } else if (_purchases.isNotEmpty) {
        debugPrint('ℹ️ Purchases already restored: ${_purchases.length} purchase(s)');
        return true;
      } else {
        debugPrint('ℹ️ No purchases found to restore');
        return false;
      }
    } catch (e) {
      debugPrint('❌ Error restoring purchases: $e');
      return false;
    } finally {
      _isRestoring = false;
    }
  }

  /// Check if user has purchased a product
  /// Performance: Uses cached Set lookup for O(1) instead of O(n)
  bool hasPurchased(String productId) {
    if (_purchases.isEmpty) return false;
    
    // Use cached Set for fast lookups (rebuild cache if purchases changed)
    _purchaseIdsCache ??= _purchases.map((p) => p.productID).toSet();
    
    // Rebuild cache if purchases list changed (size mismatch)
    if (_purchaseIdsCache!.length != _purchases.length) {
      _purchaseIdsCache = _purchases.map((p) => p.productID).toSet();
    }
    
    return _purchaseIdsCache!.contains(productId);
  }

  /// Check if user has active premium subscription
  /// Performance: Optimized for common case
  bool hasPremiumSubscription() {
    if (_purchases.isEmpty) return false;
    
    // Fast path: check most common products first
    for (final purchase in _purchases) {
      final id = purchase.productID;
      if (id == premiumMonthly || id == premiumYearly) {
        return true;
      }
    }
    return false;
  }

  /// Get product details
  ProductDetails? getProduct(String productId) {
    try {
      return _products.firstWhere((p) => p.id == productId);
    } catch (e) {
      return null;
    }
  }

  /// Get all available products
  List<ProductDetails> get products => _products;

  /// Check if IAP is available
  bool get isAvailable => _isAvailable;

  /// Dispose service - properly clean up resources
  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _isAvailable = false;
    _isInitializing = false;
    _isRestoring = false;
    _purchases.clear();
    _products.clear();
    _purchaseIdsCache = null;
    _verifyingPurchases.clear();
  }
}
