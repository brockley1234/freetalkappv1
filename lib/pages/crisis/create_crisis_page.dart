import 'package:flutter/material.dart';
import '../../services/crisis_service.dart';
import '../../utils/app_logger.dart';
import 'crisis_utils.dart';

class CreateCrisisPage extends StatefulWidget {
  const CreateCrisisPage({super.key});

  @override
  State<CreateCrisisPage> createState() => _CreateCrisisPageState();
}

class _CreateCrisisPageState extends State<CreateCrisisPage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _pageController = PageController();
  late CrisisService _crisisService;

  String _crisisType = 'mental_health';
  String _severity = 'medium';
  String _visibility = 'friends';
  bool _isAnonymous = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _crisisService = CrisisService();
    CrisisAnalytics.logCrisisCreated(_crisisType, _severity);
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _contactPhoneController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Help'),
        backgroundColor: Colors.red.shade700,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProgressIndicator(),
              const SizedBox(height: 24),
              _buildEmergencyInfoCard(),
              const SizedBox(height: 24),
              _buildFormSection(
                'Crisis Details',
                [
                  _buildCrisisTypeField(),
                  const SizedBox(height: 16),
                  _buildSeverityField(),
                  const SizedBox(height: 16),
                  _buildDescriptionField(),
                ],
              ),
              const SizedBox(height: 24),
              _buildFormSection(
                'Contact Information',
                [
                  _buildContactPhoneField(),
                  const SizedBox(height: 12),
                  Text(
                    'Providing a phone number helps responders reach you quickly.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildFormSection(
                'Visibility & Privacy',
                [
                  _buildVisibilityField(),
                  const SizedBox(height: 16),
                  _buildAnonymousSwitch(),
                  const SizedBox(height: 12),
                  Text(
                    'Anonymous posts hide your identity from other users but remain visible to administrators.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
              _buildSubmitButton(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressIndicator() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Step 1 of 3: Describe Your Situation',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: 0.33,
            minHeight: 4,
            backgroundColor: Colors.grey.shade300,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade700),
          ),
        ),
      ],
    );
  }

  Widget _buildFormSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade700,
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildEmergencyInfoCard() {
    return Card(
      color: Colors.red.shade50,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.red.shade300, width: 2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade700,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.emergency,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'In Immediate Danger?',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Call emergency services now',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Emergency call would dial 911')),
                      );
                    },
                    icon: const Icon(Icons.phone),
                    label: const Text('911'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text(
                                'Would dial 988 Suicide & Crisis Lifeline')),
                      );
                    },
                    icon: const Icon(Icons.phone),
                    label: const Text('988 Lifeline'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade700,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCrisisTypeField() {
    return DropdownButtonFormField<String>(
      initialValue: _crisisType,
      decoration: InputDecoration(
        labelText: 'Crisis Type',
        prefixIcon: Icon(
          CrisisIconUtils.getCrisisTypeIcon(_crisisType),
          color: Colors.red.shade700,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
        helperText: 'Select the type of crisis you\'re experiencing',
      ),
      items: CrisisConstants.crisisTypes.map((type) {
        return DropdownMenuItem(value: type.key, child: Text(type.value));
      }).toList(),
      onChanged: (value) {
        setState(() => _crisisType = value!);
      },
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please select a crisis type';
        }
        return null;
      },
    );
  }

  Widget _buildSeverityField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Severity Level',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          children: [
            _buildSeverityOption('low', 'Low', Colors.blue),
            _buildSeverityOption('medium', 'Medium', Colors.yellow.shade700),
            _buildSeverityOption('high', 'High', Colors.orange),
            _buildSeverityOption('critical', 'Critical', Colors.red),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Indicates how urgent your situation is',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildSeverityOption(String value, String label, Color color) {
    final isSelected = _severity == value;
    return GestureDetector(
      onTap: () => setState(() => _severity = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color:
              isSelected ? color.withValues(alpha: 0.2) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? color : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check_circle, color: color, size: 18),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? color : Colors.grey.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return TextFormField(
      controller: _descriptionController,
      maxLines: 5,
      maxLength: 1000,
      decoration: InputDecoration(
        labelText: 'Describe what\'s happening',
        hintText: 'Please provide as much detail as possible...',
        prefixIcon: const Icon(Icons.description),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
        alignLabelWithHint: true,
        helperText: 'Detailed descriptions help responders assist you better',
      ),
      validator: CrisisValidation.validateDescription,
    );
  }

  Widget _buildContactPhoneField() {
    return TextFormField(
      controller: _contactPhoneController,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: 'Contact Phone (Optional)',
        hintText: 'e.g., (555) 123-4567',
        prefixIcon: const Icon(Icons.phone),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
        helperText: 'Helps responders contact you directly',
      ),
      validator: CrisisValidation.validatePhoneNumber,
    );
  }

  Widget _buildVisibilityField() {
    return DropdownButtonFormField<String>(
      initialValue: _visibility,
      decoration: InputDecoration(
        labelText: 'Who can see this?',
        prefixIcon: const Icon(Icons.visibility),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: Colors.grey.shade50,
        helperText: 'Controls who can view and respond to your request',
      ),
      items: CrisisConstants.visibilityOptions.map((option) {
        return DropdownMenuItem(value: option.key, child: Text(option.value));
      }).toList(),
      onChanged: (value) {
        setState(() => _visibility = value!);
      },
    );
  }

  Widget _buildAnonymousSwitch() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.purple.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Post Anonymously',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Your identity will be hidden from other users',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isAnonymous,
            onChanged: (value) {
              setState(() => _isAnonymous = value);
            },
            activeThumbColor: Colors.purple,
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : _submitCrisis,
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red.shade700,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        disabledBackgroundColor: Colors.grey.shade400,
      ),
      icon: _isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : const Icon(Icons.sos),
      label: Text(
        _isLoading ? 'Sending...' : 'Request Help Now',
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _submitCrisis() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      CrisisAnalytics.logCrisisCreated(_crisisType, _severity);

      final crisis = await _crisisService.createCrisis(
        crisisType: _crisisType,
        severity: _severity,
        description: _descriptionController.text.trim(),
        contactPhone: _contactPhoneController.text.trim().isEmpty
            ? null
            : _contactPhoneController.text.trim(),
        isAnonymous: _isAnonymous,
        visibility: _visibility,
      );

      if (crisis != null && mounted) {
        _showSuccessDialog(crisis);
      } else if (mounted) {
        throw Exception('Failed to create crisis - no response from server');
      }
    } catch (e) {
      if (mounted) {
        AppLogger().error('Crisis creation failed: ${e.toString()}');
        _showErrorDialog(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showSuccessDialog(dynamic crisis) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 12),
            Text('Help Request Sent'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your crisis alert has been shared with responders.',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            Text(
              'Updates:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Responders will see your request shortly'),
            Text('• You\'ll receive notifications when people offer help'),
            Text('• Stay available to coordinate with responders'),
          ],
        ),
        actions: [
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context, crisis); // Return to previous screen
            },
            icon: const Icon(Icons.check),
            label: const Text('Got it'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('Error'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Failed to send crisis alert:'),
            const SizedBox(height: 8),
            Text(
              error.replaceFirst('Exception: ', ''),
              style: const TextStyle(fontStyle: FontStyle.italic),
            ),
            const SizedBox(height: 12),
            const Text(
              'Please check your connection and try again.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _submitCrisis(); // Retry
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
