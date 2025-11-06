import 'package:flutter/material.dart';
import '../../services/job_service.dart';

class CreateJobPage extends StatefulWidget {
  final String? jobId; // For editing existing jobs

  const CreateJobPage({super.key, this.jobId});

  @override
  State<CreateJobPage> createState() => _CreateJobPageState();
}

class _CreateJobPageState extends State<CreateJobPage> {
  final _formKey = GlobalKey<FormState>();
  final JobService _jobService = JobService();

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _companyController = TextEditingController();
  final _locationController = TextEditingController();
  final _salaryController = TextEditingController();
  final _requirementsController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _applicationUrlController = TextEditingController();
  final _tagsController = TextEditingController();

  String _selectedJobType = 'full-time';
  bool _isLoading = false;
  bool _isEditMode = false;
  bool _showAdvancedOptions = false;
  bool _isSaving = false;
  int _descriptionCharCount = 0;
  int _requirementsCharCount = 0;
  int _tagsCharCount = 0;

  final List<String> _jobTypes = [
    'full-time',
    'part-time',
    'contract',
    'freelance',
    'internship',
    'remote'
  ];

  @override
  void initState() {
    super.initState();
    _isEditMode = widget.jobId != null;
    if (_isEditMode) {
      _loadJob();
    } else {
      _checkPostLimit();
    }

    // Add listeners to update character counts
    _descriptionController.addListener(() {
      setState(
          () => _descriptionCharCount = _descriptionController.text.length);
    });
    _requirementsController.addListener(() {
      setState(
          () => _requirementsCharCount = _requirementsController.text.length);
    });
    _tagsController.addListener(() {
      setState(() => _tagsCharCount = _tagsController.text.length);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _companyController.dispose();
    _locationController.dispose();
    _salaryController.dispose();
    _requirementsController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _applicationUrlController.dispose();
    _tagsController.dispose();
    super.dispose();
  }

  Future<void> _checkPostLimit() async {
    try {
      final info = await _jobService.canUserPost();

      if (info['canPost'] == false) {
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('Posting Limit Reached'),
              content: Text(
                'You can only post one job every 24 hours. Please try again in ${info['hoursRemaining']} hour(s).',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking post limit: $e')),
        );
      }
    }
  }

  Future<void> _loadJob() async {
    setState(() => _isLoading = true);
    try {
      final job = await _jobService.getJob(widget.jobId!);
      setState(() {
        _titleController.text = job.title;
        _descriptionController.text = job.description;
        _companyController.text = job.company;
        _locationController.text = job.location;
        _selectedJobType = job.jobType;
        _salaryController.text = job.salary ?? '';
        _requirementsController.text = job.requirements ?? '';
        _contactEmailController.text = job.contactEmail ?? '';
        _contactPhoneController.text = job.contactPhone ?? '';
        _applicationUrlController.text = job.applicationUrl ?? '';
        _tagsController.text = job.tags.join(', ');
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading job: $e')),
        );
      }
    }
  }

  Future<void> _saveJob() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final tags = _tagsController.text
          .split(',')
          .map((t) => t.trim())
          .where((t) => t.isNotEmpty)
          .toList();

      final jobData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'company': _companyController.text.trim(),
        'location': _locationController.text.trim(),
        'jobType': _selectedJobType,
        'salary': _salaryController.text.isEmpty
            ? null
            : _salaryController.text.trim(),
        'requirements': _requirementsController.text.isEmpty
            ? null
            : _requirementsController.text.trim(),
        'contactEmail': _contactEmailController.text.isEmpty
            ? null
            : _contactEmailController.text.trim(),
        'contactPhone': _contactPhoneController.text.isEmpty
            ? null
            : _contactPhoneController.text.trim(),
        'applicationUrl': _applicationUrlController.text.isEmpty
            ? null
            : _applicationUrlController.text.trim(),
        'tags': tags,
      };

      if (_isEditMode) {
        await _jobService.updateJob(widget.jobId!, jobData);
      } else {
        await _jobService.createJob(jobData);
      }

      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isEditMode
                ? 'Job updated successfully'
                : 'Job posted successfully',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      setState(() => _isSaving = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving job: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'Edit Job' : 'Post a Job'),
        elevation: 0,
        actions: [
          if (_isLoading)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: TextButton(
                onPressed: _isLoading || _isSaving ? null : _saveJob,
                child: Text(
                  _isEditMode ? 'Update' : 'Post',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Header with info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        _isEditMode ? Icons.edit : Icons.work_outline,
                        color: Colors.blue.shade700,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isEditMode
                                  ? 'Update your job posting'
                                  : 'Create a new job posting',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (!_isEditMode)
                              Text(
                                'You can post one job every 24 hours',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Required fields section header
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Basic Information',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Job Title
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: 'Job Title *',
                hintText: 'e.g., Senior Software Engineer, Product Manager',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.work),
                counterText: '${_titleController.text.length}/200',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a job title';
                }
                if (value.length > 200) {
                  return 'Title must be under 200 characters';
                }
                if (value.length < 5) {
                  return 'Title must be at least 5 characters';
                }
                return null;
              },
              maxLength: 200,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Company Name
            TextFormField(
              controller: _companyController,
              decoration: InputDecoration(
                labelText: 'Company Name *',
                hintText: 'e.g., Tech Solutions Inc., Startup XYZ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.business),
                counterText: '${_companyController.text.length}/200',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a company name';
                }
                if (value.length > 200) {
                  return 'Company name must be under 200 characters';
                }
                if (value.length < 2) {
                  return 'Company name must be at least 2 characters';
                }
                return null;
              },
              maxLength: 200,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Location
            TextFormField(
              controller: _locationController,
              decoration: InputDecoration(
                labelText: 'Location *',
                hintText: 'e.g., San Francisco, CA • New York • Remote',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.location_on),
                counterText: '${_locationController.text.length}/300',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a location';
                }
                if (value.length > 300) {
                  return 'Location must be under 300 characters';
                }
                return null;
              },
              maxLength: 300,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),

            // Job Type
            DropdownButtonFormField<String>(
              initialValue: _selectedJobType,
              decoration: InputDecoration(
                labelText: 'Job Type *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.category),
              ),
              items: _jobTypes.map((type) {
                return DropdownMenuItem(
                  value: type,
                  child: Text(
                    _formatJobType(type),
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedJobType = value!;
                });
              },
            ),
            const SizedBox(height: 24),

            // Description
            Text(
              'Job Description',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _descriptionController,
              decoration: InputDecoration(
                labelText: 'Job Description *',
                hintText:
                    'Describe the job responsibilities, required skills, qualifications, and what you\'re looking for in a candidate...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                alignLabelWithHint: true,
                helperText: 'Be detailed to attract qualified candidates',
                counterText: '$_descriptionCharCount/5000',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a job description';
                }
                if (value.length > 5000) {
                  return 'Description must be under 5000 characters';
                }
                if (value.length < 50) {
                  return 'Description must be at least 50 characters';
                }
                return null;
              },
              maxLines: 8,
              maxLength: 5000,
            ),
            const SizedBox(height: 24),

            // Optional fields section
            Row(
              children: [
                Container(
                  width: 4,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Additional Information',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    setState(
                        () => _showAdvancedOptions = !_showAdvancedOptions);
                  },
                  icon: Icon(
                    _showAdvancedOptions
                        ? Icons.expand_less
                        : Icons.expand_more,
                  ),
                  label: Text(_showAdvancedOptions ? 'Less' : 'More'),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Salary (optional)
            TextFormField(
              controller: _salaryController,
              decoration: InputDecoration(
                labelText: 'Salary Range (optional)',
                hintText: 'e.g., \$50,000 - \$70,000 or Competitive',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.attach_money),
                counterText: '${_salaryController.text.length}/100',
              ),
              maxLength: 100,
            ),
            const SizedBox(height: 16),

            // Requirements (optional)
            TextFormField(
              controller: _requirementsController,
              decoration: InputDecoration(
                labelText: 'Requirements (optional)',
                hintText:
                    'List the required qualifications, experience, and skills...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                alignLabelWithHint: true,
                counterText: '$_requirementsCharCount/3000',
              ),
              maxLines: 6,
              maxLength: 3000,
            ),
            const SizedBox(height: 16),

            // Tags
            TextFormField(
              controller: _tagsController,
              decoration: InputDecoration(
                labelText: 'Tags (optional)',
                hintText:
                    'e.g., engineering, remote, javascript, python, startup',
                helperText: 'Separate tags with commas (helps with search)',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.local_offer),
                counterText: '$_tagsCharCount/200',
              ),
              maxLength: 200,
            ),
            const SizedBox(height: 24),

            // Contact Information section (expandable)
            if (_showAdvancedOptions) ...[
              Text(
                'Contact Information',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Provide ways for candidates to reach you',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade600,
                ),
              ),
              const SizedBox(height: 16),

              // Contact Email
              TextFormField(
                controller: _contactEmailController,
                decoration: InputDecoration(
                  labelText: 'Contact Email (optional)',
                  hintText: 'hiring@company.com or your@email.com',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (!RegExp(
                            r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$')
                        .hasMatch(value)) {
                      return 'Please enter a valid email';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Contact Phone
              TextFormField(
                controller: _contactPhoneController,
                decoration: InputDecoration(
                  labelText: 'Contact Phone (optional)',
                  hintText: '+1 (555) 123-4567 or (555) 123-4567',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),

              // Application URL
              TextFormField(
                controller: _applicationUrlController,
                decoration: InputDecoration(
                  labelText: 'Application Link (optional)',
                  hintText: 'https://company.com/careers/apply',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.link),
                  helperText: 'Where candidates can apply directly',
                ),
                keyboardType: TextInputType.url,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    if (!value.startsWith('http://') &&
                        !value.startsWith('https://')) {
                      return 'Please enter a valid URL starting with http:// or https://';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
            ],

            // Submit button
            ElevatedButton(
              onPressed: _isLoading || _isSaving ? null : _saveJob,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isSaving)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    Icon(_isEditMode ? Icons.check : Icons.send_outlined),
                  const SizedBox(width: 8),
                  Text(
                    _isEditMode ? 'Update Job' : 'Post Job',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  String _formatJobType(String type) {
    return type
        .split('-')
        .map((e) => e[0].toUpperCase() + e.substring(1))
        .join('-');
  }
}
