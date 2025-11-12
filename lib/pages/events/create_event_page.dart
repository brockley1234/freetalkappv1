import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import '../../services/event_service.dart';
import '../../services/api_service.dart';

class CreateEventPage extends StatefulWidget {
  final String? eventId; // For editing existing events

  const CreateEventPage({super.key, this.eventId});

  @override
  State<CreateEventPage> createState() => _CreateEventPageState();
}

class _CreateEventPageState extends State<CreateEventPage> {
  final _formKey = GlobalKey<FormState>();
  final EventService _eventService = EventService();
  final ImagePicker _imagePicker = ImagePicker();
  
  // Memoize expensive operations
  late final List<DropdownMenuItem<String>> _visibilityItems;

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationNameController = TextEditingController();
  final _locationAddressController = TextEditingController();
  final _capacityController = TextEditingController();
  final _tagsController = TextEditingController();

  DateTime? _startTime;
  DateTime? _endTime;
  String _visibility = 'public';
  bool _isLoading = false;
  bool _isAllDay = false;
  bool _hasUnsavedChanges = false;
  XFile? _selectedImage;
  String? _existingImageUrl; // For editing existing events

  @override
  void initState() {
    super.initState();
    
    // Initialize dropdown items once
    _visibilityItems = const [
      DropdownMenuItem(value: 'public', child: Text('Public')),
      DropdownMenuItem(value: 'friends', child: Text('Friends Only')),
      DropdownMenuItem(value: 'private', child: Text('Private')),
    ];
    
    // Add listeners to track changes
    _titleController.addListener(_markAsChanged);
    _descriptionController.addListener(_markAsChanged);
    _locationNameController.addListener(_markAsChanged);
    _locationAddressController.addListener(_markAsChanged);
    _capacityController.addListener(_markAsChanged);
    _tagsController.addListener(_markAsChanged);
    
    if (widget.eventId != null) {
      _loadEventData();
    }
  }
  
  void _markAsChanged() {
    if (!_hasUnsavedChanges) {
      setState(() => _hasUnsavedChanges = true);
    }
  }

  /// Format DateTime for user-friendly display
  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'Not selected';
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(dateTime.year, dateTime.month, dateTime.day);
    
    String dateStr;
    if (dateOnly == today) {
      dateStr = 'Today';
    } else if (dateOnly == tomorrow) {
      dateStr = 'Tomorrow';
    } else {
      dateStr = DateFormat('EEE, MMM d, yyyy').format(dateTime);
    }
    
    final timeStr = DateFormat('h:mm a').format(dateTime);
    return '$dateStr at $timeStr';
  }

  /// Show dialog to confirm discarding unsaved changes
  Future<bool> _confirmDiscard() async {
    if (!_hasUnsavedChanges) return true;
    
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text('You have unsaved changes. Are you sure you want to leave?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }

  Future<void> _loadEventData() async {
    try {
      final event = await _eventService.getEvent(widget.eventId!);
      setState(() {
        _titleController.text = event.title;
        _descriptionController.text = event.description;
        _locationNameController.text = event.locationName ?? '';
        _locationAddressController.text = event.locationAddress ?? '';
        _capacityController.text = event.capacity?.toString() ?? '';
        _tagsController.text = event.tags.join(', ');
        _startTime = event.startTime;
        _endTime = event.endTime;
        _visibility = event.visibility;
        _isAllDay = event.isAllDay;
        _existingImageUrl = event.coverImage;
        _hasUnsavedChanges = false; // Reset since we just loaded
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading event: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationNameController.dispose();
    _locationAddressController.dispose();
    _capacityController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    if (_isLoading) return; // Prevent image picking during loading
    
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 600, // Further reduced for better performance
        maxHeight: 400,
        imageQuality: 70, // Further reduced for better performance
      );
      if (image != null && mounted) {
        // Use a single setState call to reduce rebuilds
        setState(() {
          _selectedImage = image;
          _existingImageUrl = null;
          _hasUnsavedChanges = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _selectDateTime(BuildContext context, bool isStartTime) async {
    final date = await showDatePicker(
      context: context,
      initialDate: isStartTime 
          ? (_startTime ?? DateTime.now())
          : (_endTime ?? _startTime ?? DateTime.now()),
      firstDate: widget.eventId != null ? DateTime(2020) : DateTime.now(), // Allow past dates for editing
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (date != null && mounted) {
      if (_isAllDay) {
        // For all-day events, set time to midnight
        setState(() {
          if (isStartTime) {
            _startTime = DateTime(date.year, date.month, date.day, 0, 0);
          } else {
            _endTime = DateTime(date.year, date.month, date.day, 23, 59);
          }
          _hasUnsavedChanges = true;
        });
      } else {
        // Show time picker for regular events
        final time = await showTimePicker(
          context: mounted ? this.context : context,
          initialTime: isStartTime && _startTime != null
              ? TimeOfDay.fromDateTime(_startTime!)
              : isStartTime == false && _endTime != null
                  ? TimeOfDay.fromDateTime(_endTime!)
                  : TimeOfDay.now(),
        );

        if (time != null && mounted) {
          final dateTime = DateTime(
            date.year,
            date.month,
            date.day,
            time.hour,
            time.minute,
          );
          setState(() {
            if (isStartTime) {
              _startTime = dateTime;
              // If endTime is not set or is before the new startTime, update it
              if (_endTime == null || _endTime!.isBefore(dateTime)) {
                _endTime = dateTime.add(const Duration(hours: 1));
              }
            } else {
              // Validate that endTime is after startTime
              if (_startTime != null && dateTime.isBefore(_startTime!)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('End time must be after start time')),
                );
                return;
              }
              _endTime = dateTime;
            }
            _hasUnsavedChanges = true;
          });
        }
      }
    }
  }

  Future<void> _saveEvent() async {
    if (!_formKey.currentState!.validate()) return;

    if (_startTime == null || _endTime == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select start and end times')),
      );
      return;
    }

    // Validate that end time is after start time
    if (_endTime!.isBefore(_startTime!) || _endTime == _startTime) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time')),
      );
      return;
    }

    // Validate that start time is in the future (for new events only)
    if (widget.eventId == null && _startTime!.isBefore(DateTime.now())) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Start time must be in the future')),
      );
      return;
    }

    // Validate capacity if provided
    if (_capacityController.text.isNotEmpty) {
      final capacity = int.tryParse(_capacityController.text);
      if (capacity == null || capacity <= 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Capacity must be a positive number')),
        );
        return;
      }
    }

    // Validate title length
    if (_titleController.text.length > 100) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Title must be 100 characters or less')),
      );
      return;
    }

    // Validate description length
    if (_descriptionController.text.length > 1000) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Description must be 1000 characters or less')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      // Upload image if selected
      String? coverImageUrl;
      bool shouldDeleteImage = false;
      
      if (_selectedImage != null) {
        final uploadResult = await ApiService.uploadImage(_selectedImage!);
        debugPrint('DEBUG: Upload result: $uploadResult');
        if (uploadResult['success'] == true) {
          coverImageUrl = uploadResult['data']['url'];
          debugPrint('DEBUG: Image uploaded successfully. URL: $coverImageUrl');
        } else {
          debugPrint('DEBUG: Image upload failed: ${uploadResult['message']}');
        }
      } else if (_existingImageUrl != null) {
        coverImageUrl = _existingImageUrl;
      } else {
        // If editing and both are null, we want to delete the image
        shouldDeleteImage = widget.eventId != null;
      }

      final eventData = <String, dynamic>{
        'title': _titleController.text,
        'description': _descriptionController.text,
        // Send UTC ISO8601 to avoid timezone parsing quirks on server
        'startTime': _startTime!.toUtc().toIso8601String(),
        'endTime': _endTime!.toUtc().toIso8601String(),
        // Mirror to legacy field used by backend validator fallback
        'date': _startTime!.toUtc().toIso8601String(),
        // Make timezone explicit
        'timezone': 'UTC',
        'isAllDay': _isAllDay,
        'visibility': _visibility,
        'tags': tags,
        if (_locationNameController.text.isNotEmpty)
          'locationName': _locationNameController.text,
        if (_locationAddressController.text.isNotEmpty)
          'locationAddress': _locationAddressController.text,
        if (_capacityController.text.isNotEmpty && int.tryParse(_capacityController.text) != null)
          'capacity': int.parse(_capacityController.text),
        // Handle coverImage: set to new URL, null for deletion, or omit to keep existing
        if (shouldDeleteImage)
          'coverImage': null
        else if (coverImageUrl != null)
          'coverImage': coverImageUrl,
      };

      debugPrint('DEBUG: Event data being saved:');
      debugPrint('DEBUG: - coverImage: ${eventData['coverImage']}');
      debugPrint('DEBUG: - shouldDeleteImage: $shouldDeleteImage');
      debugPrint('DEBUG: - coverImageUrl: $coverImageUrl');

      if (widget.eventId != null) {
        debugPrint('DEBUG: Updating existing event ${widget.eventId}');
        await _eventService.updateEvent(widget.eventId!, eventData);
      } else {
        debugPrint('DEBUG: Creating new event');
        await _eventService.createEvent(eventData);
      }

      if (!mounted) return;
      setState(() => _hasUnsavedChanges = false);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (!mounted) return;
      String errorMessage = 'Error saving event: $e';
      if (e is ApiException) {
        errorMessage = e.userFriendlyMessage;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _confirmDiscard();
        if (shouldPop && context.mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.eventId != null ? 'Edit Event' : 'Create Event'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final shouldPop = await _confirmDiscard();
              if (shouldPop && context.mounted) {
                Navigator.pop(context);
              }
            },
          ),
          actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(color: Colors.white),
              ),
            )
          else
            TextButton(
              onPressed: _isLoading ? null : _saveEvent,
              child: const Text('Save', style: TextStyle(color: Colors.green)),
            ),
          ],
        ),
        body: Form(
        key: _formKey,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: 1,
          itemBuilder: (context, index) => Column(
            children: [
            // Cover Image Section
            Container(
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: InkWell(
                onTap: _isLoading ? null : _pickImage,
                borderRadius: BorderRadius.circular(12),
                child: RepaintBoundary(
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                    if (_selectedImage != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          File(_selectedImage!.path),
                          fit: BoxFit.cover,
                          cacheWidth: 300, // Further optimized for performance
                          cacheHeight: 150,
                          filterQuality: FilterQuality.low, // Reduce quality for better performance
                        ),
                      )
                    else if (_existingImageUrl != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: _existingImageUrl!,
                          fit: BoxFit.cover,
                          memCacheWidth: 300, // Further optimized for performance
                          memCacheHeight: 150,
                          filterQuality: FilterQuality.low, // Reduce quality for better performance
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.error, size: 20),
                          ),
                        ),
                      )
                    else
                      Container(
                        color: Colors.grey[100],
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_photo_alternate,
                                size: 48, color: Colors.grey[400]),
                            const SizedBox(height: 8),
                            Text(
                              'Add Cover Image',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Add a delete button when there's an existing image or a selected new image
                    if ((_existingImageUrl != null || _selectedImage != null) && !_isLoading)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Material(
                          color: Colors.red[600],
                          borderRadius: BorderRadius.circular(20),
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                _existingImageUrl = null;
                                _selectedImage = null;
                              });
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: const Padding(
                              padding: EdgeInsets.all(8.0),
                              child: Icon(Icons.delete, color: Colors.white, size: 20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Event Title Field
            TextFormField(
              controller: _titleController,
              enabled: !_isLoading,
              decoration: InputDecoration(
                labelText: 'Event Title *',
                border: const OutlineInputBorder(),
                helperText: '${_titleController.text.length}/100 characters',
                helperMaxLines: 1,
              ),
              maxLength: 100,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a title';
                }
                if (value.length > 100) {
                  return 'Title must be 100 characters or less';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _descriptionController,
              enabled: !_isLoading,
              decoration: InputDecoration(
                labelText: 'Description *',
                border: const OutlineInputBorder(),
                helperText: '${_descriptionController.text.length}/1000 characters',
                helperMaxLines: 1,
              ),
              maxLines: 4,
              maxLength: 1000,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a description';
                }
                if (value.length > 1000) {
                  return 'Description must be 1000 characters or less';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Start Time
            ListTile(
              enabled: !_isLoading,
              title: const Text('Start Time *'),
              subtitle: Text(
                _formatDateTime(_startTime),
                style: TextStyle(
                  fontWeight: _startTime != null ? FontWeight.w500 : null,
                  color: _startTime != null ? Theme.of(context).primaryColor : null,
                ),
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _isLoading ? null : () => _selectDateTime(context, true),
              shape: RoundedRectangleBorder(
                side: const BorderSide(color: Colors.grey),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),

            // End Time
            ListTile(
              enabled: !_isLoading,
              title: const Text('End Time *'),
              subtitle: Text(
                _formatDateTime(_endTime),
                style: TextStyle(
                  fontWeight: _endTime != null ? FontWeight.w500 : null,
                  color: _endTime != null && _startTime != null && _endTime!.isBefore(_startTime!)
                      ? Colors.red
                      : _endTime != null
                          ? Theme.of(context).primaryColor
                          : null,
                ),
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _isLoading ? null : () => _selectDateTime(context, false),
              shape: RoundedRectangleBorder(
                side: BorderSide(
                  color: _endTime != null && _startTime != null && _endTime!.isBefore(_startTime!)
                      ? Colors.red
                      : Colors.grey,
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),

            // All Day Toggle
            SwitchListTile(
              title: const Text('All Day Event'),
              subtitle: const Text('Event runs for the entire day'),
              value: _isAllDay,
              onChanged: _isLoading ? null : (value) {
                setState(() {
                  _isAllDay = value;
                  _hasUnsavedChanges = true;
                  // If switching to all-day, reset times to midnight and 11:59 PM
                  if (value && _startTime != null) {
                    _startTime = DateTime(
                      _startTime!.year,
                      _startTime!.month,
                      _startTime!.day,
                      0,
                      0,
                    );
                  }
                  if (value && _endTime != null) {
                    _endTime = DateTime(
                      _endTime!.year,
                      _endTime!.month,
                      _endTime!.day,
                      23,
                      59,
                    );
                  }
                });
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _locationNameController,
              enabled: !_isLoading,
              decoration: const InputDecoration(
                labelText: 'Location Name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _locationAddressController,
              enabled: !_isLoading,
              decoration: const InputDecoration(
                labelText: 'Location Address',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _capacityController,
              enabled: !_isLoading,
              decoration: const InputDecoration(
                labelText: 'Capacity (leave empty for unlimited)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),

            DropdownButtonFormField<String>(
              initialValue: _visibility,
              decoration: const InputDecoration(
                labelText: 'Visibility',
                border: OutlineInputBorder(),
              ),
              items: _visibilityItems,
              onChanged: _isLoading ? null : (value) {
                if (value != null) {
                  setState(() {
                    _visibility = value;
                    _hasUnsavedChanges = true;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _tagsController,
              enabled: !_isLoading,
              decoration: const InputDecoration(
                labelText: 'Tags (comma-separated)',
                border: OutlineInputBorder(),
                helperText: 'e.g. music, sports, tech',
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              '* Required fields',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            ],
          ),
        ),
        ),
      ),
    );
  }
}
