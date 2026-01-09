#!/bin/bash
# Script to scrub exposed API keys from git history using git-filter-repo
# This will rewrite git history to remove sensitive data

set -e

echo "==============================================="
echo "GIT HISTORY SCRUBBING SCRIPT"
echo "==============================================="
echo ""
echo "WARNING: This will rewrite git history!"
echo "This is necessary to remove exposed secrets from all commits."
echo ""
echo "Before running this script:"
echo "1. Make sure all team members have pushed their changes"
echo "2. Notify team members that they'll need to re-clone the repo"
echo "3. Make a backup of your repo just in case"
echo ""
echo "This script requires git-filter-repo to be installed."
echo "Install with: pip3 install git-filter-repo"
echo ""
read -p "Do you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 0
fi

# Check if git-filter-repo is installed
if ! command -v git-filter-repo &> /dev/null; then
    echo "Error: git-filter-repo is not installed"
    echo "Install it with: pip3 install git-filter-repo"
    exit 1
fi

# Create expressions file for git-filter-repo
cat > /tmp/expressions.txt << 'EOF'
***REMOVED***
REDACTED_TEST_KEY==>REDACTED_TEST_KEY
REDACTED_IOS_KEY==>REDACTED_IOS_KEY
REDACTED_ANDROID_KEY==>REDACTED_ANDROID_KEY
EOF

echo ""
echo "Scrubbing secrets from git history..."
echo ""

# Run git-filter-repo to replace the secrets
git-filter-repo --replace-text /tmp/expressions.txt --force

# Clean up
rm /tmp/expressions.txt

echo ""
echo "==============================================="
echo "SUCCESS: Secrets scrubbed from git history"
echo "==============================================="
echo ""
echo "NEXT STEPS:"
echo "1. Review the changes with: git log --all --oneline"
echo "2. Force push to remote: git push origin --force --all"
echo "3. Force push tags: git push origin --force --tags"
echo "4. Notify all team members to re-clone the repository"
echo ""
echo "IMPORTANT: You must still revoke the old keys in RevenueCat"
echo "and generate new ones!"
echo ""
