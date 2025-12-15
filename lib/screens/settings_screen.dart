// lib/screens/settings_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart'; // Needed for TutorialController

import '../models/user_profile.dart';
import '../models/envelope.dart';
import '../models/transaction.dart';
import '../services/auth_service.dart';
import '../services/envelope_repo.dart';
import '../services/user_service.dart';
// NEW: Import the security service
import '../services/account_security_service.dart';
// TUTORIAL IMPORT - UPDATED
import '../services/tutorial_controller.dart';

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

              // Data & Privacy (Export)
              _SettingsSection(
                title: 'Data & Privacy',
                icon: Icons.lock_outline,
                children: [
                  _SettingsTile(
                    title: 'Export My Data',
                    subtitle: 'Download your data as CSV',
                    leading: const Icon(Icons.file_download_outlined),
                    onTap: () => _exportUserData(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Legal Section
              _SettingsSection(
                title: 'Legal',
                icon: Icons.gavel_outlined,
                children: [
                  _SettingsTile(
                    title: 'Privacy Policy',
                    leading: const Icon(Icons.policy_outlined),
                    trailing: const Icon(Icons.open_in_new, size: 20),
                    onTap: () => _openUrl(
                      'https://xphabletx.github.io/envelope-lite/PRIVACY_POLICY',
                    ),
                  ),
                  _SettingsTile(
                    title: 'Terms of Service',
                    leading: const Icon(Icons.description_outlined),
                    trailing: const Icon(Icons.open_in_new, size: 20),
                    onTap: () => _openUrl(
                      'https://xphabletx.github.io/envelope-lite/TERMS_OF_SERVICE',
                    ),
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
                    onTap: () async {
                      final Uri emailLaunchUri = Uri(
                        scheme: 'mailto',
                        path: 'telmccall@gmail.com',
                        query: 'subject=Envelope Lite Support',
                      );
                      if (!await launchUrl(emailLaunchUri)) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Could not launch email client'),
                            ),
                          );
                        }
                      }
                    },
                    trailing: const Icon(Icons.chevron_right),
                  ),
                  // TUTORIAL RESET BUTTON - UPDATED
                  _SettingsTile(
                    title: 'Replay Tutorial',
                    subtitle: 'Show the onboarding tour again',
                    leading: const Icon(Icons.help_outline),
                    onTap: () async {
                      // Using the new controller reset logic
                      context.read<TutorialController>().reset();

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Tutorial reset! Return to home to start again',
                            ),
                          ),
                        );
                        // Navigate back to home
                        Navigator.of(
                          context,
                        ).popUntil((route) => route.isFirst);
                      }
                    },
                  ),
                  FutureBuilder<PackageInfo>(
                    future: PackageInfo.fromPlatform(),
                    builder: (context, snapshot) {
                      String versionText = 'Loading...';
                      if (snapshot.hasData) {
                        versionText =
                            '${snapshot.data!.version} (${snapshot.data!.buildNumber})';
                      }

                      return _SettingsTile(
                        title: 'App Version',
                        subtitle: versionText,
                        leading: const Icon(Icons.info_outlined),
                        onTap: null,
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Logout
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
                        await AuthService.signOut();
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // DANGER ZONE
              const Divider(),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Danger Zone',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: Icon(
                  Icons.delete_forever,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'Delete Account',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.error,
                  ),
                ),
                subtitle: const Text('Permanently delete account and all data'),
                onTap: () async {
                  // NEW: Use the service instead of manual code
                  final securityService = AccountSecurityService();
                  await securityService.deleteAccount(context);
                },
              ),
              const SizedBox(height: 32),
            ],
          );
        },
      ),
    );
  }

  // --- Helpers ---

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $url');
    }
  }

  Future<void> _exportUserData(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final envelopes = await repo.getAllEnvelopes();
      final envelopesCsv = _generateEnvelopesCsv(envelopes);
      final transactionsCsv = await _generateTransactionsCsv(envelopes, repo);

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());

      final envelopesFile = File('${tempDir.path}/envelopes_$timestamp.csv');
      final transactionsFile = File(
        '${tempDir.path}/transactions_$timestamp.csv',
      );

      await envelopesFile.writeAsString(envelopesCsv);
      await transactionsFile.writeAsString(transactionsCsv);

      if (context.mounted) {
        Navigator.of(context).pop();
        await Share.shareXFiles([
          XFile(envelopesFile.path),
          XFile(transactionsFile.path),
        ], subject: 'My Envelope Lite Data Export');
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _generateEnvelopesCsv(List<Envelope> envelopes) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Name,Current Amount,Target Amount,Auto-Fill Amount,Group,Is Shared',
    );
    for (var env in envelopes) {
      buffer.writeln(
        [
          _escapeCsv(env.name),
          env.currentAmount.toStringAsFixed(2),
          (env.targetAmount ?? 0).toStringAsFixed(2),
          (env.autoFillAmount ?? 0).toStringAsFixed(2),
          _escapeCsv(env.groupId ?? 'None'),
          env.isShared ? 'Yes' : 'No',
        ].join(','),
      );
    }
    return buffer.toString();
  }

  Future<String> _generateTransactionsCsv(
    List<Envelope> envelopes,
    EnvelopeRepo repo,
  ) async {
    final buffer = StringBuffer();
    buffer.writeln('Date,Envelope,Type,Amount,Description,Source,Target');

    for (var env in envelopes) {
      final transactions = await repo.getTransactions(env.id);

      for (var tx in transactions) {
        String source = '';
        String target = '';

        if (tx.type == TransactionType.transfer) {
          source = tx.sourceEnvelopeName ?? 'Unknown';
          target = tx.targetEnvelopeName ?? 'Unknown';
        } else if (tx.type == TransactionType.deposit) {
          source = 'Income';
          target = env.name;
        } else if (tx.type == TransactionType.withdrawal) {
          source = env.name;
          target = 'Merchant/Expense';
        }

        buffer.writeln(
          [
            tx.date.toIso8601String(),
            _escapeCsv(env.name),
            tx.type.name,
            tx.amount.toStringAsFixed(2),
            _escapeCsv(tx.description),
            _escapeCsv(source),
            _escapeCsv(target),
          ].join(','),
        );
      }
    }
    return buffer.toString();
  }

  String _escapeCsv(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}

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
                // FIXED: Modernize deprecation
                color: Colors.black.withValues(alpha: 0.05),
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
                // FIXED: Modernize deprecation
                color: theme.colorScheme.onSurfaceVariant.withValues(
                  alpha: 0.5,
                ),
              ),
              child: trailing!,
            )
          : null,
      onTap: onTap,
      enabled: onTap != null,
    );
  }
}
