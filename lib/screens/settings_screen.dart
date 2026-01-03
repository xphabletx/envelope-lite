// lib/screens/settings_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/envelope_repo.dart';
import '../services/user_service.dart';
import '../services/account_security_service.dart';
import '../services/data_export_service.dart';
import '../services/group_repo.dart';
import '../services/account_repo.dart';
import '../services/customer_center_service.dart';
import '../providers/workspace_provider.dart';

import '../screens/appearance_settings_screen.dart';
import '../screens/workspace_management_screen.dart';
import '../screens/workspace_gate.dart';
import '../screens/pay_day_settings_screen.dart';
import '../screens/settings/tutorial_manager_screen.dart';
import '../screens/settings/faq_screen.dart';
import '../services/scheduled_payment_repo.dart';
import '../services/pay_day_settings_service.dart';
import '../widgets/tutorial_wrapper.dart';
import '../data/tutorial_sequences.dart';
import '../utils/responsive_helper.dart';
import '../providers/locale_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.repo});

  final EnvelopeRepo repo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final userService = UserService(repo.db, repo.currentUserId);
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
      body: StreamBuilder<UserProfile?>(
        stream: userService.userProfileStream,
        builder: (context, snapshot) {
          final profile = snapshot.data;
          final displayName = profile?.displayName ?? 'User';
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
                    subtitle: profile?.photoURL != null
                        ? 'Tap to change'
                        : 'Tap to add',
                    leading: profile?.photoURL != null
                        ? CircleAvatar(
                            backgroundImage: NetworkImage(profile!.photoURL!),
                            radius: 20,
                          )
                        : const Icon(Icons.add_a_photo_outlined),
                    onTap: () async {
                      await _showProfilePhotoOptions(
                        context,
                        userService,
                        profile?.photoURL,
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
                  _SettingsTile(
                    title: 'Manage Subscription',
                    subtitle: 'View and manage your Stuffrite Premium subscription',
                    leading: const Icon(Icons.card_membership_outlined),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await CustomerCenterService.presentCustomerCenter(context);
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
    UserService userService,
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
                await _pickAndUploadPhoto(context, userService);
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
                  await _removePhoto(context, userService);
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
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.network(
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
    UserService userService,
  ) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (pickedFile == null) return;

    if (!context.mounted) return;

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final imageFile = File(pickedFile.path);
      final userId = userService.userId;
      final workspaceId = repo.workspaceId;

      if (workspaceId != null) {
        // WORKSPACE MODE: Upload to Firebase Storage (partner can see photo)
        debugPrint(
          '[Settings] 🤝 Workspace mode: uploading photo to Firebase Storage',
        );

        final storageRef = FirebaseStorage.instance
            .ref()
            .child('user_photos')
            .child('$userId.jpg');

        await storageRef.putFile(imageFile);
        final downloadUrl = await storageRef.getDownloadURL();

        // Save URL to user profile
        await userService.updateUserProfile(photoURL: downloadUrl);

        debugPrint('[Settings] ✅ Photo uploaded to Firebase Storage');
      } else {
        // SOLO MODE: Save locally only (privacy + offline)
        debugPrint('[Settings] 📦 Solo mode: saving photo locally');

        final appDir = await getApplicationDocumentsDirectory();
        final localPath = '${appDir.path}/profile_photo_$userId.jpg';

        await imageFile.copy(localPath);

        // Save path to SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_photo_path', localPath);

        debugPrint('[Settings] ✅ Photo saved locally: $localPath');
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

  Future<void> _removePhoto(
    BuildContext context,
    UserService userService,
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
      await userService.updateUserProfile(photoURL: '');

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
      debugPrint('Could not launch $url');
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

      final dataExportService = DataExportService(
        envelopeRepo: repo,
        groupRepo: groupRepo,
        scheduledPaymentRepo: scheduledPaymentRepo,
        accountRepo: accountRepo, // New: Pass AccountRepo
      );

      final filePath = await dataExportService.generateExcelFile();

      if (context.mounted) {
        Navigator.of(context).pop(); // Dismiss the progress dialog
        await DataExportService.showExportOptions(context, filePath);
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
