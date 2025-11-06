import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/job_model.dart';
import '../../services/job_service.dart';
import '../../services/messaging_service.dart';
import '../../utils/auth_storage.dart';
import '../../utils/app_logger.dart';
import 'create_job_page.dart';
import '../chat_page.dart';

class JobDetailPage extends StatefulWidget {
  final String jobId;

  const JobDetailPage({super.key, required this.jobId});

  @override
  State<JobDetailPage> createState() => _JobDetailPageState();
}

class _JobDetailPageState extends State<JobDetailPage> {
  final JobService _jobService = JobService();
  Job? _job;
  bool _isLoading = true;
  bool _isCreatingConversation = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    _initializeAndLoad();
  }

  Future<void> _initializeAndLoad() async {
    // Load user ID first, then load job
    _currentUserId = await AuthStorage.getUserId();
    await _loadJob();
  }

  Future<void> _loadJob() async {
    setState(() => _isLoading = true);
    try {
      final job = await _jobService.getJob(widget.jobId);
      setState(() {
        _job = job;
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

  Future<void> _deleteJob() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Job'),
        content:
            const Text('Are you sure you want to delete this job posting?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _jobService.deleteJob(widget.jobId);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Job deleted successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting job: $e')),
          );
        }
      }
    }
  }

  Future<void> _toggleActiveStatus() async {
    try {
      await _jobService.toggleJobActive(widget.jobId);
      _loadJob();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_job!.isActive ? 'Job deactivated' : 'Job activated'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error toggling status: $e')),
        );
      }
    }
  }

  Future<void> _applyToJob() async {
    try {
      final result = await _jobService.applyToJob(widget.jobId);

      _loadJob(); // Refresh to update application count

      if (mounted && result['success'] == true) {
        final conversationId = result['data']?['conversationId'];

        // Show success dialog with option to view conversation
        final shouldOpenChat = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green, size: 28),
                SizedBox(width: 12),
                Text('Application Submitted!'),
              ],
            ),
            content: const Text(
              'Your application has been submitted and a message has been sent to the job poster. Would you like to open the conversation now?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Later'),
              ),
              ElevatedButton.icon(
                onPressed: () => Navigator.pop(context, true),
                icon: const Icon(Icons.message),
                label: const Text('Open Chat'),
              ),
            ],
          ),
        );

        // If user wants to open chat and we have a conversation ID
        if (shouldOpenChat == true && conversationId != null) {
          // Create a Map representation of the job poster for ChatPage
          final otherUserMap = {
            '_id': _job!.postedBy.id,
            'name': _job!.postedBy.name,
            'profilePicture': _job!.postedBy.profilePicture,
            'isVerified': _job!.postedBy.isVerified,
            'email': _job!.postedBy.email,
          };

          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatPage(
                  conversationId: conversationId,
                  otherUser: otherUserMap,
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error applying: $e')),
        );
      }
    }
  }

  Future<void> _messageJobPoster() async {
    if (_job == null || _isCreatingConversation) return;

    setState(() => _isCreatingConversation = true);

    try {
      // Get or create conversation with job poster
      final result = await MessagingService.getOrCreateConversation(
        _job!.postedBy.id,
      );

      setState(() => _isCreatingConversation = false);

      if (result['success'] == true) {
        final conversation = result['data']['conversation'];
        final conversationId = conversation['_id'];

        // Create a Map representation of the job poster for ChatPage
        final otherUserMap = {
          '_id': _job!.postedBy.id,
          'name': _job!.postedBy.name,
          'profilePicture': _job!.postedBy.profilePicture,
          'isVerified': _job!.postedBy.isVerified,
          'email': _job!.postedBy.email,
        };

        // Navigate to chat page
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatPage(
                conversationId: conversationId,
                otherUser: otherUserMap,
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result['message'] ?? 'Failed to start conversation',
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isCreatingConversation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open link')),
        );
      }
    }
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  Future<void> _shareJob() async {
    if (_job == null) return;

    try {
      final jobUrl = 'https://freetalk.site/jobs/${_job!.id}';
      final shareText = '''
Check out this job opportunity on FreeTalk:

${_job!.title}
${_job!.company} • ${_job!.location}

${_job!.description}

View full details: $jobUrl
''';

      await Share.share(
        shareText.trim(),
        subject: '${_job!.title} - ${_job!.company}',
      );
    } catch (e) {
      AppLogger().error('Failed to share job: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Details'),
        elevation: 0,
        actions: [
          if (_job != null && _currentUserId == _job!.postedBy.id) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => CreateJobPage(jobId: widget.jobId),
                  ),
                );
                if (result == true) {
                  _loadJob();
                }
              },
              tooltip: 'Edit job',
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'toggle') {
                  _toggleActiveStatus();
                } else if (value == 'delete') {
                  _deleteJob();
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'toggle',
                  child: Row(
                    children: [
                      Icon(
                        _job!.isActive ? Icons.pause : Icons.play_arrow,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(_job!.isActive ? 'Deactivate' : 'Activate'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 18),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ] else if (_job != null)
            IconButton(
              icon: const Icon(Icons.share_outlined),
              onPressed: _shareJob,
              tooltip: 'Share job',
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _job == null
              ? const Center(child: Text('Job not found'))
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header section
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          border: Border(
                            bottom: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _job!.title,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      height: 1.2,
                                    ),
                                  ),
                                ),
                                if (!_job!.isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'INACTIVE',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                if (_job!.isExpired)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade300,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'EXPIRED',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  _job!.company,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (_job!.postedBy.isVerified) ...[
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.verified,
                                    size: 20,
                                    color: Colors.blue.shade700,
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(
                                  Icons.location_on,
                                  size: 18,
                                  color: Colors.grey.shade700,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    _job!.location,
                                    style: TextStyle(
                                      fontSize: 15,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.shade100,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    _job!.getJobTypeDisplay(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.blue.shade700,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (_job!.salary != null) ...[
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.attach_money,
                                          size: 16,
                                          color: Colors.green.shade700,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          _job!.salary!,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                                const Spacer(),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.visibility,
                                          size: 16,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${_job!.views}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          Icons.people,
                                          size: 16,
                                          color: Colors.grey.shade600,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${_job!.applications}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Posted ${_getTimeAgo(_job!.createdAt)}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ), // Description
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Job Description',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _job!.description,
                              style: const TextStyle(fontSize: 16, height: 1.5),
                            ),

                            // Requirements
                            if (_job!.requirements != null) ...[
                              const SizedBox(height: 24),
                              const Text(
                                'Requirements',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _job!.requirements!,
                                style:
                                    const TextStyle(fontSize: 16, height: 1.5),
                              ),
                            ],

                            // Tags
                            if (_job!.tags.isNotEmpty) ...[
                              const SizedBox(height: 24),
                              const Text(
                                'Tags',
                                style: TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _job!.tags.map((tag) {
                                  return Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      tag,
                                      style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.grey.shade700),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],

                            // Contact Information
                            const SizedBox(height: 24),
                            const Text(
                              'Contact Information',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            if (_job!.contactEmail != null)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.email),
                                title: Text(_job!.contactEmail!),
                                trailing: IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () => _copyToClipboard(
                                      _job!.contactEmail!, 'Email'),
                                ),
                              ),
                            if (_job!.contactPhone != null)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.phone),
                                title: Text(_job!.contactPhone!),
                                trailing: IconButton(
                                  icon: const Icon(Icons.copy),
                                  onPressed: () => _copyToClipboard(
                                      _job!.contactPhone!, 'Phone'),
                                ),
                              ),
                            if (_job!.applicationUrl != null)
                              ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const Icon(Icons.link),
                                title: const Text('Application Link'),
                                trailing: IconButton(
                                  icon: const Icon(Icons.open_in_new),
                                  onPressed: () =>
                                      _launchUrl(_job!.applicationUrl!),
                                ),
                              ),

                            // Posted by
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Posted By',
                                  style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold),
                                ),
                                if (_currentUserId != _job!.postedBy.id)
                                  TextButton.icon(
                                    onPressed: _isCreatingConversation
                                        ? null
                                        : _messageJobPoster,
                                    icon: _isCreatingConversation
                                        ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Icon(Icons.message, size: 18),
                                    label: const Text('Message'),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Text(
                                  _job!.postedBy.name,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                if (_job!.postedBy.isVerified) ...[
                                  const SizedBox(width: 8),
                                  Icon(Icons.verified,
                                      size: 18, color: Colors.blue.shade700),
                                ],
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Posted ${_getTimeAgo(_job!.createdAt)}',
                              style: TextStyle(
                                  fontSize: 14, color: Colors.grey.shade600),
                            ),
                            const SizedBox(height: 80), // Space for FAB
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
      floatingActionButton: _job != null && _currentUserId != _job!.postedBy.id
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Message Poster button - always visible for non-poster viewers
                FloatingActionButton.extended(
                  onPressed: _isCreatingConversation ? null : _messageJobPoster,
                  icon: _isCreatingConversation
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.message),
                  label: Text(_isCreatingConversation
                      ? 'Opening...'
                      : 'Message Poster'),
                  backgroundColor: Colors.blue.shade600,
                  heroTag: 'message_poster',
                ),
                // Apply Now button - only visible if job is active and not expired
                if (_job!.isActive && !_job!.isExpired) ...[
                  const SizedBox(height: 12),
                  FloatingActionButton.extended(
                    onPressed: _applyToJob,
                    icon: const Icon(Icons.send),
                    label: const Text('Apply Now'),
                    heroTag: 'apply_now',
                  ),
                ],
              ],
            )
          : null,
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} month${(difference.inDays / 30).floor() > 1 ? 's' : ''} ago';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }
}
