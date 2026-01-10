// lib/screens/settings_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/envelope_repo.dart';
import '../services/user_service.dart';
import '../services/account_security_service.dart';
import '../services/data_export_service.dart';
import '../services/group_repo.dart';
import '../services/account_repo.dart';
import '../services/bug_report_service.dart';
import '../services/subscription_service.dart';
import '../services/app_update_service.dart';
import '../services/hive_service.dart';
import '../services/pay_day_settings_service.dart';
import '../services/scheduled_payment_repo.dart';
import '../providers/workspace_provider.dart';
import '../models/envelope.dart';
import '../models/account.dart';
import '../models/transaction.dart' as models;
import '../models/scheduled_payment.dart';
import '../models/envelope_group.dart';

import '../screens/appearance_settings_screen.dart';
import '../screens/workspace_management_screen.dart';
import '../screens/workspace_gate.dart';
import '../screens/pay_day_settings_screen.dart';
import '../screens/settings/tutorial_manager_screen.dart';
import '../screens/settings/faq_screen.dart';
import '../screens/settings/about_screen.dart';
import '../screens/debug/force_sync_screen.dart';
import '../widgets/tutorial_wrapper.dart';
import '../data/tutorial_sequences.dart';
import '../utils/responsive_helper.dart';
import '../providers/locale_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.repo});

  final EnvelopeRepo repo;

  /// Get user profile data from local sources (local-first, works offline)
  Future<Map<String, String?>> _getLocalUserProfile() async {
    try {
      // 1. Get displayName from FirebaseAuth (always available offline)
      final currentUser = FirebaseAuth.instance.currentUser;
      final displayName = currentUser?.displayName;

      // 2. Get photoURL from SharedPreferences (local-first)
      final prefs = await SharedPreferences.getInstance();
      final photoURL = prefs.getString('profile_photo_path_${repo.currentUserId}');

      return {
        'displayName': displayName,
        'photoURL': photoURL,
      };
    } catch (e) {
      return {};
    }
  }

  /// Update display name locally-first
  Future<void> _updateDisplayName(String newName) async {
    try {
      // 1. Update FirebaseAuth user object (local-first, works offline)
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await currentUser.updateDisplayName(newName.trim());
      }

      // 2. Best-effort sync to Firestore (optional, fails silently offline)
      try {
        final userService = UserService(repo.db, repo.currentUserId);
        await userService.updateUserProfile(displayName: newName.trim());
      } catch (e) {
      }
    } catch (e) {
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = FirebaseAuth.instance.currentUser;

    return TutorialWrapper(
      tutorialSequence: settingsTutorial,
      spotlightKeys: const {},
      child: Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: FittedBox(
          child: Text(
            'Settings',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.colorScheme.onSurface),
      ),
      body: FutureBuilder<Map<String, String?>>(
        future: _getLocalUserProfile(),
        builder: (context, snapshot) {
          final profileData = snapshot.data ?? {};
          final displayName = profileData['displayName'] ?? 'User';
          final photoURL = profileData['photoURL'];
          final email = currentUser?.email ?? 'No email found';
          final responsive = context.responsive;

          return ListView(
            padding: responsive.safePadding,
            children: [
              // Profile Section
              _SettingsSection(
                title: 'Profile',
                icon: Icons.person_outline,
                children: [
                  _SettingsTile(
                    title: 'Profile Photo',
                    subtitle: photoURL != null
                        ? 'Tap to change'
                        : 'Tap to add',
                    leading: photoURL != null
                        ? FutureBuilder<Widget>(
                            future: _buildProfilePhotoWidget(photoURL, repo.currentUserId),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return snapshot.data!;
                              }
                              return const CircleAvatar(
                                radius: 20,
                                child: Icon(Icons.person),
                              );
                            },
                          )
                        : const Icon(Icons.add_a_photo_outlined),
                    onTap: () async {
                      await _showProfilePhotoOptions(
                        context,
                        photoURL,
                      );
                    },
                  ),
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
                              textCapitalization: TextCapitalization.words,
                              autocorrect: false,
                              decoration: const InputDecoration(
                                labelText: 'Display Name',
                                border: OutlineInputBorder(),
                              ),
                              onTap: () {
                                controller.selection = TextSelection(
                                  baseOffset: 0,
                                  extentOffset: controller.text.length,
                                );
                              },
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
                        await _updateDisplayName(newName);
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
                  Consumer<LocaleProvider>(
                    builder: (context, localeProvider, _) {
                      return _SettingsTile(
                        title: 'Currency',
                        subtitle: '${LocaleProvider.getCurrencyName(localeProvider.currencyCode)} (${localeProvider.currencySymbol})',
                        leading: const Icon(Icons.attach_money_outlined),
                        onTap: () => _showCurrencyPicker(context, localeProvider),
                        trailing: const Icon(Icons.chevron_right),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Pay Day Settings Section
              _SettingsSection(
                title: 'Pay Day',
                icon: Icons.payments_outlined,
                children: [
                  _SettingsTile(
                    title: 'Pay Day Settings',
                    subtitle: 'Configure your pay schedule & calendar',
                    leading: const Icon(Icons.calendar_month_outlined),
                    onTap: () {
                      final payDayService = PayDaySettingsService(
                        repo.db,
                        repo.currentUserId,
                      );
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              PayDaySettingsScreen(service: payDayService),
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
                  if (repo.workspaceId != null) ...[
                    _SettingsTile(
                      title: 'Manage Workspace',
                      subtitle: 'Members, join code & settings',
                      leading: const Icon(Icons.settings_outlined),
                      onTap: () {
                        final wsId = repo.workspaceId;
                        if (wsId == null) return;
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => WorkspaceManagementScreen(
                              repo: repo,
                              workspaceId: wsId,
                              currentUserId: repo.currentUserId,
                              onWorkspaceLeft: () {
                                // The app needs to restart to pick up the workspace change
                                // For now just pop back
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
                              repo: repo,
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
                    subtitle: 'Download your data as .xlsx',
                    leading: const Icon(Icons.file_download_outlined),
                    onTap: () => _exportDataNew(context),
                  ),
                  // Disabled - DataCleanupService removed
                  // _SettingsTile(
                  //   title: 'Clean Up Orphaned Data',
                  //   subtitle: 'Remove deleted items still in database',
                  //   leading: const Icon(Icons.cleaning_services_outlined),
                  //   onTap: () => _cleanupOrphanedData(context),
                  // ),
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
                      'https://develapp.tech/stuffrite/privacy.html',
                    ),
                  ),
                  _SettingsTile(
                    title: 'Terms of Service',
                    leading: const Icon(Icons.description_outlined),
                    trailing: const Icon(Icons.open_in_new, size: 20),
                    onTap: () =>
                        _openUrl('https://develapp.tech/stuffrite/terms.html'),
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
                    title: 'Report a Bug',
                    subtitle: 'Help us improve the app',
                    leading: const Icon(Icons.bug_report_outlined),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => BugReportService.showBugReportDialog(context),
                  ),
                  _SettingsTile(
                    title: 'Send Feedback',
                    subtitle: 'Share your suggestions',
                    leading: const Icon(Icons.feedback_outlined),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => BugReportService.sendFeedback(context),
                  ),
                  _SettingsTile(
                    title: 'Check for Updates',
                    subtitle: 'See if a new version is available',
                    leading: const Icon(Icons.system_update_outlined),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await AppUpdateService.clearSkippedVersion();
                      if (context.mounted) {
                        await AppUpdateService.checkForUpdates(
                          context,
                          showNoUpdateDialog: true,
                          respectSkipVersion: false,
                        );
                      }
                    },
                  ),
                  _SettingsTile(
                    title: 'Contact Us',
                    leading: const Icon(Icons.email_outlined),
                    onTap: () async {
                      final Uri emailLaunchUri = Uri(
                        scheme: 'mailto',
                        path: 'hello@develapp.tech',
                        query: 'subject=Stuffrite Support',
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
                  _SettingsTile(
                    title: 'Manage Subscription',
                    subtitle: 'View and manage your Stuffrite Premium subscription',
                    leading: const Icon(Icons.card_membership_outlined),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await SubscriptionService().presentCustomerCenter(context);
                    },
                  ),
                  _SettingsTile(
                    title: 'Help & FAQ',
                    subtitle: 'Searchable frequently asked questions',
                    leading: const Icon(Icons.help_outline),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const FAQScreen()),
                      );
                    },
                  ),
                  _SettingsTile(
                    title: 'Tutorial Manager',
                    subtitle: 'Replay tutorials for specific screens',
                    leading: const Icon(Icons.school_outlined),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TutorialManagerScreen(repo: repo),
                        ),
                      );
                    },
                  ),
                  _SettingsTile(
                    title: 'About',
                    subtitle: 'App version, info & credits',
                    leading: const Icon(Icons.info_outlined),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Developer Tools (Debug only)
              _SettingsSection(
                title: 'Developer Tools',
                icon: Icons.build_outlined,
                children: [
                  _SettingsTile(
                    title: 'Force Sync to Firebase',
                    subtitle: 'Upload all local data to cloud',
                    leading: const Icon(Icons.cloud_upload_outlined, color: Colors.orange),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ForceSyncScreen(repo: repo),
                        ),
                      );
                    },
                  ),
                  _SettingsTile(
                    title: 'Reset Transactions & Balances',
                    subtitle: 'Clear all transactions and reset envelope balances to zero',
                    leading: const Icon(Icons.restore_outlined, color: Colors.red),
                    onTap: () => _resetTransactionsAndBalances(context),
                  ),
                  _SettingsTile(
                    title: 'Nuclear Reset: Delete ALL Envelopes',
                    subtitle: 'Permanently delete all envelopes from Hive AND Firestore',
                    leading: const Icon(Icons.delete_forever, color: Colors.red),
                    onTap: () => _nuclearDeleteAllEnvelopes(context),
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
                        // CRITICAL: Set logging out flag FIRST to prevent phantom builds
                        final workspaceProvider = Provider.of<WorkspaceProvider>(context, listen: false);
                        workspaceProvider.setLoggingOut(true);

                        // Show loading indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (ctx) =>
                              const Center(child: CircularProgressIndicator()),
                        );

                        try {
                          await AuthService.signOut();
                          // Dismiss loading dialog and pop all routes
                          // The AuthWrapper will automatically show SignInScreen
                          if (context.mounted) {
                            Navigator.of(context).popUntil((route) => route.isFirst);
                          }
                        } catch (e) {
                          // Reset logging out flag on error
                          workspaceProvider.setLoggingOut(false);
                          if (context.mounted) {
                            Navigator.pop(context); // Dismiss loading
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Logout failed: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                ],
              ),

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
      ),
    );
  }

  // --- Helpers ---

  Future<void> _showCurrencyPicker(
    BuildContext context,
    LocaleProvider localeProvider,
  ) async {
    final theme = Theme.of(context);
    final responsive = context.responsive;
    final isLandscape = responsive.isLandscape;

    final selectedCurrency = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: isLandscape ? 0.85 : 0.7,
        minChildSize: isLandscape ? 0.6 : 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            SizedBox(height: isLandscape ? 12 : 16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(height: isLandscape ? 12 : 16),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: isLandscape ? 20 : 24),
              child: Text(
                'Select Currency',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isLandscape ? 18 : null,
                ),
              ),
            ),
            SizedBox(height: isLandscape ? 12 : 16),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: LocaleProvider.supportedCurrencies.length,
                itemBuilder: (context, index) {
                  final currency = LocaleProvider.supportedCurrencies[index];
                  final code = currency['code']!;
                  final name = currency['name']!;
                  final symbol = currency['symbol']!;
                  final isSelected = localeProvider.currencyCode == code;

                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isLandscape ? 20 : 24,
                      vertical: isLandscape ? 4 : 8,
                    ),
                    leading: Container(
                      width: isLandscape ? 40 : 48,
                      height: isLandscape ? 40 : 48,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? theme.colorScheme.primary.withAlpha(26)
                            : theme.colorScheme.surfaceContainerHighest,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          symbol,
                          style: TextStyle(
                            fontSize: isLandscape ? 16 : 20,
                            fontWeight: FontWeight.bold,
                            color: isSelected
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: isLandscape ? 14 : null,
                      ),
                    ),
                    subtitle: Text(
                      code,
                      style: TextStyle(fontSize: isLandscape ? 12 : null),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle,
                            color: theme.colorScheme.primary,
                            size: isLandscape ? 20 : 24,
                          )
                        : null,
                    selected: isSelected,
                    onTap: () => Navigator.pop(ctx, code),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selectedCurrency != null) {
      await localeProvider.setCurrency(selectedCurrency);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Currency updated to ${LocaleProvider.getCurrencyName(selectedCurrency)}',
            ),
          ),
        );
      }
    }
  }

  Future<void> _showProfilePhotoOptions(
    BuildContext context,
    String? currentPhotoURL,
  ) async {
    final theme = Theme.of(context);

    await showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            if (currentPhotoURL != null)
              ListTile(
                leading: const Icon(Icons.visibility_outlined),
                title: const Text('View Photo'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showFullPhoto(context, currentPhotoURL);
                },
              ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from Gallery'),
              onTap: () async {
                Navigator.pop(ctx);
                await _pickAndUploadPhoto(context);
              },
            ),
            if (currentPhotoURL != null)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: theme.colorScheme.error,
                ),
                title: Text(
                  'Remove Photo',
                  style: TextStyle(color: theme.colorScheme.error),
                ),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _removePhoto(context);
                },
              ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Cancel'),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _showFullPhoto(BuildContext context, String photoURL) async {
    // Determine if it's a network URL or local file
    final isNetworkUrl = photoURL.startsWith('http://') || photoURL.startsWith('https://');

    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: isNetworkUrl
                  ? Image.network(
                      photoURL,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return const SizedBox(
                          height: 200,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey,
                          child: const Icon(Icons.error, color: Colors.white),
                        );
                      },
                    )
                  : Image.file(
                      File(photoURL),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey,
                          child: const Icon(Icons.error, color: Colors.white),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndUploadPhoto(
    BuildContext context,
  ) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );

    if (pickedFile == null) return;

    // Get theme colors before async gap
    final primaryColor = Theme.of(context).colorScheme.primary;
    final onPrimaryColor = Theme.of(context).colorScheme.onPrimary;

    // Crop the image to a circle
    final croppedFile = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      compressFormat: ImageCompressFormat.jpg,
      compressQuality: 85,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop Profile Photo',
          toolbarColor: primaryColor,
          toolbarWidgetColor: onPrimaryColor,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
          cropStyle: CropStyle.circle,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
          ],
          // Fix status bar - use light/dark mode instead of color
          statusBarLight: onPrimaryColor.computeLuminance() > 0.5,
          activeControlsWidgetColor: primaryColor,
          // Move controls to bottom to avoid status bar overlap
          hideBottomControls: false,
          // Proper padding and layout
          cropFrameColor: primaryColor,
          cropGridColor: primaryColor.withValues(alpha: 0.3),
          dimmedLayerColor: Colors.black.withValues(alpha: 0.6),
          // Show crop frame to make it clearer
          showCropGrid: true,
        ),
        IOSUiSettings(
          title: 'Crop Profile Photo',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          cropStyle: CropStyle.circle,
          aspectRatioPresets: [
            CropAspectRatioPreset.square,
          ],
        ),
      ],
    );

    if (croppedFile == null) return;

    if (!context.mounted) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final imageFile = File(croppedFile.path);
      final userId = repo.currentUserId;
      final workspaceId = repo.workspaceId;

      if (workspaceId != null) {
        // WORKSPACE MODE: Upload to Firebase Storage (partner can see photo)

        final storageRef = FirebaseStorage.instance
            .ref()
            .child('user_photos')
            .child('$userId.jpg');

        await storageRef.putFile(imageFile);
        final downloadUrl = await storageRef.getDownloadURL();

        // Save URL locally first
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_photo_path_$userId', downloadUrl);

        // Best-effort sync to Firestore
        try {
          final userService = UserService(repo.db, userId);
          await userService.updateUserProfile(photoURL: downloadUrl);
        } catch (e) {
        }

      } else {
        // SOLO MODE: Save locally only (privacy + offline)

        final appDir = await getApplicationDocumentsDirectory();
        final localPath = '${appDir.path}/profile_$userId.jpg';

        await imageFile.copy(localPath);

        // Save path to SharedPreferences (local-first)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_photo_path_$userId', localPath);

      }

      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile photo updated')));
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Helper to build profile photo widget that supports both network URLs and local file paths
  // Note: photoURL parameter is actually the value from SharedPreferences (can be file path or URL)
  static Future<Widget> _buildProfilePhotoWidget(String photoURL, String userId) async {
    // Check if it's a network URL (starts with http/https)
    if (photoURL.startsWith('http://') || photoURL.startsWith('https://')) {
      return CircleAvatar(
        backgroundImage: NetworkImage(photoURL),
        radius: 20,
      );
    } else {
      // It's a local file path - reconstruct the path dynamically using current app directory
      // This handles cases where the iOS container path changes between app launches
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'profile_$userId.jpg';
        final reconstructedPath = '${appDir.path}/$fileName';

        // Try the reconstructed path first (most reliable)
        if (File(reconstructedPath).existsSync()) {
          return CircleAvatar(
            backgroundImage: FileImage(File(reconstructedPath)),
            radius: 20,
          );
        }

        // Fallback: Try the stored path (might work if container didn't change)
        if (File(photoURL).existsSync()) {
          return CircleAvatar(
            backgroundImage: FileImage(File(photoURL)),
            radius: 20,
          );
        }

      } catch (e) {
      }

      // Fallback to default icon
      return const CircleAvatar(
        radius: 20,
        child: Icon(Icons.person),
      );
    }
  }

  Future<void> _removePhoto(
    BuildContext context,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Photo?'),
        content: const Text(
          'Are you sure you want to remove your profile photo?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      // Remove from SharedPreferences (local-first)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('profile_photo_path_${repo.currentUserId}');

      // Best-effort sync to Firestore
      try {
        final userService = UserService(repo.db, repo.currentUserId);
        await userService.updateUserProfile(photoURL: '');
      } catch (e) {
      }

      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Profile photo removed')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error removing photo: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    }
  }

  Future<void> _exportDataNew(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final groupRepo = GroupRepo(repo);
      final scheduledPaymentRepo = ScheduledPaymentRepo(repo.currentUserId);
      final accountRepo = AccountRepo(repo);
      final payDaySettingsService = PayDaySettingsService(repo.db, repo.currentUserId);

      final dataExportService = DataExportService(
        envelopeRepo: repo,
        groupRepo: groupRepo,
        scheduledPaymentRepo: scheduledPaymentRepo,
        accountRepo: accountRepo,
        payDaySettingsService: payDaySettingsService,
      );

      final filePath = await dataExportService.generateExcelFile();

      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss the progress dialog

        // Show success message with file location
        final fileName = filePath.split('/').last;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export saved to Documents: $fileName'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Share',
              onPressed: () async {
                await DataExportService.showExportOptions(context, filePath);
              },
            ),
          ),
        );
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

  // Removed - DataCleanupService no longer exists
  // Future<void> _cleanupOrphanedData(BuildContext context) async { ... }

  Future<void> _resetTransactionsAndBalances(BuildContext context) async {
    final theme = Theme.of(context);

    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: const Text('Reset Transactions & Balances?'),
        content: const Text(
          'This will:\n'
          '• Clear ALL transaction history\n'
          '• Reset ALL envelope balances to \$0.00\n'
          '• Reset ALL account balances to \$0.00\n'
          '\n'
          'This will NOT affect:\n'
          '• Cash flow amounts\n'
          '• Autopilot settings\n'
          '• Envelope/account structure\n'
          '\n'
          'This action cannot be undone!',
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
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Access Hive boxes directly to reset balances
      final envelopeBox = HiveService.getBox<Envelope>('envelopes');
      final accountBox = HiveService.getBox<Account>('accounts');
      final transactionBox = HiveService.getBox<models.Transaction>('transactions');

      // Reset all envelope balances
      final envelopes = repo.getEnvelopesSync();
      for (final envelope in envelopes) {
        final resetEnvelope = envelope.copyWith(currentAmount: 0.0);
        await envelopeBox.put(envelope.id, resetEnvelope);
      }

      // Reset all account balances
      final accountRepo = AccountRepo(repo);
      final accounts = accountRepo.getAccountsSync();
      for (final account in accounts) {
        final resetAccount = account.copyWith(currentBalance: 0.0);
        await accountBox.put(account.id, resetAccount);
      }

      // Clear all transactions from Hive
      await transactionBox.clear();

      // Clear all transactions from Firestore
      final transactionsSnapshot = await repo.db
          .collection('users')
          .doc(repo.currentUserId)
          .collection('transactions')
          .get();

      // Delete all transaction documents
      for (final doc in transactionsSnapshot.docs) {
        await doc.reference.delete();
      }

      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ All transactions and balances have been reset'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reset failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _nuclearDeleteAllEnvelopes(BuildContext context) async {
    final theme = Theme.of(context);

    // Show SCARY confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            const Text('⚠️ NUCLEAR RESET ⚠️'),
          ],
        ),
        content: const Text(
          '🔥 THIS WILL PERMANENTLY DELETE:\n\n'
          '• ALL of YOUR envelopes (not partner\'s)\n'
          '• ALL of YOUR transactions\n'
          '• ALL of YOUR scheduled payments\n'
          '• ALL of YOUR binders/groups\n'
          '• From BOTH Hive (local) AND Firestore (cloud)\n\n'
          '⚠️ THIS CANNOT BE UNDONE!\n\n'
          'Are you absolutely sure?',
          style: TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('YES, DELETE EVERYTHING'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // 1. Delete all envelopes from Hive
      final envelopeBox = HiveService.getBox<Envelope>('envelopes');
      await envelopeBox.clear();

      // 2. Delete all transactions from Hive
      final transactionBox = HiveService.getBox<models.Transaction>('transactions');
      await transactionBox.clear();

      // 3. Delete all scheduled payments from Hive
      final scheduledPaymentBox = HiveService.getBox<ScheduledPayment>('scheduledPayments');
      await scheduledPaymentBox.clear();

      // 4. Delete all groups from Hive
      final groupBox = HiveService.getBox<EnvelopeGroup>('groups');
      await groupBox.clear();

      // 5. Force delete from Firestore (cloud)
      // Delete from root collections (solo mode data)
      await repo.db
          .collection('envelopes')
          .where('userId', isEqualTo: repo.currentUserId)
          .get()
          .then((snapshot) async {
        for (var doc in snapshot.docs) {
          await doc.reference.delete();
        }
      });

      await repo.db
          .collection('transactions')
          .where('userId', isEqualTo: repo.currentUserId)
          .get()
          .then((snapshot) async {
        for (var doc in snapshot.docs) {
          await doc.reference.delete();
        }
      });

      await repo.db
          .collection('scheduledPayments')
          .where('userId', isEqualTo: repo.currentUserId)
          .get()
          .then((snapshot) async {
        for (var doc in snapshot.docs) {
          await doc.reference.delete();
        }
      });

      // WORKSPACE MODE: Also delete from workspace subcollections
      final workspaceId = repo.workspaceId;
      if (workspaceId != null && workspaceId.isNotEmpty) {

        // Delete workspace envelopes (only user's own)
        await repo.db
            .collection('workspaces')
            .doc(workspaceId)
            .collection('envelopes')
            .where('userId', isEqualTo: repo.currentUserId)
            .get()
            .then((snapshot) async {
          for (var doc in snapshot.docs) {
            await doc.reference.delete();
          }
        });

        // Delete workspace transactions (only user's own)
        await repo.db
            .collection('workspaces')
            .doc(workspaceId)
            .collection('transactions')
            .where('userId', isEqualTo: repo.currentUserId)
            .get()
            .then((snapshot) async {
          for (var doc in snapshot.docs) {
            await doc.reference.delete();
          }
        });

        // Delete workspace scheduled payments (only user's own)
        await repo.db
            .collection('workspaces')
            .doc(workspaceId)
            .collection('scheduledPayments')
            .where('userId', isEqualTo: repo.currentUserId)
            .get()
            .then((snapshot) async {
          for (var doc in snapshot.docs) {
            await doc.reference.delete();
          }
        });
      }

      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('🔥 Nuclear reset complete! All data deleted from Hive and Firestore.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Nuclear reset failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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
                color: Colors.black.withAlpha(13),
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
                color: theme.colorScheme.onSurfaceVariant.withAlpha(128),
              ),
              child: trailing!,
            )
          : null,
      onTap: onTap,
      enabled: onTap != null,
    );
  }
}
