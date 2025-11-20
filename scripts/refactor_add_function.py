#!/usr/bin/env python3
"""
Script za preciznu zamenu funkcije _pokaziDijalogZaDodavanje sa pozivom novog widget-a
"""

import re

def refactor_file():
    file_path = "../lib/screens/mesecni_putnici_screen.dart"
    
    # Čitamo fajl
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 1. Dodaj import
    import_pattern = r"(import '../widgets/autocomplete_ime_field\.dart';)"
    new_import = r"\1\nimport '../widgets/add_mesecni_putnik_dialog.dart';"
    content = re.sub(import_pattern, new_import, content)
    
    # 2. Zameni funkciju
    # Tražimo početak funkcije i zatim do prve funkcije koja sledi
    start_pattern = r"  void _pokaziDijalogZaDodavanje\(\) \{"
    end_pattern = r"  void _resetujFormuZaDodavanje\(\) \{"
    
    # Pronađi početak i kraj
    start_match = re.search(start_pattern, content)
    end_match = re.search(end_pattern, content)
    
    if start_match and end_match:
        start_pos = start_match.start()
        # Tražimo poslednju zatvorenu zagradu pre sledeće funkcije
        text_between = content[start_match.end():end_match.start()]
        
        # Brojimo zagrade da nađemo where funkcija ends
        brace_count = 1  # Početna {
        i = start_match.end()
        
        while i < len(content) and brace_count > 0:
            if content[i] == '{':
                brace_count += 1
            elif content[i] == '}':
                brace_count -= 1
            i += 1
        
        if brace_count == 0:
            end_pos = i
            
            # Nova funkcija
            new_function = """  void _pokaziDijalogZaDodavanje() {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddMesecniPutnikDialog(
        onPutnikAdded: () {
          _ucitajMesecnePutnike();
        },
      ),
    );
  }

  /// 🧹 RESETUJ FORMU ZA DODAVANJE MESEČNOG PUTNIKA
  void _resetujFormuZaDodavanje() {"""
            
            # Zameni
            content = content[:start_pos] + new_function + content[end_match.start() + len("  void _resetujFormuZaDodavanje() {"):]
    
    # Zapiši fajl
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("Refaktoring completed!")

if __name__ == "__main__":
    refactor_file()