import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
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
  
  // Cache for subscription status to reduce API calls
  static Map<String, dynamic>? _cachedStatus;
  static DateTime? _statusCacheTime;
  static const Duration _statusCacheDuration = Duration(minutes: 2); // Cache for 2 minutes
  
  // Cache for feature access to reduce redundant checks
  static final Map<String, Map<String, dynamic>> _featureAccessCache = {};
  static final Map<String, DateTime> _featureAccessCacheTime = {};
  static const Duration _featureAccessCacheDuration = Duration(minutes: 1); // Cache for 1 minute

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
  /// This will restore purchases from the store and verify them with the backend
  static Future<Map<String, dynamic>> restorePurchases() async {
    try {
      await initialize();

      if (!_iapService.isAvailable) {
        return {
          'success': false,
          'message': 'In-App Purchase not available on this device',
        };
      }

      debugPrint('🔄 Starting restore purchases process...');

      // Restore purchases - this will trigger purchase updates through the stream
      final restored = await _iapService.restorePurchases();

      if (restored) {
        // Clear cache to force fresh status check after restore
        clearStatusCache();
        
        // Wait briefly for backend verification to complete (reduced delay for performance)
        await Future.delayed(const Duration(milliseconds: 1500));

        // Check backend status to confirm purchases were restored (with timeout, force refresh)
        final status = await getSubscriptionStatus(forceRefresh: true).timeout(
          const Duration(seconds: 10),
          onTimeout: () => <String, dynamic>{
            'success': false,
            'message': 'Status check timed out',
          },
        );
        
        if (status['success'] == true) {
          final data = status['data'];
          final hasPremium = data['isPremium'] ?? false;
          
          return {
            'success': true,
            'message': hasPremium 
                ? 'Purchases restored and verified successfully' 
                : 'Restore completed. No active purchases found.',
            'hasPremium': hasPremium,
          };
        } else {
          return {
            'success': true,
            'message': 'Purchases restored. Verification may take a moment.',
          };
        }
      } else {
        return {
          'success': false,
          'message': 'No previous purchases found to restore',
        };
      }
    } catch (e) {
      debugPrint('❌ Error restoring purchases: $e');
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
  /// Performance: Uses caching to reduce API calls
  static Future<Map<String, dynamic>> getSubscriptionStatus({bool forceRefresh = false}) async {
    try {
      // Return cached status if still valid and not forcing refresh
      if (!forceRefresh && 
          _cachedStatus != null && 
          _statusCacheTime != null &&
          DateTime.now().difference(_statusCacheTime!) < _statusCacheDuration) {
        debugPrint('📦 Using cached subscription status');
        return _cachedStatus!;
      }

      final token = await ApiService.getAccessToken();

      if (token == null) {
        throw Exception('Not authenticated');
      }

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/payment/subscription-status'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw TimeoutException('Subscription status check timed out', const Duration(seconds: 10));
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final result = {
          'success': true,
          'data': data['data'],
        };
        
        // Cache the result
        _cachedStatus = result;
        _statusCacheTime = DateTime.now();
        
        return result;
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Failed to get subscription status',
        };
      }
    } catch (e) {
      // Return cached status on error if available
      if (_cachedStatus != null) {
        debugPrint('⚠️ Error getting subscription status, using cached: $e');
        return _cachedStatus!;
      }
      
      return {
        'success': false,
        'message': 'Error: ${e.toString()}',
      };
    }
  }
  
  /// Clear subscription status cache (call after purchase/restore)
  static void clearStatusCache() {
    _cachedStatus = null;
    _statusCacheTime = null;
    _featureAccessCache.clear();
    _featureAccessCacheTime.clear();
  }

  /// Check feature access (combines local IAP check with backend verification)
  /// Performance: Uses caching and local-first approach
  static Future<Map<String, dynamic>> checkFeatureAccess(String feature, {bool forceRefresh = false}) async {
    try {
      // First check local IAP status (fast, no network)
      final localAccess = await hasFeatureAccess(feature);

      // Check cache first (unless forcing refresh)
      if (!forceRefresh && 
          _featureAccessCache.containsKey(feature) &&
          _featureAccessCacheTime.containsKey(feature) &&
          DateTime.now().difference(_featureAccessCacheTime[feature]!) < _featureAccessCacheDuration) {
        debugPrint('📦 Using cached feature access for: $feature');
        return _featureAccessCache[feature]!;
      }

      // Then verify with backend (slower but authoritative)
      final token = await ApiService.getAccessToken();

      if (token == null) {
        // If not authenticated, just return local status
        final result = {
          'success': true,
          'hasAccess': localAccess,
          'isPremium': localAccess,
        };
        _featureAccessCache[feature] = result;
        _featureAccessCacheTime[feature] = DateTime.now();
        return result;
      }

      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/payment/check-feature/$feature'),
        headers: {
          'Authorization': 'Bearer $token',
        },
      ).timeout(
        const Duration(seconds: 8),
        onTimeout: () {
          throw TimeoutException('Feature access check timed out', const Duration(seconds: 8));
        },
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final result = {
          'success': true,
          'hasAccess': data['data']['hasAccess'] ?? localAccess,
          'isPremium': data['data']['isPremium'] ?? localAccess,
          'expiresAt': data['data']['expiresAt'],
        };
        
        // Cache the result
        _featureAccessCache[feature] = result;
        _featureAccessCacheTime[feature] = DateTime.now();
        
        return result;
      } else {
        // Fallback to local status if backend check fails
        final result = {
          'success': true,
          'hasAccess': localAccess,
          'isPremium': localAccess,
        };
        _featureAccessCache[feature] = result;
        _featureAccessCacheTime[feature] = DateTime.now();
        return result;
      }
    } catch (e) {
      // On error, fallback to local IAP check or cached value
      if (_featureAccessCache.containsKey(feature)) {
        debugPrint('⚠️ Error checking feature access, using cached: $e');
        return _featureAccessCache[feature]!;
      }
      
      final localAccess = await hasFeatureAccess(feature);
      final result = {
        'success': true,
        'hasAccess': localAccess,
        'isPremium': localAccess,
        'message': 'Using local verification',
      };
      _featureAccessCache[feature] = result;
      _featureAccessCacheTime[feature] = DateTime.now();
      return result;
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
