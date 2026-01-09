#!/bin/bash
# Verification script to ensure security measures are in place

echo "🔐 Security Verification Checklist"
echo "=================================="
echo ""

# Check 1: .env file exists
if [ -f .env ]; then
    echo "✅ .env file exists"
else
    echo "❌ .env file missing - copy from .env.example"
fi

# Check 2: .env is in .gitignore
if grep -q "^\.env$" .gitignore; then
    echo "✅ .env is in .gitignore"
else
    echo "❌ .env not in .gitignore"
fi

# Check 3: .env is not tracked by git
if git ls-files --error-unmatch .env 2>/dev/null; then
    echo "❌ WARNING: .env is tracked by git! Run: git rm --cached .env"
else
    echo "✅ .env is not tracked by git"
fi

# Check 4: No hardcoded keys in source
echo ""
echo "Checking for hardcoded API keys in source..."
if grep -r "REDACTED_TEST_KEY\|REDACTED_IOS_KEY\|REDACTED_ANDROID_KEY" lib/ docs/ --exclude-dir=.git 2>/dev/null; then
    echo "❌ WARNING: Old API keys still found in source code!"
else
    echo "✅ No hardcoded old API keys found in source"
fi

# Check 5: Keys are in .env
echo ""
echo "Checking if keys are set in .env..."
source .env 2>/dev/null
if [ -z "$REVENUECAT_TEST_API_KEY" ]; then
    echo "❌ REVENUECAT_TEST_API_KEY not set in .env"
else
    echo "✅ REVENUECAT_TEST_API_KEY is set"
fi

if [ -z "$REVENUECAT_IOS_API_KEY" ]; then
    echo "❌ REVENUECAT_IOS_API_KEY not set in .env"
else
    echo "✅ REVENUECAT_IOS_API_KEY is set"
fi

if [ -z "$REVENUECAT_ANDROID_API_KEY" ]; then
    echo "❌ REVENUECAT_ANDROID_API_KEY not set in .env"
else
    echo "✅ REVENUECAT_ANDROID_API_KEY is set"
fi

# Check 6: Helper scripts exist and are executable
echo ""
if [ -x "./run_with_keys.sh" ]; then
    echo "✅ run_with_keys.sh is executable"
else
    echo "❌ run_with_keys.sh missing or not executable"
fi

if [ -x "./build_with_keys.sh" ]; then
    echo "✅ build_with_keys.sh is executable"
else
    echo "❌ build_with_keys.sh missing or not executable"
fi

if [ -x "./scrub_secrets.sh" ]; then
    echo "✅ scrub_secrets.sh is executable"
else
    echo "❌ scrub_secrets.sh missing or not executable"
fi

echo ""
echo "=================================="
echo "Next steps:"
echo "1. If any checks failed, fix them before proceeding"
echo "2. See IMMEDIATE_ACTIONS.md for what to do next"
echo "3. Most importantly: REVOKE old keys in RevenueCat!"
echo ""
