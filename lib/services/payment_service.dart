import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_service.dart';
import 'iap_service.dart';

/// COMPLIANCE NOTE: This service now uses native In-App Purchase (IAP)
/// for digital goods/features as required by Apple App Store and Google Play Store.
///
/// External payment processors (Stripe, etc.) can ONLY be used for:
/// - Physical goods/services
/// - Content consumed outside the app
/// - Peer-to-peer payments
///
/// NOTE: IAP is not supported on web platforms. On web, IAP will gracefully
/// return as unavailable without causing errors.
class PaymentService {
  // Initialize IAP service (singleton)
  static final IAPService _iapService = IAPService();
  static bool _initialized = false;

  /// Initialize the payment service
  /// Safe to call on all platforms (iOS, Android, Web)
  static Future<void> initialize() async {
    if (!_initialized) {
      await _iapService.initialize();
      _initialized = true;
    }
  }

  /// Purchase a feature using native In-App Purchase
  /// COMPLIANT with App Store and Play Store policies
  static Future<Map<String, dynamic>> purchaseFeature(String feature) async {
    try {
      // Ensure IAP is initialized
      await initialize();

      if (!_iapService.isAvailable) {
        return {
          'success': false,
          'message': 'In-App Purchase not available on this device',
        };
      }

      // Map features to product IDs
      String productId;
      switch (feature.toLowerCase()) {
        case 'premium':
        case 'premium_monthly':
          productId = IAPService.premiumMonthly;
          break;
        case 'premium_yearly':
          productId = IAPService.premiumYearly;
          break;
        case 'verified_badge':
        case 'verified':
          productId = IAPService.verifiedBadge;
          break;
        case 'ad_free':
        case 'remove_ads':
          productId = IAPService.adFree;
          break;
        default:
          return {
            'success': false,
            'message': 'Unknown feature: $feature',
          };
      }

      // Initiate purchase
      final success = await _iapService.purchaseProduct(productId);

      if (success) {
        return {
          'success': true,
          'message': 'Purchase initiated successfully',
          'productId': productId,
        };
      } else {
        return {
          'success': false,
          'message': 'Failed to initiate purchase',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  /// OLD METHOD - DEPRECATED - Use purchaseFeature() instead
  /// Kept for backward compatibility during migration
  @Deprecated('Use purchaseFeature() with native IAP instead')
  static Future<Map<String, dynamic>> createPaymentIntent(
      String feature) async {
    // Redirect to new compliant method
    return await purchaseFeature(feature);
  }

  /// Check if user has purchased a specific feature
  static Future<bool> hasFeatureAccess(String feature) async {
    await initialize();

    switch (feature.toLowerCase()) {
      case 'premium':
      case 'premium_monthly':
      case 'premium_yearly':
        return _iapService.hasPremiumSubscription();
      case 'verified_badge':
      case 'verified':
        return _iapService.hasPurchased(IAPService.verifiedBadge);
      case 'ad_free':
      case 'remove_ads':
        return _iapService.hasPurchased(IAPService.adFree);
      default:
        return false;
    }
  }

  /// Restore previous purchases (REQUIRED by Apple)
  static Future<Map<String, dynamic>> restorePurchases() async {
    try {
      await initialize();
      await _iapService.restorePurchases();

      return {
        'success': true,
        'message': 'Purchases restored successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error restoring purchases: ${e.toString()}',
      };
    }
  }

  /// Get all available IAP products
  static Future<List<Map<String, dynamic>>> getAvailableProducts() async {
    await initialize();

    final products = _iapService.products;
    return products
        .map((product) => {
              'id': product.id,
              'title': product.title,
              'description': product.description,
              'price': product.price,
              'rawPrice': product.rawPrice,
              'currencyCode': product.currencyCode,
            })
        .toList();
  }

  /// OLD METHOD - DEPRECATED
  @Deprecated('IAP purchases are verified automatically')
  static Future<Map<String, dynamic>> verifyPayment(
      String paymentIntentId) async {
    return {
      'success': false,
      'message':
          'This method is deprecated. IAP purchases are verified automatically.',
    };
  }

  /// Get subscription status from backend
  static Future<Map<String, dynamic>> getSubscriptionStatus() async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/payment/subscription-status'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'data': data['data'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get subscription status',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  /// Check feature access (combines local IAP check with backend verification)
  static Future<Map<String, dynamic>> checkFeatureAccess(String feature) async {
    try {
      // First check local IAP status (fast)
      final localAccess = await hasFeatureAccess(feature);

      // Then verify with backend (slower but authoritative)
      final token = await ApiService.getAccessToken();

      if (token == null) {
        // If not authenticated, just return local status
        return {
          'success': true,
          'hasAccess': localAccess,
          'isPremium': localAccess,
        };
      }

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/payment/check-feature/$feature'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'hasAccess': data['data']['hasAccess'] ?? localAccess,
          'isPremium': data['data']['isPremium'] ?? localAccess,
          'expiresAt': data['data']['expiresAt'],
        };
      } else {
        // Fallback to local status if backend check fails
        return {
          'success': true,
          'hasAccess': localAccess,
          'isPremium': localAccess,
        };
      }
    } catch (e) {
      // On error, fallback to local IAP check
      final localAccess = await hasFeatureAccess(feature);
      return {
        'success': true,
        'hasAccess': localAccess,
        'isPremium': localAccess,
        'message': 'Using local verification',
      };
    }
  }

  /// Get instant verification (FREE for all users)
  static Future<Map<String, dynamic>> getInstantVerification() async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/users/get-verified'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get verification',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  /// Get instant feature access (for testing/demo purposes)
  /// In production, this would be replaced with actual payment processing
  static Future<Map<String, dynamic>> getInstantFeatureAccess(
      String feature, String plan) async {
    try {
      final token = await ApiService.getAccessToken();

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/payment/instant-access'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'feature': feature,
          'plan': plan,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        return {
          'success': true,
          'data': data['data'],
          'message': data['message'],
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to activate feature',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }
}
