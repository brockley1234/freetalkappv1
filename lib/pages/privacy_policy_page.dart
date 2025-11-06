import 'package:flutter/material.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Privacy Policy'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'ReelTalk Privacy Policy',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Last updated: October 4, 2025',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 24),
          _buildSection(
            'Introduction',
            'ReelTalk ("we", "our", or "us") is committed to protecting your privacy. This Privacy Policy explains how we collect, use, disclose, and safeguard your information when you use our social networking application.',
          ),
          _buildSection(
            '1. Information We Collect',
            'We collect several types of information:\n\n'
                '• Account Information: Name, email address, password, and profile picture\n'
                '• Profile Information: Bio, preferences, and settings\n'
                '• Content: Posts, comments, messages, reactions, and stories you create\n'
                '• Usage Data: How you interact with the service, features used, and time spent\n'
                '• Device Information: IP address, browser type, device type, and operating system\n'
                '• Location Data: General location based on IP address (if permitted)',
          ),
          _buildSection(
            '2. How We Use Your Information',
            'We use the collected information to:\n\n'
                '• Provide, maintain, and improve our services\n'
                '• Create and manage your account\n'
                '• Enable you to connect and communicate with other users\n'
                '• Send you notifications, updates, and promotional materials\n'
                '• Personalize your experience and content recommendations\n'
                '• Detect, prevent, and address technical issues and security threats\n'
                '• Analyze usage patterns and improve our services\n'
                '• Comply with legal obligations',
          ),
          _buildSection(
            '3. Information Sharing and Disclosure',
            'We may share your information in the following circumstances:\n\n'
                '• Public Content: Posts, comments, and profile information you choose to make public\n'
                '• With Other Users: Messages and content you share with specific users\n'
                '• Service Providers: Third-party vendors who help us operate the service\n'
                '• Legal Requirements: When required by law or to protect our rights\n'
                '• Business Transfers: In connection with a merger, sale, or acquisition\n\n'
                'We do NOT sell your personal information to third parties.',
          ),
          _buildSection(
            '4. Data Security',
            'We implement appropriate security measures to protect your information:\n\n'
                '• Encryption of data in transit and at rest\n'
                '• Secure password hashing\n'
                '• Regular security audits and updates\n'
                '• Access controls and authentication\n'
                '• Monitoring for suspicious activity\n\n'
                'However, no method of transmission over the internet is 100% secure, and we cannot guarantee absolute security.',
          ),
          _buildSection(
            '5. Your Rights and Choices',
            'You have the following rights regarding your information:\n\n'
                '• Access: View the personal information we have about you\n'
                '• Correction: Update or correct your information\n'
                '• Deletion: Request deletion of your account and data\n'
                '• Opt-out: Unsubscribe from promotional emails\n'
                '• Privacy Settings: Control who can see your content\n'
                '• Data Portability: Request a copy of your data\n'
                '• Restriction: Limit how we process your information',
          ),
          _buildSection(
            '6. Cookies and Tracking Technologies',
            'We use cookies and similar technologies to:\n\n'
                '• Maintain your session and keep you logged in\n'
                '• Remember your preferences and settings\n'
                '• Analyze usage patterns and improve performance\n'
                '• Provide personalized content and features\n\n'
                'You can control cookies through your browser settings.',
          ),
          _buildSection(
            '7. Third-Party Services',
            'Our service may contain links to third-party websites or services. We are not responsible for the privacy practices of these third parties. We encourage you to review their privacy policies.',
          ),
          _buildSection(
            '8. Children\'s Privacy',
            'ReelTalk is not intended for users under the age of 13. We do not knowingly collect information from children under 13. If we become aware that a child under 13 has provided us with personal information, we will delete it immediately.',
          ),
          _buildSection(
            '9. Data Retention',
            'We retain your information for as long as your account is active or as needed to provide services. You can request deletion of your account at any time. Some information may be retained for legal or legitimate business purposes.',
          ),
          _buildSection(
            '10. International Data Transfers',
            'Your information may be transferred to and processed in countries other than your own. We ensure appropriate safeguards are in place to protect your information in accordance with this privacy policy.',
          ),
          _buildSection(
            '11. Changes to Privacy Policy',
            'We may update this Privacy Policy from time to time. We will notify you of any material changes by posting the new policy on this page and updating the "Last updated" date. Your continued use of the service after changes constitutes acceptance.',
          ),
          _buildSection(
            '12. Contact Us',
            'If you have questions about this Privacy Policy or our privacy practices, please contact us at:\n\n'
                'Email: privacy@ReelTalk.com\n'
                'Address: ReelTalk Privacy Team',
          ),
          _buildSection(
            'Your Consent',
            'By using ReelTalk, you consent to the collection and use of information as described in this Privacy Policy.',
          ),
          const SizedBox(height: 32),
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
              ),
              child: const Text('I Understand'),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(content, style: const TextStyle(fontSize: 15, height: 1.5)),
        ],
      ),
    );
  }
}
