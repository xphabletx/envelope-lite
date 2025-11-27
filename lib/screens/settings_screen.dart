import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/envelope_repo.dart';
import '../services/user_service.dart';

import '../theme/app_themes.dart';
import '../providers/theme_provider.dart';
import '../screens/theme_picker_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.repo});

  final EnvelopeRepo repo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Settings',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Section
          _SettingsSection(
            title: 'Profile',
            icon: Icons.person_outline,
            children: [
              _SettingsTile(
                title: 'Display Name',
                subtitle: 'Team Envelopes', // TODO: Pull from UserService
                leading: const Icon(Icons.badge_outlined),
                onTap: () async {
                  final userService = UserService(repo.db, repo.currentUserId);
                  final profile = await userService.getUserProfile();

                  if (!context.mounted) return;

                  final newName = await showDialog<String>(
                    context: context,
                    builder: (ctx) {
                      final controller = TextEditingController(
                        text: profile?.displayName ?? '',
                      );
                      return AlertDialog(
                        title: const Text('Edit Display Name'),
                        content: TextField(
                          controller: controller,
                          decoration: const InputDecoration(
                            labelText: 'Display Name',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.pop(ctx, controller.text),
                            child: const Text('Save'),
                          ),
                        ],
                      );
                    },
                  );

                  if (newName != null && newName.isNotEmpty) {
                    await userService.updateUserProfile(displayName: newName);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Display name updated')),
                      );
                    }
                  }
                },
              ),
              _SettingsTile(
                title: 'Email',
                subtitle: repo.currentUserId, // TODO: Show actual email
                leading: const Icon(Icons.email_outlined),
                onTap: null, // Read-only
              ),
              _SettingsTile(
                title: 'Profile Photo',
                subtitle: 'Tap to upload',
                leading: const Icon(Icons.photo_camera_outlined),
                onTap: () {
                  // TODO: Open image picker
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Photo upload coming soon')),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Themes Section
          _SettingsSection(
            title: 'Themes',
            icon: Icons.palette_outlined,
            children: [
              _SettingsTile(
                title: 'Choose Theme',
                subtitle: AppThemes.getThemeName(
                  Provider.of<ThemeProvider>(context).currentThemeId,
                ),
                leading: const Icon(Icons.color_lens_outlined),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ThemePickerScreen(),
                    ),
                  );
                },
                trailing: const Icon(Icons.chevron_right),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Workspace Section
          _SettingsSection(
            title: 'Workspace',
            icon: Icons.groups_outlined,
            children: [
              if (repo.inWorkspace) ...[
                _SettingsTile(
                  title: 'Current Workspace',
                  subtitle: repo.workspaceId ?? 'Solo Mode',
                  leading: const Icon(Icons.people_outline),
                  onTap: null,
                ),
                _SettingsTile(
                  title: 'Rename Workspace',
                  leading: const Icon(Icons.edit_outlined),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Workspace rename coming soon'),
                      ),
                    );
                  },
                ),
                _SettingsTile(
                  title: 'Leave Workspace',
                  leading: const Icon(Icons.logout),
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Leave Workspace?'),
                        content: const Text(
                          'Are you sure you want to leave this workspace? You\'ll return to Solo Mode.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Leave'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Left workspace')),
                      );
                    }
                  },
                ),
              ] else ...[
                _SettingsTile(
                  title: 'Create / Join Workspace',
                  subtitle: 'Currently in Solo Mode',
                  leading: const Icon(Icons.group_add),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Workspace creation coming soon'),
                      ),
                    );
                  },
                  trailing: const Icon(Icons.chevron_right),
                ),
              ],
            ],
          ),

          const SizedBox(height: 24),

          // Account Section
          _SettingsSection(
            title: 'Account',
            icon: Icons.account_circle_outlined,
            children: [
              _SettingsTile(
                title: 'Logout',
                leading: const Icon(Icons.logout, color: Colors.red),
                titleColor: Colors.red,
                onTap: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Logout?'),
                      content: const Text('Are you sure you want to logout?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text('Logout'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && context.mounted) {
                    await AuthService.signOut();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Signed out')),
                      );
                    }
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // FAQ / Help Section
          _SettingsSection(
            title: 'FAQ / Help',
            icon: Icons.help_outline,
            children: [
              _SettingsTile(
                title: 'Frequently Asked Questions',
                leading: const Icon(Icons.question_answer_outlined),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('FAQ coming soon')),
                  );
                },
                trailing: const Icon(Icons.chevron_right),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Support Section
          _SettingsSection(
            title: 'Support',
            icon: Icons.support_agent_outlined,
            children: [
              _SettingsTile(
                title: 'Contact Us',
                leading: const Icon(Icons.email_outlined),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Contact form coming soon')),
                  );
                },
                trailing: const Icon(Icons.chevron_right),
              ),
              _SettingsTile(
                title: 'App Version',
                subtitle: '1.0.0',
                leading: const Icon(Icons.info_outlined),
                onTap: null,
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// Settings Section Widget
class _SettingsSection extends StatelessWidget {
  const _SettingsSection({
    required this.title,
    required this.icon,
    required this.children,
  });

  final String title;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

// Settings Tile Widget
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.titleColor,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: leading,
      title: Text(
        title,
        style: TextStyle(fontWeight: FontWeight.w500, color: titleColor),
      ),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: trailing,
      onTap: onTap,
      enabled: onTap != null,
    );
  }
}
