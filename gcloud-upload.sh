#!/bin/bash

# Google Cloud Android Publisher Upload Script
echo "🚀 Google Cloud Android Publisher Upload"
echo "========================================"

# Project info
PROJECT_ID="gavra-notif-20250920162521"
PACKAGE_NAME="com.gavra013.gavra_android"
AAB_FILE="build/app/outputs/bundle/release/app-release.aab"

echo "📱 Package: $PACKAGE_NAME"
echo "📦 AAB File: $AAB_FILE"
echo "🌍 Project: $PROJECT_ID"

# Set project
gcloud config set project $PROJECT_ID

# Check if API is enabled
echo "🔧 Checking Google Play Developer API..."
gcloud services list --enabled --filter="name:androidpublisher.googleapis.com" --format="value(name)"

if [ $? -eq 0 ]; then
    echo "✅ Google Play Developer API is enabled"
else
    echo "❌ Enabling Google Play Developer API..."
    gcloud services enable androidpublisher.googleapis.com
fi

echo ""
echo "📋 NEXT STEPS:"
echo "1. Upload AAB manually to Play Console"
echo "2. Or use specialized tools like fastlane"
echo "3. gcloud doesn't have direct Play Store upload commands"
echo ""
echo "🔗 Manual Upload URL:"
echo "https://play.google.com/console/u/0/developers/6672411763752552043/app/4973349502068577873/tracks/4700674859540927683/releases/1/prepare"