#!/usr/bin/env python3
"""
Promote Google Play build from Alpha to Production
Since 14-day test period expired, we can now promote to production
"""

import os
import json
from pathlib import Path
from google.oauth2 import service_account
from googleapiclient.discovery import build

def promote_to_production():
    """Promote current alpha build to production"""
    
    print("\n" + "="*60)
    print("🚀 GOOGLE PLAY: PROMOTING TO PRODUCTION")
    print("="*60)
    
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
        
        # Get current edits
        edits_response = service.edits().list(packageName=package_name).execute()
        edits = edits_response.get('edits', [])
        
        if not edits:
            print("❌ No edits found")
            return False
        
        # Use most recent edit
        edit_id = edits[0]['id']
        print(f"📝 Using edit: {edit_id}")
        
        # Get current alpha track
        tracks_response = service.edits().tracks().list(
            packageName=package_name,
            editId=edit_id
        ).execute()
        
        alpha_release = None
        for track in tracks_response.get('tracks', []):
            if track['track'] == 'alpha':
                releases = track.get('releases', [])
                if releases:
                    alpha_release = releases[0]
                    print(f"\n📊 Current Alpha Release:")
                    print(f"   Status: {alpha_release.get('status')}")
                    print(f"   Version: {alpha_release.get('name')}")
                    print(f"   Release Notes: {alpha_release.get('releaseNotes', {}).get('en-US', 'N/A')}")
                    break
        
        if not alpha_release:
            print("❌ No alpha release found")
            return False
        
        # Prepare production release with same build
        print("\n🎯 Promoting to Production...")
        
        release_notes = [{
            'language': 'en-US',
            'text': 'Version 6.0.50 - Production Release\n\n• All platforms now synchronized\n• Improved stability and performance\n• Updated screenshots and features'
        }]
        
        # Update production track with same build
        update_body = {
            'track': 'production',
            'releases': [{
                'versionCodes': alpha_release.get('versionCodes', []),
                'status': 'completed',  # 'completed' = immediate release
                'releaseNotes': release_notes,
                'name': alpha_release.get('name', '6.0.50+420')
            }]
        }
        
        update_response = service.edits().tracks().update(
            packageName=package_name,
            editId=edit_id,
            track='production',
            body=update_body
        ).execute()
        
        print(f"✅ Production track updated")
        print(f"   Status: {update_response['releases'][0].get('status')}")
        
        # Commit the changes
        print("\n📤 Committing changes...")
        commit_response = service.edits().commit(
            packageName=package_name,
            editId=edit_id
        ).execute()
        
        print(f"✅ PROMOTED TO PRODUCTION!")
        print(f"   Edit committed: {commit_response.get('id')}")
        print(f"\n📌 The app is now live on Google Play Store!")
        
        return True
        
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        import traceback
        traceback.print_exc()
        return False

if __name__ == "__main__":
    promote_to_production()
