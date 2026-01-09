# Security Incident Remediation Guide

## Incident Summary
**Date:** 2026-01-09
**Issue:** RevenueCat API keys were exposed in public GitHub repository
**Severity:** HIGH - Public API keys can be used to access your RevenueCat account and data
**Status:** Remediation in progress

---

## Exposed Credentials

The following API keys were found in the public repository:
- **Test API Key:** `REDACTED_TEST_KEY`
- **iOS API Key:** `REDACTED_IOS_KEY`
- **Android API Key:** `REDACTED_ANDROID_KEY`

**Locations:**
- `lib/config/revenue_cat_config.dart`
- `docs/MASTER_CONTEXT.md`
- Throughout git history in multiple commits

---

## ✅ Completed Actions (Automated)

1. **Removed hardcoded keys** from source code
2. **Migrated to environment variables** using Flutter's `--dart-define`
3. **Updated .gitignore** to prevent future exposure
4. **Created helper scripts** for building with secrets
5. **Created scrubbing script** to clean git history

---

## 🚨 CRITICAL ACTIONS REQUIRED (Manual)

### 1. Revoke Exposed API Keys Immediately

**You must do this NOW:**

1. Go to [RevenueCat Dashboard → Settings → API Keys](https://app.revenuecat.com/settings/keys)
2. **Delete** or **Rotate** these three API keys:
   - Test API Key: `REDACTED_TEST_KEY`
   - iOS API Key: `REDACTED_IOS_KEY`
   - Android API Key: `REDACTED_ANDROID_KEY`

3. **Generate new API keys** for:
   - Test environment
   - iOS production
   - Android production

⚠️ **Why this is critical:** Anyone who accessed your repository can use these keys to:
- View customer purchase data
- Access subscription information
- Potentially modify entitlements (depending on key permissions)
- Generate costs to your account

### 2. Review RevenueCat Audit Logs

1. Go to [RevenueCat Dashboard → Settings → Audit Log](https://app.revenuecat.com/settings/audit-log)
2. Check for any suspicious API activity from unknown IP addresses
3. Look for unauthorized access between when the keys were first committed and now
4. Document any suspicious activity

### 3. Check for Unauthorized Usage

Review your RevenueCat metrics for:
- Unusual spikes in API calls
- Unexpected subscriber modifications
- Webhook deliveries to unknown endpoints
- Any other anomalies

### 4. Update Your Environment

After generating new keys from RevenueCat:

1. Add the new keys to `.env` file:
   ```bash
   REVENUECAT_TEST_API_KEY=your_new_test_key
   REVENUECAT_IOS_API_KEY=your_new_ios_key
   REVENUECAT_ANDROID_API_KEY=your_new_android_key
   ```

2. **Never commit the `.env` file** (it's already in .gitignore)

### 5. Scrub Git History

⚠️ **This will rewrite git history - coordinate with your team first!**

Run the provided script to remove the old keys from all git history:

```bash
# Install git-filter-repo first
pip3 install git-filter-repo

# Run the scrubbing script
./scrub_secrets.sh
```

This will:
- Replace all occurrences of the old keys with "REDACTED" in all commits
- Rewrite the entire git history
- Require a force push to remote

**After running:**
```bash
# Force push to remote (this rewrites history on GitHub)
git push origin --force --all
git push origin --force --tags
```

⚠️ **Important:** All team members will need to re-clone the repository after this step.

### 6. Force GitHub Cache Refresh

Even after rewriting history, GitHub may cache the old content:

1. Contact GitHub Support to clear their cache for your repository
   - Go to https://support.github.com/
   - Request cache purge for exposed secrets
   - Reference the commit SHAs that contained secrets

2. Alternatively, you can:
   - Make the repository private temporarily
   - Wait 24-48 hours for caches to expire
   - Make it public again (if needed)

---

## 🔧 How to Build/Run Going Forward

### Development
```bash
# Run the app with keys loaded from .env
./run_with_keys.sh
```

### Building for Production
```bash
# Build with keys loaded from .env
./build_with_keys.sh build ios
./build_with_keys.sh build android
```

### CI/CD Integration

For GitHub Actions or other CI systems, add these as encrypted secrets:
```yaml
env:
  REVENUECAT_TEST_API_KEY: ${{ secrets.REVENUECAT_TEST_API_KEY }}
  REVENUECAT_IOS_API_KEY: ${{ secrets.REVENUECAT_IOS_API_KEY }}
  REVENUECAT_ANDROID_API_KEY: ${{ secrets.REVENUECAT_ANDROID_API_KEY }}
```

Then build with:
```bash
flutter build ios \
  --dart-define=REVENUECAT_TEST_API_KEY="$REVENUECAT_TEST_API_KEY" \
  --dart-define=REVENUECAT_IOS_API_KEY="$REVENUECAT_IOS_API_KEY" \
  --dart-define=REVENUECAT_ANDROID_API_KEY="$REVENUECAT_ANDROID_API_KEY"
```

---

## 📋 Verification Checklist

- [ ] Revoked/rotated all exposed API keys in RevenueCat dashboard
- [ ] Generated new API keys
- [ ] Added new keys to `.env` file (not committed)
- [ ] Verified `.env` is in `.gitignore`
- [ ] Ran scrub_secrets.sh to clean git history
- [ ] Force pushed cleaned history to GitHub
- [ ] Contacted GitHub support to purge cache
- [ ] Reviewed RevenueCat audit logs for suspicious activity
- [ ] Notified team members to re-clone repository
- [ ] Updated CI/CD pipelines with new keys (as secrets)
- [ ] Tested app builds successfully with new keys
- [ ] Documented this incident for future reference

---

## 🛡️ Prevention Measures

**Already implemented:**
- ✅ API keys now loaded from environment variables
- ✅ `.env` file added to `.gitignore`
- ✅ Helper scripts created for secure builds
- ✅ Documentation updated

**Recommended additional measures:**
- [ ] Enable git pre-commit hooks to scan for secrets
- [ ] Use tools like `git-secrets` or `detect-secrets`
- [ ] Set up GitHub secret scanning alerts
- [ ] Regular security audits of committed code
- [ ] Team training on secure credential management

---

## 📞 Support Resources

- **RevenueCat Support:** https://www.revenuecat.com/support
- **GitHub Support:** https://support.github.com/
- **Git-filter-repo:** https://github.com/newren/git-filter-repo

---

## Timeline

**2026-01-09 (Today):**
- [x] Detected exposed API keys
- [x] Removed hardcoded keys from source code
- [x] Set up environment variable system
- [x] Updated .gitignore
- [x] Created remediation scripts and documentation
- [ ] **PENDING: Revoke old keys in RevenueCat** ← DO THIS NOW
- [ ] **PENDING: Run git history scrubbing** ← DO THIS AFTER TESTING
- [ ] **PENDING: Force push cleaned history** ← DO THIS AFTER SCRUBBING

---

## Questions?

If you need help with any of these steps, especially the git history rewriting, ask for clarification before proceeding. The git history scrubbing is irreversible and requires careful coordination.

**The most critical step is revoking the old keys in RevenueCat - do this immediately!**
