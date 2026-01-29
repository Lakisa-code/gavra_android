#!/usr/bin/env python3
"""
Check Huawei AppGallery submission status and rejection details
"""
import os
import json
import requests
from datetime import datetime

HUAWEI_APP_ID = "116046535"
HUAWEI_CLIENT_ID = "1850740994484473152"
HUAWEI_CLIENT_SECRET = "F4CC48ADE493A712D729DDF8B7A11542591BDBC52AD2999E950CC7BED1DEDC98"

BASE_URL = "https://connect-api.cloud.huawei.com"
AUTH_URL = f"{BASE_URL}/api/oauth2/v1/token"
APP_API = f"{BASE_URL}/api/publish/v2/app-info"

def get_access_token():
    """Get OAuth2 access token"""
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
        response.raise_for_status()
        data = response.json()
        return data.get('access_token')
    except Exception as e:
        print(f"❌ Error getting token: {e}")
        return None

def get_app_status(token):
    """Get detailed app status"""
    try:
        headers = {
            'Authorization': f'Bearer {token}',
            'client_id': HUAWEI_CLIENT_ID,
        }
        
        response = requests.get(
            f"{APP_API}?appId={HUAWEI_APP_ID}",
            headers=headers,
            timeout=10
        )
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"❌ Error getting status: {e}")
        return None

def parse_release_state(state_code):
    """Parse release state code"""
    states = {
        0: "Draft",
        1: "Submitted",
        2: "Under Review",
        3: "Approved",
        4: "Released",
        5: "Rejected",
        6: "On Shelves",
        7: "Off Shelves",
    }
    return states.get(state_code, f"Unknown ({state_code})")

def main():
    print("\n" + "=" * 70)
    print("🟠 HUAWEI APPGALLERY - SUBMISSION STATUS CHECK")
    print("=" * 70)
    print(f"App ID: {HUAWEI_APP_ID}")
    print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("-" * 70)
    
    # Get token
    print("\n📝 Authenticating with Huawei API...")
    token = get_access_token()
    
    if not token:
        print("❌ Failed to authenticate")
        return
    
    print("✅ Authentication successful")
    
    # Get status
    print("\n📊 Fetching app status...")
    status_data = get_app_status(token)
    
    if not status_data:
        print("❌ Failed to get app status")
        return
    
    print("✅ Status retrieved")
    
    # Parse response
    print("\n" + "-" * 70)
    print("📋 APP STATUS DETAILS:")
    print("-" * 70)
    
    if 'data' in status_data:
        data = status_data['data']
        
        print(f"\nVersion Number:     {data.get('versionNumber', 'N/A')}")
        print(f"Version Code:       {data.get('versionCode', 'N/A')}")
        release_state = data.get('releaseState', -1)
        print(f"Release State:      {parse_release_state(release_state)}")
        
        if 'onShelfVersionNumber' in data:
            print(f"\nLive Version:       {data.get('onShelfVersionNumber', 'N/A')}")
            print(f"Live Version Code:  {data.get('onShelfVersionCode', 'N/A')}")
        
        print(f"\nUpdate Time:        {data.get('updateTime', 'N/A')}")
        print(f"Default Language:   {data.get('defaultLang', 'N/A')}")
        print(f"Published Country:  {data.get('publishCountry', 'N/A')}")
        
        # Check for rejection reasons
        if 'rejectInfo' in data:
            print(f"\n⚠️  REJECTION INFO:")
            reject_info = data.get('rejectInfo')
            print(f"   {json.dumps(reject_info, indent=2, ensure_ascii=False)}")
        
        if 'reviewResult' in data:
            print(f"\n📝 REVIEW RESULT:")
            review = data.get('reviewResult')
            print(f"   {json.dumps(review, indent=2, ensure_ascii=False)}")
        
    elif 'message' in status_data:
        print(f"API Message: {status_data['message']}")
    
    # Raw response for debugging
    print("\n" + "-" * 70)
    print("📄 RAW RESPONSE:")
    print("-" * 70)
    print(json.dumps(status_data, indent=2, ensure_ascii=False))
    
    print("\n" + "=" * 70)

if __name__ == "__main__":
    main()
