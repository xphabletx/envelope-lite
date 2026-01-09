#!/bin/bash
# Run script that loads API keys from .env file
# Usage: ./run_with_keys.sh

set -e

# Check if .env file exists
if [ ! -f .env ]; then
    echo "Error: .env file not found!"
    echo "Copy .env.example to .env and add your API keys"
    exit 1
fi

# Load environment variables from .env
export $(cat .env | grep -v '^#' | xargs)

# Check if keys are set
if [ -z "$REVENUECAT_TEST_API_KEY" ] || [ -z "$REVENUECAT_IOS_API_KEY" ] || [ -z "$REVENUECAT_ANDROID_API_KEY" ]; then
    echo "Error: One or more API keys are missing in .env file"
    echo "Please set all required keys:"
    echo "  - REVENUECAT_TEST_API_KEY"
    echo "  - REVENUECAT_IOS_API_KEY"
    echo "  - REVENUECAT_ANDROID_API_KEY"
    exit 1
fi

# Run with dart-define flags
flutter run \
    --dart-define=REVENUECAT_TEST_API_KEY="$REVENUECAT_TEST_API_KEY" \
    --dart-define=REVENUECAT_IOS_API_KEY="$REVENUECAT_IOS_API_KEY" \
    --dart-define=REVENUECAT_ANDROID_API_KEY="$REVENUECAT_ANDROID_API_KEY"
