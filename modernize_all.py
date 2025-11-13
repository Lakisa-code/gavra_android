#!/usr/bin/env python3
import re
import os
import glob

def update_all_dart_files():
    """Update all .dart files in lib/ directory"""
    
    dart_files = glob.glob("lib/**/*.dart", recursive=True)
    
    for file_path in dart_files:
        print(f"📂 Obrađujem: {file_path}")
        
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            original_content = content
            
            # Replace .withOpacity(X) with .withValues(alpha: X)
            content = re.sub(r'\.withOpacity\(([0-9.]+)\)', r'.withValues(alpha: \1)', content)
            
            # Replace .opacity with .a (for alpha channel)
            content = re.sub(r'\.opacity\b', r'.a', content)
            
            # Replace activeColor with activeThumbColor in Switch widgets
            content = re.sub(r'activeColor:', r'activeThumbColor:', content)
            
            # Replace value: with initialValue: in DropdownButtonFormField (more careful)
            content = re.sub(r'(\s+)value:\s*([^,\n]+),(\s*//.*)?(\s*decoration)', r'\1initialValue: \2,\3\4', content)
            
            if content != original_content:
                with open(file_path, 'w', encoding='utf-8') as f:
                    f.write(content)
                print(f"✅ Ažuriran: {file_path}")
            else:
                print(f"⏸️  Bez promena: {file_path}")
                
        except Exception as e:
            print(f"❌ Greška u {file_path}: {e}")

if __name__ == "__main__":
    print("🚀 Modernizujem sve Dart fajlove...")
    update_all_dart_files()
    print("✅ Završeno!")