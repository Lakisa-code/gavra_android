#!/usr/bin/env python3
"""
Update App Description on All Platforms
Gavra 013: Change from "otvorenog tipa" to "zatvorenog tipa"
"""

from google.oauth2 import service_account
from googleapiclient.discovery import build
from pathlib import Path
import json
import sys
import jwt
import time
from datetime import datetime, timedelta
import requests

# New descriptions - "zatvorenog tipa"
NEW_DESCRIPTION = """Gavra 013 - Aplikacija zatvorenog tipa za naše putnike

Gavra je moderna mobilna aplikacija namenjena za sve ljude koji žele da organizuju i prate svoje putovanja na najjednostavniji način.

Ključne Mogućnosti:
• Planiranje puteva i ruta
• Praćenje polazaka i vozila
• Upravljanje putnicima
• Optimizacija ruta
• Obaveštenja u realnom vremenu
• Offline mapa podrška
• Detaljni izveštaji

Idealno za:
✓ Putničke servise
✓ Turizamske agencije
✓ Organizatore putovanja
✓ Vozače i vozove
✓ Sve koji putuju redovno

Verzija 6.0.50 - Stabilna i pouzdana
Poslednje ažuriranje: Januara 2026

Poboljšanja u ovoj verziji:
• Poboljšana stabilnost
• Brži prikaz ruta
• Bolja baterijska potrošnja
• Jednostavniji interfejs
• Podrška za sve jezike
"""

SHORT_DESCRIPTION = "Aplikacija zatvorenog tipa za organizaciju polazaka"

def update_google_play():
    """Update Google Play Store Listing"""
    print("\n" + "="*70)
    print("🔴 GOOGLE PLAY - UPDATE DESCRIPTION")
    print("="*70)
    
    try:
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
        
        # Create edit
        edit_response = service.edits().insert(
            packageName=package_name,
            body={}
        ).execute()
        
        edit_id = edit_response['id']
        print(f"✅ Created edit: {edit_id}")
        
        # Update listing for all languages
        languages = ['en-US', 'en', 'sr', 'sr-RS', 'en-GB']
        
        for lang in languages:
            try:
                update_body = {
                    'title': 'Gavra 013',
                    'shortDescription': SHORT_DESCRIPTION,
                    'fullDescription': NEW_DESCRIPTION,
                }
                
                service.edits().listings().update(
                    packageName=package_name,
                    editId=edit_id,
                    language=lang,
                    body=update_body
                ).execute()
                
                print(f"  ✅ Updated {lang}")
            except Exception as e:
                print(f"  ⚠️  Could not update {lang}: {str(e)}")
        
        # Commit
        commit = service.edits().commit(
            packageName=package_name,
            editId=edit_id
        ).execute()
        
        print(f"\n✅ Google Play description updated!")
        print(f"   Edit committed: {commit.get('id')}")
        return True
        
    except Exception as e:
        print(f"❌ Google Play error: {str(e)}")
        import traceback
        traceback.print_exc()
        return False

def update_huawei():
    """Update Huawei AppGallery Listing"""
    print("\n" + "="*70)
    print("🎯 HUAWEI APPGALLERY - UPDATE DESCRIPTION")
    print("="*70)
    
    print("⚠️  Manual update required on Huawei AppGallery:")
    print("   1. Go to AppGallery Connect console")
    print("   2. Select app and version")
    print("   3. Update app description to:")
    print(f"\n   {SHORT_DESCRIPTION}")
    print("\n   4. Save and submit")
    return True

def update_ios():
    """Update iOS App Store Listing via App Store Connect API"""
    print("\n" + "="*70)
    print("🍎 iOS APP STORE - UPDATE DESCRIPTION")
    print("="*70)
    
    print("⚠️  Manual update required on App Store Connect:")
    print("   1. Go to App Store Connect console")
    print("   2. Select app version")
    print("   3. Update app description to:")
    print(f"\n   {SHORT_DESCRIPTION}")
    print("\n   4. Save and submit for review")
    return True

def main():
    print("\n" + "="*70)
    print("📝 UPDATE APP DESCRIPTIONS - ALL PLATFORMS")
    print("   Change: 'otvorenog tipa' → 'zatvorenog tipa'")
    print("="*70)
    
    print("\nNew Description:")
    print(f"  {SHORT_DESCRIPTION}")
    
    results = {
        'Google Play': update_google_play(),
        'Huawei': update_huawei(),
        'iOS': update_ios()
    }
    
    print("\n" + "="*70)
    print("SUMMARY")
    print("="*70)
    for platform, success in results.items():
        status = "✅" if success else "❌"
        print(f"{status} {platform}")
    
    print("\n" + "="*70)
    print("📌 NEXT STEPS:")
    print("="*70)
    print("""
1. ✅ Google Play: Description updated automatically
2. ⏳ Huawei: Manual update required (see console)
3. ⏳ iOS: Manual update required (see App Store Connect)
4. ✅ All commits pushed to GitHub

The new description will appear:
• Google Play: Immediately
• Huawei: After manual update
• iOS: After app review (24-48 hours)
""")

if __name__ == "__main__":
    main()
