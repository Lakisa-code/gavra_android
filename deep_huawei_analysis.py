#!/usr/bin/env python3
"""
Deep dive into Huawei rejection reasons using all available APIs
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
        return response.json().get('access_token')
    except Exception as e:
        print(f"❌ Error getting token: {e}")
        return None

def api_call(token, endpoint, params=None):
    """Make API call to Huawei"""
    try:
        headers = {
            'Authorization': f'Bearer {token}',
            'client_id': HUAWEI_CLIENT_ID,
        }
        
        url = f"{BASE_URL}{endpoint}"
        response = requests.get(url, headers=headers, params=params, timeout=10)
        response.raise_for_status()
        return response.json()
    except Exception as e:
        print(f"❌ Error calling {endpoint}: {e}")
        return None

def main():
    print("\n" + "=" * 80)
    print("🟠 HUAWEI APPGALLERY - DEEP REJECTION ANALYSIS")
    print("=" * 80)
    print(f"App ID: {HUAWEI_APP_ID}")
    print(f"Timestamp: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("-" * 80)
    
    token = get_access_token()
    if not token:
        print("❌ Failed to authenticate")
        return
    
    print("✅ Authenticated")
    
    # Try different API endpoints to get rejection info
    endpoints_to_try = [
        ("/api/publish/v2/app-info", f"?appId={HUAWEI_APP_ID}"),
        ("/api/publish/v2/audit-result", f"?appId={HUAWEI_APP_ID}"),
        ("/api/publish/v2/version-info", f"?appId={HUAWEI_APP_ID}"),
        ("/api/publish/v2/release-info", f"?appId={HUAWEI_APP_ID}"),
        ("/api/publish/v2/app-audit-info", f"?appId={HUAWEI_APP_ID}"),
        ("/api/publish/v2/app/audit", f"?appId={HUAWEI_APP_ID}"),
    ]
    
    print("\n🔍 Trying different API endpoints...\n")
    
    for endpoint, params_str in endpoints_to_try:
        print(f"📍 Endpoint: {endpoint}{params_str}")
        result = api_call(token, endpoint, {"appId": HUAWEI_APP_ID})
        
        if result:
            if 'ret' in result and result['ret'].get('code') == 0:
                print("   ✅ Success - Full response:")
                print(f"   {json.dumps(result, indent=4, ensure_ascii=False)}\n")
            else:
                print(f"   ⚠️  Response: {json.dumps(result, indent=4)}\n")
        else:
            print("   ❌ Failed\n")
    
    print("\n" + "=" * 80)
    print("📝 CHECKING VERSION HISTORY...")
    print("=" * 80)
    
    # Try to get version history
    version_endpoints = [
        ("/api/publish/v2/app-version-info", f"?appId={HUAWEI_APP_ID}"),
        ("/api/publish/v2/version-history", f"?appId={HUAWEI_APP_ID}"),
    ]
    
    for endpoint, params_str in version_endpoints:
        print(f"\n📍 {endpoint}{params_str}")
        result = api_call(token, endpoint, {"appId": HUAWEI_APP_ID})
        if result:
            print(f"   {json.dumps(result, indent=4, ensure_ascii=False)}\n")

if __name__ == "__main__":
    main()
