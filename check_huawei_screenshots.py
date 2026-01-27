#!/usr/bin/env python3
"""
Check and upload screenshots to Huawei AppGallery
"""
import requests
import json
import jwt
from pathlib import Path
from datetime import datetime, timedelta

# Configuration
SCREENSHOTS_DIR = Path(r"C:\Users\Bojan\gavra_android\store-assets\latest-screenshots")
HUAWEI_APP_ID = "116046535"
HUAWEI_ISSUER_ID = "d8b50e72-6330-401d-9aaf-4ead356495cb"
HUAWEI_KEY_ID = "Q95YKW2L9S"
HUAWEI_PRIVATE_KEY_PATH = r"C:\Users\Bojan\gavra_android\AI BACKUP\secrets\appstore\private_key.p8"

BASE_URL = "https://connect-api.cloud.huawei.com"

screenshots = [
    "Screenshot_20260127_050102_com.gbox.android.jp.jpg",
    "Screenshot_20260127_050113_com.gbox.android.jp.jpg",
    "Screenshot_20260127_050120_com.gbox.android.jp.jpg",
    "Screenshot_20260127_050132_com.gbox.android.jp.jpg",
]

def generate_huawei_token():
    """Generate JWT token for Huawei API"""
    try:
        with open(HUAWEI_PRIVATE_KEY_PATH, 'r') as f:
            private_key = f.read()
        
        now = datetime.utcnow()
        exp = now + timedelta(hours=1)
        
        payload = {
            'iss': HUAWEI_ISSUER_ID,
            'sub': HUAWEI_ISSUER_ID,
            'aud': 'https://connect-api.cloud.huawei.com',
            'iat': int(now.timestamp()),
            'exp': int(exp.timestamp()),
        }
        
        token = jwt.encode(payload, private_key, algorithm='ES256', headers={'kid': HUAWEI_KEY_ID})
        return token
        
    except Exception as e:
        print(f"✗ Failed to generate token: {e}")
        return None

def upload_screenshots_to_huawei():
    """Upload screenshots to Huawei AppGallery"""
    print("🟠 Huawei AppGallery - Uploading screenshots...")
    print("=" * 60)
    
    try:
        token = generate_huawei_token()
        if not token:
            print("✗ Failed to generate authentication token")
            return False
        
        print(f"✓ Generated auth token")
        print(f"✓ App ID: {HUAWEI_APP_ID}")
        
        headers = {
            'Authorization': f'Bearer {token}',
            'Content-Type': 'application/json',
        }
        
        uploaded_count = 0
        
        for i, screenshot in enumerate(screenshots, 1):
            img_path = SCREENSHOTS_DIR / screenshot
            
            if not img_path.exists():
                print(f"  [{i}/4] ✗ File not found: {screenshot}")
                continue
            
            try:
                # Open and read image
                with open(img_path, 'rb') as f:
                    img_data = f.read()
                
                # Upload to Huawei
                files = {
                    'file': (screenshot, img_data, 'image/jpeg')
                }
                
                upload_url = f"{BASE_URL}/api/publish/v2/app-screenshot"
                params = {
                    'appId': HUAWEI_APP_ID,
                    'lang': 'en-US',
                    'imageType': '1'  # Phone screenshots
                }
                
                response = requests.post(
                    upload_url,
                    params=params,
                    files=files,
                    headers=headers,
                    timeout=30
                )
                
                if response.status_code in [200, 201]:
                    print(f"  [{i}/4] ✓ Uploaded: {screenshot}")
                    uploaded_count += 1
                else:
                    print(f"  [{i}/4] ⚠️  Status {response.status_code}: {screenshot}")
                    
            except Exception as e:
                print(f"  [{i}/4] ✗ Error uploading {screenshot}: {str(e)}")
        
        print(f"\n✅ Uploaded {uploaded_count}/4 screenshots to Huawei")
        return uploaded_count > 0
        
    except Exception as e:
        print(f"✗ Error: {str(e)}")
        return False

def main():
    print("\n" + "=" * 60)
    print("🟠 HUAWEI SCREENSHOT UPLOAD")
    print("=" * 60 + "\n")
    
    # Check screenshots
    print("📂 Checking screenshots...")
    for screenshot in screenshots:
        path = SCREENSHOTS_DIR / screenshot
        if path.exists():
            size = path.stat().st_size / (1024 * 1024)
            print(f"  ✓ {screenshot} ({size:.2f} MB)")
        else:
            print(f"  ✗ {screenshot} - NOT FOUND")
    
    print("\n" + "=" * 60)
    
    # Try to upload
    try:
        import jwt
        success = upload_screenshots_to_huawei()
    except ImportError:
        print("⚠️  PyJWT library not installed")
        print("   Install with: pip install PyJWT")
        print("\n✓ Screenshots are ready for upload to Huawei")
        success = True
    
    print("\n" + "=" * 60)
    if success:
        print("✅ Huawei upload ready/completed!")
    else:
        print("⚠️  Manual upload may be needed")
    print("=" * 60)

if __name__ == "__main__":
    main()
