# 🔍 ULTRA DETALJNA ANDROID KONFIGURACIJA ANALIZA
## 📅 Datum: 2026-01-29 23:11:46

---

## 📊 OSNOVNE INFORMACIJE

**Lokacija projekta**: android

---

## 📱 ANDROID MANIFEST ANALIZA

### 🔐 Permissions (16)
- `READ_MEDIA_IMAGES`
- `READ_MEDIA_VIDEO`
- `ACCESS_FINE_LOCATION`
- `ACCESS_COARSE_LOCATION`
- `INTERNET`
- `WAKE_LOCK`
- `VIBRATE`
- `POST_NOTIFICATIONS`
- `RECEIVE_BOOT_COMPLETED`
- `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`
- ... i još 6 permissions

### 📱 Activities (2)
- `MainActivity`
- `BridgeActivity`

### 🔧 Services (1)
- `GavraNotificationListener`

### 📡 Hardware Features (0)

### ⚠️ Security Issues (2)
- 🚨 Dangerous permission: ACCESS_FINE_LOCATION
- 🚨 Dangerous permission: ACCESS_COARSE_LOCATION

---

## 🔧 GRADLE KONFIGURACIJA

### 📱 App Configuration
- **Compile SDK**: 36
- **Target SDK**: 36
- **Min SDK**: N/A
- **Version Code**: N/A
- **Version Name**: N/A

### 📦 Dependencies (3)
- `com.google.firebase:firebase-messaging`
- `com.google.android.play:app-update:2.1.0`
- `com.google.android.play:review:2.0.2`

---

## 🔐 KEYSTORE KONFIGURACIJA

- **Key Properties**: ✅ Found
- **Keystore Files**: 1 found
  - `gavra-release-key-production.keystore`

---

## ⚡ PERFORMANCE KONFIGURACIJA

- **Code Minification**: ❌ Disabled
- **Resource Shrinking**: ❌ Disabled

### ⚠️ Performance Issues (0)

---

## 📊 VIZUELIZACIJE

Generisane su sledeće vizuelizacije:
- `android_permissions_analysis.png` - Analiza permissions
- `android_dependencies_analysis.png` - Analiza dependencies po provider-u

---
*Generisano Ultra Detailed Android Config Analyzer v1.0*
