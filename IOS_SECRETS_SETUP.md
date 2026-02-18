# 🔐 GitHub Secrets za iOS Deployment

## Generisane lozinke (kopiraj odmah)

```
MATCH_PASSWORD=BszgN8w51ZyFlb7RYc6QSh2AJdfkiEjO
MATCH_KEYCHAIN_PASSWORD=rNMlIc4BTS9GnDQO
```

## 📋 Kompletna lista GitHub Secrets

Dodaj ove secrets na: https://github.com/Lakisa-code/gavra_android/settings/secrets/actions

### 1. MATCH_GIT_URL
```
https://github.com/Lakisa-code/gavra-ios-certificates.git
```

### 2. MATCH_PASSWORD
```
BszgN8w51ZyFlb7RYc6QSh2AJdfkiEjO
```

### 3. MATCH_GIT_BASIC_AUTHORIZATION
Kreiraj GitHub Personal Access Token:
1. Idi na: https://github.com/settings/tokens/new
2. Name: "iOS Fastlane Match"
3. Expiration: "No expiration" ili "1 year"
4. Scope: ✅ **repo** (full control)
5. Generate token
6. Kopiraj token i encode-uj ga (čuvaj token negde sigurno!)

**Napomena**: Token treba da encode-uješ u base64, ali GitHub Actions će to automatski uraditi ako staviš samo token.

### 4. FASTLANE_USER
Tvoj Apple ID email (onaj koji koristiš za developer.apple.com)

### 5. FASTLANE_PASSWORD
Tvoja Apple ID lozinka

### 6. FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD
1. Idi na: https://appleid.apple.com/account/manage
2. Security > App-Specific Passwords
3. Klikni "+"
4. Label: "GitHub Actions Gavra"
5. Generiši i kopiraj (format: xxxx-xxxx-xxxx-xxxx)

### 7. APPLE_TEAM_ID
1. Idi na: https://developer.apple.com/account
2. Membership details
3. Kopiraj Team ID (format: ABC123DEF4)

### 8. MATCH_KEYCHAIN_NAME
```
match_keychain
```

### 9. MATCH_KEYCHAIN_PASSWORD
```
rNMlIc4BTS9GnDQO
```

## ✅ Već postoje (ne treba dodavati)

- ✅ APPSTORE_KEY_ID
- ✅ APPSTORE_ISSUER_ID
- ✅ APPSTORE_API_KEY_P8
- ✅ ENV_FILE_CONTENT
- ✅ IOS_GOOGLE_SERVICES_PLIST (treba dodati ako ne postoji)

## 🚀 Inicijalizacija Fastlane Match (lokalno)

**VAŽNO**: Prvo dodaj sve GitHub secrets, pa onda pokreni lokalno:

```bash
cd ios
bundle install
bundle exec fastlane match init
```

Odgovori na pitanja:
- Storage mode: `git`
- Git URL: `https://github.com/Lakisa-code/gavra-ios-certificates.git`

Zatim pokreni:
```bash
export MATCH_PASSWORD="BszgN8w51ZyFlb7RYc6QSh2AJdfkiEjO"
export FASTLANE_USER="tvoj-apple-id@email.com"
export FASTLANE_PASSWORD="tvoja-lozinka"
export APPLE_TEAM_ID="tvoj-team-id"

bundle exec fastlane match appstore
```

Ovo će kreirati Distribution Certificate i App Store Provisioning Profile.

## 🧪 Testiranje

Nakon što dodaš sve secrets i inicijaluzuješ Match, pokreni workflow:

```bash
gh workflow run gavra-ios.yml
```

## 🔒 Sigurnost

- **MATCH_PASSWORD**: Čuva se u GitHub Secrets (enkriptovano)
- **Certificates**: Čuvaju se u privatnom `gavra-ios-certificates` repo (enkriptovani sa MATCH_PASSWORD)
- **GitHub PAT**: Ima pristup samo `gavra-ios-certificates` repo-u

## ❓ Troubleshooting

### "Could not find a matching code signing identity"
- Proveri da li je APPLE_TEAM_ID ispravan
- Proveri da li si pokrenuo `fastlane match appstore` lokalno

### "Authentication failed"
- Proveri FASTLANE_USER i FASTLANE_PASSWORD
- Proveri da li postoji FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD (ako imaš 2FA)

### "Repository not found"
- Proveri MATCH_GIT_URL
- Proveri da li MATCH_GIT_BASIC_AUTHORIZATION ima pristup repo-u
