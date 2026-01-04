import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/device_info_helper.dart';
import 'logger_service.dart';

class BugReportService {
  static const String supportEmail = 'hello@develapp.tech';

  /// Show bug report dialog with options
  static Future<void> showBugReportDialog(BuildContext context) async {
    final theme = Theme.of(context);

    return showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        title: Row(
          children: [
            Icon(Icons.bug_report, color: theme.colorScheme.primary),
            const SizedBox(width: 12),
            const Text('Report a Bug'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Help us improve Stuffrite by reporting bugs or issues you encounter.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Choose an option:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            _BugReportOption(
              icon: Icons.email_outlined,
              title: 'Email Report',
              subtitle: 'Opens email with pre-filled info',
              onTap: () {
                Navigator.pop(ctx);
                sendEmailBugReport(context);
              },
            ),
            const SizedBox(height: 8),
            _BugReportOption(
              icon: Icons.attachment,
              title: 'Export Logs',
              subtitle: 'Share debug logs for analysis',
              onTap: () {
                Navigator.pop(ctx);
                exportLogs(context);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  /// Send bug report via email with pre-filled device info
  static Future<void> sendEmailBugReport(BuildContext context) async {
    try {
      final deviceInfo = await DeviceInfoHelper.getFormattedDeviceInfo();
      final recentLogs = await LoggerService.getRecentLogs(lines: 50);

      final emailBody = '''
Please describe the bug or issue you encountered:

[Describe the issue here]

Steps to reproduce:
1.
2.
3.

Expected behavior:
[What should happen]

Actual behavior:
[What actually happened]

--- DO NOT EDIT BELOW THIS LINE ---

$deviceInfo

--- Recent Logs (Last 50 lines) ---
$recentLogs
''';

      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: supportEmail,
        query: _encodeQueryParameters({
          'subject': 'Stuffrite Bug Report',
          'body': emailBody,
        }),
      );

      if (!await launchUrl(emailUri)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not launch email client'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error creating bug report: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Export debug logs file
  static Future<void> exportLogs(BuildContext context) async {
    try {
      final logFile = await LoggerService.getLogFile();

      if (logFile == null || !await logFile.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No log file found'),
            ),
          );
        }
        return;
      }

      // Share the log file
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(logFile.path)],
          text: 'Stuffrite Debug Logs',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error exporting logs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Send feedback via email
  static Future<void> sendFeedback(BuildContext context) async {
    try {
      final deviceInfo = await DeviceInfoHelper.getFormattedDeviceInfo();

      final emailBody = '''
Thank you for your feedback!

Please share your thoughts, suggestions, or feature requests:

[Your feedback here]

--- Device Information ---
$deviceInfo
''';

      final Uri emailUri = Uri(
        scheme: 'mailto',
        path: supportEmail,
        query: _encodeQueryParameters({
          'subject': 'Stuffrite Feedback',
          'body': emailBody,
        }),
      );

      if (!await launchUrl(emailUri)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not launch email client'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sending feedback: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Encode query parameters for mailto URL
  static String _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((entry) =>
            '${Uri.encodeComponent(entry.key)}=${Uri.encodeComponent(entry.value)}')
        .join('&');
  }
}

class _BugReportOption extends StatelessWidget {
  const _BugReportOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(
            color: theme.colorScheme.outline.withAlpha(51),
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: theme.colorScheme.primary,
              size: 28,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withAlpha(153),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: theme.colorScheme.onSurface.withAlpha(128),
            ),
          ],
        ),
      ),
    );
  }
}
