#!/usr/bin/env python3
"""
🔍 ULTRA DETALJNA FLUTTER/DART KOD ANALIZA
Analizira kompletnu Flutter aplikaciju za:
- Kod kvalitet
- Kompleksnost
- Dependencies
- Arhitekturu
- Best practices
"""

import os
import re
import json
import subprocess
from pathlib import Path
from collections import defaultdict, Counter
import matplotlib.pyplot as plt
import seaborn as sns

class FlutterCodeAnalyzer:
    def __init__(self, project_root):
        self.project_root = Path(project_root)
        self.lib_path = self.project_root / "lib"
        self.analysis_results = {}
        self.issues = []

    def analyze_project_structure(self):
        """Analiza strukture Flutter projekta"""
        print("📁 Analiziram strukturu projekta...")

        structure = {
            "dart_files": [],
            "directories": [],
            "total_lines": 0,
            "file_sizes": {}
        }

        for file_path in self.lib_path.rglob("*.dart"):
            if file_path.is_file():
                structure["dart_files"].append(str(file_path.relative_to(self.project_root)))

                # Broj linija
                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        lines = len(f.readlines())
                        structure["total_lines"] += lines
                        structure["file_sizes"][str(file_path.relative_to(self.project_root))] = lines
                except:
                    pass

        # Direktorijumi
        for dir_path in self.lib_path.rglob("*"):
            if dir_path.is_dir():
                structure["directories"].append(str(dir_path.relative_to(self.project_root)))

        self.analysis_results["structure"] = structure
        return structure

    def analyze_code_quality(self):
        """Analiza kvaliteta koda"""
        print("🔍 Analiziram kvalitet koda...")

        quality_metrics = {
            "total_files": 0,
            "total_classes": 0,
            "total_functions": 0,
            "total_widgets": 0,
            "complexity_warnings": [],
            "code_smells": []
        }

        for file_path in self.lib_path.rglob("*.dart"):
            if not file_path.is_file():
                continue

            quality_metrics["total_files"] += 1

            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()

                # Broj klasa
                classes = len(re.findall(r'class\s+\w+', content))
                quality_metrics["total_classes"] += classes

                # Broj funkcija
                functions = len(re.findall(r'(?:void|Future|Stream|Widget)\s+\w+\s*\(', content))
                quality_metrics["total_functions"] += functions

                # Broj widgeta
                widgets = len(re.findall(r'class\s+\w+.*extends\s+(?:StatelessWidget|StatefulWidget)', content))
                quality_metrics["total_widgets"] += widgets

                # Kompleksnost - duge funkcije
                lines = content.split('\n')
                for i, line in enumerate(lines):
                    if line.strip().startswith(('void ', 'Future<', 'Widget ', 'Function(')):
                        # Pronađi kraj funkcije
                        brace_count = 0
                        func_lines = 0
                        for j in range(i, len(lines)):
                            func_lines += 1
                            if '{' in lines[j]:
                                brace_count += lines[j].count('{')
                            if '}' in lines[j]:
                                brace_count -= lines[j].count('}')
                            if brace_count == 0:
                                break

                        if func_lines > 50:  # Preko 50 linija
                            quality_metrics["complexity_warnings"].append({
                                "file": str(file_path.relative_to(self.project_root)),
                                "function": line.strip()[:50] + "...",
                                "lines": func_lines
                            })

                # Code smells
                if len(content) > 10000:  # Fajl preko 10KB
                    quality_metrics["code_smells"].append({
                        "type": "Large file",
                        "file": str(file_path.relative_to(self.project_root)),
                        "size": len(content)
                    })

                # TODO komentari
                todos = len(re.findall(r'//.*(?:TODO|FIXME|HACK)', content, re.IGNORECASE))
                if todos > 0:
                    quality_metrics["code_smells"].append({
                        "type": "TODO comments",
                        "file": str(file_path.relative_to(self.project_root)),
                        "count": todos
                    })

            except Exception as e:
                self.issues.append(f"Greška pri analizi {file_path}: {e}")

        self.analysis_results["quality"] = quality_metrics
        return quality_metrics

    def analyze_dependencies(self):
        """Analiza dependencies"""
        print("📦 Analiziram dependencies...")

        pubspec_path = self.project_root / "pubspec.yaml"
        deps_info = {
            "flutter_deps": [],
            "third_party_deps": [],
            "dev_deps": [],
            "total_deps": 0
        }

        if pubspec_path.exists():
            try:
                with open(pubspec_path, 'r', encoding='utf-8') as f:
                    content = f.read()

                # Flutter dependencies
                flutter_match = re.search(r'dependencies:(.*?)(?:dev_dependencies|$)', content, re.DOTALL)
                if flutter_match:
                    deps_section = flutter_match.group(1)
                    deps = re.findall(r'^\s*(\w+):\s*[\^~]?[\d.]+', deps_section, re.MULTILINE)
                    deps_info["flutter_deps"] = deps

                # Dev dependencies
                dev_match = re.search(r'dev_dependencies:(.*?)(?:flutter|$)', content, re.DOTALL)
                if dev_match:
                    dev_section = dev_match.group(1)
                    dev_deps = re.findall(r'^\s*(\w+):\s*[\^~]?[\d.]+', dev_section, re.MULTILINE)
                    deps_info["dev_deps"] = dev_deps

                deps_info["total_deps"] = len(deps_info["flutter_deps"]) + len(deps_info["dev_deps"])

            except Exception as e:
                self.issues.append(f"Greška pri čitanju pubspec.yaml: {e}")

        self.analysis_results["dependencies"] = deps_info
        return deps_info

    def analyze_architecture(self):
        """Analiza arhitekture aplikacije"""
        print("🏗️ Analiziram arhitekturu...")

        architecture = {
            "layers": {
                "presentation": [],  # UI/screens
                "business": [],      # BLoC, ViewModels
                "data": [],          # Repositories, Services
                "domain": []         # Models, Entities
            },
            "patterns": {
                "bloc": 0,
                "provider": 0,
                "riverpod": 0,
                "getx": 0,
                "custom": 0
            },
            "imports_analysis": {}
        }

        # Analiza po direktorijumima
        for file_path in self.lib_path.rglob("*.dart"):
            if not file_path.is_file():
                continue

            rel_path = str(file_path.relative_to(self.lib_path))

            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    content = f.read()

                # Odredi sloj
                if any(keyword in rel_path.lower() for keyword in ['screen', 'page', 'ui', 'widget']):
                    architecture["layers"]["presentation"].append(rel_path)
                elif any(keyword in rel_path.lower() for keyword in ['bloc', 'cubit', 'viewmodel', 'controller']):
                    architecture["layers"]["business"].append(rel_path)
                elif any(keyword in rel_path.lower() for keyword in ['repo', 'service', 'api', 'database']):
                    architecture["layers"]["data"].append(rel_path)
                elif any(keyword in rel_path.lower() for keyword in ['model', 'entity', 'dto']):
                    architecture["layers"]["domain"].append(rel_path)

                # Detektuj pattern
                if 'extends Bloc' in content or 'extends Cubit' in content:
                    architecture["patterns"]["bloc"] += 1
                if 'extends ChangeNotifier' in content or 'Provider.of' in content:
                    architecture["patterns"]["provider"] += 1
                if 'extends StateNotifier' in content or 'riverpod' in content.lower():
                    architecture["patterns"]["riverpod"] += 1
                if 'GetX' in content or 'Get.find' in content:
                    architecture["patterns"]["getx"] += 1

            except Exception as e:
                self.issues.append(f"Greška pri analizi arhitekture {file_path}: {e}")

        self.analysis_results["architecture"] = architecture
        return architecture

    def generate_visualizations(self):
        """Generiše vizuelizacije"""
        print("📊 Generišem vizuelizacije...")

        # 1. Distribucija veličine fajlova
        if "structure" in self.analysis_results:
            file_sizes = self.analysis_results["structure"]["file_sizes"]

            plt.figure(figsize=(12, 6))
            sizes = list(file_sizes.values())
            files = [f.split('/')[-1] for f in file_sizes.keys()]

            plt.bar(range(len(sizes)), sizes)
            plt.xticks(range(len(files)), files, rotation=45, ha='right')
            plt.title('Distribucija veličine Dart fajlova (broj linija)')
            plt.ylabel('Broj linija')
            plt.tight_layout()
            plt.savefig('flutter_code_size_distribution.png', dpi=300, bbox_inches='tight')
            plt.close()

        # 2. Arhitektura - distribucija po slojevima
        if "architecture" in self.analysis_results:
            layers = self.analysis_results["architecture"]["layers"]

            plt.figure(figsize=(10, 6))
            layer_names = list(layers.keys())
            layer_counts = [len(layers[layer]) for layer in layer_names]

            plt.bar(layer_names, layer_counts)
            plt.title('Distribucija fajlova po arhitekturnim slojevima')
            plt.ylabel('Broj fajlova')
            plt.xticks(rotation=45)
            plt.tight_layout()
            plt.savefig('flutter_architecture_layers.png', dpi=300, bbox_inches='tight')
            plt.close()

        # 3. State management patterns
        if "architecture" in self.analysis_results:
            patterns = self.analysis_results["architecture"]["patterns"]

            plt.figure(figsize=(8, 6))
            pattern_names = list(patterns.keys())
            pattern_counts = list(patterns.values())

            plt.pie(pattern_counts, labels=pattern_names, autopct='%1.1f%%')
            plt.title('Korišćenje State Management Pattern-a')
            plt.axis('equal')
            plt.savefig('flutter_state_management_patterns.png', dpi=300, bbox_inches='tight')
            plt.close()

    def generate_report(self):
        """Generiše detaljan izveštaj"""
        print("📝 Generišem izveštaj...")

        report = f"""# 🔍 ULTRA DETALJNA FLUTTER/DART KOD ANALIZA
## 📅 Datum: {__import__('datetime').datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

---

## 📊 OSNOVNE INFORMACIJE

**Lokacija projekta**: {self.project_root}
**Analizirano fajlova**: {self.analysis_results.get('structure', {}).get('total_files', 0)}
**Ukupno linija koda**: {self.analysis_results.get('structure', {}).get('total_lines', 0)}

---

## 📁 STRUKTURA PROJEKTA

### 📂 Direktorijumi
"""
        if "structure" in self.analysis_results:
            for directory in self.analysis_results["structure"]["directories"][:10]:  # Prvih 10
                report += f"- `{directory}`\n"
            if len(self.analysis_results["structure"]["directories"]) > 10:
                report += f"- ... i još {len(self.analysis_results["structure"]["directories"]) - 10} direktorijuma\n"

        report += "\n### 📄 Najveći fajlovi\n"
        if "structure" in self.analysis_results:
            sorted_files = sorted(self.analysis_results["structure"]["file_sizes"].items(),
                                key=lambda x: x[1], reverse=True)
            for file_path, lines in sorted_files[:10]:
                report += f"- `{file_path}`: {lines} linija\n"

        report += "\n---\n\n## 🔍 KVALITET KODA\n\n"
        if "quality" in self.analysis_results:
            quality = self.analysis_results["quality"]
            report += f"""**Ukupno klasa**: {quality['total_classes']}
**Ukupno funkcija**: {quality['total_functions']}
**Ukupno widgeta**: {quality['total_widgets']}

### ⚠️ Upozorenja o kompleksnosti
"""
            for warning in quality['complexity_warnings'][:5]:  # Prvih 5
                report += f"- `{warning['file']}`: {warning['function']} ({warning['lines']} linija)\n"

            report += "\n### 🐛 Code Smells\n"
            for smell in quality['code_smells'][:5]:  # Prvih 5
                report += f"- **{smell['type']}**: `{smell['file']}` ({smell.get('count', smell.get('size', 'N/A'))})\n"

        report += "\n---\n\n## 📦 DEPENDENCIES\n\n"
        if "dependencies" in self.analysis_results:
            deps = self.analysis_results["dependencies"]
            report += f"""**Ukupno dependencies**: {deps['total_deps']}

### Flutter Dependencies ({len(deps['flutter_deps'])})
"""
            for dep in deps['flutter_deps'][:10]:
                report += f"- `{dep}`\n"
            if len(deps['flutter_deps']) > 10:
                report += f"- ... i još {len(deps['flutter_deps']) - 10} dependencies\n"

            report += f"\n### Dev Dependencies ({len(deps['dev_deps'])})\n"
            for dep in deps['dev_deps'][:5]:
                report += f"- `{dep}`\n"

        report += "\n---\n\n## 🏗️ ARHITEKTURA\n\n"
        if "architecture" in self.analysis_results:
            arch = self.analysis_results["architecture"]
            report += f"""### Slojevi aplikacije
- **Presentation**: {len(arch['layers']['presentation'])} fajlova
- **Business Logic**: {len(arch['layers']['business'])} fajlova
- **Data**: {len(arch['layers']['data'])} fajlova
- **Domain**: {len(arch['layers']['domain'])} fajlova

### State Management Patterns
"""
            for pattern, count in arch['patterns'].items():
                if count > 0:
                    report += f"- **{pattern.upper()}**: {count} fajlova\n"

        if self.issues:
            report += "\n---\n\n## ⚠️ PROBLEMI TOKOM ANALIZE\n\n"
            for issue in self.issues[:10]:
                report += f"- {issue}\n"

        report += "\n---\n\n## 📊 VIZUELIZACIJE\n\n"
        report += """Generisane su sledeće vizuelizacije:
- `flutter_code_size_distribution.png` - Distribucija veličine fajlova
- `flutter_architecture_layers.png` - Arhitekturni slojevi
- `flutter_state_management_patterns.png` - State management patterni

---
*Generisano Ultra Detailed Flutter Code Analyzer v1.0*
"""

        with open('ULTRA_DETAILED_FLUTTER_CODE_ANALYSIS_REPORT_2026.md', 'w', encoding='utf-8') as f:
            f.write(report)

        print("✅ Izveštaj sačuvan: ULTRA_DETAILED_FLUTTER_CODE_ANALYSIS_REPORT_2026.md")
    def run_full_analysis(self):
        """Pokreće kompletnu analizu"""
        print("🚀 POKRETANJE ULTRA DETALJNE FLUTTER/DART ANALIZE")
        print("=" * 60)

        try:
            self.analyze_project_structure()
            self.analyze_code_quality()
            self.analyze_dependencies()
            self.analyze_architecture()
            self.generate_visualizations()
            self.generate_report()

            print("\n🎉 FLUTTER/DART ANALIZA ZAVRŠENA!")
            print("📁 Izveštaj: ULTRA_DETAILED_FLUTTER_CODE_ANALYSIS_REPORT_2026.md")
            print("📊 Vizuelizacije: flutter_*.png fajlovi")

        except Exception as e:
            print(f"❌ Greška tokom analize: {e}")
            import traceback
            traceback.print_exc()

if __name__ == "__main__":
    analyzer = FlutterCodeAnalyzer(".")
    analyzer.run_full_analysis()