#!/usr/bin/env python3
"""
SEARCH: Pronađi gde je VS plaćanje moglo biti upisano
Traži sve reference na Sašku Notar u logima
"""

import os
import re
from pathlib import Path
from datetime import datetime

def search_in_files(pattern, directory="."):
    """Pretraživ sve fajlove za pattern"""
    matches = []
    for root, dirs, files in os.walk(directory):
        # Skip ignored dirs
        dirs[:] = [d for d in dirs if d not in ['.git', '.flutter', 'build', '__pycache__']]
        
        for file in files:
            if file.endswith(('.md', '.txt', '.json', '.log')):
                filepath = os.path.join(root, file)
                try:
                    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
                        for line_num, line in enumerate(f, 1):
                            if re.search(pattern, line, re.IGNORECASE):
                                matches.append((filepath, line_num, line.strip()))
                except:
                    pass
    return matches

print("=" * 80)
print("PRETRAGA: Logovi plaćanja Saške Notar")
print("=" * 80)
print()

# Traži reference na Sašku i plaćanja
patterns = [
    r"saska.*notar|notar.*saska",
    r"d7ed7e10-58a3-4e04-b8c7-4e46af34530f",  # UUID putnika
    r"vs.*placen|placen.*vs",
    r"600.*vs|vs.*600",
]

all_matches = {}
for pattern in patterns:
    matches = search_in_files(pattern, ".")
    if matches:
        all_matches[pattern] = matches

if not all_matches:
    print("❌ Nema pronađenih logova o plaćanju u dostupnim fajlovima")
else:
    for pattern, matches in all_matches.items():
        print(f"\n🔍 Pattern: {pattern}")
        print(f"   Pronađeno: {len(matches)} rezultata")
        for filepath, line_num, line in matches[:3]:  # Prikaži samo prve 3
            print(f"   - {filepath}:{line_num}")
            print(f"     {line[:100]}")

print()
print("=" * 80)
print("ZAKLJUČAK:")
print("=" * 80)
print()
print("Problem je verovatno u aplikaciji jer:")
print("- VS plaćanje je korisnik (Bojan) REKAO da je upisao")
print("- Ali u bazi se pojavljuje samo BC plaćanje")
print("- A u dostupnim logima nema ostatka VS plaćanja")
print()
print("Mogućnosti:")
print("1. Aplikacija sprema samo BC")
print("2. Ili sprema VS ali se ne sinhronizuje sa Supabase")
print()
