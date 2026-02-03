# 🔧 Flutter Build Troubleshooting Guide

## Quick Diagnosis Flowchart

```
Build Failed?
│
├─→ "version solving failed"?
│   └─→ Dart/Flutter version mismatch
│       → Check DEPENDENCY_MATRIX.md
│       → Update pubspec.yaml constraint
│       → Update Flutter version in workflow
│
├─→ "toARGB32()" not found?
│   └─→ Code incompatible with Flutter version
│       → Replace toARGB32() with .value
│       → Files: smart_colors.dart, auth_screen.dart
│
├─→ "initialValue" parameter error?
│   └─→ DropdownButtonFormField changed API
│       → Replace initialValue with value
│       → Handle null: value.isNotEmpty ? value : null
│       → Files: home_screen.dart, adrese_screen.dart
│
├─→ "process finished with exit code 1"?
│   └─→ Gradle/Kotlin compilation error
│       → Check full log for actual error
│       → Usually dependency or code compatibility
│
└─→ Build takes 30+ minutes?
    └─→ First build with new Flutter version
        → Subsequent builds will be 15-20 min (cached)
```

---

## 🔍 Common Error Messages & Solutions

### Error: "version solving failed"
```
Because gavra_android depends on local_auth ^2.3.0 
which requires SDK version ^3.5.4 and no versions of 
local_auth match >2.3.0 <3.0.0, local_auth ^2.3.0 is forbidden.
```

**Cause**: Dart SDK version too old for package  
**Solution**:
1. Check current Dart version: `flutter --version`
2. Look up package on pub.dev/packages/{name}/versions
3. Either:
   - Upgrade Flutter (if Dart too old)
   - Downgrade package (if Flutter too new)

**Example**:
```yaml
# If Flutter 3.16.0 (Dart 3.2.0) selected:
# - DON'T use local_auth ^2.3.0 (needs 3.5.4+)
# - USE local_auth ^2.1.0 (compatible with 3.2.0)

local_auth: ^2.1.0  # For Dart 3.2.0
local_auth: ^2.3.0  # For Dart 3.5.3+
```

---

### Error: "Color.toARGB32() isn't defined"
```
Error: The method 'toARGB32' isn't defined for the class 'Color'.
 - 'Color' is from 'dart:ui'.
Try correcting the name to the name of an existing method.
```

**Cause**: Flutter 3.27+ removed toARGB32() method  
**Solution**: Replace all occurrences with `.value`

**Search & Replace**:
```dart
// Find: .toARGB32()
// Replace: .value

// Example:
// ❌ primary.toARGB32() == 0xFFE91E63
// ✅ primary.value == 0xFFE91E63
```

**Files to Check**:
- `lib/utils/smart_colors.dart`
- `lib/screens/auth_screen.dart`
- `lib/screens/adrese_screen.dart`

---

### Error: "No named parameter with the name 'initialValue'"
```
Error: No named parameter with the name 'initialValue'.
                       initialValue: jedinicaMere,
                       ^^^^^^^^^^^^
```

**Cause**: Flutter 3.27+ changed DropdownButtonFormField API  
**Solution**: Use `value` instead of `initialValue`

**Code Change**:
```dart
// ❌ OLD (Flutter <3.27)
DropdownButtonFormField<String>(
  initialValue: jedinicaMere,
  items: [...],
  onChanged: (val) { ... },
)

// ✅ NEW (Flutter 3.27+)
DropdownButtonFormField<String>(
  value: jedinicaMere.isNotEmpty ? jedinicaMere : null,
  items: [...],
  onChanged: (val) { ... },
)
```

**Files to Check**:
- `lib/screens/home_screen.dart` (line ~798)
- `lib/screens/adrese_screen.dart` (line ~455)

---

### Error: "Unable to determine Flutter version for channel: stable"
```
Unable to determine Flutter version for channel: stable 
version: stable architecture: x64
```

**Cause**: "stable" channel is ambiguous/unstable  
**Solution**: Use explicit version number

**Workflow Fix** (.github/workflows/quick-build.yml):
```yaml
# ❌ DON'T USE
flutter-version: 'stable'

# ✅ USE EXPLICIT VERSION
flutter-version: '3.24.3'
```

---

## 📊 Build Performance

### Typical Build Times
| Scenario | Duration | Notes |
|----------|----------|-------|
| First build (new Flutter) | 25-30 min | Downloading Flutter SDK |
| Subsequent builds | 15-20 min | Using cached Flutter |
| With code changes | 18-25 min | Recompiling modified code |

### Why GitHub Actions is Faster
- ✅ Optimized Linux servers
- ✅ Parallel Gradle tasks
- ✅ Good network for downloads
- ✅ SSD storage
- ✅ No UI rendering needed

### Speed Tips
1. Use consistent Flutter version across builds (avoids re-download)
2. Keep pubspec.lock committed (speeds up dependency resolution)
3. Don't change dependencies unnecessarily
4. Gradle cache persists between runs (10-15 min saved)

---

## 🛠️ Manual Fix Commands

### Clean & Rebuild Locally
```bash
# Full clean
flutter clean
rm -rf pubspec.lock
rm -rf android/.gradle

# Rebuild
flutter pub get
flutter build apk --release
```

### Check Dart/Flutter Versions
```bash
# Show current versions
flutter --version

# Show only Dart version
dart --version

# Check Flutter channels available
flutter channel
```

### Debug Build Issues
```bash
# Verbose output
flutter build apk --release -v

# Show gradle errors
flutter build apk --release --gradle-verbose
```

---

## 📋 Pre-Build Verification Checklist

Before pushing code that will trigger GitHub Actions:

### Code Quality Checks
- [ ] No `toARGB32()` calls (search: `toARGB32`)
- [ ] No `initialValue` in DropdownButtonFormField (search: `initialValue`)
- [ ] `flutter analyze` shows no critical errors
- [ ] `dart format` applied to modified files

### Dependency Checks
- [ ] Verified Flutter version in both workflow files matches
- [ ] Checked pub.dev for all new dependencies
- [ ] Verified all dependencies' Dart SDK requirements
- [ ] pubspec.yaml changes don't create conflicts

### Documentation Updates
- [ ] Update DEPENDENCY_MATRIX.md if changing versions
- [ ] Update BUILD_GUIDE.md with new instructions
- [ ] Update this file if discovering new issues

### Build Verification
- [ ] Local build works: `flutter build apk --release`
- [ ] No new warnings in build output
- [ ] APK file created successfully

---

## 🚨 Emergency Recovery

If GitHub Actions build is stuck/failing repeatedly:

### Step 1: Delete Failed Runs
```bash
gh run list --workflow="quick-build.yml" --limit=10
gh run delete <RUN_ID>  # Repeat for all failed runs
```

### Step 2: Force Workflow Dispatch with Clean Flags
```bash
gh workflow run quick-build.yml \
  -f changelog="Emergency rebuild - clean cache"
```

### Step 3: Check Latest Run
```bash
gh run list --workflow="quick-build.yml" --limit=1
gh run view <NEW_RUN_ID> --log-failed
```

### Step 4: If Still Failing
- Review DEPENDENCY_MATRIX.md
- Check if any pubspec.yaml changes accidentally committed
- Review recent code changes for incompatibilities
- Consider reverting to last known good commit

---

## 📞 When to Contact GitHub Support

- Build infrastructure errors (not dependency/code errors)
- GitHub Actions quotas/limits exceeded
- Secrets not properly configured
- Workflow YAML syntax errors (not logic errors)

---

*Last Updated: 2026-02-03*  
*Status: ✅ Flutter 3.24.3 + Dart 3.5.3 - STABLE*  
*Note: app_links dependency handled by supabase_flutter automatically*
