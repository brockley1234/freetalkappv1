import 'package:flutter/material.dart';
import '../services/poke_service.dart';

class PokeDialog extends StatelessWidget {
  final String recipientId;
  final String recipientName;

  const PokeDialog({
    super.key,
    required this.recipientId,
    required this.recipientName,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Poke $recipientName',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Choose how you want to poke them!',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.5,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                _buildPokeButton(
                  context,
                  icon: '👋',
                  label: 'Slap',
                  color: Colors.orange,
                  pokeType: 'slap',
                ),
                _buildPokeButton(
                  context,
                  icon: '💋',
                  label: 'Kiss',
                  color: Colors.pink,
                  pokeType: 'kiss',
                ),
                _buildPokeButton(
                  context,
                  icon: '🤗',
                  label: 'Hug',
                  color: Colors.purple,
                  pokeType: 'hug',
                ),
                _buildPokeButton(
                  context,
                  icon: '👋',
                  label: 'Wave',
                  color: Colors.blue,
                  pokeType: 'wave',
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPokeButton(
    BuildContext context, {
    required String icon,
    required String label,
    required Color color,
    required String pokeType,
  }) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          Navigator.pop(context);
          await _sendPoke(context, pokeType, label);
        },
        child: Container(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(icon, style: const TextStyle(fontSize: 28)),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendPoke(
    BuildContext context,
    String pokeType,
    String label,
  ) async {
    try {
      // Show loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
                const SizedBox(width: 12),
                Text('Sending $label...'),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }

      // Send the poke
      final pokeService = PokeService();
      await pokeService.sendPoke(recipientId, pokeType);

      // Show success message
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('$label sent to $recipientName! 🎉')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Show error message with details
      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to send $label: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }
}

/// Show the poke dialog
void showPokeDialog(
  BuildContext context,
  String recipientId,
  String recipientName,
) {
  showDialog(
    context: context,
    builder: (context) =>
        PokeDialog(recipientId: recipientId, recipientName: recipientName),
  );
}
