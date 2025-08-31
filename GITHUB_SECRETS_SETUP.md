# 🔐 GitHub Secrets Setup za TestFlight

## Idemo u GitHub repo pa Settings > Secrets and variables > Actions

### 1. **P12_BASE64**
```bash
# Konvertuj .p12 certificate u base64
base64 -i ios_distribution.p12 | pbcopy
# ili na Windows:
certutil -encode ios_distribution.p12 tmp.b64 && type tmp.b64
```

### 2. **P12_PASSWORD** 
```
# Password koji si koristio kad si kreirao certificate
```

### 3. **MOBILEPROVISION_BASE64**
```bash
# Konvertuj .mobileprovision u base64  
base64 -i Gavra_Android_App_Store_Profile.mobileprovision | pbcopy
# ili na Windows:
certutil -encode Gavra_Android_App_Store_Profile.mobileprovision tmp.b64 && type tmp.b64
```

### 4. **TEAM_ID**
```
# Tvoj Apple Developer Team ID (10 karaktera)
# Naći ćeš u Apple Developer Account > Membership
```

### 5. **APPLE_ID** 
```
# Tvoj Apple ID email
```

### 6. **APPLE_PASSWORD**
```
# App-specific password (NE glavni password!)
# Generiši na: appleid.apple.com > Sign-In and Security > App-Specific Passwords
```

## 🚀 Kad dodaš secrets, workflow će raditi automatski na svaki push!

### Test:
```bash
git push origin main
# Idi na GitHub > Actions > vidi kako radi iOS TestFlight deploy! 🎯
```
