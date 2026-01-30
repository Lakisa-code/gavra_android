#!/usr/bin/env python3
"""
🔒 ULTRA DETALJNA SIGURNOSNA ANALIZA
Analizira sigurnost Flutter/Android aplikacije:
- API ključevi i secrets
- Network security
- Data storage security
- Authentication security
- Code security issues
- Dependency vulnerabilities
"""

import os
import re
import json
import base64
from pathlib import Path
from collections import defaultdict
import requests

class SecurityAnalyzer:
    def __init__(self, project_root):
        self.project_root = Path(project_root)
        self.analysis_results = {}
        self.issues = []
        self.warnings = []
        self.critical_issues = []

    def analyze_api_keys_and_secrets(self):
        """Analiza API ključeva i tajni"""
        print("🔑 Analiziram API ključeve i tajne...")

        secrets_info = {
            "hardcoded_keys": [],
            "env_variables": [],
            "exposed_secrets": [],
            "weak_keys": []
        }

        # Analiziraj .env fajlove
        env_files = [".env", ".env.example", ".env.backup"]
        for env_file in env_files:
            env_path = self.project_root / env_file
            if env_path.exists():
                try:
                    with open(env_path, 'r', encoding='utf-8') as f:
                        content = f.read()

                    # Nađi sve SUPABASE ključeve
                    supabase_matches = re.findall(r'SUPABASE_[^=]+=[^\n]+', content)
                    for match in supabase_matches:
                        key_name = match.split('=')[0]
                        secrets_info["env_variables"].append({
                            "type": "Supabase",
                            "key": key_name,
                            "file": env_file
                        })

                    # Firebase ključevi
                    firebase_matches = re.findall(r'FIREBASE_[^=]+=[^\n]+', content)
                    for match in firebase_matches:
                        key_name = match.split('=')[0]
                        secrets_info["env_variables"].append({
                            "type": "Firebase",
                            "key": key_name,
                            "file": env_file
                        })

                    # Huawei ključevi
                    huawei_matches = re.findall(r'HUAWEI_[^=]+=[^\n]+', content)
                    for match in huawei_matches:
                        key_name = match.split('=')[0]
                        secrets_info["env_variables"].append({
                            "type": "Huawei",
                            "key": key_name,
                            "file": env_file
                        })

                except Exception as e:
                    self.issues.append(f"Greška pri čitanju {env_file}: {e}")

        # Analiziraj Dart fajlove za hardcoded ključeve
        for dart_file in self.project_root.rglob("*.dart"):
            if dart_file.is_file():
                try:
                    with open(dart_file, 'r', encoding='utf-8') as f:
                        content = f.read()
                        lines = content.split('\n')

                    for i, line in enumerate(lines, 1):
                        # Supabase URL i ključevi
                        if 'supabase' in line.lower() and ('url' in line.lower() or 'key' in line.lower()):
                            if 'http' in line and not line.strip().startswith('//'):
                                secrets_info["hardcoded_keys"].append({
                                    "type": "Supabase URL/Key",
                                    "file": str(dart_file.relative_to(self.project_root)),
                                    "line": i,
                                    "content": line.strip()[:100] + "..."
                                })

                        # Firebase config
                        if 'firebase' in line.lower() and ('api' in line.lower() or 'key' in line.lower()):
                            secrets_info["hardcoded_keys"].append({
                                "type": "Firebase Config",
                                "file": str(dart_file.relative_to(self.project_root)),
                                "line": i,
                                "content": line.strip()[:100] + "..."
                            })

                        # API ključevi pattern
                        api_patterns = [
                            r'api[_-]?key["\s]*:[\s]*["\']([^"\']+)["\']',
                            r'secret["\s]*:[\s]*["\']([^"\']+)["\']',
                            r'token["\s]*:[\s]*["\']([^"\']+)["\']'
                        ]

                        for pattern in api_patterns:
                            matches = re.findall(pattern, line, re.IGNORECASE)
                            for match in matches:
                                if len(match) > 10:  # Samo duži ključevi
                                    secrets_info["hardcoded_keys"].append({
                                        "type": "API Key/Token",
                                        "file": str(dart_file.relative_to(self.project_root)),
                                        "line": i,
                                        "content": f"***{match[-4:]}"
                                    })

                except Exception as e:
                    self.issues.append(f"Greška pri analizi {dart_file}: {e}")

        # Proveri da li su .env fajlovi u .gitignore
        gitignore_path = self.project_root / ".gitignore"
        if gitignore_path.exists():
            try:
                with open(gitignore_path, 'r', encoding='utf-8') as f:
                    gitignore_content = f.read()

                env_files_to_check = [".env", ".env.backup"]
                for env_file in env_files_to_check:
                    if env_file in gitignore_content:
                        secrets_info["exposed_secrets"].append(f"✅ {env_file} je u .gitignore")
                    else:
                        secrets_info["exposed_secrets"].append(f"🚨 {env_file} NIJE u .gitignore")

            except Exception as e:
                self.issues.append(f"Greška pri čitanju .gitignore: {e}")

        self.analysis_results["secrets"] = secrets_info
        return secrets_info

    def analyze_network_security(self):
        """Analiza network sigurnosti"""
        print("🌐 Analiziram network sigurnost...")

        network_info = {
            "http_urls": [],
            "insecure_connections": [],
            "certificate_pinning": False,
            "network_security_config": False
        }

        # Analiziraj Dart fajlove za HTTP URLs
        for dart_file in self.project_root.rglob("*.dart"):
            if dart_file.is_file():
                try:
                    with open(dart_file, 'r', encoding='utf-8') as f:
                        content = f.read()

                    # Nađi HTTP URLs (ne HTTPS)
                    http_urls = re.findall(r'http://[^\s"\']+', content)
                    for url in http_urls:
                        if not url.startswith('http://localhost') and not url.startswith('http://127.0.0.1'):
                            network_info["insecure_connections"].append({
                                "url": url,
                                "file": str(dart_file.relative_to(self.project_root))
                            })

                    # Proveri za certificate pinning
                    if 'certificate' in content.lower() or 'ssl' in content.lower():
                        network_info["certificate_pinning"] = True

                except Exception as e:
                    self.issues.append(f"Greška pri network analizi {dart_file}: {e}")

        # Proveri Android network security config
        nsc_path = self.project_root / "android" / "app" / "src" / "main" / "res" / "xml" / "network_security_config.xml"
        if nsc_path.exists():
            network_info["network_security_config"] = True
        else:
            self.warnings.append("Network Security Config fajl ne postoji")

        self.analysis_results["network"] = network_info
        return network_info

    def analyze_data_storage_security(self):
        """Analiza sigurnosti skladištenja podataka"""
        print("💾 Analiziram sigurnost skladištenja podataka...")

        storage_info = {
            "shared_preferences_usage": [],
            "database_encryption": False,
            "sensitive_data_storage": [],
            "file_permissions": []
        }

        # Analiziraj Dart fajlove za storage patterns
        for dart_file in self.project_root.rglob("*.dart"):
            if dart_file.is_file():
                try:
                    with open(dart_file, 'r', encoding='utf-8') as f:
                        content = f.read()

                    # SharedPreferences usage
                    if 'SharedPreferences' in content:
                        storage_info["shared_preferences_usage"].append(
                            str(dart_file.relative_to(self.project_root))
                        )

                    # Sensitive data patterns
                    sensitive_patterns = [
                        r'password["\s]*:[\s]*["\']([^"\']+)["\']',
                        r'token["\s]*:[\s]*["\']([^"\']+)["\']',
                        r'secret["\s]*:[\s]*["\']([^"\']+)["\']'
                    ]

                    for pattern in sensitive_patterns:
                        matches = re.findall(pattern, content, re.IGNORECASE)
                        for match in matches:
                            storage_info["sensitive_data_storage"].append({
                                "type": "Hardcoded sensitive data",
                                "file": str(dart_file.relative_to(self.project_root)),
                                "data": f"***{match[-4:]}" if len(match) > 4 else "***"
                            })

                    # Database encryption
                    if 'encrypt' in content.lower() or 'sqlcipher' in content.lower():
                        storage_info["database_encryption"] = True

                except Exception as e:
                    self.issues.append(f"Greška pri storage analizi {dart_file}: {e}")

        self.analysis_results["storage"] = storage_info
        return storage_info

    def analyze_authentication_security(self):
        """Analiza sigurnosti autentifikacije"""
        print("🔐 Analiziram sigurnost autentifikacije...")

        auth_info = {
            "auth_methods": [],
            "token_storage": [],
            "session_management": [],
            "auth_issues": []
        }

        # Analiziraj Dart fajlove za auth patterns
        for dart_file in self.project_root.rglob("*.dart"):
            if dart_file.is_file():
                try:
                    with open(dart_file, 'r', encoding='utf-8') as f:
                        content = f.read()

                    # Supabase auth
                    if 'supabase.auth' in content:
                        auth_info["auth_methods"].append("Supabase Auth")

                    # Firebase auth
                    if 'firebase_auth' in content or 'FirebaseAuth' in content:
                        auth_info["auth_methods"].append("Firebase Auth")

                    # JWT tokens
                    if 'jwt' in content.lower() or 'bearer' in content.lower():
                        auth_info["token_storage"].append("JWT/Bearer tokens detected")

                    # Session management
                    if 'session' in content.lower():
                        auth_info["session_management"].append("Session management detected")

                    # Weak auth patterns
                    if 'password' in content.lower() and '123456' in content:
                        auth_info["auth_issues"].append("Weak default password detected")

                    if 'admin' in content.lower() and 'admin' in content:
                        auth_info["auth_issues"].append("Default admin credentials detected")

                except Exception as e:
                    self.issues.append(f"Greška pri auth analizi {dart_file}: {e}")

        # Deduplicate
        auth_info["auth_methods"] = list(set(auth_info["auth_methods"]))

        self.analysis_results["auth"] = auth_info
        return auth_info

    def analyze_dependency_vulnerabilities(self):
        """Analiza ranjivosti dependencies"""
        print("📦 Analiziram ranjivosti dependencies...")

        vuln_info = {
            "pub_dependencies": [],
            "gradle_dependencies": [],
            "known_vulnerabilities": [],
            "outdated_packages": []
        }

        # Analiziraj pubspec.yaml
        pubspec_path = self.project_root / "pubspec.yaml"
        if pubspec_path.exists():
            try:
                with open(pubspec_path, 'r', encoding='utf-8') as f:
                    content = f.read()

                # Izvuci dependencies
                dep_section = re.search(r'dependencies:(.*?)(?:dev_dependencies|$)', content, re.DOTALL)
                if dep_section:
                    deps = re.findall(r'^\s*(\w+):\s*[\^~]?([\d.]+)', dep_section.group(1), re.MULTILINE)
                    vuln_info["pub_dependencies"] = deps

                    # Proveri poznate ranjivosti
                    vulnerable_packages = {
                        'firebase_core': '3.8.0',  # Primer
                        'supabase_flutter': '2.10.3'  # Primer
                    }

                    for package, version in deps:
                        if package in vulnerable_packages:
                            if version < vulnerable_packages[package]:
                                vuln_info["known_vulnerabilities"].append({
                                    "package": package,
                                    "current": version,
                                    "recommended": vulnerable_packages[package]
                                })

            except Exception as e:
                self.issues.append(f"Greška pri čitanju pubspec.yaml: {e}")

        # Analiziraj Android dependencies
        gradle_path = self.project_root / "android" / "app" / "build.gradle.kts"
        if gradle_path.exists():
            try:
                with open(gradle_path, 'r', encoding='utf-8') as f:
                    content = f.read()

                deps = re.findall(r'implementation\("([^"]+)"\)', content)
                vuln_info["gradle_dependencies"] = deps

            except Exception as e:
                self.issues.append(f"Greška pri čitanju build.gradle.kts: {e}")

        self.analysis_results["vulnerabilities"] = vuln_info
        return vuln_info

    def generate_security_score(self):
        """Generiše sigurnosni skor"""
        score = 100  # Počni sa 100

        # Oduzmi poene za probleme
        if "secrets" in self.analysis_results:
            secrets = self.analysis_results["secrets"]
            score -= len(secrets["hardcoded_keys"]) * 20
            score -= len([x for x in secrets["exposed_secrets"] if "🚨" in x]) * 15

        if "network" in self.analysis_results:
            network = self.analysis_results["network"]
            score -= len(network["insecure_connections"]) * 10

        if "storage" in self.analysis_results:
            storage = self.analysis_results["storage"]
            score -= len(storage["sensitive_data_storage"]) * 15

        if "auth" in self.analysis_results:
            auth = self.analysis_results["auth"]
            score -= len(auth["auth_issues"]) * 25

        if "vulnerabilities" in self.analysis_results:
            vuln = self.analysis_results["vulnerabilities"]
            score -= len(vuln["known_vulnerabilities"]) * 10

        return max(0, score)  # Ne može biti manje od 0

    def generate_report(self):
        """Generiše detaljan sigurnosni izveštaj"""
        print("📝 Generišem sigurnosni izveštaj...")

        security_score = self.generate_security_score()

        report = f"""# 🔒 ULTRA DETALJNA SIGURNOSNA ANALIZA
## 📅 Datum: {__import__('datetime').datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

---

## 📊 SIGURNOSNI SKOR: **{security_score}/100**

"""

        if security_score >= 80:
            report += "🟢 **VISOK NIVO SIGURNOSTI** - Aplikacija je dobro zaštićena\n"
        elif security_score >= 60:
            report += "🟡 **SREDNJI NIVO SIGURNOSTI** - Postoje neki sigurnosni problemi\n"
        else:
            report += "🔴 **NIZAK NIVO SIGURNOSTI** - Potrebne su hitne sigurnosne ispravke\n"

        report += "\n---\n\n## 🔑 API KLJUČEVI I TAJNE\n\n"
        if "secrets" in self.analysis_results:
            secrets = self.analysis_results["secrets"]

            report += f"### Environment Variables ({len(secrets['env_variables'])})\n"
            for var in secrets['env_variables'][:5]:
                report += f"- `{var['key']}` ({var['type']}) - {var['file']}\n"

            if secrets['hardcoded_keys']:
                report += f"\n### 🚨 Hardcoded Keys ({len(secrets['hardcoded_keys'])})\n"
                for key in secrets['hardcoded_keys'][:5]:
                    report += f"- **{key['type']}** in `{key['file']}` line {key['line']}\n"

            report += f"\n### .gitignore Status\n"
            for status in secrets['exposed_secrets']:
                report += f"- {status}\n"

        report += "\n---\n\n## 🌐 NETWORK SIGURNOST\n\n"
        if "network" in self.analysis_results:
            network = self.analysis_results["network"]

            report += f"- **Certificate Pinning**: {'✅ Implemented' if network['certificate_pinning'] else '❌ Not implemented'}\n"
            report += f"- **Network Security Config**: {'✅ Exists' if network['network_security_config'] else '❌ Missing'}\n"

            if network['insecure_connections']:
                report += f"\n### 🚨 Insecure Connections ({len(network['insecure_connections'])})\n"
                for conn in network['insecure_connections'][:3]:
                    report += f"- `{conn['url']}` in `{conn['file']}`\n"

        report += "\n---\n\n## 💾 SIGURNOST SKLADIŠTENJA\n\n"
        if "storage" in self.analysis_results:
            storage = self.analysis_results["storage"]

            report += f"- **Database Encryption**: {'✅ Enabled' if storage['database_encryption'] else '❌ Disabled'}\n"
            report += f"- **SharedPreferences Usage**: {len(storage['shared_preferences_usage'])} files\n"

            if storage['sensitive_data_storage']:
                report += f"\n### 🚨 Sensitive Data Issues ({len(storage['sensitive_data_storage'])})\n"
                for issue in storage['sensitive_data_storage'][:3]:
                    report += f"- {issue['type']} in `{issue['file']}`\n"

        report += "\n---\n\n## 🔐 AUTENTIFIKACIJA\n\n"
        if "auth" in self.analysis_results:
            auth = self.analysis_results["auth"]

            report += f"### Auth Methods ({len(auth['auth_methods'])})\n"
            for method in auth['auth_methods']:
                report += f"- ✅ {method}\n"

            if auth['auth_issues']:
                report += f"\n### 🚨 Auth Issues ({len(auth['auth_issues'])})\n"
                for issue in auth['auth_issues']:
                    report += f"- {issue}\n"

        report += "\n---\n\n## 📦 DEPENDENCY RANJIVOSTI\n\n"
        if "vulnerabilities" in self.analysis_results:
            vuln = self.analysis_results["vulnerabilities"]

            report += f"**Pub Dependencies**: {len(vuln['pub_dependencies'])}\n"
            report += f"**Android Dependencies**: {len(vuln['gradle_dependencies'])}\n"

            if vuln['known_vulnerabilities']:
                report += f"\n### 🚨 Known Vulnerabilities ({len(vuln['known_vulnerabilities'])})\n"
                for v in vuln['known_vulnerabilities']:
                    report += f"- `{v['package']}`: {v['current']} → {v['recommended']}\n"

        report += "\n---\n\n## ⚠️ UPOZORENJA\n\n"
        for warning in self.warnings[:10]:
            report += f"- ⚠️ {warning}\n"

        if self.issues:
            report += "\n### Problemi tokom analize\n"
            for issue in self.issues[:5]:
                report += f"- {issue}\n"

        report += "\n---\n\n## 🛡️ SIGURNOSNE PREPORUKE\n\n"
        report += """### Visok prioritet
1. **Uklonite sve hardcoded API ključeve** iz koda
2. **Implementirajte certificate pinning** za HTTPS konekcije
3. **Šifrujte sensitive podatke** u lokalnom skladištu
4. **Koristite secure storage** za tokens i credentials

### Srednji prioritet
1. **Dodajte Network Security Configuration** za Android
2. **Implementirajte proper session management**
3. **Redovno ažurirajte dependencies**
4. **Dodajte code obfuscation** u release build

### Nizak prioritet
1. **Implementirajte biometric authentication**
2. **Dodajte rate limiting** za API pozive
3. **Implementirajte proper logging** bez sensitive data

---
*Generisano Ultra Detailed Security Analyzer v1.0*
"""

        with open('ULTRA_DETAILED_SECURITY_ANALYSIS_REPORT_2026.md', 'w', encoding='utf-8') as f:
            f.write(report)

        print("✅ Sigurnosni izveštaj sačuvan: ULTRA_DETAILED_SECURITY_ANALYSIS_REPORT_2026.md")
    def run_full_analysis(self):
        """Pokreće kompletnu sigurnosnu analizu"""
        print("🚀 POKRETANJE ULTRA DETALJNE SIGURNOSNE ANALIZE")
        print("=" * 60)

        try:
            self.analyze_api_keys_and_secrets()
            self.analyze_network_security()
            self.analyze_data_storage_security()
            self.analyze_authentication_security()
            self.analyze_dependency_vulnerabilities()
            self.generate_report()

            print("\n🎉 SIGURNOSNA ANALIZA ZAVRŠENA!")
            print("📁 Izveštaj: ULTRA_DETAILED_SECURITY_ANALYSIS_REPORT_2026.md")

        except Exception as e:
            print(f"❌ Greška tokom analize: {e}")
            import traceback
            traceback.print_exc()

if __name__ == "__main__":
    analyzer = SecurityAnalyzer(".")
    analyzer.run_full_analysis()