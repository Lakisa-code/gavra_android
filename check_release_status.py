#!/usr/bin/env python3
"""
Check release status across all platforms and prepare for production
"""

import json
import subprocess
import sys
from pathlib import Path

def run_mcp_command(mcp_type, query):
    """Execute MCP commands via npx"""
    try:
        if mcp_type == "google":
            # Check Google Play status
            result = subprocess.run(
                ["npx", "mcp", "client", "google-play", query],
                cwd="c:/Users/Bojan/gavra_android",
                capture_output=True,
                text=True,
                timeout=30
            )
        elif mcp_type == "ios":
            # Check iOS/App Store status
            result = subprocess.run(
                ["npx", "mcp", "client", "appstore", query],
                cwd="c:/Users/Bojan/gavra_android",
                capture_output=True,
                text=True,
                timeout=30
            )
        else:
            return None
            
        return result.stdout if result.returncode == 0 else result.stderr
    except Exception as e:
        return f"Error: {str(e)}"

def check_google_play():
    """Check Google Play status"""
    print("\n" + "="*60)
    print("🔍 GOOGLE PLAY STATUS CHECK")
    print("="*60)
    
    try:
        # Using Python to call Google Play API directly
        from google.oauth2 import service_account
        from googleapiclient.discovery import build
        
        # Load service account
        key_file = "c:/Users/Bojan/gavra_android/AI BACKUP/secrets/google/play-store-key.json"
        credentials = service_account.Credentials.from_service_account_file(
            key_file,
            scopes=['https://www.googleapis.com/auth/androidpublisher']
        )
        
        service = build('androidpublisher', 'v3', credentials=credentials)
        package_name = "com.gavra013.gavra_android"
        
        # Get all releases
        try:
            response = service.edits().list(packageName=package_name).execute()
            edits = response.get('edits', [])
            print(f"✅ Connected to Google Play")
            print(f"📦 Package: {package_name}")
            print(f"📝 Active edits: {len(edits)}")
            
            # Get tracks info
            for edit in edits[:3]:  # Check first 3 edits
                edit_id = edit['id']
                tracks_response = service.edits().tracks().list(
                    packageName=package_name,
                    editId=edit_id
                ).execute()
                
                print(f"\n📊 Edit {edit_id}:")
                for track in tracks_response.get('tracks', []):
                    track_name = track['track']
                    releases = track.get('releases', [])
                    print(f"   Track '{track_name}':")
                    for release in releases:
                        status = release.get('status', 'UNKNOWN')
                        version = release.get('name', 'N/A')
                        print(f"     - Status: {status}")
                        print(f"     - Version: {version}")
                
        except Exception as e:
            print(f"⚠️  Could not fetch edit details: {str(e)}")
            
    except Exception as e:
        print(f"❌ Error connecting to Google Play: {str(e)}")
        print("   Ensure: play-store-key.json exists at:")
        print("   c:/Users/Bojan/gavra_android/AI BACKUP/secrets/google/play-store-key.json")

def check_huawei():
    """Check Huawei status"""
    print("\n" + "="*60)
    print("🔍 HUAWEI APPGALLERY STATUS CHECK")
    print("="*60)
    print("⏳ Huawei status check requires OAuth2 token refresh")
    print("   Current status: Screenshots uploaded (6.0.46+414)")
    print("   Next: Build upload with 6.0.50+420")

def check_ios():
    """Check iOS/App Store status"""
    print("\n" + "="*60)
    print("🔍 iOS APP STORE STATUS CHECK")
    print("="*60)
    print("⏳ iOS status check requires valid JWT token")
    print("   Current status: Credentials configured")
    print("   Next: Build upload and TestFlight submission")

def main():
    print("\n🚀 APP RELEASE STATUS CHECK - 2026-01-27")
    print("="*60)
    
    check_google_play()
    check_huawei()
    check_ios()
    
    print("\n" + "="*60)
    print("📋 PRODUCTION RELEASE PLAN")
    print("="*60)
    print("""
✅ COMPLETED:
  - Version 6.0.50+420 configured in pubspec.yaml
  - Screenshots uploaded to Google Play & Huawei
  - All credentials configured

⏳ TODO FOR PRODUCTION:
  1. Build Release APK/AAB (flutter build apk/appbundle --release)
  2. Build Release IPA (flutter build ios --release)
  
  3. GOOGLE PLAY:
     - Upload APK/AAB with version 6.0.50+420
     - Move from Alpha to Production track
     - Submit for review (if needed)
  
  4. iOS APP STORE:
     - Upload IPA with version 6.0.50+420
     - Create new version in App Store Connect
     - Submit for review
     - Wait for approval (~24-48 hours)
  
  5. HUAWEI APPGALLERY:
     - Upload APK with version 6.0.50+420
     - Create new version (6.0.50)
     - Submit for review
     - Wait for approval

⚠️  14-DAY TEST PERIOD EXPIRED ON GOOGLE PLAY
    - If Alpha track was internal testing, can now promote to Production
    - Or can create new Production version with 6.0.50+420
    """)

if __name__ == "__main__":
    main()
