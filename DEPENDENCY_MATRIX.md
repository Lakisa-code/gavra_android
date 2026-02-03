# 📦 Dependency Compatibility Matrix

## Current Setup (✅ Working)
**Flutter Version**: 3.24.3  
**Dart SDK**: 3.5.3+  
**Last Updated**: 2026-02-03  
**Key Fix**: Removed explicit `app_links` dependency - let `supabase_flutter` resolve it automatically

---

## 🎯 Key Dependencies & Requirements

### Flutter/Dart Foundation
| Package | Version | Dart SDK Required | Flutter Version | Status |
|---------|---------|-------------------|-----------------|--------|
| Flutter | 3.24.3 | 3.5.3+ | - | ✅ Current |
| Dart SDK | 3.5.3+ | - | 3.24.3+ | ✅ Current |

### Critical Dependencies (Cause Build Failures if Wrong)
| Package | Current | Required Dart | Required Flutter | ⚠️ Notes |
|---------|---------|---|---|---|
| `supabase_flutter` | ^2.9.0 | ^3.5.3 | 3.24.0+ | ✅ Automatically resolves `app_links` (no explicit version needed) |
| `flutter_native_contact_picker` | ^0.0.11 | ^3.5.3 | 3.24.0+ | ❌ Fails with Dart <3.5.3 (SDK version mismatch) |
| `local_auth` | ^2.3.0 | ^3.5.4 | 3.24.0+ | ⚠️ 2.1.0 works with Dart 3.2.0, but 2.3.0 is better |

### Optional/Secondary Dependencies
| Package | Version | Notes |
|---------|---------|-------|
| `firebase_core` | ^3.8.0 | Works fine |
| `supabase_flutter` | ^2.10.3 | Works fine |
| `firebase_messaging` | ^15.1.5 | Works fine |
| `huawei_push` | ^6.14.0+300 | Works fine |

---

## ⚠️ Known Issues & Workarounds

### Issue #1: toARGB32() Method Not Found
**Problem**: Flutter 3.27.0 removed `Color.toARGB32()`  
**Solution**: Use `Color.value` instead  
**Files Affected**:
- `lib/utils/smart_colors.dart` (6 occurrences) - ✅ FIXED
- `lib/screens/auth_screen.dart` (3 occurrences) - ✅ FIXED

**Code Change**:
```dart
// ❌ Old (breaks with Flutter 3.27+)
color.toARGB32() == 0xFFE91E63

// ✅ New
color.value == 0xFFE91E63
```

---

### Issue #2: DropdownButtonFormField initialValue Parameter
**Problem**: Flutter 3.27.0+ changed `initialValue` to `value`  
**Solution**: Use `value` parameter instead, handle null with conditional  
**Files Affected**:
- `lib/screens/home_screen.dart` (line 798) - ✅ FIXED
- `lib/screens/adrese_screen.dart` (line 455) - ✅ FIXED

**Code Change**:
```dart
// ❌ Old
DropdownButtonFormField<String>(
  initialValue: jedinicaMere,
  ...
)

// ✅ New
DropdownButtonFormField<String>(
  value: jedinicaMere.isNotEmpty ? jedinicaMere : null,
  ...
)
```

---

## 🔄 Flutter Version Compatibility Timeline

### Tried Versions
| Version | Dart | Status | Issue |
|---------|------|--------|-------|
| 3.27.0 | 3.5.0 | ❌ FAILED | `toARGB32()` not found, `initialValue` issue |
| 3.24.0 | 3.5.0 | ❌ FAILED | `flutter_native_contact_picker` needs Dart 3.5.3+ |
| 3.16.0 | 3.2.0 | ❌ FAILED | `local_auth ^2.3.0` needs Dart 3.2.3+ |
| **3.24.3** | **3.5.3** | ✅ WORKING | All dependencies compatible |

### Lessons Learned
1. **Never use "stable" channel** - Use explicit versions
2. **Check all dependencies before choosing Flutter version** - Use `pub.dev` to verify SDK requirements
3. **Dart SDK is the bottleneck** - Most issues are Dart version mismatches
4. **Lock critical dependencies** - Use exact versions for packages that are fragile

---

## 📋 Pre-Build Checklist

Before running GitHub Actions build, verify:
- [ ] Flutter version in `quick-build.yml` and `build-and-release.yml`
- [ ] All `pubspec.yaml` dependencies are compatible with chosen Flutter version
- [ ] No `toARGB32()` calls in codebase
- [ ] No `initialValue` in `DropdownButtonFormField` - use `value` instead
- [ ] Check `pub.dev` for each package's SDK requirements

---

## 🚀 Future Updates

If updating Flutter/Dart in future:

### Step 1: Check Dependencies on pub.dev
```
Visit: pub.dev/packages/{package_name}
Look for: "SDK version" requirement
```

### Step 2: Update Build Guide
Update `.github/BUILD_GUIDE.md` with new Flutter version

### Step 3: Run Local Test
```bash
flutter clean
flutter pub get
flutter build apk --release
```

### Step 4: Update This Matrix
Document any new issues found

---

## 📞 Support Commands

Check what Dart version is in Flutter:
```bash
flutter --version
```

Check if package is compatible with Dart version:
```bash
# Visit: https://pub.dev/packages/{package}/versions
# Check "SDK version" field under Requirements
```

Force specific Flutter version:
```bash
# In .github/workflows/quick-build.yml
flutter-version: '3.24.3'
```

---

*Last Tested: 2026-02-03 | Status: ✅ Building Successfully*
