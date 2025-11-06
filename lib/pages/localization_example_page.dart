import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';

/// This is an example page demonstrating how to use localization in FreeTalk
///
/// Key points:
/// 1. Import AppLocalizations
/// 2. Get the localization instance using AppLocalizations.of(context)!
/// 3. Use the localization keys instead of hardcoded strings
///
class LocalizationExamplePage extends StatelessWidget {
  const LocalizationExamplePage({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the localization instance
    // This will automatically update when the language changes
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      // Use localization for AppBar title
      appBar: AppBar(
        title: Text(l10n.settings),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            // Use localization for tooltip
            tooltip: l10n.search,
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section: Common Texts
            Text(
              'Common Texts',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _buildExampleItem(context, l10n.ok),
            _buildExampleItem(context, l10n.cancel),
            _buildExampleItem(context, l10n.save),
            _buildExampleItem(context, l10n.delete),
            _buildExampleItem(context, l10n.loading),

            const Divider(height: 32),

            // Section: Authentication
            Text(
              'Authentication',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _buildExampleItem(context, l10n.login),
            _buildExampleItem(context, l10n.register),
            _buildExampleItem(context, l10n.logout),
            _buildExampleItem(context, l10n.email),
            _buildExampleItem(context, l10n.password),
            _buildExampleItem(context, l10n.forgotPassword),

            const Divider(height: 32),

            // Section: Navigation
            Text(
              'Navigation',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _buildExampleItem(context, l10n.home),
            _buildExampleItem(context, l10n.profile),
            _buildExampleItem(context, l10n.messages),
            _buildExampleItem(context, l10n.notifications),
            _buildExampleItem(context, l10n.settings),

            const Divider(height: 32),

            // Section: Posts
            Text(
              'Posts',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            _buildExampleItem(context, l10n.createPost),
            _buildExampleItem(context, l10n.editPost),
            _buildExampleItem(context, l10n.deletePost),
            _buildExampleItem(context, l10n.likePost),
            _buildExampleItem(context, l10n.comments),
            _buildExampleItem(context, l10n.sharePost),

            const Divider(height: 32),

            // Example: Button with localized text
            Text(
              'Example: Buttons',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: () {},
                  child: Text(l10n.save),
                ),
                OutlinedButton(
                  onPressed: () {},
                  child: Text(l10n.cancel),
                ),
                TextButton(
                  onPressed: () {},
                  child: Text(l10n.edit),
                ),
              ],
            ),

            const Divider(height: 32),

            // Example: Dialog with localized text
            Text(
              'Example: Dialog',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _showExampleDialog(context, l10n),
              child: Text('Show ${l10n.delete} Dialog'),
            ),

            const Divider(height: 32),

            // Example: Form with localized labels
            Text(
              'Example: Form',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            TextFormField(
              decoration: InputDecoration(
                labelText: l10n.email,
                hintText: 'Enter your ${l10n.email.toLowerCase()}',
                prefixIcon: const Icon(Icons.email),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              obscureText: true,
              decoration: InputDecoration(
                labelText: l10n.password,
                hintText: 'Enter your ${l10n.password.toLowerCase()}',
                prefixIcon: const Icon(Icons.lock),
              ),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        tooltip: l10n.createPost,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildExampleItem(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 8),
          Text(text),
        ],
      ),
    );
  }

  void _showExampleDialog(BuildContext context, AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.delete),
        content: Text('${l10n.delete} this item?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.success)),
              );
            },
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
  }
}
