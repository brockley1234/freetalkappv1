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
  List<ProductDetails> _products = [];
  final List<PurchaseDetails> _purchases = [];

  // Product IDs - Must match App Store Connect and Play Console
  static const String premiumMonthly = 'com.freetalk.premium_monthly';
  static const String premiumYearly = 'com.freetalk.premium_yearly';
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
  Future<void> initialize() async {
    try {
      debugPrint('🛒 Initializing In-App Purchase service...');

      // Web is not allowed to process payments for digital goods (policy compliance)
      if (kIsWeb) {
        debugPrint('ℹ️ IAP is not supported on web. Purchases are disabled.');
        _isAvailable = false;
        return;
      }

      // Initialize IAP instance for mobile platforms only
      _iap = InAppPurchase.instance;

      // Check if IAP is available
      _isAvailable = await _iap!.isAvailable();

      if (!_isAvailable) {
        debugPrint('⚠️ In-App Purchase not available on this device');
        return;
      }

      debugPrint('✅ In-App Purchase is available');

      // Listen to purchase updates
      _subscription = _iap!.purchaseStream.listen(
        _onPurchaseUpdate,
        onDone: () => debugPrint('🛒 Purchase stream done'),
        onError: (error) => debugPrint('❌ Purchase stream error: $error'),
      );

      // Load products
      await loadProducts();

      // Restore previous purchases (required by Apple)
      await restorePurchases();

      debugPrint('✅ IAP service initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing IAP service: $e');
    }
  }

  /// Load available products from stores
  Future<void> loadProducts() async {
    try {
      if (!_isAvailable || _iap == null) {
        debugPrint('⚠️ IAP not available, cannot load products');
        return;
      }

      debugPrint('📦 Loading products...');

      final ProductDetailsResponse response =
          await _iap!.queryProductDetails(productIds);

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

      debugPrint('✅ Loaded ${_products.length} products:');
      for (final product in _products) {
        debugPrint('  - ${product.id}: ${product.title} (${product.price})');
      }
    } catch (e) {
      debugPrint('❌ Error loading products: $e');
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
      if (product.id == premiumMonthly || product.id == premiumYearly) {
        // Subscription
        success = await _iap!.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        // One-time purchase
        success = await _iap!.buyNonConsumable(purchaseParam: purchaseParam);
      }

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
        // Purchase successful
        debugPrint('✅ Purchase successful: ${purchaseDetails.productID}');

        // CRITICAL: Verify purchase with backend BEFORE granting access
        final verified = await _verifyPurchaseWithBackend(purchaseDetails);

        if (verified) {
          _onPurchaseSuccess(purchaseDetails);
        } else {
          debugPrint('❌ Purchase verification failed');
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
  Future<bool> _verifyPurchaseWithBackend(
      PurchaseDetails purchaseDetails) async {
    try {
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

      // Send verification request to backend
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/iap/verify-purchase'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
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
    }
  }

  /// Handle successful purchase
  void _onPurchaseSuccess(PurchaseDetails purchaseDetails) {
    debugPrint(
        '✅ Purchase verified and completed: ${purchaseDetails.productID}');

    // Grant access to the purchased feature
    // This should be coordinated with your backend

    // Update local state
    _purchases.add(purchaseDetails);
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
  Future<void> restorePurchases() async {
    try {
      if (!_isAvailable || _iap == null) {
        debugPrint('⚠️ IAP not available');
        return;
      }

      debugPrint('🔄 Restoring purchases...');

      await _iap!.restorePurchases();

      debugPrint('✅ Purchases restored');
    } catch (e) {
      debugPrint('❌ Error restoring purchases: $e');
    }
  }

  /// Check if user has purchased a product
  bool hasPurchased(String productId) {
    return _purchases.any((p) => p.productID == productId);
  }

  /// Check if user has active premium subscription
  bool hasPremiumSubscription() {
    return hasPurchased(premiumMonthly) || hasPurchased(premiumYearly);
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

  /// Dispose service
  void dispose() {
    _subscription?.cancel();
  }
}
