# Fastlane Match Setup

Fastlane Match koristi Git repository za čuvanje iOS certificate-a i provisioning profila.

## Potrebni GitHub Secrets

Dodaj sledeće secrets u GitHub repository (`Settings > Secrets and variables > Actions`):

### 1. MATCH_GIT_URL
```
git@github.com:Lakisa-code/gavra-ios-certificates.git
```
ili
```
https://github.com/Lakisa-code/gavra-ios-certificates.git
```

### 2. MATCH_PASSWORD
Kreira se nasumična lozinka koja se koristi za enkripciju certificate-a u Git repo-u.
```bash
openssl rand -base64 32
```

### 3. MATCH_GIT_BASIC_AUTHORIZATION (ako koristiš HTTPS)
Base64 encoded format `username:token`. Za GitHub, username može biti bilo šta:
```bash
echo -n "any_user:ghp_your_github_token" | base64
```
Zameni `ghp_your_github_token` sa tvojim pravim tokenom.

Ili kreiraj SSH deploy key za `gavra-ios-certificates` repo.

### 4. FASTLANE_USER
Apple ID email adresa (npr. `your-email@example.com`)

### 5. FASTLANE_PASSWORD
Apple ID lozinka

### 6. FASTLANE_APPLE_APPLICATION_SPECIFIC_PASSWORD
App-specific password generisan na https://appleid.apple.com/account/manage
- Idi na "Security" > "App-Specific Passwords"
- Klikni "Generate Password..."
- Nazovi "GitHub Actions" i sačuvaj generisanu lozinku

### 7. APPLE_TEAM_ID
Pronađi na https://developer.apple.com/account
- Membership details > Team ID

### 8. MATCH_KEYCHAIN_NAME (opciono)
```
match_keychain
```

### 9. MATCH_KEYCHAIN_PASSWORD (opciono)
```bash
openssl rand -base64 16
```

## Inicijalizacija Match-a (lokalno)

Pokreni **jednom** lokalno da generiše certificate i provisioning profile:

```bash
cd ios
bundle install
bundle exec fastlane match appstore --readonly false
```

Ovo će:
1. Kreirati Apple Distribution Certificate
2. Kreirati App Store Provisioning Profile
3. Enkriptovati ih sa MATCH_PASSWORD
4. Commit-ovati u `gavra-ios-certificates` repo

## Provera

Da proveriš da li Match radi:

```bash
cd ios
bundle exec fastlane match appstore --readonly
```

## Troubleshooting

### Invalid code signing identity
- Proveri da li je Team ID ispravan
- Proveri da li su certificates validni na developer.apple.com

### Authentication failed
- Proveri FASTLANE_USER i FASTLANE_PASSWORD
- Proveri da li je 2FA omogućen (potreban je app-specific password)

### Git repository error
- Proveri MATCH_GIT_URL
- Proveri da li imaš pristup repo-u (SSH key ili PAT)
