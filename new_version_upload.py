#!/usr/bin/env python3
"""
Upload new version 6.0.50+420 to all platforms
"""

import os
import json
from pathlib import Path
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

def upload_to_google_play():
    """Upload new version to Google Play"""
    
    print("\n" + "="*70)
    print("🚀 GOOGLE PLAY: CREATE NEW VERSION 6.0.50+420")
    print("="*70)
    
    try:
        # Load credentials
        key_file = "c:/Users/Bojan/gavra_android/AI BACKUP/secrets/google/play-store-key.json"
        if not Path(key_file).exists():
            print(f"❌ Key file not found: {key_file}")
            return False
            
        credentials = service_account.Credentials.from_service_account_file(
            key_file,
            scopes=['https://www.googleapis.com/auth/androidpublisher']
        )
        
        service = build('androidpublisher', 'v3', credentials=credentials)
        package_name = "com.gavra013.gavra_android"
        
        print(f"✅ Connected to Google Play")
        print(f"📦 Package: {package_name}")
        
        # Create new edit
        edit_response = service.edits().insert(
            packageName=package_name,
            body={}
        ).execute()
        
        edit_id = edit_response['id']
        print(f"📝 Created new edit: {edit_id}")
        
        # Now we need to upload APK/AAB
        # For production, we should use AAB (App Bundle)
        print("\n📋 NOTE: You need to upload APK/AAB file first!")
        print("   Run: flutter build appbundle --release")
        print("   Then this script can upload it")
        
        print(f"\n✅ Edit created successfully: {edit_id}")
        print("   Next step: Upload APK/AAB file")
        
        return edit_id
        
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        import traceback
        traceback.print_exc()
        return False

def check_builds():
    """Check if builds exist"""
    print("\n" + "="*70)
    print("🔍 CHECKING FOR RELEASE BUILDS")
    print("="*70)
    
    build_paths = {
        'APK': 'build/app/outputs/flutter-apk/app-release.apk',
        'AAB': 'build/app/outputs/bundle/release/app-release.aab',
        'IPA': 'build/ios/ipa/gavra_android.ipa'
    }
    
    for build_type, path in build_paths.items():
        full_path = f"c:/Users/Bojan/gavra_android/{path}"
        exists = Path(full_path).exists()
        status = "✅ FOUND" if exists else "❌ NOT FOUND"
        print(f"{build_type:6} {status}: {path}")
    
    missing = [k for k, p in build_paths.items() if not Path(f"c:/Users/Bojan/gavra_android/{p}").exists()]
    
    if missing:
        print(f"\n⚠️  Missing builds: {', '.join(missing)}")
        print("\n📋 BUILD COMMANDS NEEDED:")
        print("   1. Flutter Clean:")
        print("      flutter clean")
        print("\n   2. Android APK:")
        print("      flutter build apk --release")
        print("\n   3. Android App Bundle (for Play Store):")
        print("      flutter build appbundle --release")
        print("\n   4. iOS IPA:")
        print("      flutter build ios --release")
        return False
    else:
        print("\n✅ All builds are ready!")
        return True

def main():
    print("\n" + "="*70)
    print("📦 NEW VERSION 6.0.50+420 - PRODUCTION UPLOAD")
    print("="*70)
    
    # Check if builds exist
    if not check_builds():
        print("\n🔨 FIRST STEP: BUILD RELEASE BINARIES")
        print("   Use the commands shown above")
        return
    
    # If builds exist, proceed with upload
    print("\n✅ All builds ready - proceeding with upload...")
    upload_to_google_play()

if __name__ == "__main__":
    main()
