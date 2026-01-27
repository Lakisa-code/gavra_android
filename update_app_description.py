#!/usr/bin/env python3
"""
Update App Description on All Platforms
"""

from google.oauth2 import service_account
from googleapiclient.discovery import build
from pathlib import Path
import json

# Novi description
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
        
        print(f"✅ Connected to Google Play")
        
        # Create new edit
        edit_response = service.edits().insert(
            packageName=package_name,
            body={}
        ).execute()
        
        edit_id = edit_response['id']
        print(f"📝 Created edit: {edit_id}")
        
        # Update listing for en-US
        update_body = {
            'title': 'Gavra 013 - Putni Organizer',
            'shortDescription': SHORT_DESCRIPTION,
            'fullDescription': NEW_DESCRIPTION
        }
        
        listing_response = service.edits().listingsUpdate(
            packageName=package_name,
            editId=edit_id,
            language='en-US',
            body=update_body
        ).execute()
        
        print(f"✅ Updated listing for en-US")
        print(f"   Title: Gavra 013 - Putni Organizer")
        print(f"   Short Desc: {SHORT_DESCRIPTION[:50]}...")
        print(f"   Full Desc: {len(NEW_DESCRIPTION)} characters")
        
        # Commit changes
        commit_response = service.edits().commit(
            packageName=package_name,
            editId=edit_id
        ).execute()
        
        print(f"✅ Changes committed! Edit ID: {commit_response['id']}")
        return True
        
    except Exception as e:
        print(f"❌ Error: {str(e)}")
        return False

def update_huawei():
    """Update Huawei AppGallery Description"""
    print("\n" + "="*70)
    print("🎯 HUAWEI APPGALLERY - UPDATE DESCRIPTION")
    print("="*70)
    
    print("""
⚠️  Huawei update trebam OAuth2 token ili direktan API pristup.
    
Alternativa: Ažurirati ručno u Huawei AppGallery Connect:
    
1. Idi na: https://developer.huawei.com/consumer/en/appgallery/
2. TvojaApp: Gavra (App ID: 116046535)
3. App Information → Description
4. Ažuriraj deskripciju sa:

""")
    print(NEW_DESCRIPTION)
    
    print("""
5. Spremi promene
6. Novo je ready za review

Za više informacija:
https://developer.huawei.com/consumer/en/appgallery/
""")
    
    return True

def update_ios():
    """Update iOS App Store Description"""
    print("\n" + "="*70)
    print("🍎 iOS APP STORE - UPDATE DESCRIPTION")
    print("="*70)
    
    print("""
⚠️  iOS update trebam App Store Connect API pristup.
    
Alternativa: Ažurirati ručno u App Store Connect:
    
1. Idi na: https://appstoreconnect.apple.com
2. Tvoja App: Gavra 013
3. App Store → App Information
4. Ažuriraj Description sa:

""")
    print(NEW_DESCRIPTION)
    
    print("""
5. Spremi promene
6. Novo je ready za review

Za više informacija:
https://appstoreconnect.apple.com/
""")
    
    return True

def main():
    print("\n" + "╔" + "="*68 + "╗")
    print("║" + "  UPDATE APP DESCRIPTION - ALL PLATFORMS".center(68) + "║")
    print("║" + "  Version 6.0.50+420".center(68) + "║")
    print("╚" + "="*68 + "╝")
    
    print("\n📱 NEW DESCRIPTION:")
    print("="*70)
    print(NEW_DESCRIPTION)
    print("="*70)
    
    print("\n\n🚀 UPDATING PLATFORMS...")
    
    # Update all platforms
    google_ok = update_google_play()
    huawei_ok = update_huawei()
    ios_ok = update_ios()
    
    print("\n" + "="*70)
    print("✅ SUMMARY")
    print("="*70)
    print(f"Google Play: {'✅ UPDATED' if google_ok else '❌ FAILED'}")
    print(f"Huawei:      {'✅ READY' if huawei_ok else '❌ FAILED'}")
    print(f"iOS:         {'✅ READY' if ios_ok else '❌ FAILED'}")
    print("="*70)
    
    if google_ok:
        print("\n✨ Google Play description je ažurirana i aktivna!")
    
    print("\n💡 SLEDEĆI KORACI:")
    print("   1. Ažuriruj Huawei description ručno (link gore)")
    print("   2. Ažuriruj iOS description ručno (link gore)")
    print("   3. Submit za review ako je potrebno")

if __name__ == "__main__":
    main()
