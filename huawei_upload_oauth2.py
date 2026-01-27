#!/usr/bin/env python3
"""
Upload screenshots to Huawei AppGallery with correct OAuth2 credentials
"""
import os
import json
import requests
from pathlib import Path

# Configuration
SCREENSHOTS_DIR = Path(r"C:\Users\Bojan\gavra_android\store-assets\latest-screenshots")
HUAWEI_APP_ID = "116046535"
HUAWEI_CLIENT_ID = "1850740994484473152"
HUAWEI_CLIENT_SECRET = "F4CC48ADE493A712D729DDF8B7A11542591BDBC52AD2999E950CC7BED1DEDC98"

BASE_URL = "https://connect-api.cloud.huawei.com"
AUTH_URL = f"{BASE_URL}/api/oauth2/v1/token"
PUBLISH_API = f"{BASE_URL}/api/publish/v2"

screenshots = [
    "Screenshot_20260127_050102_com.gbox.android.jp.jpg",
    "Screenshot_20260127_050113_com.gbox.android.jp.jpg",
    "Screenshot_20260127_050120_com.gbox.android.jp.jpg",
    "Screenshot_20260127_050132_com.gbox.android.jp.jpg",
]

def get_access_token():
    """Get OAuth2 access token from Huawei"""
    print("🔐 Getting Huawei OAuth2 token...")
    
    try:
        response = requests.post(
            AUTH_URL,
            json={
                'client_id': HUAWEI_CLIENT_ID,
                'client_secret': HUAWEI_CLIENT_SECRET,
                'grant_type': 'client_credentials'
            },
            timeout=10
        )
        
        if response.status_code != 200:
            print(f"✗ Auth failed: {response.status_code}")
            print(f"  Response: {response.text}")
            return None
        
        data = response.json()
        token = data.get('access_token')
        print(f"✓ Got access token (expires in {data.get('expires_in')} seconds)")
        return token
        
    except Exception as e:
        print(f"✗ Error getting token: {e}")
        return None

def get_screenshot_upload_url(token, app_id, filename):
    """Get upload URL for screenshot - FIXED with fileName parameter"""
    try:
        headers = {
            'Authorization': f'Bearer {token}',
            'client_id': HUAWEI_CLIENT_ID,
        }
        
        # resourceType: 1=icon, 2=featureImage, 3=screenshot, 5=appPreview
        response = requests.get(
            f"{PUBLISH_API}/upload-url/for-obs",
            params={
                'appId': app_id,
                'suffix': 'jpg',
                'fileName': filename,  # THIS WAS MISSING!
                'resourceType': '3'  # Screenshots
            },
            headers=headers,
            timeout=10
        )
        
        if response.status_code != 200:
            print(f"  ✗ Failed to get upload URL: {response.status_code}")
            print(f"    Response: {response.text}")
            return None
        
        data = response.json()
        upload_url = data.get('uploadUrl')
        auth_code = data.get('authCode')
        file_id = data.get('fileId')
        
        if not upload_url:
            print(f"  ✗ No uploadUrl in response: {data}")
            return None
            'uploadUrl': upload_url,
            'authCode': auth_code,
            'fileId': file_id
        }
        
    except Exception as e:
        print(f"  ✗ Error getting upload URL: {e}")
        return None

def upload_screenshot_file(upload_info, file_path):
    """Upload screenshot file to Huawei OBS"""
    try:
        with open(file_path, 'rb') as f:
            file_data = f.read()
        
        # Upload to OBS
        files = {'file': ('screenshot.jpg', file_data, 'image/jpeg')}
        params = {
            'authCode': upload_info['authCode'],
            'fileId': upload_info['fileId']
        }
        
        response = requests.post(
            upload_info['uploadUrl'],
            files=files,
            params=params,
            timeout=30
        )
        
        if response.status_code in [200, 201, 204]:
            return True
        
        print(f"    Upload status: {response.status_code}")
        return False
        
    except Exception as e:
        print(f"    ✗ Error uploading file: {e}")
        return False

def upload_screenshots_to_huawei():
    """Main upload function"""
    print("🟠 Huawei AppGallery - Uploading screenshots...")
    print("=" * 60)
    
    # Get token
    token = get_access_token()
    if not token:
        return False
    
    print(f"✓ App ID: {HUAWEI_APP_ID}")
    print()
    
    uploaded_count = 0
    
    for i, screenshot in enumerate(screenshots, 1):
        img_path = SCREENSHOTS_DIR / screenshot
        
        if not img_path.exists():
            print(f"  [{i}/4] ✗ File not found: {screenshot}")
            continue
        
        print(f"  [{i}/4] Uploading: {screenshot}")
        
        # Get upload URL
        upload_info = get_screenshot_upload_url(token, HUAWEI_APP_ID, screenshot)
        if not upload_info:
            print(f"       ✗ Failed to get upload URL")
            continue
        
        # Upload file
        if upload_screenshot_file(upload_info, img_path):
            print(f"       ✓ Successfully uploaded!")
            uploaded_count += 1
        else:
            print(f"       ✗ Upload failed")
    
    print(f"\n✅ Uploaded {uploaded_count}/4 screenshots to Huawei")
    return uploaded_count > 0

def main():
    print("\n" + "=" * 60)
    print("🟠 HUAWEI SCREENSHOT UPLOAD - OAUTH2 (FIXED)")
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
    
    print("\n" + "=" * 60)
    print("Starting upload...")
    print("=" * 60 + "\n")
    
    success = upload_screenshots_to_huawei()
    
    print("\n" + "=" * 60)
    if success:
        print("✅ Huawei upload completed!")
    else:
        print("⚠️  Upload encountered issues")
    print("=" * 60)
    
    return 0 if success else 1

if __name__ == "__main__":
    exit(main())
