#!/usr/bin/env python3
import re
import sys

def update_opacity_to_values(file_path):
    """Replace .withOpacity(X) with .withValues(alpha: X) and .opacity with .a"""
    
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Replace .withOpacity(0.X) with .withValues(alpha: 0.X)
    content = re.sub(r'\.withOpacity\(([0-9.]+)\)', r'.withValues(alpha: \1)', content)
    
    # Replace .opacity with .a (for alpha channel)
    content = re.sub(r'\.opacity\b', r'.a', content)
    
    with open(file_path, 'w', encoding='utf-8') as f:
        f.write(content)
    
    print(f"✅ Updated {file_path}")

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python update_opacity.py <file_path>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    update_opacity_to_values(file_path)