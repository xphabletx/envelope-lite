# Firebase Remote Config Setup for Version Management

This guide will help you set up Firebase Remote Config to manage app updates.

## 🎯 What You Get

- **Real-time version control** - Update version info without redeploying
- **Custom update messages** - Personalize what users see
- **Force update capability** - Require critical security updates
- **Automatic checking** - Users get notified of new versions
- **A/B testing ready** - Can target specific users or percentages

## 📋 Setup Steps

### 1. Enable Remote Config in Firebase Console

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your Stuffrite project
3. Navigate to **Remote Config** in the left sidebar
4. Click **"Get started"** (if first time)

### 2. Add Parameters

Add these 4 parameters in Remote Config:

#### Parameter 1: `latest_version`
- **Key:** `latest_version`
- **Default value:** `1.1.3`
- **Description:** The latest version available in app stores
- **Update this** when you release a new version

#### Parameter 2: `min_required_version`
- **Key:** `min_required_version`
- **Default value:** `1.0.0`
- **Description:** Minimum version required to use the app
- **Use this** for security-critical updates

#### Parameter 3: `force_update`
- **Key:** `force_update`
- **Default value:** `false` (boolean)
- **Description:** Whether to force users to update
- **Set to `true`** when you need everyone to update immediately

#### Parameter 4: `update_message`
- **Key:** `update_message`
- **Default value:** `A new version is available with bug fixes and improvements!`
- **Description:** Custom message shown to users
- **Customize** for each release (e.g., "New feature: Dark mode!")

### 3. Publish Changes

After adding all parameters:
1. Click **"Publish changes"** in the top right
2. Confirm the publish

### 4. Test Your Setup

Run your app and check the logs for:
```
[Main] 🔄 Remote Config initialized for updates
[LoggerService] Remote Config initialized successfully
```

### 5. Check for Updates Manually

In the app:
1. Go to **Settings** → **Support** → **Check for Updates**
2. You should see "You're Up to Date" (since 1.1.3 is current)

## 🚀 How to Use for Releases

### When Releasing Version 1.2.0:

1. **Deploy to App Store / Play Store** first
2. **Wait for approval** (especially iOS)
3. **Update Firebase Remote Config:**
   - `latest_version`: `1.2.0`
   - `update_message`: `New features: Time machine improvements and bug fixes!`
   - `force_update`: `false` (unless critical)
4. **Publish changes**

Within 1 hour (or on next app startup), users will be prompted to update!

### For Critical Security Updates:

1. Release version 1.2.1 with security fix
2. Update Remote Config:
   - `latest_version`: `1.2.1`
   - `force_update`: `true` ⚠️
   - `min_required_version`: `1.2.1`
   - `update_message`: `Critical security update required`
3. Users will be **forced** to update (can't dismiss dialog)

## 📊 Monitoring

### Check Who's Updated:
- Firebase Analytics automatically tracks app versions
- Go to **Analytics** → **Events** → **app_version**
- See distribution of versions across your user base

### Remote Config Analytics:
- See how many users fetched new config values
- Track parameter value changes over time

## 🎨 Advanced: Conditional Updates

You can target specific users:

### Example: Beta Testers Only
```
Condition: User in segment "beta_testers"
Value for latest_version: "1.3.0-beta"
```

### Example: Android Only
```
Condition: Platform == "android"
Value for latest_version: "1.2.0"
```

### Example: Percentage Rollout
```
Condition: User in randomized group (10%)
Value for latest_version: "1.2.0"
```

## 🔧 Troubleshooting

### "No update available" when there should be:
- Check Remote Config is published
- Wait up to 1 hour (default fetch interval)
- Or restart the app to force refresh

### Users not seeing updates:
- Verify `latest_version` > current app version
- Check Firebase console for parameter values
- Look at app logs for Remote Config errors

### Force update not working:
- Ensure both `force_update` = `true` AND `latest_version` is newer
- Users on older versions won't see it until they open the app

## 📱 App Store URLs

Already configured in the code:
- **iOS:** `https://apps.apple.com/app/id6738365743`
- **Android:** `https://play.google.com/store/apps/details?id=com.develapp.stuffrite`

## 🔄 Automatic Update Checks

Currently configured to check:
- **Once per day** automatically (in background)
- **On app startup** (after initialization)
- **Manual check** via Settings → Check for Updates

To change frequency, edit `app_update_service.dart`:
```dart
minimumFetchInterval: const Duration(hours: 1), // Change this
```

## 📝 Version Number Format

Use semantic versioning: `MAJOR.MINOR.PATCH`
- **MAJOR**: Breaking changes (e.g., 1.0.0 → 2.0.0)
- **MINOR**: New features (e.g., 1.1.0 → 1.2.0)
- **PATCH**: Bug fixes (e.g., 1.1.3 → 1.1.4)

## 🎉 Done!

Your app now has professional version management with Firebase Remote Config!
