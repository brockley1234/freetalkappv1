import 'package:flutter/material.dart';

class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Terms of Service'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          const Text(
            'ReelChat Terms of Service',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Last updated: October 4, 2025',
            style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
          ),
          const SizedBox(height: 24),
          _buildSection(
            '1. Acceptance of Terms',
            'By accessing and using ReelChat, you accept and agree to be bound by the terms and provision of this agreement. If you do not agree to these terms, please do not use this service.',
          ),
          _buildSection(
            '2. Description of Service',
            'ReelChat is a social networking platform that allows users to share posts, messages, stories, and interact with other users. We reserve the right to modify, suspend or discontinue the service at any time without notice.',
          ),
          _buildSection(
            '3. User Accounts',
            'You are responsible for maintaining the confidentiality of your account and password. You agree to accept responsibility for all activities that occur under your account. You must notify us immediately of any unauthorized use of your account.',
          ),
          _buildSection(
            '4. User Content',
            'You retain all rights to the content you post on ReelChat. However, by posting content, you grant ReelChat a worldwide, non-exclusive, royalty-free license to use, copy, reproduce, process, adapt, publish, and display such content.',
          ),
          _buildSection(
            '5. Prohibited Conduct',
            'You agree not to:\n'
                '• Post illegal, harmful, threatening, abusive, or offensive content\n'
                '• Harass, stalk, or harm other users\n'
                '• Impersonate any person or entity\n'
                '• Spam or send unsolicited messages\n'
                '• Attempt to gain unauthorized access to the service\n'
                '• Violate any applicable laws or regulations',
          ),
          _buildSection(
            '6. Content Moderation',
            'We reserve the right to remove any content that violates these terms or is otherwise objectionable. We may suspend or terminate accounts that repeatedly violate our terms.',
          ),
          _buildSection(
            '7. Intellectual Property',
            'The ReelChat service, including its original content, features, and functionality, is owned by ReelChat and is protected by international copyright, trademark, and other intellectual property laws.',
          ),
          _buildSection(
            '8. Privacy',
            'Your use of ReelChat is also governed by our Privacy Policy. Please review our Privacy Policy to understand our practices.',
          ),
          _buildSection(
            '9. Disclaimer of Warranties',
            'ReelChat is provided "as is" without warranties of any kind, either express or implied. We do not warrant that the service will be uninterrupted, secure, or error-free.',
          ),
          _buildSection(
            '10. Limitation of Liability',
            'To the maximum extent permitted by law, ReelChat shall not be liable for any indirect, incidental, special, consequential, or punitive damages resulting from your use of the service.',
          ),
          _buildSection(
            '11. Changes to Terms',
            'We reserve the right to modify these terms at any time. We will notify users of any material changes. Your continued use of the service after changes constitutes acceptance of the new terms.',
          ),
          _buildSection(
            '12. Termination',
            'We may terminate or suspend your account and access to the service immediately, without prior notice, for any reason, including breach of these terms.',
          ),
          _buildSection(
            '13. Governing Law',
            'These terms shall be governed by and construed in accordance with applicable laws, without regard to conflict of law provisions.',
          ),
          _buildSection(
            '14. Contact Information',
            'If you have any questions about these Terms of Service, please contact us at support@ReelTalk.com',
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
