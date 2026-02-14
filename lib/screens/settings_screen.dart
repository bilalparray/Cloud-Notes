import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  static const String appVersion = '1.0.0';
  static const String playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.qayham.cloudnotes';
  static const String webUrl = 'https://qayham.com/cloudnotes';

  static String get _shareText =>
      'Check out Cloud Notes – sync your notes across devices.\n\n'
      'Android: $playStoreUrl\n'
      'Web: $webUrl';

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();
    final user = authService.currentUser;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Settings',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          const _SectionHeader(title: 'Account'),
          if (user != null) ...[
            _SettingsTile(
              icon: Icons.email_outlined,
              title: 'Email',
              subtitle: user.email ?? 'Not set',
            ),
            if (user.displayName != null && user.displayName!.isNotEmpty)
              _SettingsTile(
                icon: Icons.person_outline_rounded,
                title: 'Display name',
                subtitle: user.displayName!,
              ),
          ],
          const SizedBox(height: 24),
          const _SectionHeader(title: 'Share'),
          ListTile(
            leading:
                Icon(Icons.share_rounded, size: 22, color: colorScheme.primary),
            title: const Text(
              'Share app',
              style: TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              'Share Play Store and web links',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            onTap: () => _shareApp(context),
          ),
          const SizedBox(height: 24),
          const _SectionHeader(title: 'About'),
          const _SettingsTile(
            icon: Icons.info_outline_rounded,
            title: 'Cloud Notes',
            subtitle: 'Version $appVersion',
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: OutlinedButton.icon(
              onPressed: () => _handleLogout(context),
              icon: Icon(Icons.logout_rounded,
                  size: 20, color: colorScheme.error),
              label: Text(
                'Log out',
                style: TextStyle(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: colorScheme.error),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _shareApp(BuildContext context) async {
    try {
      await Share.share(
        _shareText,
        subject: 'Cloud Notes – App & Web',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not share: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Log out'),
        content: const Text('Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await AuthService().signOut();
      // AuthWrapper will show LoginScreen when auth state changes
    }
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, size: 22, color: colorScheme.primary),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
