#!/usr/bin/env python3
"""
🔍 ULTRA DETALJNA ANDROID KONFIGURACIJA ANALIZA
Analizira Android deo Flutter aplikacije:
- Android Manifest
- Gradle konfiguracije
- Permissions
- Dependencies
- Build settings
- Security analiza
"""

import os
import re
import json
import xml.etree.ElementTree as ET
from pathlib import Path
from collections import defaultdict, Counter
import matplotlib.pyplot as plt
import seaborn as sns

class AndroidConfigAnalyzer:
    def __init__(self, project_root):
        self.project_root = Path(project_root)
        self.android_path = self.project_root / "android"
        self.analysis_results = {}
        self.issues = []

    def analyze_manifest(self):
        """Analiza AndroidManifest.xml"""
        print("📱 Analiziram Android Manifest...")

        manifest_path = self.android_path / "app" / "src" / "main" / "AndroidManifest.xml"
        manifest_info = {
            "permissions": [],
            "activities": [],
            "services": [],
            "receivers": [],
            "providers": [],
            "features": [],
            "metadata": [],
            "security_issues": []
        }

        if manifest_path.exists():
            try:
                tree = ET.parse(manifest_path)
                root = tree.getroot()

                # Namespace
                ns = {'android': 'http://schemas.android.com/apk/res/android'}

                # Permissions
                for perm in root.findall(".//uses-permission"):
                    name = perm.get('{http://schemas.android.com/apk/res/android}name', '')
                    if name:
                        manifest_info["permissions"].append(name.replace('android.permission.', ''))

                # Dangerous permissions
                dangerous_perms = [
                    'READ_EXTERNAL_STORAGE', 'WRITE_EXTERNAL_STORAGE', 'CAMERA',
                    'RECORD_AUDIO', 'ACCESS_FINE_LOCATION', 'ACCESS_COARSE_LOCATION',
                    'READ_CONTACTS', 'READ_PHONE_STATE', 'SEND_SMS', 'READ_SMS'
                ]

                for perm in manifest_info["permissions"]:
                    if perm in dangerous_perms:
                        manifest_info["security_issues"].append(f"Dangerous permission: {perm}")

                # Activities
                for activity in root.findall(".//activity"):
                    name = activity.get('{http://schemas.android.com/apk/res/android}name', '')
                    if name:
                        manifest_info["activities"].append(name.split('.')[-1])

                # Services
                for service in root.findall(".//service"):
                    name = service.get('{http://schemas.android.com/apk/res/android}name', '')
                    if name:
                        manifest_info["services"].append(name.split('.')[-1])

                # Broadcast Receivers
                for receiver in root.findall(".//receiver"):
                    name = receiver.get('{http://schemas.android.com/apk/res/android}name', '')
                    if name:
                        manifest_info["receivers"].append(name.split('.')[-1])

                # Content Providers
                for provider in root.findall(".//provider"):
                    name = provider.get('{http://schemas.android.com/apk/res/android}name', '')
                    if name:
                        manifest_info["providers"].append(name.split('.')[-1])

                # Uses Features
                for feature in root.findall(".//uses-feature"):
                    name = feature.get('{http://schemas.android.com/apk/res/android}name', '')
                    required = feature.get('{http://schemas.android.com/apk/res/android}required', 'true')
                    if name:
                        manifest_info["features"].append({
                            "name": name.replace('android.hardware.', ''),
                            "required": required == 'true'
                        })

                # Application metadata
                app = root.find(".//application")
                if app is not None:
                    for meta in app.findall("meta-data"):
                        name = meta.get('{http://schemas.android.com/apk/res/android}name', '')
                        value = meta.get('{http://schemas.android.com/apk/res/android}value', '')
                        if name:
                            manifest_info["metadata"].append({"name": name, "value": value})

                # Security checks
                if not any('INTERNET' in perm for perm in manifest_info["permissions"]):
                    manifest_info["security_issues"].append("Missing INTERNET permission")

                if any('DEBUG' in meta.get('name', '') for meta in manifest_info["metadata"]):
                    manifest_info["security_issues"].append("Debug metadata found in production")

            except Exception as e:
                self.issues.append(f"Greška pri parsiranju AndroidManifest.xml: {e}")

        self.analysis_results["manifest"] = manifest_info
        return manifest_info

    def analyze_gradle_config(self):
        """Analiza Gradle konfiguracija"""
        print("🔧 Analiziram Gradle konfiguracije...")

        gradle_info = {
            "app_gradle": {},
            "project_gradle": {},
            "dependencies": [],
            "build_types": [],
            "product_flavors": [],
            "gradle_warnings": []
        }

        # App level build.gradle.kts
        app_gradle_path = self.android_path / "app" / "build.gradle.kts"
        if app_gradle_path.exists():
            try:
                with open(app_gradle_path, 'r', encoding='utf-8') as f:
                    content = f.read()

                # Compile SDK
                compile_sdk_match = re.search(r'compileSdk\s*=\s*(\d+)', content)
                if compile_sdk_match:
                    gradle_info["app_gradle"]["compile_sdk"] = int(compile_sdk_match.group(1))

                # Target SDK
                target_sdk_match = re.search(r'targetSdk\s*=\s*(\d+)', content)
                if target_sdk_match:
                    gradle_info["app_gradle"]["target_sdk"] = int(target_sdk_match.group(1))

                # Min SDK
                min_sdk_match = re.search(r'minSdk\s*=\s*(\d+)', content)
                if min_sdk_match:
                    gradle_info["app_gradle"]["min_sdk"] = int(min_sdk_match.group(1))

                # Version code/name
                version_code_match = re.search(r'versionCode\s*=\s*(\d+)', content)
                if version_code_match:
                    gradle_info["app_gradle"]["version_code"] = int(version_code_match.group(1))

                version_name_match = re.search(r'versionName\s*=\s*"([^"]+)"', content)
                if version_name_match:
                    gradle_info["app_gradle"]["version_name"] = version_name_match.group(1)

                # Dependencies
                deps = re.findall(r'implementation\("([^"]+)"\)', content)
                gradle_info["dependencies"].extend(deps)

                # Build types
                build_types_match = re.search(r'buildTypes\s*\{(.*?)\}', content, re.DOTALL)
                if build_types_match:
                    build_section = build_types_match.group(1)
                    if 'release' in build_section:
                        gradle_info["build_types"].append("release")
                    if 'debug' in build_section:
                        gradle_info["build_types"].append("debug")

                # Provera sigurnosti
                if 'debuggable true' in content:
                    gradle_info["gradle_warnings"].append("Debuggable set to true in release build")

                if 'minifyEnabled false' in content:
                    gradle_info["gradle_warnings"].append("Code minification disabled")

            except Exception as e:
                self.issues.append(f"Greška pri čitanju app build.gradle.kts: {e}")

        # Project level build.gradle.kts
        project_gradle_path = self.android_path / "build.gradle.kts"
        if project_gradle_path.exists():
            try:
                with open(project_gradle_path, 'r', encoding='utf-8') as f:
                    content = f.read()

                # Kotlin version
                kotlin_match = re.search(r'kotlin\s*\(\s*"([^"]+)"\s*\)', content)
                if kotlin_match:
                    gradle_info["project_gradle"]["kotlin_version"] = kotlin_match.group(1)

                # Gradle version
                gradle_match = re.search(r'gradle\s*\(\s*"([^"]+)"\s*\)', content)
                if gradle_match:
                    gradle_info["project_gradle"]["gradle_version"] = gradle_match.group(1)

            except Exception as e:
                self.issues.append(f"Greška pri čitanju project build.gradle.kts: {e}")

        self.analysis_results["gradle"] = gradle_info
        return gradle_info

    def analyze_keystore_config(self):
        """Analiza keystore konfiguracije"""
        print("🔐 Analiziram keystore konfiguraciju...")

        keystore_info = {
            "key_properties_exists": False,
            "keystore_files": [],
            "security_issues": []
        }

        # Key properties
        key_props_path = self.android_path / "key.properties"
        if key_props_path.exists():
            keystore_info["key_properties_exists"] = True
            try:
                with open(key_props_path, 'r', encoding='utf-8') as f:
                    content = f.read()

                if 'storePassword' in content and 'keyPassword' in content:
                    keystore_info["has_passwords"] = True
                else:
                    keystore_info["security_issues"].append("Missing keystore passwords in key.properties")

            except Exception as e:
                self.issues.append(f"Greška pri čitanju key.properties: {e}")

        # Keystore fajlovi
        for file_path in self.android_path.glob("*.keystore"):
            keystore_info["keystore_files"].append(file_path.name)

        if not keystore_info["keystore_files"]:
            keystore_info["security_issues"].append("No keystore files found")

        self.analysis_results["keystore"] = keystore_info
        return keystore_info

    def analyze_performance_config(self):
        """Analiza performansi konfiguracije"""
        print("⚡ Analiziram performance konfiguraciju...")

        perf_info = {
            "proguard_enabled": False,
            "r8_enabled": False,
            "optimization_flags": [],
            "performance_issues": []
        }

        app_gradle_path = self.android_path / "app" / "build.gradle.kts"
        if app_gradle_path.exists():
            try:
                with open(app_gradle_path, 'r', encoding='utf-8') as f:
                    content = f.read()

                # ProGuard/R8
                if 'minifyEnabled true' in content:
                    perf_info["proguard_enabled"] = True
                if 'shrinkResources true' in content:
                    perf_info["r8_enabled"] = True

                # Performance issues
                if 'minifyEnabled false' in content:
                    perf_info["performance_issues"].append("Code minification disabled - larger APK size")

                if 'shrinkResources false' in content:
                    perf_info["performance_issues"].append("Resource shrinking disabled - larger APK size")

                if 'compileSdk' in content:
                    compile_sdk_match = re.search(r'compileSdk\s*=\s*(\d+)', content)
                    if compile_sdk_match and int(compile_sdk_match.group(1)) < 33:
                        perf_info["performance_issues"].append("Old compile SDK - consider upgrading")

            except Exception as e:
                self.issues.append(f"Greška pri analizi performance konfiguracije: {e}")

        self.analysis_results["performance"] = perf_info
        return perf_info

    def generate_visualizations(self):
        """Generiše vizuelizacije"""
        print("📊 Generišem vizuelizacije...")

        # 1. Permissions analysis
        if "manifest" in self.analysis_results:
            permissions = self.analysis_results["manifest"]["permissions"]

            if permissions:
                plt.figure(figsize=(12, 6))
                perm_counts = Counter(permissions)
                perms = list(perm_counts.keys())
                counts = list(perm_counts.values())

                plt.bar(range(len(perms)), counts)
                plt.xticks(range(len(perms)), perms, rotation=45, ha='right')
                plt.title('Android Permissions Usage')
                plt.ylabel('Count')
                plt.tight_layout()
                plt.savefig('android_permissions_analysis.png', dpi=300, bbox_inches='tight')
                plt.close()

        # 2. Dependencies analysis
        if "gradle" in self.analysis_results:
            deps = self.analysis_results["gradle"]["dependencies"]

            if deps:
                # Kategorizuj dependencies
                categories = {
                    'Google': 0,
                    'Firebase': 0,
                    'Huawei': 0,
                    'Other': 0
                }

                for dep in deps:
                    if 'google' in dep.lower():
                        categories['Google'] += 1
                    elif 'firebase' in dep.lower():
                        categories['Firebase'] += 1
                    elif 'huawei' in dep.lower():
                        categories['Huawei'] += 1
                    else:
                        categories['Other'] += 1

                plt.figure(figsize=(8, 6))
                plt.pie(categories.values(), labels=categories.keys(), autopct='%1.1f%%')
                plt.title('Android Dependencies by Provider')
                plt.axis('equal')
                plt.savefig('android_dependencies_analysis.png', dpi=300, bbox_inches='tight')
                plt.close()

    def generate_report(self):
        """Generiše detaljan izveštaj"""
        print("📝 Generišem izveštaj...")

        report = f"""# 🔍 ULTRA DETALJNA ANDROID KONFIGURACIJA ANALIZA
## 📅 Datum: {__import__('datetime').datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

---

## 📊 OSNOVNE INFORMACIJE

**Lokacija projekta**: {self.android_path}

---

## 📱 ANDROID MANIFEST ANALIZA

"""

        if "manifest" in self.analysis_results:
            manifest = self.analysis_results["manifest"]

            report += f"""### 🔐 Permissions ({len(manifest['permissions'])})
"""
            for perm in manifest['permissions'][:10]:
                report += f"- `{perm}`\n"
            if len(manifest['permissions']) > 10:
                report += f"- ... i još {len(manifest['permissions']) - 10} permissions\n"

            report += f"""
### 📱 Activities ({len(manifest['activities'])})
"""
            for activity in manifest['activities'][:5]:
                report += f"- `{activity}`\n"

            report += f"""
### 🔧 Services ({len(manifest['services'])})
"""
            for service in manifest['services'][:5]:
                report += f"- `{service}`\n"

            report += f"""
### 📡 Hardware Features ({len(manifest['features'])})
"""
            for feature in manifest['features'][:5]:
                required = "✅ Required" if feature['required'] else "⚠️ Optional"
                report += f"- `{feature['name']}` - {required}\n"

            if manifest['security_issues']:
                report += f"""
### ⚠️ Security Issues ({len(manifest['security_issues'])})
"""
                for issue in manifest['security_issues']:
                    report += f"- 🚨 {issue}\n"

        report += "\n---\n\n## 🔧 GRADLE KONFIGURACIJA\n\n"
        if "gradle" in self.analysis_results:
            gradle = self.analysis_results["gradle"]

            if gradle['app_gradle']:
                app_gradle = gradle['app_gradle']
                report += f"""### 📱 App Configuration
- **Compile SDK**: {app_gradle.get('compile_sdk', 'N/A')}
- **Target SDK**: {app_gradle.get('target_sdk', 'N/A')}
- **Min SDK**: {app_gradle.get('min_sdk', 'N/A')}
- **Version Code**: {app_gradle.get('version_code', 'N/A')}
- **Version Name**: {app_gradle.get('version_name', 'N/A')}

### 📦 Dependencies ({len(gradle['dependencies'])})
"""
                for dep in gradle['dependencies'][:10]:
                    report += f"- `{dep}`\n"
                if len(gradle['dependencies']) > 10:
                    report += f"- ... i još {len(gradle['dependencies']) - 10} dependencies\n"

            if gradle['gradle_warnings']:
                report += f"""
### ⚠️ Gradle Warnings ({len(gradle['gradle_warnings'])})
"""
                for warning in gradle['gradle_warnings']:
                    report += f"- ⚠️ {warning}\n"

        report += "\n---\n\n## 🔐 KEYSTORE KONFIGURACIJA\n\n"
        if "keystore" in self.analysis_results:
            keystore = self.analysis_results["keystore"]

            report += f"""- **Key Properties**: {'✅ Found' if keystore['key_properties_exists'] else '❌ Missing'}
- **Keystore Files**: {len(keystore['keystore_files'])} found
"""
            for ks_file in keystore['keystore_files']:
                report += f"  - `{ks_file}`\n"

            if keystore['security_issues']:
                report += f"""
### ⚠️ Security Issues ({len(keystore['security_issues'])})
"""
                for issue in keystore['security_issues']:
                    report += f"- 🚨 {issue}\n"

        report += "\n---\n\n## ⚡ PERFORMANCE KONFIGURACIJA\n\n"
        if "performance" in self.analysis_results:
            perf = self.analysis_results["performance"]

            report += f"""- **Code Minification**: {'✅ Enabled' if perf['proguard_enabled'] else '❌ Disabled'}
- **Resource Shrinking**: {'✅ Enabled' if perf['r8_enabled'] else '❌ Disabled'}

### ⚠️ Performance Issues ({len(perf['performance_issues'])})
"""
            for issue in perf['performance_issues']:
                report += f"- ⚠️ {issue}\n"

        if self.issues:
            report += "\n---\n\n## ⚠️ PROBLEMI TOKOM ANALIZE\n\n"
            for issue in self.issues[:10]:
                report += f"- {issue}\n"

        report += "\n---\n\n## 📊 VIZUELIZACIJE\n\n"
        report += """Generisane su sledeće vizuelizacije:
- `android_permissions_analysis.png` - Analiza permissions
- `android_dependencies_analysis.png` - Analiza dependencies po provider-u

---
*Generisano Ultra Detailed Android Config Analyzer v1.0*
"""

        with open('ULTRA_DETAILED_ANDROID_CONFIG_ANALYSIS_REPORT_2026.md', 'w', encoding='utf-8') as f:
            f.write(report)

        print("✅ Izveštaj sačuvan: ULTRA_DETAILED_ANDROID_CONFIG_ANALYSIS_REPORT_2026.md")
    def run_full_analysis(self):
        """Pokreće kompletnu analizu"""
        print("🚀 POKRETANJE ULTRA DETALJNE ANDROID KONFIGURACIJE ANALIZE")
        print("=" * 70)

        try:
            self.analyze_manifest()
            self.analyze_gradle_config()
            self.analyze_keystore_config()
            self.analyze_performance_config()
            self.generate_visualizations()
            self.generate_report()

            print("\n🎉 ANDROID KONFIGURACIJA ANALIZA ZAVRŠENA!")
            print("📁 Izveštaj: ULTRA_DETAILED_ANDROID_CONFIG_ANALYSIS_REPORT_2026.md")
            print("📊 Vizuelizacije: android_*.png fajlovi")

        except Exception as e:
            print(f"❌ Greška tokom analize: {e}")
            import traceback
            traceback.print_exc()

if __name__ == "__main__":
    analyzer = AndroidConfigAnalyzer(".")
    analyzer.run_full_analysis()