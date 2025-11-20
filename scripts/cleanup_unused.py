#!/usr/bin/env python3
"""
Script za čišćenje svih nekorišćenih delova nakon refaktoringa
"""

import re

def clean_unused_code():
    file_path = "../lib/screens/mesecni_putnici_screen.dart"
    
    # Čitamo fajl
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # 1. Ukloni _initializeControllers() funkciju kompletno
    init_pattern = r"  void _initializeControllers\(\) \{[^}]*\}\s*"
    content = re.sub(init_pattern, "", content, flags=re.DOTALL)
    
    # 2. Ukloni poziv _initializeControllers() iz initState
    init_call_pattern = r"\s*_initializeControllers\(\);\s*"
    content = re.sub(init_call_pattern, "\n", content)
    
    # 3. Ukloni sve dispose pozive za controller-e
    dispose_patterns = [
        r"\s*_imeController\.dispose\(\);\s*",
        r"\s*_tipSkoleController\.dispose\(\);\s*",
        r"\s*_brojTelefonaController\.dispose\(\);\s*", 
        r"\s*_brojTelefonaOcaController\.dispose\(\);\s*",
        r"\s*_brojTelefonaMajkeController\.dispose\(\);\s*",
        r"\s*_adresaBelaCrkvaController\.dispose\(\);\s*",
        r"\s*_adresaVrsacController\.dispose\(\);\s*",
        r"\s*_polazakBcPonController\.dispose\(\);\s*",
        r"\s*_polazakBcUtoController\.dispose\(\);\s*",
        r"\s*_polazakBcSreController\.dispose\(\);\s*",
        r"\s*_polazakBcCetController\.dispose\(\);\s*",
        r"\s*_polazakBcPetController\.dispose\(\);\s*",
        r"\s*_polazakVsPonController\.dispose\(\);\s*",
        r"\s*_polazakVsUtoController\.dispose\(\);\s*",
        r"\s*_polazakVsSreController\.dispose\(\);\s*",
        r"\s*_polazakVsCetController\.dispose\(\);\s*",
        r"\s*_polazakVsPetController\.dispose\(\);\s*",
    ]
    
    for pattern in dispose_patterns:
        content = re.sub(pattern, "\n", content)
        
    # 4. Ukloni _resetujFormuZaDodavanje() funkciju i povezane funkcije
    reset_pattern = r"  void _resetujFormuZaDodavanje\(\)[^}]*\}\s*"
    content = re.sub(reset_pattern, "", content, flags=re.DOTALL)
    
    # 5. Ukloni _sacuvajNovogPutnika() funkciju  
    save_pattern = r"  Future<void> _sacuvajNovogPutnika\(\)[^}]*\}\s*"
    content = re.sub(save_pattern, "", content, flags=re.DOTALL)
    
    # 6. Ukloni sve _buildRadniDanCheckbox i povezane widget funkcije
    widget_patterns = [
        r"  Widget _buildRadniDanCheckbox\([^}]*\}\s*",
        r"  Widget _buildVremenaPolaskaSekcija\(\)[^}]*\}\s*",
        r"  String _getRadniDaniString\(\)[^}]*\}\s*",
        r"  void _kopirajVremenaNaDrugeRadneDane\([^}]*\}\s*",
        r"  void _ocistiVremenaZaDan\([^}]*\}\s*",
        r"  void _popuniStandardnaVremena\([^}]*\}\s*",
        r"  TextEditingController _getControllerBelaCrkva\([^}]*\}\s*",
        r"  TextEditingController _getControllerVrsac\([^}]*\}\s*"
    ]
    
    for pattern in widget_patterns:
        content = re.sub(pattern, "", content, flags=re.DOTALL)
    
    # 7. Ukloni sve reference na _noviRadniDani
    content = re.sub(r"\s*_noviRadniDani\.forEach[^}]*\}\s*\);", "", content, flags=re.DOTALL)
    
    # Zapiši fajl
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print("Cleanup completed!")

if __name__ == "__main__":
    clean_unused_code()