import 'package:flutter/material.dart';
import '../services/report_service.dart';

class ReportDialog extends StatefulWidget {
  final String contentType; // 'user', 'post', 'video', 'club'
  final String contentId;
  final String contentName;

  const ReportDialog({
    super.key,
    required this.contentType,
    required this.contentId,
    required this.contentName,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final _formKey = GlobalKey<FormState>();
  final _detailsController = TextEditingController();
  final _reportService = ReportService();

  String? _selectedReason;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a reason')),
      );
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      switch (widget.contentType) {
        case 'user':
          await _reportService.reportUser(
            userId: widget.contentId,
            reason: _selectedReason!,
            details: _detailsController.text.trim().isEmpty
                ? null
                : _detailsController.text.trim(),
          );
          break;
        case 'post':
          await _reportService.reportPost(
            postId: widget.contentId,
            reason: _selectedReason!,
            details: _detailsController.text.trim().isEmpty
                ? null
                : _detailsController.text.trim(),
          );
          break;
        case 'video':
          await _reportService.reportVideo(
            videoId: widget.contentId,
            reason: _selectedReason!,
            details: _detailsController.text.trim().isEmpty
                ? null
                : _detailsController.text.trim(),
          );
          break;
        case 'club':
          await _reportService.reportClub(
            clubId: widget.contentId,
            reason: _selectedReason!,
            details: _detailsController.text.trim().isEmpty
                ? null
                : _detailsController.text.trim(),
          );
          break;
        default:
          throw Exception('Invalid content type');
      }

      if (!mounted) return;

      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Report submitted successfully. Our team will review it shortly.'),
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _isSubmitting = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to submit report: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final reasons = ReportService.getReportReasons();

    return AlertDialog(
      title: Row(
        children: [
          Icon(
            Icons.flag,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(width: 8),
          const Text('Report Content'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Report: ${widget.contentName}',
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Why are you reporting this?',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              RadioGroup<String>(
                groupValue: _selectedReason,
                onChanged: (value) {
                  if (!_isSubmitting) {
                    setState(() => _selectedReason = value);
                  }
                },
                child: Column(
                  children: reasons
                      .map((reason) => RadioListTile<String>(
                            title: Text(reason.label),
                            subtitle: Text(
                              reason.description,
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                            value: reason.value,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Additional Details (Optional)',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _detailsController,
                enabled: !_isSubmitting,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(
                  hintText: 'Provide additional context...',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                validator: (value) {
                  if (value != null && value.length > 500) {
                    return 'Details cannot exceed 500 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 8),
              Text(
                'Your report will be reviewed by our moderation team.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _submitReport,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError,
          ),
          child: _isSubmitting
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).colorScheme.onError,
                    ),
                  ),
                )
              : const Text('Submit Report'),
        ),
      ],
    );
  }
}
