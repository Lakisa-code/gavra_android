#!/usr/bin/env python3
"""
Upload screenshots to iOS App Store via App Store Connect API
"""
import os
import json
import requests
from pathlib import Path
from datetime import datetime
import time

SCREENSHOTS_DIR = Path(r"C:\Users\Bojan\gavra_android\store-assets\latest-screenshots")
APP_ID = "1590131706"  # App ID from appstore-mcp/.env
BUNDLE_ID = "com.gavra013.gavra013ios"

# Credentials from appstore-mcp/.env
ISSUER_ID = "d8b50e72-6330-401d-9aaf-4ead356495cb"
KEY_ID = "Q95YKW2L9S"
PRIVATE_KEY_PATH = Path(r"C:/Users/Bojan/gavra_android/AI BACKUP/secrets/appstore/private_key.p8")

BASE_URL = "https://api.appstoreconnect.apple.com/v1"

screenshots = [
    "Screenshot_20260127_050102_com.gbox.android.jp.jpg",
    "Screenshot_20260127_050113_com.gbox.android.jp.jpg",
    "Screenshot_20260127_050120_com.gbox.android.jp.jpg",
    "Screenshot_20260127_050132_com.gbox.android.jp.jpg",
]

def generate_jwt_token():
    """Generate JWT token for App Store Connect API"""
    try:
        import jwt
    except ImportError:
        print("❌ PyJWT not installed. Installing...")
        os.system("pip install PyJWT")
        import jwt
    
    print("🔐 Generating JWT token for App Store Connect...")
    
    try:
        # Read private key
        with open(PRIVATE_KEY_PATH, 'r') as f:
            private_key = f.read()
        
        # Generate JWT
        payload = {
            'iss': ISSUER_ID,
            'aud': 'appstoreconnect-v1',
            'sub': ISSUER_ID,
            'exp': int(time.time()) + 1200,  # 20 minutes
            'iat': int(time.time())
        }
        
        token = jwt.encode(payload, private_key, algorithm='ES256', headers={'kid': KEY_ID})
        print(f"✓ JWT token generated")
        return token
        
    except Exception as e:
        print(f"✗ Error generating JWT: {e}")
        return None

def get_app_versions(token):
    """Get all app versions"""
    print("📦 Fetching app versions...")
    
    try:
        headers = {'Authorization': f'Bearer {token}'}
        
        response = requests.get(
            f"{BASE_URL}/apps/{APP_ID}/appStoreVersions",
            headers=headers,
            timeout=10
        )
        
        if response.status_code != 200:
            print(f"✗ Failed to get versions: {response.status_code}")
            print(f"  Response: {response.text[:300]}")
            return None
        
        data = response.json()
        versions = data.get('data', [])
        print(f"✓ Found {len(versions)} version(s)")
        
        if versions:
            for v in versions:
                print(f"  - {v.get('attributes', {}).get('versionString')} ({v['id']})")
        
        return versions
        
    except Exception as e:
        print(f"✗ Error fetching versions: {e}")
        return None

def get_app_store_version_screenshots(token, version_id):
    """Get screenshot set for specific app version"""
    print(f"📸 Fetching screenshots for version {version_id}...")
    
    try:
        headers = {'Authorization': f'Bearer {token}'}
        
        response = requests.get(
            f"{BASE_URL}/appStoreVersions/{version_id}/appStoreVersionLocalizationsV2",
            headers=headers,
            timeout=10
        )
        
        if response.status_code != 200:
            print(f"✗ Failed: {response.status_code}")
            return None
        
        data = response.json()
        localizations = data.get('data', [])
        print(f"✓ Found {len(localizations)} localization(s)")
        
        # Get English localization
        for loc in localizations:
            attrs = loc.get('attributes', {})
            if attrs.get('locale') == 'en-US':
                print(f"✓ Using en-US localization")
                return loc.get('id')
        
        return None
        
    except Exception as e:
        print(f"✗ Error: {e}")
        return None

def main():
    print("\n" + "=" * 60)
    print("🍎 iOS APP STORE - SCREENSHOT UPLOAD")
    print("=" * 60 + "\n")
    
    # Check screenshots
    print("📂 Checking screenshots...")
    all_exist = True
    for screenshot in screenshots:
        path = SCREENSHOTS_DIR / screenshot
        if path.exists():
            size = path.stat().st_size / (1024 * 1024)
            print(f"  ✓ {screenshot} ({size:.2f} MB)")
        else:
            print(f"  ✗ {screenshot} - NOT FOUND")
            all_exist = False
    
    if not all_exist:
        print("\n✗ Some files missing!")
        return 1
    
    # Generate JWT
    token = generate_jwt_token()
    if not token:
        return 1
    
    print(f"✓ Token: {token[:50]}...\n")
    
    # Get versions
    versions = get_app_versions(token)
    if not versions:
        return 1
    
    print()
    
    # Get first version's screenshots
    if versions:
        version_id = versions[0]['id']
        localization_id = get_app_store_version_screenshots(token, version_id)
        if localization_id:
            print(f"\n✓ Localization ID: {localization_id}")
    
    print("\n" + "=" * 60)
    print("✅ iOS API check completed")
    print("=" * 60)
    
    return 0

if __name__ == "__main__":
    exit(main())
