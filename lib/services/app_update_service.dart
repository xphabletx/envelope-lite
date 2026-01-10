import 'dart:io';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'logger_service.dart';

class AppUpdateService {
  // App Store / Play Store URLs
  static const String iosAppStoreUrl = 'https://apps.apple.com/app/id6738365743';
  static const String androidPlayStoreUrl = 'https://play.google.com/store/apps/details?id=com.develapp.stuffrite';

  // Remote Config keys
  static const String _latestVersionKey = 'latest_version';
  static const String _minRequiredVersionKey = 'min_required_version';
  static const String _forceUpdateKey = 'force_update';
  static const String _updateMessageKey = 'update_message';

  // SharedPreferences keys
  static const String _lastCheckKey = 'last_update_check';
  static const String _skipVersionKey = 'skip_version';

  static FirebaseRemoteConfig? _remoteConfig;

  /// Check for app updates and show dialog if available
  static Future<void> checkForUpdates(
    BuildContext context, {
    bool showNoUpdateDialog = false,
    bool respectSkipVersion = true,
  }) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Check if we should skip this check (once per day)
      if (!showNoUpdateDialog && !await _shouldCheckForUpdate()) {
        return;
      }

      final latestVersion = await _getLatestVersion();

      if (latestVersion == null) {
        if (showNoUpdateDialog && context.mounted) {
          _showNoUpdateDialog(context);
        }
        return;
      }

      // Save last check time
      await _saveLastCheckTime();

      // Check if user skipped this version
      if (respectSkipVersion && await _hasSkippedVersion(latestVersion)) {
        return;
      }

      if (_isNewerVersion(currentVersion, latestVersion)) {
        if (context.mounted) {
          _showUpdateDialog(context, currentVersion, latestVersion);
        }
      } else if (showNoUpdateDialog && context.mounted) {
        _showNoUpdateDialog(context);
      }
    } catch (e) {
      if (showNoUpdateDialog && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not check for updates: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Initialize Firebase Remote Config
  static Future<void> init() async {
    try {
      _remoteConfig = FirebaseRemoteConfig.instance;

      // Set config settings
      await _remoteConfig!.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1), // Fetch new values max once per hour
      ));

      // Set default values
      await _remoteConfig!.setDefaults({
        _latestVersionKey: '1.1.3',
        _minRequiredVersionKey: '1.0.0',
        _forceUpdateKey: false,
        _updateMessageKey: 'A new version is available with bug fixes and improvements!',
      });

      // Fetch and activate
      await _remoteConfig!.fetchAndActivate();

      await LoggerService.info('Remote Config initialized successfully');
    } catch (e) {
      await LoggerService.error('Failed to initialize Remote Config', e);
    }
  }

  /// Get latest version from Firebase Remote Config
  static Future<String?> _getLatestVersion() async {
    try {
      if (_remoteConfig == null) {
        await init();
      }

      await _remoteConfig!.fetchAndActivate();
      final latestVersion = _remoteConfig!.getString(_latestVersionKey);

      if (latestVersion.isNotEmpty) {
        await LoggerService.info('Latest version from Remote Config: $latestVersion');
        return latestVersion;
      }
    } catch (e) {
      await LoggerService.error('Error fetching latest version from Remote Config', e);
    }

    return null;
  }

  /// Check if force update is required
  static Future<bool> _isForceUpdateRequired() async {
    try {
      if (_remoteConfig == null) {
        await init();
      }

      return _remoteConfig!.getBool(_forceUpdateKey);
    } catch (e) {
      return false;
    }
  }

  /// Get custom update message
  static Future<String> _getUpdateMessage() async {
    try {
      if (_remoteConfig == null) {
        await init();
      }

      final message = _remoteConfig!.getString(_updateMessageKey);
      return message.isNotEmpty
          ? message
          : 'A new version is available with bug fixes and improvements!';
    } catch (e) {
      return 'A new version is available with bug fixes and improvements!';
    }
  }

  /// Compare version strings (e.g., "1.2.3" vs "1.2.4")
  static bool _isNewerVersion(String current, String latest) {
    final currentParts = current.split('.').map(int.parse).toList();
    final latestParts = latest.split('.').map(int.parse).toList();

    for (int i = 0; i < 3; i++) {
      final currentPart = i < currentParts.length ? currentParts[i] : 0;
      final latestPart = i < latestParts.length ? latestParts[i] : 0;

      if (latestPart > currentPart) return true;
      if (latestPart < currentPart) return false;
    }

    return false;
  }

  /// Show update available dialog
  static Future<void> _showUpdateDialog(
    BuildContext context,
    String currentVersion,
    String latestVersion,
  ) async {
    final theme = Theme.of(context);
    final forceUpdate = await _isForceUpdateRequired();
    final updateMessage = await _getUpdateMessage();

    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (ctx) => PopScope(
        canPop: !forceUpdate,
        child: AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          title: Row(
            children: [
              Icon(
                forceUpdate ? Icons.warning : Icons.system_update,
                color: forceUpdate ? Colors.orange : theme.colorScheme.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Text(forceUpdate ? 'Update Required' : 'Update Available'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                updateMessage,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Current Version:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(179),
                    ),
                  ),
                  Text(
                    currentVersion,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Latest Version:',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(179),
                    ),
                  ),
                  Text(
                    latestVersion,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              if (forceUpdate) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(51),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'This update is required to continue using the app',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            if (!forceUpdate) ...[
              TextButton(
                onPressed: () async {
                  await _skipVersion(latestVersion);
                  Navigator.pop(ctx);
                },
                child: const Text('Skip This Version'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Later'),
              ),
            ],
            FilledButton(
              onPressed: () async {
                if (!forceUpdate) {
                  Navigator.pop(ctx);
                }
                await _openStore();
              },
              child: const Text('Update Now'),
            ),
          ],
        ),
      ),
    );
  }

  /// Show no update available dialog
  static void _showNoUpdateDialog(BuildContext context) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Row(
          children: [
            Icon(
              Icons.check_circle_outline,
              color: Colors.green,
              size: 28,
            ),
            const SizedBox(width: 12),
            const Text('You\'re Up to Date'),
          ],
        ),
        content: const Text(
          'You\'re running the latest version of Stuffrite.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// Open the appropriate app store
  static Future<void> _openStore() async {
    String url;
    if (Platform.isIOS) {
      url = iosAppStoreUrl;
    } else if (Platform.isAndroid) {
      url = androidPlayStoreUrl;
    } else {
      return;
    }

    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    }
  }

  /// Check if we should check for updates (once per day)
  static Future<bool> _shouldCheckForUpdate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastCheck = prefs.getInt(_lastCheckKey);

      if (lastCheck == null) return true;

      final lastCheckTime = DateTime.fromMillisecondsSinceEpoch(lastCheck);
      final now = DateTime.now();
      final difference = now.difference(lastCheckTime);

      return difference.inHours >= 24;
    } catch (e) {
      return true;
    }
  }

  /// Save last check time
  static Future<void> _saveLastCheckTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastCheckKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
    }
  }

  /// Skip a specific version
  static Future<void> _skipVersion(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_skipVersionKey, version);
    } catch (e) {
    }
  }

  /// Check if user has skipped this version
  static Future<bool> _hasSkippedVersion(String version) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final skippedVersion = prefs.getString(_skipVersionKey);
      return skippedVersion == version;
    } catch (e) {
      return false;
    }
  }

  /// Clear skipped version (for manual checks)
  static Future<void> clearSkippedVersion() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_skipVersionKey);
    } catch (e) {
    }
  }
}
