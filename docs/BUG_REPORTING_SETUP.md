# Bug Reporting & Logging System - Complete Guide

## 🎯 What's Implemented

You now have a complete bug reporting and logging system with:

1. ✅ **Device Info Helper** - Captures device/app details
2. ✅ **Logger Service** - Automatic debug log management
3. ✅ **Bug Report Service** - Pre-filled email reports
4. ✅ **App Update Service** - Firebase Remote Config version checking
5. ✅ **Settings Integration** - User-facing UI

## 📱 User Experience

### In Settings → Support:

1. **Report a Bug**
   - Opens dialog with 2 options:
     - Email Report (pre-filled with device info + logs)
     - Export Logs (share debug file)

2. **Send Feedback**
   - Opens email with device info template
   - For feature requests and suggestions

3. **Check for Updates**
   - Manually check for new versions
   - Shows "Up to Date" or update dialog

4. **About Screen**
   - App version, build number
   - Developer info, links to privacy/terms

## 🔧 How It Works

### Logger Service

**Location:** `lib/services/logger_service.dart`

**Features:**
- Writes to `stuffrite_debug.log` in Documents folder
- Auto-cleans logs older than 7 days
- Limits to 1000 lines max
- 3 log levels: `info()`, `warning()`, `error()`

**Usage in your code:**
```dart
import 'package:stuffrite/services/logger_service.dart';

// Info logging
await LoggerService.info('User completed onboarding');

// Warning logging
await LoggerService.warning('API response slow: 3.2s');

// Error logging with stack trace
try {
  // risky code
} catch (e, stackTrace) {
  await LoggerService.error('Failed to load data', e, stackTrace);
}
```

**Where logs are stored:**
- iOS: `/Documents/stuffrite_debug.log`
- Android: `/Documents/stuffrite_debug.log`

### Bug Report Flow

When user taps "Report a Bug":

1. **Dialog shows 2 options:**
   - Email Report
   - Export Logs

2. **Email Report:**
   ```
   Subject: Stuffrite Bug Report

   Body:
   [User describes issue]

   Steps to reproduce:
   1.
   2.
   3.

   --- Device Information ---
   App Version: 1.1.3 (4)
   OS Version: iOS 17.2
   Platform: iOS
   Package Name: com.develapp.stuffrite

   --- Recent Logs (Last 50 lines) ---
   [2025-01-04 10:23:45] [INFO] App started: v1.1.3 (4)
   [2025-01-04 10:23:46] [INFO] Remote Config initialized
   ...
   ```

3. **Export Logs:**
   - Shares the full `stuffrite_debug.log` file
   - User can attach to email, upload to cloud, etc.

### Update Checking

**Automatic Check:**
- On app startup
- Once per 24 hours (configurable)

**Manual Check:**
- Settings → Support → Check for Updates

**Firebase Remote Config Parameters:**
```json
{
  "latest_version": "1.1.3",
  "force_update": false,
  "update_message": "Bug fixes and improvements!"
}
```

## 📊 What You'll Receive

### Bug Report Email:
```
To: hello@develapp.tech
Subject: Stuffrite Bug Report

From: user@example.com

User's description of the bug...

--- Device Information ---
App Version: 1.1.3 (4)
OS Version: Android 14
Platform: Android
Package Name: com.develapp.stuffrite

--- Recent Logs ---
[Timestamp] [LEVEL] Log message
...
```

### Feedback Email:
```
To: hello@develapp.tech
Subject: Stuffrite Feedback

From: user@example.com

User's feedback...

--- Device Information ---
[Same as above]
```

## 🚀 Next Steps (Optional)

### Add Firebase Crashlytics (Recommended)

For automatic crash reporting:

1. **Add dependency:**
   ```yaml
   # pubspec.yaml
   firebase_crashlytics: ^4.1.3
   ```

2. **Initialize in main.dart:**
   ```dart
   await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

   FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterError;
   ```

3. **Benefits:**
   - Automatic crash reports
   - Stack traces
   - Device info
   - User impact metrics

### Add Sentry (Alternative)

For advanced error tracking:

1. **Add dependency:**
   ```yaml
   sentry_flutter: ^8.0.0
   ```

2. **Initialize:**
   ```dart
   await SentryFlutter.init(
     (options) {
       options.dsn = 'YOUR_SENTRY_DSN';
     },
     appRunner: () => runApp(MyApp()),
   );
   ```

3. **Benefits:**
   - Real-time error tracking
   - Performance monitoring
   - Release health
   - Issue assignment/tracking

### Add Analytics for Version Tracking

**Firebase Analytics** (already available):

```dart
import 'package:firebase_analytics/firebase_analytics.dart';

// In main.dart after initialization:
final analytics = FirebaseAnalytics.instance;
await analytics.setUserProperty(
  name: 'app_version',
  value: packageInfo.version,
);
```

**View in Firebase Console:**
- Analytics → Events → app_version
- See which versions users are on
- Track update adoption rates

## 🐛 Common Issues & Solutions

### "Email client not launching"
- User doesn't have email app configured
- Suggest they manually copy logs and email

### "Can't find log file"
- Logs are stored in app's Documents directory
- Only accessible to the app (sandboxed)
- Must use "Export Logs" to share

### "Remote Config not updating"
- Default fetch interval is 1 hour
- Restart app to force fresh fetch
- Check Firebase Console for published changes

### "Force update not working"
- Ensure both `force_update=true` AND version is newer
- Dialog will show on next app open
- Can't force users to update mid-session

## 📝 Best Practices

### Logging:

**DO:**
- Log important user actions
- Log API errors with context
- Log state changes
- Use appropriate log levels

**DON'T:**
- Log sensitive data (passwords, tokens, PII)
- Log in tight loops (performance)
- Log every single action (noise)

### Bug Reports:

**Encourage users to:**
- Describe what they were doing
- Include steps to reproduce
- Mention if it's consistent or random

**You should:**
- Respond within 24-48 hours
- Ask for clarification if needed
- Let them know when fixed

### Version Updates:

**Best practices:**
- Update `latest_version` only after store approval
- Use `force_update` sparingly (security only)
- Write clear, user-friendly update messages
- Test Remote Config in staging first

## 📞 Support Workflow

### When you receive a bug report:

1. ✅ **Read logs first** - Often reveals the issue
2. ✅ **Check device info** - iOS vs Android, version
3. ✅ **Try to reproduce** - Follow steps if provided
4. ✅ **Fix and test** - Create fix, test on similar device
5. ✅ **Release update** - Deploy fix
6. ✅ **Notify user** - Reply to their email
7. ✅ **Update Remote Config** - Prompt users to update

### Triage Priority:

**P0 - Critical (Force Update):**
- Security vulnerabilities
- Data loss bugs
- App crashes on launch

**P1 - High (Regular Update):**
- Feature completely broken
- Affects majority of users
- Workaround available

**P2 - Medium (Next Release):**
- Minor bugs
- Affects small percentage
- Has workaround

**P3 - Low (Backlog):**
- Cosmetic issues
- Feature requests
- Nice-to-haves

## 🎉 Summary

You now have:
- ✅ Automated logging system
- ✅ Easy bug reporting for users
- ✅ Pre-filled device diagnostics
- ✅ Remote version management
- ✅ Force update capability
- ✅ Professional support workflow

All ready to go! Just set up Firebase Remote Config and you're done.
