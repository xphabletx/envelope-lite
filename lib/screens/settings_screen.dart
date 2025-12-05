import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/envelope_repo.dart';
import '../services/user_service.dart';

import '../theme/app_themes.dart';
import '../providers/theme_provider.dart';
import '../screens/theme_picker_screen.dart';
import '../screens/appearance_settings_screen.dart';
import '../screens/workspace_settings_screen.dart';
import '../screens/workspace_gate.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.repo});

  final EnvelopeRepo repo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userService = UserService(repo.db, repo.currentUserId);
    final currentUser = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Settings',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: StreamBuilder<UserProfile?>(
        stream: userService.userProfileStream,
        builder: (context, snapshot) {
          final profile = snapshot.data;
          final displayName = profile?.displayName ?? 'User';
          final email = currentUser?.email ?? 'No email found';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Profile Section
              _SettingsSection(
                title: 'Profile',
                icon: Icons.person_outline,
                children: [
                  _SettingsTile(
                    title: 'Display Name',
                    subtitle: displayName,
                    leading: const Icon(Icons.badge_outlined),
                    onTap: () async {
                      if (!context.mounted) return;

                      final newName = await showDialog<String>(
                        context: context,
                        builder: (ctx) {
                          final controller = TextEditingController(
                            text: displayName,
                          );
                          return AlertDialog(
                            backgroundColor: theme.colorScheme.surface,
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

                      if (newName != null) {
                        // Allow blank - UI will show "Your Envelopes" as fallback
                        await userService.updateUserProfile(
                          displayName: newName.trim(),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Display name updated'),
                            ),
                          );
                        }
                      }
                    },
                  ),
                  _SettingsTile(
                    title: 'Email',
                    subtitle: email,
                    leading: const Icon(Icons.email_outlined),
                    onTap: null,
                  ),
                  _SettingsTile(
                    title: 'Profile Photo',
                    subtitle: 'Tap to upload',
                    leading: const Icon(Icons.photo_camera_outlined),
                    onTap: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Photo upload coming soon'),
                        ),
                      );
                    },
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Appearance Section
              _SettingsSection(
                title: 'Appearance',
                icon: Icons.palette_outlined,
                children: [
                  _SettingsTile(
                    title: 'Customize Appearance',
                    subtitle: 'Theme, font, and celebration emoji',
                    leading: const Icon(Icons.color_lens_outlined),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AppearanceSettingsScreen(),
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
                      title: 'Workspace Settings',
                      subtitle: 'Manage sharing, members & workspace',
                      leading: const Icon(Icons.settings_outlined),
                      onTap: () {
                        final wsId = repo.workspaceId;
                        if (wsId == null) return;

                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => WorkspaceSettingsScreen(
                              repo: repo,
                              workspaceId: wsId,
                              currentUserId: repo.currentUserId,
                              onWorkspaceLeft: () {
                                Navigator.of(context).pop();
                              },
                            ),
                          ),
                        );
                      },
                      trailing: const Icon(Icons.chevron_right),
                    ),
                  ] else ...[
                    _SettingsTile(
                      title: 'Create / Join Workspace',
                      subtitle: 'Currently in Solo Mode',
                      leading: const Icon(Icons.group_add),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => WorkspaceGate(
                              onJoined: (workspaceId) {
                                // Workspace joined successfully
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Joined workspace!'),
                                  ),
                                );
                              },
                            ),
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
                    leading: Icon(Icons.logout, color: theme.colorScheme.error),
                    titleColor: theme.colorScheme.error,
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Logout?'),
                          content: const Text(
                            'Are you sure you want to logout?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: TextButton.styleFrom(
                                foregroundColor: theme.colorScheme.error,
                              ),
                              child: const Text('Logout'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true && context.mounted) {
                        // Just sign out - this will trigger auth state change
                        // When user signs back in, we'll check onboarding status then
                        await AuthService.signOut();

                        // The StreamBuilder in main.dart will automatically show SignInScreen
                        // after detecting the user is null
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
                        const SnackBar(
                          content: Text('Contact form coming soon'),
                        ),
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
          );
        },
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
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
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
    final theme = Theme.of(context);

    return ListTile(
      leading: leading != null
          ? IconTheme(
              data: IconThemeData(
                color: titleColor ?? theme.colorScheme.onSurfaceVariant,
              ),
              child: leading!,
            )
          : null,
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w500,
          color: titleColor ?? theme.colorScheme.onSurface,
        ),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: trailing != null
          ? IconTheme(
              data: IconThemeData(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
              child: trailing!,
            )
          : null,
      onTap: onTap,
      enabled: onTap != null,
    );
  }
}
