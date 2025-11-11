import 'package:flutter/material.dart';
import '../services/api_service.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About ReelChat'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // App Logo/Icon
          Center(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                size: 64,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(height: 24),

          // App Name and Version
          Center(
            child: Text(
              ApiService.appName,
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 8),

          Center(
            child: Text(
              ApiService.appVersion,
              style: TextStyle(
                fontSize: 16, 
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Tagline
          Center(
            child: Text(
              'Your Voice, Your Community, Your Connection',
              style: TextStyle(
                fontSize: 18,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 32),

          // Mission Statement
          Card(
            elevation: 2,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.favorite, color: Theme.of(context).colorScheme.error, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        'Our Mission',
                        style: TextStyle(
                            fontSize: 20, 
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'To create a vibrant, inclusive social platform where meaningful connections thrive. We believe in empowering communities through real-time communication, authentic expression, and shared experiences.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // About This App
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What is ReelTalk?',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${ApiService.appName} is a next-generation social media platform built for iOS, Android, and Web. We combine real-time messaging, rich content sharing, interactive gaming, and community features into one beautiful, performant application. Available on Google Play, Apple App Store, and web - ${ApiService.appName} brings people together anywhere, anytime.',
                    style: TextStyle(
                      fontSize: 15,
                      height: 1.6,
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Features Section
          _buildSectionTitle('Core Features'),

          _buildFeatureItem(
            Icons.post_add,
            'Share Posts',
            'Create posts with text, images, videos, and music. Express yourself with rich media content and reach your community.',
          ),

          _buildFeatureItem(
            Icons.message_outlined,
            'Real-Time Messaging',
            'Instant messaging with real-time updates via Socket.IO. See typing indicators and read receipts instantly.',
          ),

          _buildFeatureItem(
            Icons.auto_awesome,
            'Daily Streaks',
            'Build and maintain engagement streaks. Challenge yourself and track your consistency with leaderboards.',
          ),

          _buildFeatureItem(
            Icons.group_outlined,
            'Clubs & Communities',
            'Join or create clubs around shared interests. Connect with people who share your passions.',
          ),

          _buildFeatureItem(
            Icons.games_outlined,
            'Multiplayer Games',
            'Play interactive games with friends. Invite others and compete on real-time scoreboards.',
          ),

          _buildFeatureItem(
            Icons.campaign_outlined,
            'Stories',
            'Share moments that disappear after 24 hours. Ephemeral content for authentic sharing.',
          ),

          _buildFeatureItem(
            Icons.favorite_outline,
            'Multiple Reactions',
            'Express yourself beyond likes with diverse reaction types. Engage meaningfully with content.',
          ),

          _buildFeatureItem(
            Icons.comment_outlined,
            'Comments & Replies',
            'Engage in nested conversations. Build communities through meaningful discussions.',
          ),

          _buildFeatureItem(
            Icons.notifications_outlined,
            'Smart Notifications',
            'Firebase Cloud Messaging for instant alerts. Never miss important updates.',
          ),

          _buildFeatureItem(
            Icons.card_giftcard_outlined,
            'Achievements & Badges',
            'Unlock achievements and earn badges. Celebrate milestones in your ${ApiService.appName} journey.',
          ),

          _buildFeatureItem(
            Icons.memory_outlined,
            'Memories Feature',
            'Relive past moments. Nostalgia-driven content that brings back cherished memories.',
          ),

          _buildFeatureItem(
            Icons.security_outlined,
            'End-to-End Privacy',
            'Control who sees your content. Privacy controls for profile, posts, and messages.',
          ),

          _buildFeatureItem(
            Icons.dark_mode_outlined,
            'Dark & Light Modes',
            'Switch between beautiful light and dark themes. Easy on the eyes, day or night.',
          ),

          const SizedBox(height: 24),

          // Statistics Section
          _buildSectionTitle('By The Numbers'),

          SizedBox(
            height: 140,
            child: Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: GridView.count(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 1.2,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _buildStatItem('3', 'Platforms', '(iOS, Android, Web)'),
                    _buildStatItem('50+', 'Features', 'Rich social experience'),
                    _buildStatItem('28', 'API Routes', 'Robust backend'),
                    _buildStatItem('30+', 'DB Models', 'Complex data'),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Technology Stack
          _buildSectionTitle('Built With Modern Tech'),

          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildTechItem(context,
                      'Flutter 3.24+', 'Cross-platform UI (iOS, Android, Web)'),
                  const Divider(),
                  _buildTechItem(context,'Node.js 18+', 'High-performance backend'),
                  const Divider(),
                  _buildTechItem(context,'Express.js', 'Flexible web framework'),
                  const Divider(),
                  _buildTechItem(context,'MongoDB', 'Scalable NoSQL database'),
                  const Divider(),
                  _buildTechItem(context,
                      'Socket.IO 4.8', 'Real-time bidirectional communication'),
                  const Divider(),
                  _buildTechItem(context,
                      'Firebase', 'Authentication & Cloud Messaging (FCM)'),
                  const Divider(),
                  _buildTechItem(context,
                      'In-App Purchase', 'Stripe & App Store/Google Play'),
                  const Divider(),
                  _buildTechItem(context,'Provider', 'State management for Flutter'),
                  const Divider(),
                  _buildTechItem(context,
                      'Nginx & SSL', 'Production-grade hosting & security'),
                  const Divider(),
                  _buildTechItem(context,'Docker', 'Containerization for deployment'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // App Information
          _buildSectionTitle('Project Details'),

          Card(
            elevation: 2,
            child: Column(
              children: [
                _buildInfoListTile(
                  Icons.developer_mode,
                  'Developers',
                  'Johnny & Walid',
                ),
                const Divider(height: 1),
                _buildInfoListTile(
                  Icons.calendar_today,
                  'Launch',
                  'October 2025',
                ),
                const Divider(height: 1),
                _buildInfoListTile(
                  Icons.language,
                  'Platforms',
                  'iOS, Android, Web',
                ),
                const Divider(height: 1),
                _buildInfoListTile(
                  Icons.info_outline,
                  'Status',
                  'Live Production',
                ),
                const Divider(height: 1),
                _buildInfoListTile(
                  Icons.storage_outlined,
                  '',
                  '',
                ),
                const Divider(height: 1),
                _buildInfoListTile(
                  Icons.cloud_outlined,
                  '',
                  '',
                ),
                const Divider(height: 1),
                _buildInfoListTile(Icons.code, 'Build',
                    '${ApiService.appVersion} (Production)'),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // Credits
          _buildSectionTitle('Special Thanks & Credits'),

          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCreditItem(context,'Framework', 'Flutter & Dart'),
                  _buildCreditItem(context,'Server', 'Express.js & Node.js'),
                  _buildCreditItem(context,'Real-Time', 'Socket.IO'),
                  _buildCreditItem(context,'Database', 'MongoDB & Mongoose'),
                  _buildCreditItem(context,'Design System', 'Material Design 3'),
                  _buildCreditItem(context,'Icons', 'Material Icons & Cupertino'),
                  _buildCreditItem(context,'State Mgmt', 'Provider Pattern'),
                  _buildCreditItem(context,'Cloud Services', 'Firebase & DigitalOcean'),
                  _buildCreditItem(context,
                      'Community', 'Flutter & Node.js Communities'),
                  _buildCreditItem(context,'Inspiration', 'Modern social platforms'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Social/Contact Section
          _buildSectionTitle('Get In Touch'),

          Card(
            elevation: 2,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.public, color: Colors.blue),
                  title: const Text('Visit Our Website'),
                  subtitle: const Text('https://freetalk.site'),
                  trailing: const Icon(Icons.open_in_new),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Opening website...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.store_outlined, color: Colors.blue),
                  title: const Text('Download'),
                  subtitle: const Text('Available on App Store & Google Play'),
                  trailing: const Icon(Icons.download),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Download links coming soon'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading:
                      const Icon(Icons.bug_report_outlined, color: Colors.blue),
                  title: const Text('Report Issues'),
                  subtitle: const Text('Help us improve FreeTalk'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                            'Issue tracker: https://github.com/johnnyb12331-lgtm/freetalk'),
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 32),

          // Legal Links
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Opening Terms of Service...')),
                  );
                },
                child: const Text('Terms'),
              ),
              Text(
                ' • ', 
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Opening Privacy Policy...')),
                  );
                },
                child: const Text('Privacy'),
              ),
              Text(
                ' • ', 
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Opening Community Guidelines...')),
                  );
                },
                child: const Text('Guidelines'),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Copyright
          Center(
            child: Text(
              '© 2025 FreeTalk. All rights reserved.',
              style: TextStyle(
                fontSize: 12, 
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 8),

          Center(
            child: Text(
              'Built with ❤️ by John & Walid',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 8),

          Center(
            child: Text(
              'Version ${ApiService.appVersion}',
              style: TextStyle(
                fontSize: 11, 
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String title, String description) {
    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue, size: 24),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(description, style: const TextStyle(fontSize: 13)),
      ),
    );
  }

  Widget _buildTechItem(BuildContext context, String name, String description) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          Text(
            description,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), 
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoListTile(IconData icon, String title, String subtitle) {
    return ListTile(
      leading: Icon(icon, color: Colors.blue),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }

  Widget _buildCreditItem(BuildContext context, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7), 
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String number, String label, String description) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          number,
          style: const TextStyle(
              fontSize: 24, fontWeight: FontWeight.bold, color: Colors.blue),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          description,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
