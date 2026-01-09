# Secure Build Setup Guide

This guide explains how to build and run the Stuffrite app with secure API key management.

## Why This Changed

Previously, API keys were hardcoded in the source code. This is a security risk, especially in public repositories. We've migrated to environment-based configuration.

## Quick Start

### First Time Setup

1. **Get your API keys from RevenueCat:**
   - Go to https://app.revenuecat.com/settings/keys
   - Copy your Test, iOS, and Android API keys

2. **Add keys to .env file:**
   ```bash
   # Edit .env and add your keys
   REVENUECAT_TEST_API_KEY=your_test_key
   REVENUECAT_IOS_API_KEY=your_ios_key
   REVENUECAT_ANDROID_API_KEY=your_android_key
   ```

3. **Verify setup:**
   ```bash
   ./verify_security.sh
   ```

### Running the App

Instead of `flutter run`, use:
```bash
./run_with_keys.sh
```

This automatically loads your API keys from `.env` and passes them to Flutter.

### Building for Production

Instead of `flutter build`, use:
```bash
# For iOS
./build_with_keys.sh build ios --release

# For Android
./build_with_keys.sh build android --release

# For macOS
./build_with_keys.sh build macos --release
```

## How It Works

### Environment Variables
API keys are loaded using Flutter's `--dart-define` flag at compile time:

```dart
static const String iosApiKey = String.fromEnvironment(
  'REVENUECAT_IOS_API_KEY',
  defaultValue: '',
);
```

### Build Scripts
The helper scripts:
1. Read your `.env` file
2. Export the variables
3. Pass them to Flutter using `--dart-define`
4. Build/run your app

## CI/CD Setup

### GitHub Actions Example

```yaml
name: Build

on: [push]

jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup Flutter
        uses: subosito/flutter-action@v2

      - name: Build iOS
        env:
          REVENUECAT_TEST_API_KEY: ${{ secrets.REVENUECAT_TEST_API_KEY }}
          REVENUECAT_IOS_API_KEY: ${{ secrets.REVENUECAT_IOS_API_KEY }}
          REVENUECAT_ANDROID_API_KEY: ${{ secrets.REVENUECAT_ANDROID_API_KEY }}
        run: |
          flutter build ios --release \
            --dart-define=REVENUECAT_TEST_API_KEY="$REVENUECAT_TEST_API_KEY" \
            --dart-define=REVENUECAT_IOS_API_KEY="$REVENUECAT_IOS_API_KEY" \
            --dart-define=REVENUECAT_ANDROID_API_KEY="$REVENUECAT_ANDROID_API_KEY"
```

**Don't forget to add secrets in GitHub:**
Settings → Secrets and variables → Actions → New repository secret

### Xcode Cloud

Add environment variables in Xcode Cloud settings:
1. Open App Store Connect
2. Go to your app → Xcode Cloud
3. Manage Workflows → Environment Variables
4. Add the three API keys as secret variables

Then in your build script:
```bash
flutter build ipa --release \
  --dart-define=REVENUECAT_TEST_API_KEY="$REVENUECAT_TEST_API_KEY" \
  --dart-define=REVENUECAT_IOS_API_KEY="$REVENUECAT_IOS_API_KEY" \
  --dart-define=REVENUECAT_ANDROID_API_KEY="$REVENUECAT_ANDROID_API_KEY"
```

## Troubleshooting

### "API key not set" error
Run `./verify_security.sh` to diagnose the issue.

Common causes:
- `.env` file doesn't exist (copy from `.env.example`)
- Keys not set in `.env` file
- Using `flutter run` instead of `./run_with_keys.sh`

### Build works locally but not in CI
Make sure you've added the API keys as secrets in your CI system.

### Keys showing as empty in app
The keys are set at compile time, not runtime. You must build with the helper scripts or `--dart-define` flags.

## Security Best Practices

✅ **DO:**
- Use the helper scripts (`run_with_keys.sh`, `build_with_keys.sh`)
- Keep `.env` in `.gitignore` (already done)
- Store secrets in CI/CD secret management
- Rotate API keys periodically
- Review who has access to your repository

❌ **DON'T:**
- Commit `.env` file to git
- Share API keys in chat/email
- Hardcode keys in source code
- Use production keys in development

## Team Setup

When a new team member joins:

1. They clone the repository
2. Copy `.env.example` to `.env`
3. Get API keys from team lead (or RevenueCat if they have access)
4. Add keys to their local `.env` file
5. Run `./verify_security.sh` to verify setup
6. Start developing with `./run_with_keys.sh`

## Files Reference

- **`.env`** - Your local API keys (gitignored, never commit)
- **`.env.example`** - Template showing required variables
- **`run_with_keys.sh`** - Run app with keys from .env
- **`build_with_keys.sh`** - Build app with keys from .env
- **`verify_security.sh`** - Check your security setup
- **`lib/config/revenue_cat_config.dart`** - Configuration class that reads keys

## Need Help?

See the full security documentation:
- [IMMEDIATE_ACTIONS.md](IMMEDIATE_ACTIONS.md) - If you're responding to a security incident
- [SECURITY_REMEDIATION.md](SECURITY_REMEDIATION.md) - Complete remediation guide
