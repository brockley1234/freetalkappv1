import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '../../models/marketplace_item_model.dart';
import '../../services/marketplace_service.dart';
import '../../utils/permission_helper.dart';
import 'dart:io';
import 'dart:typed_data';

class CreateMarketplaceListingPage extends StatefulWidget {
  const CreateMarketplaceListingPage({super.key});

  @override
  State<CreateMarketplaceListingPage> createState() => _CreateMarketplaceListingPageState();
}

class _CreateMarketplaceListingPageState extends State<CreateMarketplaceListingPage> {
  final _formKey = GlobalKey<FormState>();
  final MarketplaceService _marketplaceService = MarketplaceService();
  
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _priceController = TextEditingController();
  final TextEditingController _shippingCostController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _zipCodeController = TextEditingController();

  String _selectedCategory = 'other';
  String _selectedCondition = 'good';
  bool _shippingAvailable = false;
  bool _localPickupOnly = false;
  List<XFile> _selectedImages = [];
  bool _isLoading = false;
  bool _isLoadingLocation = false;
  double? _currentLatitude;
  double? _currentLongitude;
  String? _locationStatus;

  final List<String> _categories = [
    'electronics',
    'clothing',
    'furniture',
    'vehicles',
    'books',
    'toys',
    'sports',
    'home',
    'tools',
    'collectibles',
    'other'
  ];

  final List<String> _conditions = [
    'new',
    'like_new',
    'excellent',
    'good',
    'fair',
    'poor'
  ];

  @override
  void initState() {
    super.initState();
    // Try to get location automatically when page loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _getCurrentLocation();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _shippingCostController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipCodeController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (!mounted) return;
    
    setState(() {
      _isLoadingLocation = true;
      _locationStatus = 'Getting your location...';
    });

    try {
      // Request permission
      bool hasPermission = false;
      if (kIsWeb) {
        hasPermission = true; // Geolocator handles browser permissions
      } else {
        hasPermission = await PermissionHelper.requestLocationPermission(
          context,
          purpose: 'auto-fill your location for local buyers',
        );
      }

      if (!hasPermission) {
        setState(() {
          _isLoadingLocation = false;
          _locationStatus = 'Location permission denied';
        });
        return;
      }

      // Check if location services are enabled
      if (!kIsWeb) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          setState(() {
            _isLoadingLocation = false;
            _locationStatus = 'Location services disabled';
          });
          return;
        }
      }

      // Get current position
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 10),
        ),
      ).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          throw Exception('Location request timed out');
        },
      );

      setState(() {
        _currentLatitude = position.latitude;
        _currentLongitude = position.longitude;
        _isLoadingLocation = false;
        _locationStatus = 'Location found! GPS coordinates saved.';
      });

      // Note: Address fields can be filled manually if needed
      // Reverse geocoding would require additional package (geocoding)
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
        _locationStatus = 'Could not get location: ${e.toString()}';
      });
    }
  }

  Future<void> _pickImages() async {
    final ImagePicker picker = ImagePicker();
    final List<XFile> images = await picker.pickMultiImage();
    if (images.isNotEmpty) {
      setState(() {
        _selectedImages.addAll(images);
        if (_selectedImages.length > 10) {
          _selectedImages = _selectedImages.take(10).toList();
        }
      });
    }
  }

  Future<void> _removeImage(int index) async {
    setState(() {
      _selectedImages.removeAt(index);
    });
  }

  Future<void> _submitListing() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedImages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one image')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Location is now required - city, state, and zip code fields are validated
      final location = MarketplaceLocation(
        city: _cityController.text.trim(),
        state: _stateController.text.trim(),
        zipCode: _zipCodeController.text.trim(),
        latitude: _currentLatitude,
        longitude: _currentLongitude,
      );

      await _marketplaceService.createListing(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        category: _selectedCategory,
        price: double.parse(_priceController.text),
        images: _selectedImages,
        condition: _selectedCondition,
        shippingAvailable: _shippingAvailable,
        shippingCost: _shippingAvailable && _shippingCostController.text.isNotEmpty
            ? double.parse(_shippingCostController.text)
            : 0,
        localPickupOnly: _localPickupOnly,
        location: location,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Listing created successfully!')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        String errorMessage = 'Error creating listing';
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
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Listing'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Images
            const Text('Photos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _selectedImages.length + 1,
                itemBuilder: (context, index) {
                  if (index == _selectedImages.length) {
                    return GestureDetector(
                      onTap: _pickImages,
                      child: Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate, size: 40),
                            SizedBox(height: 8),
                            Text('Add Photo'),
                          ],
                        ),
                      ),
                    );
                  }
                  return Stack(
                    children: [
                      Container(
                        width: 120,
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: kIsWeb
                              ? FutureBuilder<Uint8List>(
                                  future: _selectedImages[index].readAsBytes(),
                                  builder: (context, snapshot) {
                                    if (snapshot.hasData) {
                                      return Image.memory(
                                        snapshot.data!,
                                        fit: BoxFit.cover,
                                        width: 120,
                                        height: 120,
                                      );
                                    } else if (snapshot.hasError) {
                                      return Container(
                                        width: 120,
                                        height: 120,
                                        color: Colors.grey[300],
                                        child: const Icon(Icons.broken_image, size: 40),
                                      );
                                    } else {
                                      return Container(
                                        width: 120,
                                        height: 120,
                                        color: Colors.grey[200],
                                        child: const Center(
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        ),
                                      );
                                    }
                                  },
                                )
                              : Image.file(
                                  File(_selectedImages[index].path),
                                  fit: BoxFit.cover,
                                  width: 120,
                                  height: 120,
                                ),
                        ),
                      ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: CircleAvatar(
                          radius: 12,
                          backgroundColor: Colors.black54,
                          child: IconButton(
                            padding: EdgeInsets.zero,
                            iconSize: 16,
                            icon: const Icon(Icons.close, color: Colors.white),
                            onPressed: () => _removeImage(index),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 24),

            // Title
            TextFormField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Title *',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a title';
                }
                if (value.length < 3) {
                  return 'Title must be at least 3 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description *',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a description';
                }
                if (value.length < 10) {
                  return 'Description must be at least 10 characters';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Category
            DropdownButtonFormField<String>(
              initialValue: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category *',
                border: OutlineInputBorder(),
              ),
              items: _categories.map((cat) {
                return DropdownMenuItem(
                  value: cat,
                  child: Text(cat.substring(0, 1).toUpperCase() + cat.substring(1)),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedCategory = value!);
              },
            ),
            const SizedBox(height: 16),

            // Condition
            DropdownButtonFormField<String>(
              initialValue: _selectedCondition,
              decoration: const InputDecoration(
                labelText: 'Condition *',
                border: OutlineInputBorder(),
              ),
              items: _conditions.map((cond) {
                return DropdownMenuItem(
                  value: cond,
                  child: Text(cond.split('_').map((e) => e[0].toUpperCase() + e.substring(1)).join(' ')),
                );
              }).toList(),
              onChanged: (value) {
                setState(() => _selectedCondition = value!);
              },
            ),
            const SizedBox(height: 16),

            // Price
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: 'Price (USD) *',
                border: OutlineInputBorder(),
                prefixText: '\$',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a price';
                }
                final price = double.tryParse(value);
                if (price == null || price <= 0) {
                  return 'Please enter a valid price';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Shipping options
            CheckboxListTile(
              title: const Text('Offer Shipping'),
              value: _shippingAvailable,
              onChanged: (value) {
                setState(() => _shippingAvailable = value ?? false);
              },
            ),
            if (_shippingAvailable) ...[
              TextFormField(
                controller: _shippingCostController,
                decoration: const InputDecoration(
                  labelText: 'Shipping Cost (USD)',
                  border: OutlineInputBorder(),
                  prefixText: '\$',
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
            ],
            CheckboxListTile(
              title: const Text('Local Pickup Only'),
              value: _localPickupOnly,
              onChanged: (value) {
                setState(() => _localPickupOnly = value ?? false);
              },
            ),
            const SizedBox(height: 16),

            // Location section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Location *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                if (_isLoadingLocation)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton.icon(
                    onPressed: _getCurrentLocation,
                    icon: const Icon(Icons.location_on, size: 18),
                    label: const Text('Use My Location'),
                  ),
              ],
            ),
            if (_locationStatus != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _locationStatus!,
                  style: TextStyle(
                    fontSize: 12,
                    color: _locationStatus!.contains('found') || _locationStatus!.contains('saved')
                        ? Colors.green
                        : Colors.grey[600],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: 'City *',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. New York',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'City is required';
                      }
                      if (value.trim().length < 2) {
                        return 'Enter a valid city name';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    controller: _stateController,
                    decoration: const InputDecoration(
                      labelText: 'State *',
                      border: OutlineInputBorder(),
                      hintText: 'e.g. NY',
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'State is required';
                      }
                      if (value.trim().length < 2) {
                        return 'Enter a valid state';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _zipCodeController,
              decoration: const InputDecoration(
                labelText: 'Zip Code *',
                border: OutlineInputBorder(),
                hintText: 'e.g. 10001',
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Zip code is required';
                }
                if (value.trim().length < 3) {
                  return 'Enter a valid zip code';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            Text(
              '* Location is required. This helps buyers find items nearby and improves visibility.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 24),

            // Submit button
            ElevatedButton(
              onPressed: _isLoading ? null : _submitListing,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create Listing'),
            ),
          ],
        ),
      ),
    );
  }
}

