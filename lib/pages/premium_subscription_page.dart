import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../services/payment_service.dart';
import '../services/iap_service.dart';

class PremiumSubscriptionPage extends StatefulWidget {
  const PremiumSubscriptionPage({super.key});

  @override
  State<PremiumSubscriptionPage> createState() =>
      _PremiumSubscriptionPageState();
}

class _PremiumSubscriptionPageState extends State<PremiumSubscriptionPage> {
  bool _isLoading = false;
  bool _isCheckingStatus = true;
  bool _hasPremium = false;
  String? _expiresAt;
  String _selectedPlan = 'monthly'; // 'monthly' or 'yearly'

  @override
  void initState() {
    super.initState();
    _checkCurrentStatus();
    _initializeIAP();
  }

  Future<void> _initializeIAP() async {
    try {
      final iapService = IAPService();
      await iapService.initialize();

      // Listen for successful purchases
      // The IAP service handles purchase verification through its stream
      if (mounted) {
        debugPrint('✅ IAP initialized for premium page');
      }
    } catch (e) {
      debugPrint('❌ Error initializing IAP: $e');
    }
  }

  Future<void> _checkCurrentStatus() async {
    setState(() => _isCheckingStatus = true);

    try {
      final result = await PaymentService.checkFeatureAccess('premium');

      if (mounted) {
        setState(() {
          _hasPremium = result['hasAccess'] ?? false;
          _expiresAt = result['expiresAt'];
          _isCheckingStatus = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isCheckingStatus = false);
      }
    }
  }

  Future<void> _startPurchase() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Use real In-App Purchase for production
      final productId = _selectedPlan == 'monthly'
          ? 'com.freetalk.premium_monthly'
          : 'com.freetalk.premium_yearly';

      debugPrint('🛒 Starting purchase for: $productId');

      final iapService = IAPService();

      // Check if payment is available (IAP for mobile, web payment for web)
      if (!iapService.isAvailable) {
        if (!mounted) return;
        // On web, show "coming soon" message since Stripe checkout is disabled
        if (kIsWeb) {
          _showComingSoonDialog();
        } else {
          _showErrorDialog('Payment processing is currently unavailable. '
              'Please try again later.');
        }
        setState(() {
          _isLoading = false;
        });
        return;
      }

      // Start the purchase
      final success = await iapService.purchaseProduct(productId);

      if (!mounted) return;

      if (success) {
        // The purchase flow will handle success/error through the stream
        debugPrint('✅ Purchase initiated successfully');

        // Show loading dialog while purchase is being processed
        _showProcessingDialog();

        // Poll for status updates every 2 seconds for up to 30 seconds
        int attempts = 0;
        while (attempts < 15 && mounted) {
          await Future.delayed(const Duration(seconds: 2));
          await _checkCurrentStatus();

          if (_hasPremium) {
            if (mounted) {
              Navigator.of(context).pop(); // Close processing dialog
              _showSuccessDialog();
            }
            break;
          }
          attempts++;
        }

        if (!_hasPremium && mounted) {
          Navigator.of(context).pop(); // Close processing dialog
          _showErrorDialog(
              'Purchase is being processed. Please check back in a few minutes.');
        }
      } else {
        // On web, show a "coming soon" message since Stripe checkout is disabled
        if (kIsWeb) {
          _showComingSoonDialog();
        } else {
          _showErrorDialog('Failed to start purchase. Please try again.');
        }
      }
    } catch (e) {
      debugPrint('❌ Purchase error: $e');
      if (mounted) {
        _showErrorDialog('Error: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showProcessingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Processing your purchase...'),
            SizedBox(height: 8),
            Text(
              'This may take a few moments',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 32),
            SizedBox(width: 12),
            Text('Welcome to Premium!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade400, Colors.orange.shade600],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.star, color: Colors.white, size: 60),
            ),
            const SizedBox(height: 16),
            const Text(
              'Congratulations! 🎉',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'You now have access to all premium features!',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBenefit('👀 See profile visitors'),
                  _buildBenefit('🚫 Ad-free experience'),
                  _buildBenefit('🎨 Custom themes'),
                  _buildBenefit('✨ Verified badge'),
                  _buildBenefit('⚡ Priority support'),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context, true); // Return to previous page
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Awesome!'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Purchase Failed'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showComingSoonDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: Colors.amber, size: 28),
            SizedBox(width: 12),
            Text('Premium Coming Soon'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.star, color: Colors.amber.shade700, size: 60),
            ),
            const SizedBox(height: 16),
            const Text(
              'Premium subscriptions are not available yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 12),
            const Text(
              'We\'re working on bringing premium features to you soon. Check back later!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 14)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isCheckingStatus) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Premium Subscription'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_hasPremium) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Premium Subscription'),
          backgroundColor: Colors.amber,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade400, Colors.orange.shade600],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star, color: Colors.white, size: 80),
                ),
                const SizedBox(height: 24),
                const Text(
                  'You\'re Premium!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Enjoying all the premium benefits',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (_expiresAt != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.access_time, color: Colors.amber),
                        const SizedBox(height: 8),
                        Text(
                          'Active until',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatExpiryDate(_expiresAt!),
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 32, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Back to Profile'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Go Premium'),
        backgroundColor: Colors.amber,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.amber.shade100, Colors.white],
          ),
        ),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade400, Colors.orange.shade600],
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.star, color: Colors.white, size: 60),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Unlock Premium',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Get access to exclusive features',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 32),

                // Features
                _buildFeatureCard(
                  icon: Icons.visibility,
                  title: 'Profile Visitors',
                  description: 'See who viewed your profile and when',
                  color: Colors.blue,
                ),
                const SizedBox(height: 16),
                _buildFeatureCard(
                  icon: Icons.block,
                  title: 'Ad-Free Experience',
                  description: 'Enjoy FreeTalk without any advertisements',
                  color: Colors.red,
                ),
                const SizedBox(height: 16),
                _buildFeatureCard(
                  icon: Icons.palette,
                  title: 'Custom Themes',
                  description:
                      'Personalize your app with custom colors and themes',
                  color: Colors.purple,
                ),
                const SizedBox(height: 16),
                _buildFeatureCard(
                  icon: Icons.verified,
                  title: 'Verified Badge',
                  description: 'Get a verified badge on your profile',
                  color: Colors.amber,
                ),
                const SizedBox(height: 16),
                _buildFeatureCard(
                  icon: Icons.support_agent,
                  title: 'Priority Support',
                  description: 'Get faster responses from our support team',
                  color: Colors.green,
                ),
                const SizedBox(height: 32),

                // Plan Selection
                const Text(
                  'Choose Your Plan',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildPlanCard(
                  title: 'Monthly',
                  price: '\$9.99',
                  period: 'per month',
                  value: 'monthly',
                ),
                const SizedBox(height: 12),
                _buildPlanCard(
                  title: 'Yearly',
                  price: '\$99.99',
                  period: 'per year',
                  savings: 'Save 17%',
                  value: 'yearly',
                  isPopular: true,
                ),
                const SizedBox(height: 32),

                // Purchase Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _startPurchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.star, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Get Premium - ${_selectedPlan == 'monthly' ? '\$9.99/mo' : '\$99.99/yr'}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Cancel anytime. No hidden fees.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required String title,
    required String price,
    required String period,
    String? savings,
    required String value,
    bool isPopular = false,
  }) {
    final isSelected = _selectedPlan == value;

    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = value),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.amber : Colors.grey.shade300,
            width: isSelected ? 3 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: Colors.amber.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Stack(
          children: [
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.amber : Colors.grey.shade400,
                      width: 2,
                    ),
                    color: isSelected ? Colors.amber : Colors.transparent,
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            price,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            period,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (isPopular)
              Positioned(
                top: -8,
                right: -8,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.amber.shade400, Colors.orange.shade600],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'POPULAR',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            if (savings != null && !isPopular)
              Positioned(
                top: 0,
                right: 0,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    savings,
                    style: TextStyle(
                      color: Colors.green.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatExpiryDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.month}/${date.day}/${date.year}';
    } catch (e) {
      return 'N/A';
    }
  }
}
