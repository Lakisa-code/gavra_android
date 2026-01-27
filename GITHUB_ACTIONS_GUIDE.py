#!/usr/bin/env python3
"""
Check GitHub Actions Workflows Status and Deployment Options
"""

print("""
╔══════════════════════════════════════════════════════════════════════════════╗
║                   GITHUB ACTIONS DEPLOYMENT ANALYSIS                         ║
╚══════════════════════════════════════════════════════════════════════════════╝

✅ WORKFLOWS PRONAĐENI:
  1. unified-deploy-all.yml         - Deploy na sve 3 platforme (PREPORUČENO!)
  2. ios-production.yml             - Samo iOS App Store
  3. huawei-production.yml          - Samo Huawei AppGallery
  4. google-closed-testing.yml      - Google Play Closed Testing
  5. test-google-auth.yml           - Test Google auth
  6. build-apk-download.yml         - Build APK samo (za preuzmimanje)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🎯 PREPORUKA: Koristi "unified-deploy-all.yml"

Razlozi:
  ✓ Deploja na sve 3 platforme paralelno (Google, Huawei, iOS)
  ✓ Automatski bump verzije ako želiš
  ✓ Dry-run opcija za testiranje
  ✓ Fleksibilan - možeš izabrati koji job-ovi da se pokrenu
  ✓ Sve je u jednom workflow-u

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📋 UNIFIKOVAN WORKFLOW PARAMETRI:

bump_version:
  - Automatski bumpa verziju sa +1 na patch i build
  - Default: true
  - Za verziju 6.0.50+420 → 6.0.51+421

release_notes:
  - Release notes za sve platforme
  - Default: "Automatsko ažuriranje (Performance Fixes)"

submit_for_review_huawei:
  - Da li submitovati Huawei za review
  - Default: true

force_replace_review_huawei:
  - Force replace ako je već u review
  - Default: false

submit_for_review_ios:
  - Da li submitovati iOS za review
  - Default: true

dry_run:
  - Samo build, bez uploada
  - Default: false

run_google_play:
  - Pokreni Google Play job?
  - Default: true

run_huawei_appgallery:
  - Pokreni Huawei job?
  - Default: true

run_ios_app_store:
  - Pokreni iOS job?
  - Default: true

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🔐 POTREBNI GITHUB SECRETS:

Za Google Play:
  ✓ GOOGLE_SERVICE_ACCOUNT_JSON  - Service account key

Za Huawei:
  ✓ HUAWEI_CLIENT_ID             - OAuth2 Client ID
  ✓ HUAWEI_CLIENT_SECRET         - OAuth2 Client Secret
  ✓ HUAWEI_APP_ID                - App ID

Za iOS:
  ✓ APP_STORE_CONNECT_ISSUER_ID       - Issuer ID
  ✓ APP_STORE_CONNECT_KEY_IDENTIFIER  - Key ID
  ✓ APP_STORE_CONNECT_PRIVATE_KEY     - Private key P8
  ✓ CERTIFICATE_PRIVATE_KEY           - Signing certificate

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

🚀 KAKO POKRENUTI ZA VERZIJU 6.0.50+420:

OPCIJA 1: AUTOMATSKI BUMP + DEPLOY NA SVE
────────────────────────────────────────
  • Idi na: https://github.com/YOUR_USER/gavra_android/actions
  • Klikni: "Workflows" → "UNIFIED DEPLOY ALL"
  • Klikni: "Run workflow"
  • Podesi:
    ✓ Auto-bump version: true
    ✓ Release notes: "Version 6.0.50+420 Production Release"
    ✓ Submit for review Huawei: true
    ✓ Submit for review iOS: true
    ✓ Dry run: false
    ✓ Run all platforms: true for each
  • Klikni: "Run workflow"

  Rezultat: Verzija 6.0.51+421 će biti buildovana i deployovana!

OPCIJA 2: DEPLOY 6.0.50+420 BEZ BUMP-a
──────────────────────────────────────
  • Prvo: Ručno postavi pubspec.yaml na 6.0.50+420 i commit
  • Zatim: Pokreni workflow sa bump_version: false
  • Rezultat: Verzija 6.0.50+420 će biti deployovana kako je

OPCIJA 3: DRY RUN (SAMO BUILD)
──────────────────────────────
  • Pokreni workflow sa dry_run: true
  • Rezultat: Build će biti kreiran, ali NEĆE biti uploadovan
  • Korisno za testiranje prije stvarnog deployment-a

OPCIJA 4: SAMO JEDNA PLATFORMA
──────────────────────────────
  • run_google_play: true/false
  • run_huawei_appgallery: true/false
  • run_ios_app_store: true/false
  • Komplicirano - bolje koristiti pojedinačne workflows

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⏱️  VREMENSKI PREGLED:

Build time:
  • Google Play (AAB): ~5-10 min
  • Huawei (APK): ~5-10 min
  • iOS (IPA): ~10-15 min
  
Upload + Review:
  • Google Play: 1-4 sata (obično instant za updates)
  • Huawei: 2-6 sati
  • iOS: 24-48 sati

Totalno: ~1-3 sata build, zatim čekanje na review

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ ZAKLJUČAK:

NIJE POTREBNA LOKALNA SKRIPTA! 🎉

Sve je već konfigurisan u GitHub Actions:
  ✓ Automatski build na ubuntu-latest i macos-latest
  ✓ Automatski upload na sve 3 prodavnice
  ✓ Automatski submit za review
  ✓ Sigurna čuvanja credencijala u GitHub Secrets
  ✓ Paralelna izvršavanja

PREPORUKA: Koristi GitHub Actions UI - mnogo je lakše i bezbednije!
""")
