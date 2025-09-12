# 🚀 Gavra Android - GitHub Actions CI/CD

![Build Status](https://github.com/bojanbc83/gavra_android/workflows/🚀%20Build%20and%20Release%20Flutter%20APK/badge.svg)
![PR Check](https://github.com/bojanbc83/gavra_android/workflows/🔍%20PR%20Quality%20Check/badge.svg)

## 📋 Automated Workflows

### 🔨 Build and Release (`build-and-release.yml`)
**Triggers:**
- Push to `main` branch
- New version tags (`v*`)
- Manual trigger

**Jobs:**
1. **🔍 Code Analysis** - Flutter analyze + tests
2. **🔨 Debug Build** - Creates debug APK for testing
3. **🚀 Release Build** - Creates production APK (main branch only)
4. **📢 Notification** - Build status summary

**Artifacts:**
- Debug APK (30 days retention)
- Release APK (90 days retention)
- GitHub Releases (on version tags)

### 🔍 PR Quality Check (`pr-check.yml`)
**Triggers:**
- Pull requests to `main`/`develop`
- Push to `develop` branch

**Checks:**
- ✅ Code formatting (`flutter format`)
- ✅ Static analysis (`flutter analyze`)
- ✅ Test execution
- ✅ Build verification
- 🔒 Basic security scan

### 🏷️ Auto Release Tagging (`auto-release.yml`)
**Triggers:**
- Push to `main` with code changes
- Automatic versioning from `pubspec.yaml`

**Features:**
- Auto-creates tags based on app version
- Generates release notes from commits
- Skip with `[skip-tag]` in commit message

## 📱 Usage

### 🔄 Development Workflow
```bash
# 1. Create feature branch
git checkout -b feature/nova-funkcionalnost

# 2. Make changes and commit
git add .
git commit -m "Add nova funkcionalnost"

# 3. Push and create PR
git push origin feature/nova-funkcionalnost
# Create PR on GitHub - triggers PR checks

# 4. Merge to main
# Triggers build, release, and auto-tagging
```

### 🚀 Release Process
```bash
# 1. Update version in pubspec.yaml
version: 1.2.3+4

# 2. Commit and push to main
git add pubspec.yaml
git commit -m "Bump version to 1.2.3"
git push origin main

# 3. Automated process:
# - Auto-creates tag v1.2.3
# - Builds release APK
# - Creates GitHub release
# - Uploads APK to release
```

### 📦 Manual Release
```bash
# Create and push tag manually
git tag -a v1.2.3 -m "Release 1.2.3"
git push origin v1.2.3
# Triggers release build and GitHub release
```

### 🛑 Skip Auto-tagging
```bash
# Add [skip-tag] to commit message
git commit -m "Fix typo [skip-tag]"
```

## 🔧 Configuration

### 🔑 Required Secrets
- `GITHUB_TOKEN` - Auto-provided by GitHub Actions

### 📊 Optional Enhancements
Add to repository secrets for extended functionality:
- `DISCORD_WEBHOOK` - Team notifications
- `SLACK_WEBHOOK` - Build notifications
- `CODECOV_TOKEN` - Coverage reporting

### 🛠️ Customization

**Modify Flutter version:**
```yaml
# In workflow files
flutter-version: '3.35.2'
channel: 'stable'
```

**Change build targets:**
```yaml
# Add iOS builds, web builds, etc.
flutter build ios --release
flutter build web --release
```

**Add deployment:**
```yaml
# Deploy to Firebase, Google Play Store, etc.
- name: Deploy to Firebase
  run: firebase deploy
```

## 📈 Build Artifacts

### 🔍 Accessing Builds
1. Go to **Actions** tab in GitHub
2. Select successful workflow run
3. Download artifacts:
   - `gavra-android-debug` - Debug APK
   - `gavra-android-release` - Release APK

### 📱 Installing APK
1. Download APK from GitHub Actions or Releases
2. Enable "Install from unknown sources" on Android
3. Install APK file

### 🏷️ Release Tags
- Automatic releases: `v1.2.3`
- Pre-releases: `v1.2.3-beta.1`
- Manual releases: Custom tags

## 🚨 Troubleshooting

### ❌ Build Failures
```bash
# Check logs in GitHub Actions
# Common issues:
# - Flutter version mismatch
# - Missing dependencies
# - Gradle build errors
```

### 🔧 Local Testing
```bash
# Test workflow locally (act required)
act -j build-debug
act -j analyze
```

### 📞 Support
- Check workflow logs in GitHub Actions
- Review Flutter doctor output
- Verify pubspec.yaml versions

---

## 🎯 Benefits

✅ **Automated Testing** - Every PR is tested
✅ **Consistent Builds** - Same environment every time  
✅ **Release Automation** - Tag and release with one push
✅ **Quality Gates** - Code analysis and formatting
✅ **Artifact Storage** - APKs stored and versioned
✅ **Team Notifications** - Build status updates

**🚀 Powered by GitHub Actions + Flutter 3.35.2**
