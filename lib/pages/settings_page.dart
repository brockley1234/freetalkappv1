import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/socket_service.dart';
import '../l10n/app_localizations.dart';
import 'loginpage.dart';
import 'terms_of_service_page.dart';
import 'privacy_policy_page.dart';
import 'saved_posts_page.dart';
import 'cache_settings_page.dart';
import 'language_selection_page.dart';
import 'package:provider/provider.dart';
import '../services/theme_service.dart';
import '../services/accessibility_service.dart';

/// Settings page providing comprehensive user account, privacy, and app configuration
/// Features organized into logical sections with real-time sync across devices
class SettingsPage extends StatefulWidget {
  final Map<String, dynamic>? user;

  const SettingsPage({super.key, this.user});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  final SocketService _socketService = SocketService();
  Map<String, dynamic>? _currentUser;
  bool _isLoading = false;

  // Settings state with improved organization
  bool _notificationsEnabled = true;
  bool _pushNotificationsEnabled = true;
  bool _emailNotificationsEnabled = false;
  bool _privateAccount = false;
  bool _showOnlineStatus = true;
  String _theme = 'system'; // system, light, dark

  // Store listener callback for cleanup
  Function(dynamic)? _settingsUpdateListener;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentUser = widget.user;
    _loadUserSettings();
    _setupSocketListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _removeSocketListener();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadUserSettings();
    }
  }

  void _setupSocketListener() {
    _settingsUpdateListener = (data) {
      if (mounted) {
        setState(() {
          // Update settings based on socket data
          if (data['privateAccount'] != null) {
            _privateAccount = data['privateAccount'];
          }
          if (data['showOnlineStatus'] != null) {
            _showOnlineStatus = data['showOnlineStatus'];
          }
        });
      }
    };
    _socketService.on('user:settings-updated', _settingsUpdateListener!);
  }

  void _removeSocketListener() {
    if (_settingsUpdateListener != null) {
      _socketService.off('user:settings-updated', _settingsUpdateListener!);
    }
  }

  Future<void> _loadUserSettings() async {
    if (!mounted) return;
    
    setState(() => _isLoading = true);
    
    try {
      final response = await ApiService.getUserSettings();
      if (response['success'] && mounted) {
        final settings = response['data'];
        setState(() {
          _notificationsEnabled = settings['notificationsEnabled'] ?? true;
          _pushNotificationsEnabled = settings['pushNotificationsEnabled'] ?? true;
          _emailNotificationsEnabled = settings['emailNotificationsEnabled'] ?? false;
          _privateAccount = settings['privateAccount'] ?? false;
          _showOnlineStatus = settings['showOnlineStatus'] ?? true;
          _theme = settings['theme'] ?? 'system';
        });
      }
    } catch (e) {
      debugPrint('Error loading user settings: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateSetting(String key, dynamic value) async {
    try {
      // For now, just emit the socket event since we don't have a specific update method
      _socketService.emit('user:settings-updated', {key: value});
    } catch (e) {
      debugPrint('Error updating setting $key: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update setting')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final screenSize = MediaQuery.of(context).size;
    final isMobile = screenSize.width < 600;
    final isTablet = screenSize.width >= 600 && screenSize.width < 1024;
    final isLarge = screenSize.width >= 1024;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settings),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        ],
      ),
      body: _buildBody(l10n, screenSize, isMobile, isTablet, isLarge),
    );
  }

  Widget _buildBody(AppLocalizations l10n, Size screenSize, bool isMobile, bool isTablet, bool isLarge) {
    // Single column layout for all screen sizes
    // For large screens, use centered content with max width
    if (isLarge) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 800),
          child: _buildSettingsColumn(l10n, isMobile),
        ),
      );
    } else {
      // Mobile and tablet layout - single column
      return _buildSettingsColumn(l10n, isMobile);
    }
  }

  Widget _buildSettingsColumn(AppLocalizations l10n, bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 8,
      ),
      child: Column(
        children: [
        // Account Section
        _buildSectionHeader(l10n.accountSettings, isMobile),
        _buildListTile(
          icon: Icons.bookmark_outline,
          title: l10n.savedPosts,
          subtitle: l10n.viewYourSavedPosts,
          onTap: _navigateToSavedPosts,
          isMobile: isMobile,
        ),
        _buildListTile(
          icon: Icons.lock_outline,
          title: l10n.changePassword,
          subtitle: l10n.updateYourPassword,
          onTap: _showChangePasswordDialog,
          isMobile: isMobile,
        ),
        _buildListTile(
          icon: Icons.email_outlined,
          title: l10n.email,
          subtitle: _currentUser?['email'] ?? l10n.notSet,
          onTap: null,
          isMobile: isMobile,
        ),
        const SizedBox(height: 24),

        // Privacy Section
        _buildSectionHeader(l10n.privacySettings, isMobile),
        _buildSwitchTile(
          icon: Icons.lock_outline,
          title: l10n.privateAccount,
          subtitle: l10n.privateAccountDescription,
          value: _privateAccount,
          onChanged: (value) {
            setState(() => _privateAccount = value);
            _updateSetting('privateAccount', value);
          },
          isMobile: isMobile,
        ),
        _buildSwitchTile(
          icon: Icons.circle,
          title: l10n.showOnlineStatus,
          subtitle: l10n.showOnlineStatusDescription,
          value: _showOnlineStatus,
          onChanged: (value) {
            setState(() => _showOnlineStatus = value);
            _updateSetting('showOnlineStatus', value);
          },
          isMobile: isMobile,
        ),
        _buildListTile(
          icon: Icons.block,
          title: l10n.blockedUsers,
          subtitle: 'Manage blocked users',
          onTap: _showBlockedUsers,
          isMobile: isMobile,
        ),
        const SizedBox(height: 24),

        // Notifications Section
        _buildSectionHeader(l10n.notifications, isMobile),
        _buildSwitchTile(
          icon: Icons.notifications_outlined,
          title: l10n.notifications,
          subtitle: 'Enable or disable notifications',
          value: _notificationsEnabled,
          onChanged: (value) {
            setState(() => _notificationsEnabled = value);
            _updateSetting('notificationsEnabled', value);
          },
          isMobile: isMobile,
        ),
        _buildSwitchTile(
          icon: Icons.phone_android,
          title: l10n.pushNotifications,
          subtitle: l10n.pushNotificationsDescription,
          value: _pushNotificationsEnabled,
          onChanged: (value) {
            setState(() => _pushNotificationsEnabled = value);
            _updateSetting('pushNotificationsEnabled', value);
          },
          isMobile: isMobile,
        ),
        _buildSwitchTile(
          icon: Icons.email,
          title: l10n.emailNotifications,
          subtitle: l10n.emailNotificationsDescription,
          value: _emailNotificationsEnabled,
          onChanged: (value) {
            setState(() => _emailNotificationsEnabled = value);
            _updateSetting('emailNotificationsEnabled', value);
          },
          isMobile: isMobile,
        ),
        const SizedBox(height: 24),

        // App Settings Section
        _buildSectionHeader('App Settings', isMobile),
        _buildListTile(
          icon: Icons.palette_outlined,
          title: l10n.theme,
          subtitle: _getThemeDisplayName(l10n),
          onTap: _showThemeDialog,
          isMobile: isMobile,
        ),
        // Accessibility Section
        const SizedBox(height: 12),
        _buildSectionHeader('Accessibility', isMobile),
        Builder(
          builder: (context) {
            final accessibility = context.watch<AccessibilityService>();
            return _buildSwitchTile(
              icon: Icons.contrast,
              title: 'High Contrast',
              subtitle: 'Increase text and UI contrast for readability',
              value: accessibility.highContrastEnabled,
              onChanged: (value) {
                accessibility.setHighContrastEnabled(value);
              },
              isMobile: isMobile,
            );
          },
        ),
        _buildListTile(
          icon: Icons.language,
          title: l10n.language,
          subtitle: _getCurrentLanguageName(),
          onTap: _navigateToLanguageSelection,
          isMobile: isMobile,
        ),
        _buildListTile(
          icon: Icons.storage,
          title: l10n.cacheSettings,
          subtitle: 'Manage cache and storage',
          onTap: _navigateToCacheSettings,
          isMobile: isMobile,
        ),
        const SizedBox(height: 24),

        // Legal Section
        _buildSectionHeader('Legal', isMobile),
        _buildListTile(
          icon: Icons.description_outlined,
          title: l10n.termsOfService,
          subtitle: 'Read terms of service',
          onTap: _navigateToTermsOfService,
          isMobile: isMobile,
        ),
        _buildListTile(
          icon: Icons.privacy_tip_outlined,
          title: l10n.privacyPolicy,
          subtitle: 'Read privacy policy',
          onTap: _navigateToPrivacyPolicy,
          isMobile: isMobile,
        ),
        const SizedBox(height: 24),

        // Danger Zone
        _buildSectionHeader('Danger Zone', isMobile),
        _buildListTile(
          icon: Icons.logout,
          title: l10n.logout,
          subtitle: 'Sign out of your account',
          onTap: _handleLogout,
          textColor: Theme.of(context).colorScheme.error.withValues(alpha: 0.8),
          isMobile: isMobile,
        ),
        _buildListTile(
          icon: Icons.delete_forever,
          title: l10n.deleteAccount,
          subtitle: 'Permanently delete your account',
          onTap: _handleDeleteAccount,
          textColor: Theme.of(context).colorScheme.error,
          isMobile: isMobile,
        ),
        const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isMobile) {
    return Padding(
      padding: EdgeInsets.only(
        top: isMobile ? 16 : 20,
        bottom: isMobile ? 8 : 12,
      ),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
          fontSize: isMobile ? 16 : 18,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  Widget _buildListTile({
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
    Color? textColor,
    required bool isMobile,
  }) {
    return Card(
      margin: EdgeInsets.only(bottom: isMobile ? 4 : 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          width: 1,
        ),
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: textColor ?? Theme.of(context).primaryColor,
          size: isMobile ? 24 : 28,
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.w500,
            color: textColor ?? Theme.of(context).textTheme.titleMedium?.color,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: isMobile ? 14 : 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        trailing: onTap != null
            ? Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              )
            : null,
        onTap: onTap,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 20,
          vertical: isMobile ? 4 : 8,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isMobile,
  }) {
    return Card(
      margin: EdgeInsets.only(bottom: isMobile ? 4 : 6),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          width: 1,
        ),
      ),
      child: SwitchListTile(
        secondary: Icon(
          icon,
          color: Theme.of(context).primaryColor,
          size: isMobile ? 24 : 28,
        ),
        title: Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.w500,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: isMobile ? 14 : 16,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        value: value,
        onChanged: onChanged,
        contentPadding: EdgeInsets.symmetric(
          horizontal: isMobile ? 16 : 20,
          vertical: isMobile ? 4 : 8,
        ),
      ),
    );
  }

  String _getThemeDisplayName(AppLocalizations l10n) {
    switch (_theme) {
      case 'light':
        return 'Light Theme';
      case 'dark':
        return 'Dark Theme';
      default:
        return 'System Theme';
    }
  }

  String _getCurrentLanguageName() {
    final locale = Localizations.localeOf(context);
    return locale.languageCode.toUpperCase();
  }

  // Navigation methods
  void _navigateToSavedPosts() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SavedPostsPage()),
    );
  }

  void _navigateToLanguageSelection() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const LanguageSelectionPage()),
    );
  }

  void _navigateToCacheSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CacheSettingsPage()),
    );
  }

  void _navigateToTermsOfService() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TermsOfServicePage()),
    );
  }

  void _navigateToPrivacyPolicy() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PrivacyPolicyPage()),
    );
  }

  // Dialog methods
  void _showChangePasswordDialog() {
    showDialog(
      context: context,
      builder: (context) => _ChangePasswordDialog(),
    );
  }

  void _showThemeDialog() {
    showDialog(
      context: context,
      builder: (context) => _ThemeSelectionDialog(
        currentTheme: _theme,
        onThemeSelected: (theme) {
          setState(() => _theme = theme);
          _updateSetting('theme', theme);
          // Apply the theme immediately
          context.read<ThemeService>().setTheme(theme);
        },
      ),
    );
  }

  void _showBlockedUsers() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (context) => const _BlockedUsersBottomSheet(),
    );
  }

  // Action methods
  void _handleLogout() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.logout),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              try {
                // Disconnect socket first
                SocketService().disconnect();
                
                // Call logout API (this will clear tokens internally)
                await ApiService.logout();
                
                // Clear local storage
                final prefs = await SharedPreferences.getInstance();
                await prefs.clear();
                
                // Verify both access and refresh tokens are cleared
                final accessToken = await ApiService.getAccessToken();
                final refreshToken = await ApiService.getRefreshToken();
                if (accessToken != null || refreshToken != null) {
                  debugPrint('⚠️ Tokens still exist after logout, forcing clear');
                  await ApiService.clearTokens();
                  // Double-check after forced clear
                  final accessToken2 = await ApiService.getAccessToken();
                  final refreshToken2 = await ApiService.getRefreshToken();
                  if (accessToken2 != null || refreshToken2 != null) {
                    debugPrint('❌ CRITICAL: Tokens still exist after forced clear!');
                  }
                }
              } catch (e) {
                debugPrint('Error during logout: $e');
                // Ensure tokens are cleared even on error
                try {
                  await ApiService.clearTokens();
                  await ApiService.clearRememberedCredentials();
                } catch (clearError) {
                  debugPrint('Error clearing tokens: $clearError');
                }
              }
              
              // Navigate to login page - check mounted before using context
              if (!mounted) return;
              Navigator.pushAndRemoveUntil(
                this.context,
                MaterialPageRoute(builder: (context) => const LoginPage()),
                (route) => false,
              );
            },
            child: Text(AppLocalizations.of(context)!.logout),
          ),
        ],
      ),
    );
  }

  void _handleDeleteAccount() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.deleteAccount),
        content: const Text('Are you sure you want to delete your account? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Implement account deletion logic
            },
            child: Text(
              AppLocalizations.of(context)!.deleteAccount,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}

// Change Password Dialog
class _ChangePasswordDialog extends StatefulWidget {
  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureCurrentPassword = true;
  bool _obscureNewPassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return AlertDialog(
      title: Text(l10n.changePassword),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _currentPasswordController,
                obscureText: _obscureCurrentPassword,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureCurrentPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureCurrentPassword = !_obscureCurrentPassword),
                  ),
                ),
                validator: (value) => value?.isEmpty == true ? 'This field is required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _newPasswordController,
                obscureText: _obscureNewPassword,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  suffixIcon: IconButton(
                    icon: Icon(_obscureNewPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureNewPassword = !_obscureNewPassword),
                  ),
                ),
                validator: (value) {
                  if (value?.isEmpty == true) return 'This field is required';
                  if (value!.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: l10n.confirmPassword,
                  suffixIcon: IconButton(
                    icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),
                validator: (value) {
                  if (value?.isEmpty == true) return 'This field is required';
                  if (value != _newPasswordController.text) return 'Passwords do not match';
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: _isLoading ? null : _changePassword,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.changePassword),
        ),
      ],
    );
  }

  Future<void> _changePassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // For now, just show success message since we don't have a specific change password method
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password change functionality not implemented yet')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error changing password')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}

// Theme Selection Dialog
class _ThemeSelectionDialog extends StatelessWidget {
  final String currentTheme;
  final Function(String) onThemeSelected;

  const _ThemeSelectionDialog({
    required this.currentTheme,
    required this.onThemeSelected,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Select Theme'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioGroup<String>(
            groupValue: currentTheme,
            onChanged: (value) {
              if (value != null) {
                onThemeSelected(value);
                Navigator.pop(context);
              }
            },
            child: const Column(
              children: [
                RadioListTile<String>(
                  title: Text('System Theme'),
                  value: 'system',
                ),
                RadioListTile<String>(
                  title: Text('Light Theme'),
                  value: 'light',
                ),
                RadioListTile<String>(
                  title: Text('Dark Theme'),
                  value: 'dark',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Blocked Users Bottom Sheet
class _BlockedUsersBottomSheet extends StatefulWidget {
  const _BlockedUsersBottomSheet();

  @override
  State<_BlockedUsersBottomSheet> createState() => _BlockedUsersBottomSheetState();
}

class _BlockedUsersBottomSheetState extends State<_BlockedUsersBottomSheet> {
  List<Map<String, dynamic>> _blockedUsers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBlockedUsers();
  }

  Future<void> _loadBlockedUsers() async {
    try {
      final response = await ApiService.getBlockedUsers();
      if (response['success'] && mounted) {
        setState(() {
          _blockedUsers = List<Map<String, dynamic>>.from(response['data']);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Container(
      height: screenHeight * 0.7,
      decoration: const BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: isMobile ? 12 : 16),
            width: isMobile ? 40 : 50,
            height: 4,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: EdgeInsets.all(isMobile ? 16 : 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Blocked Users',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontSize: isMobile ? 18 : 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.close,
                    size: isMobile ? 24 : 28,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Blocked users list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _blockedUsers.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.block,
                              size: isMobile ? 64 : 80,
                              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                            ),
                            SizedBox(height: isMobile ? 16 : 20),
                            Text(
                              'No blocked users',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                fontSize: isMobile ? 16 : 18,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                              ),
                            ),
                            SizedBox(height: isMobile ? 8 : 12),
                            Text(
                              'Users you block will appear here',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontSize: isMobile ? 14 : 16,
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.all(isMobile ? 8 : 12),
                        itemBuilder: (context, index) {
                          final user = _blockedUsers[index];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                              child: Icon(Icons.person, color: Theme.of(context).colorScheme.onSurface),
                            ),
                            title: Text(
                              user['username'] ?? 'User',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            subtitle: Text(
                              user['reason'] ?? '',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            trailing: TextButton(
                              onPressed: () => _unblockUser(user['id']),
                              child: const Text('Unblock'),
                            ),
                          );
                        },
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemCount: _blockedUsers.length,
                      ),
          ),
        ],
      ),
    );
  }

  Future<void> _unblockUser(String userId) async {
    try {
      await ApiService.unblockUser(userId);
      if (mounted) {
        _loadBlockedUsers();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User unblocked successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to unblock user')),
        );
      }
    }
  }
}
