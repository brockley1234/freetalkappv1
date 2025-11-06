import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import '../config/api_config.dart';
import '../models/marketplace_item_model.dart';
import '../utils/app_logger.dart';
import 'api_service.dart';

/// Enhanced error class for marketplace operations
class MarketplaceException implements Exception {
  final String message;
  final String? code;
  final int? statusCode;
  final Map<String, dynamic>? details;
  final String operation;

  MarketplaceException({
    required this.message,
    this.code,
    this.statusCode,
    this.details,
    required this.operation,
  });

  @override
  String toString() => message;

  /// Get user-friendly error message
  String get userMessage {
    if (statusCode != null) {
      switch (statusCode) {
        case 400:
          return 'Invalid request. Please check your input and try again.';
        case 401:
          return 'Please log in to continue.';
        case 403:
          return 'You don\'t have permission to perform this action.';
        case 404:
          return 'Listing not found. It may have been removed.';
        case 413:
          return 'Image files are too large. Please use smaller images.';
        case 429:
          return 'Too many requests. Please wait a moment and try again.';
        case 500:
          return 'Server error. Please try again later.';
        case 503:
          return 'Service temporarily unavailable. Please try again later.';
        default:
          return message;
      }
    }
    return message;
  }

  /// Get detailed error information for debugging
  Map<String, dynamic> toJson() => {
        'message': message,
        'code': code,
        'statusCode': statusCode,
        'details': details,
        'operation': operation,
      };
}

class MarketplaceService {
  final String baseUrl = ApiConfig.baseUrl;
  final AppLogger _logger = AppLogger();

  Future<Map<String, String>> _getHeaders({bool includeContentType = true}) async {
    try {
      final token = await ApiService.getAccessToken();
      final headers = <String, String>{};
      if (includeContentType) {
        headers['Content-Type'] = 'application/json';
      }
      headers['Authorization'] = 'Bearer $token';
      return headers;
    } catch (e) {
      _logger.error('Error getting auth headers: $e');
      throw MarketplaceException(
        message: 'Authentication failed. Please log in again.',
        code: 'AUTH_ERROR',
        operation: 'getHeaders',
      );
    }
  }

  /// Parse error response from API
  MarketplaceException _parseError(dynamic error, int? statusCode, String operation) {
    try {
      if (error is String) {
        try {
          final errorData = jsonDecode(error);
          final message = errorData['message'] ?? errorData['error'] ?? 'An error occurred';
          final errors = errorData['errors'];
          
          String detailedMessage = message;
          if (errors != null && errors is List && errors.isNotEmpty) {
            final errorList = errors.map((e) {
              if (e is Map) {
                return e['msg'] ?? e['message'] ?? e.toString();
              }
              return e.toString();
            }).join(', ');
            detailedMessage = '$message\n\nDetails: $errorList';
          }

          return MarketplaceException(
            message: detailedMessage,
            code: errorData['code']?.toString(),
            statusCode: statusCode ?? errorData['statusCode'],
            details: errorData is Map<String, dynamic> ? errorData : null,
            operation: operation,
          );
        } catch (_) {
          return MarketplaceException(
            message: error,
            statusCode: statusCode,
            operation: operation,
          );
        }
      } else if (error is Map) {
        return MarketplaceException(
          message: error['message'] ?? 'An error occurred',
          code: error['code']?.toString(),
          statusCode: statusCode ?? error['statusCode'],
          details: error is Map<String, dynamic> ? error : null,
          operation: operation,
        );
      }
    } catch (e) {
      _logger.error('Error parsing error response: $e');
    }

    return MarketplaceException(
      message: error.toString(),
      statusCode: statusCode,
      operation: operation,
    );
  }

  /// Handle network errors
  MarketplaceException _handleNetworkError(dynamic error, String operation) {
    if (error is SocketException) {
      return MarketplaceException(
        message: 'No internet connection. Please check your network and try again.',
        code: 'NETWORK_ERROR',
        operation: operation,
      );
    } else if (error is HttpException) {
      return MarketplaceException(
        message: 'Network error: ${error.message}',
        code: 'HTTP_ERROR',
        operation: operation,
      );
    } else if (error is FormatException) {
      return MarketplaceException(
        message: 'Invalid response from server. Please try again.',
        code: 'FORMAT_ERROR',
        operation: operation,
      );
    } else if (error is Exception) {
      final errorStr = error.toString().toLowerCase();
      if (errorStr.contains('timeout') || errorStr.contains('timed out')) {
        return MarketplaceException(
          message: 'Request timed out. Please check your connection and try again.',
          code: 'TIMEOUT_ERROR',
          operation: operation,
        );
      }
    }

    return MarketplaceException(
      message: error.toString(),
      operation: operation,
    );
  }

  // Get marketplace listings with filters
  Future<Map<String, dynamic>> getListings({
    int page = 1,
    int limit = 20,
    String? search,
    String? category,
    double? minPrice,
    double? maxPrice,
    String? condition,
    String? status,
    String? sellerId,
    double? latitude,
    double? longitude,
    double? maxDistance,
    String sortBy = 'createdAt',
    String sortOrder = 'desc',
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
        'sortBy': sortBy,
        'sortOrder': sortOrder,
      };

      if (search != null && search.isNotEmpty) queryParams['search'] = search;
      if (category != null && category.isNotEmpty) queryParams['category'] = category;
      if (minPrice != null) queryParams['minPrice'] = minPrice.toString();
      if (maxPrice != null) queryParams['maxPrice'] = maxPrice.toString();
      if (condition != null && condition.isNotEmpty) queryParams['condition'] = condition;
      if (status != null && status.isNotEmpty) queryParams['status'] = status;
      if (sellerId != null && sellerId.isNotEmpty) queryParams['sellerId'] = sellerId;
      // Add location parameters for distance calculation
      if (latitude != null && longitude != null) {
        queryParams['latitude'] = latitude.toString();
        queryParams['longitude'] = longitude.toString();
        if (maxDistance != null) {
          queryParams['maxDistance'] = maxDistance.toString();
        }
      }

      final uri = Uri.parse('$baseUrl/marketplace').replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['success'] == false) {
            throw _parseError(data['message'] ?? response.body, response.statusCode, 'getListings');
          }
          final items = (data['data']['items'] as List)
              .map((item) => MarketplaceItem.fromJson(item))
              .toList();

          return {
            'success': true,
            'items': items,
            'pagination': data['data']['pagination'],
          };
        } catch (e) {
          if (e is MarketplaceException) rethrow;
          throw _parseError(response.body, response.statusCode, 'getListings');
        }
      } else {
        throw _parseError(response.body, response.statusCode, 'getListings');
      }
    } catch (e) {
      if (e is MarketplaceException) {
        _logger.error('Error fetching marketplace listings: ${e.toJson()}');
        rethrow;
      }
      _logger.error('Error fetching marketplace listings: $e');
      throw _handleNetworkError(e, 'getListings');
    }
  }

  // Get single listing
  Future<MarketplaceItem> getListing(String id, {double? latitude, double? longitude}) async {
    try {
      final queryParams = <String, String>{};
      if (latitude != null && longitude != null) {
        queryParams['latitude'] = latitude.toString();
        queryParams['longitude'] = longitude.toString();
      }
      
      final uri = Uri.parse('$baseUrl/marketplace/$id').replace(queryParameters: queryParams);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['success'] == false) {
            throw _parseError(data['message'] ?? response.body, response.statusCode, 'getListing');
          }
          return MarketplaceItem.fromJson(data['data']['item']);
        } catch (e) {
          if (e is MarketplaceException) rethrow;
          throw _parseError(response.body, response.statusCode, 'getListing');
        }
      } else {
        throw _parseError(response.body, response.statusCode, 'getListing');
      }
    } catch (e) {
      if (e is MarketplaceException) {
        _logger.error('Error fetching marketplace listing: ${e.toJson()}');
        rethrow;
      }
      _logger.error('Error fetching marketplace listing: $e');
      throw _handleNetworkError(e, 'getListing');
    }
  }

  // Create listing
  Future<MarketplaceItem> createListing({
    required String title,
    required String description,
    required String category,
    required double price,
    required List<XFile> images,
    String condition = 'good',
    String currency = 'USD',
    int quantity = 1,
    bool shippingAvailable = false,
    double shippingCost = 0,
    bool localPickupOnly = false,
    MarketplaceLocation? location,
    List<String> tags = const [],
  }) async {
    try {
      final headers = await _getHeaders(includeContentType: false);
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/marketplace'),
      );

      request.headers.addAll(headers);

      // Add text fields
      request.fields['title'] = title;
      request.fields['description'] = description;
      request.fields['category'] = category;
      request.fields['price'] = price.toString();
      request.fields['condition'] = condition;
      request.fields['currency'] = currency;
      request.fields['quantity'] = quantity.toString();
      request.fields['shippingAvailable'] = shippingAvailable.toString();
      request.fields['shippingCost'] = shippingCost.toString();
      request.fields['localPickupOnly'] = localPickupOnly.toString();

      if (tags.isNotEmpty) {
        request.fields['tags'] = jsonEncode(tags);
      }

      // Add location if provided
      if (location != null) {
        if (location.city != null) request.fields['location[city]'] = location.city!;
        if (location.state != null) request.fields['location[state]'] = location.state!;
        if (location.country != null) request.fields['location[country]'] = location.country!;
        if (location.zipCode != null) request.fields['location[zipCode]'] = location.zipCode!;
        if (location.latitude != null) request.fields['location[latitude]'] = location.latitude.toString();
        if (location.longitude != null) request.fields['location[longitude]'] = location.longitude.toString();
      }

      // Validate images before upload
      if (images.isEmpty) {
        throw MarketplaceException(
          message: 'At least one image is required to create a listing.',
          code: 'VALIDATION_ERROR',
          operation: 'createListing',
        );
      }

      // Check image file sizes (max 10MB per image)
      const maxImageSize = 10 * 1024 * 1024; // 10MB
      for (var image in images) {
        int fileSize;
        if (kIsWeb) {
          // On web, read bytes to get file size
          final bytes = await image.readAsBytes();
          fileSize = bytes.length;
        } else {
          final file = File(image.path);
          if (await file.exists()) {
            fileSize = await file.length();
          } else {
            continue; // Skip if file doesn't exist
          }
        }
        
        if (fileSize > maxImageSize) {
          final fileName = kIsWeb ? image.name : path.basename(image.path);
          throw MarketplaceException(
            message: 'Image "$fileName" is too large (${(fileSize / 1024 / 1024).toStringAsFixed(1)}MB). Maximum size is 10MB per image.',
            code: 'FILE_TOO_LARGE',
            statusCode: 413,
            operation: 'createListing',
          );
        }
      }

      // Add images
      for (var image in images) {
        try {
          String mimeType;
          String fileName;
          
          if (kIsWeb) {
            // On web, use XFile properties
            fileName = image.name;
            final fileExtension = path.extension(fileName).toLowerCase();
            mimeType = fileExtension == '.jpg' || fileExtension == '.jpeg'
                ? 'image/jpeg'
                : fileExtension == '.png'
                    ? 'image/png'
                    : image.mimeType ?? 'image/jpeg';
            
            // Read bytes and create multipart file from bytes
            final bytes = await image.readAsBytes();
            request.files.add(
              http.MultipartFile.fromBytes(
                'images',
                bytes,
                filename: fileName,
                contentType: MediaType.parse(mimeType),
              ),
            );
          } else {
            // On mobile/desktop, use file path
            fileName = path.basename(image.path);
            final fileExtension = path.extension(image.path).toLowerCase();
            mimeType = fileExtension == '.jpg' || fileExtension == '.jpeg'
                ? 'image/jpeg'
                : fileExtension == '.png'
                    ? 'image/png'
                    : 'image/jpeg';

            request.files.add(
              await http.MultipartFile.fromPath(
                'images',
                image.path,
                contentType: MediaType.parse(mimeType),
              ),
            );
          }
        } catch (e) {
          final fileName = kIsWeb ? image.name : path.basename(image.path);
          throw MarketplaceException(
            message: 'Error processing image "$fileName": ${e.toString()}',
            code: 'IMAGE_PROCESSING_ERROR',
            operation: 'createListing',
          );
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 201) {
        try {
          final data = jsonDecode(response.body);
          if (data['success'] == false) {
            throw _parseError(data['message'] ?? response.body, response.statusCode, 'createListing');
          }
          return MarketplaceItem.fromJson(data['data']['item']);
        } catch (e) {
          if (e is MarketplaceException) rethrow;
          throw _parseError(response.body, response.statusCode, 'createListing');
        }
      } else {
        throw _parseError(response.body, response.statusCode, 'createListing');
      }
    } catch (e) {
      if (e is MarketplaceException) {
        _logger.error('Error creating marketplace listing: ${e.toJson()}');
        rethrow;
      }
      _logger.error('Error creating marketplace listing: $e');
      throw _handleNetworkError(e, 'createListing');
    }
  }

  // Update listing
  Future<MarketplaceItem> updateListing({
    required String id,
    String? title,
    String? description,
    String? category,
    double? price,
    List<XFile>? images,
    String? condition,
    int? quantity,
    bool? shippingAvailable,
    double? shippingCost,
    bool? localPickupOnly,
    MarketplaceLocation? location,
    List<String>? tags,
    String? status,
  }) async {
    try {
      final headers = await _getHeaders(includeContentType: false);
      final request = http.MultipartRequest(
        'PUT',
        Uri.parse('$baseUrl/marketplace/$id'),
      );

      request.headers.addAll(headers);

      // Add updated fields
      if (title != null) request.fields['title'] = title;
      if (description != null) request.fields['description'] = description;
      if (category != null) request.fields['category'] = category;
      if (price != null) request.fields['price'] = price.toString();
      if (condition != null) request.fields['condition'] = condition;
      if (quantity != null) request.fields['quantity'] = quantity.toString();
      if (shippingAvailable != null) request.fields['shippingAvailable'] = shippingAvailable.toString();
      if (shippingCost != null) request.fields['shippingCost'] = shippingCost.toString();
      if (localPickupOnly != null) request.fields['localPickupOnly'] = localPickupOnly.toString();
      if (status != null) request.fields['status'] = status;

      if (tags != null && tags.isNotEmpty) {
        request.fields['tags'] = jsonEncode(tags);
      }

      // Add location if provided
      if (location != null) {
        if (location.city != null) request.fields['location[city]'] = location.city!;
        if (location.state != null) request.fields['location[state]'] = location.state!;
        if (location.country != null) request.fields['location[country]'] = location.country!;
        if (location.zipCode != null) request.fields['location[zipCode]'] = location.zipCode!;
        if (location.latitude != null) request.fields['location[latitude]'] = location.latitude.toString();
        if (location.longitude != null) request.fields['location[longitude]'] = location.longitude.toString();
      }

      // Add images if provided
      if (images != null && images.isNotEmpty) {
        for (var image in images) {
          String mimeType;
          String fileName;
          
          if (kIsWeb) {
            // On web, use XFile properties
            fileName = image.name;
            final fileExtension = path.extension(fileName).toLowerCase();
            mimeType = fileExtension == '.jpg' || fileExtension == '.jpeg'
                ? 'image/jpeg'
                : fileExtension == '.png'
                    ? 'image/png'
                    : image.mimeType ?? 'image/jpeg';
            
            // Read bytes and create multipart file from bytes
            final bytes = await image.readAsBytes();
            request.files.add(
              http.MultipartFile.fromBytes(
                'images',
                bytes,
                filename: fileName,
                contentType: MediaType.parse(mimeType),
              ),
            );
          } else {
            // On mobile/desktop, use file path
            fileName = path.basename(image.path);
            final fileExtension = path.extension(image.path).toLowerCase();
            mimeType = fileExtension == '.jpg' || fileExtension == '.jpeg'
                ? 'image/jpeg'
                : fileExtension == '.png'
                    ? 'image/png'
                    : 'image/jpeg';

            request.files.add(
              await http.MultipartFile.fromPath(
                'images',
                image.path,
                contentType: MediaType.parse(mimeType),
              ),
            );
          }
        }
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['success'] == false) {
            throw _parseError(data['message'] ?? response.body, response.statusCode, 'updateListing');
          }
          return MarketplaceItem.fromJson(data['data']['item']);
        } catch (e) {
          if (e is MarketplaceException) rethrow;
          throw _parseError(response.body, response.statusCode, 'updateListing');
        }
      } else {
        throw _parseError(response.body, response.statusCode, 'updateListing');
      }
    } catch (e) {
      if (e is MarketplaceException) {
        _logger.error('Error updating marketplace listing: ${e.toJson()}');
        rethrow;
      }
      _logger.error('Error updating marketplace listing: $e');
      throw _handleNetworkError(e, 'updateListing');
    }
  }

  // Delete listing
  Future<void> deleteListing(String id) async {
    try {
      final headers = await _getHeaders();
      final response = await http.delete(
        Uri.parse('$baseUrl/marketplace/$id'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['success'] == false) {
            throw _parseError(data['message'] ?? response.body, response.statusCode, 'deleteListing');
          }
          return;
        } catch (e) {
          if (e is MarketplaceException) rethrow;
          // If deletion succeeds, ignore parsing errors
          return;
        }
      } else {
        throw _parseError(response.body, response.statusCode, 'deleteListing');
      }
    } catch (e) {
      if (e is MarketplaceException) {
        _logger.error('Error deleting marketplace listing: ${e.toJson()}');
        rethrow;
      }
      _logger.error('Error deleting marketplace listing: $e');
      throw _handleNetworkError(e, 'deleteListing');
    }
  }

  // Send inquiry
  Future<String> sendInquiry(String listingId, String message) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/marketplace/$listingId/inquire'),
        headers: headers,
        body: jsonEncode({'message': message}),
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['success'] == false) {
            throw _parseError(data['message'] ?? response.body, response.statusCode, 'sendInquiry');
          }
          return data['data']['conversationId'] as String;
        } catch (e) {
          if (e is MarketplaceException) rethrow;
          throw _parseError(response.body, response.statusCode, 'sendInquiry');
        }
      } else {
        throw _parseError(response.body, response.statusCode, 'sendInquiry');
      }
    } catch (e) {
      if (e is MarketplaceException) {
        _logger.error('Error sending inquiry: ${e.toJson()}');
        rethrow;
      }
      _logger.error('Error sending inquiry: $e');
      throw _handleNetworkError(e, 'sendInquiry');
    }
  }

  // Like/unlike listing
  Future<Map<String, dynamic>> toggleLike(String listingId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/marketplace/$listingId/like'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['success'] == false) {
            throw _parseError(data['message'] ?? response.body, response.statusCode, 'toggleLike');
          }
          return data['data'] as Map<String, dynamic>;
        } catch (e) {
          if (e is MarketplaceException) rethrow;
          throw _parseError(response.body, response.statusCode, 'toggleLike');
        }
      } else {
        throw _parseError(response.body, response.statusCode, 'toggleLike');
      }
    } catch (e) {
      if (e is MarketplaceException) {
        _logger.error('Error toggling like: ${e.toJson()}');
        rethrow;
      }
      _logger.error('Error toggling like: $e');
      throw _handleNetworkError(e, 'toggleLike');
    }
  }

  // Get my listings
  Future<Map<String, dynamic>> getMyListings({
    String? status,
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final headers = await _getHeaders();
      final queryParams = <String, String>{
        'page': page.toString(),
        'limit': limit.toString(),
      };
      if (status != null && status.isNotEmpty) queryParams['status'] = status;

      final uri = Uri.parse('$baseUrl/marketplace/my/listings').replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: headers);

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['success'] == false) {
            throw _parseError(data['message'] ?? response.body, response.statusCode, 'getMyListings');
          }
          final items = (data['data']['items'] as List)
              .map((item) => MarketplaceItem.fromJson(item))
              .toList();

          return {
            'success': true,
            'items': items,
            'pagination': data['data']['pagination'],
          };
        } catch (e) {
          if (e is MarketplaceException) rethrow;
          throw _parseError(response.body, response.statusCode, 'getMyListings');
        }
      } else {
        throw _parseError(response.body, response.statusCode, 'getMyListings');
      }
    } catch (e) {
      if (e is MarketplaceException) {
        _logger.error('Error fetching my listings: ${e.toJson()}');
        rethrow;
      }
      _logger.error('Error fetching my listings: $e');
      throw _handleNetworkError(e, 'getMyListings');
    }
  }

  // Purchase listing
  Future<Map<String, dynamic>> purchaseListing(String listingId, String paymentMethod) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/marketplace/$listingId/purchase'),
        headers: headers,
        body: jsonEncode({'paymentMethod': paymentMethod}),
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['success'] == false) {
            throw _parseError(data['message'] ?? response.body, response.statusCode, 'purchaseListing');
          }
          return data['data'] as Map<String, dynamic>;
        } catch (e) {
          if (e is MarketplaceException) rethrow;
          throw _parseError(response.body, response.statusCode, 'purchaseListing');
        }
      } else {
        throw _parseError(response.body, response.statusCode, 'purchaseListing');
      }
    } catch (e) {
      if (e is MarketplaceException) {
        _logger.error('Error purchasing listing: ${e.toJson()}');
        rethrow;
      }
      _logger.error('Error purchasing listing: $e');
      throw _handleNetworkError(e, 'purchaseListing');
    }
  }

  // Confirm purchase (seller only)
  Future<void> confirmPurchase(String listingId) async {
    try {
      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse('$baseUrl/marketplace/$listingId/confirm-purchase'),
        headers: headers,
      );

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          if (data['success'] == false) {
            throw _parseError(data['message'] ?? response.body, response.statusCode, 'confirmPurchase');
          }
          return;
        } catch (e) {
          if (e is MarketplaceException) rethrow;
          // If confirmation succeeds, ignore parsing errors
          return;
        }
      } else {
        throw _parseError(response.body, response.statusCode, 'confirmPurchase');
      }
    } catch (e) {
      if (e is MarketplaceException) {
        _logger.error('Error confirming purchase: ${e.toJson()}');
        rethrow;
      }
      _logger.error('Error confirming purchase: $e');
      throw _handleNetworkError(e, 'confirmPurchase');
    }
  }
}

