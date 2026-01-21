
lines = []
with open(r'c:\Users\Bojan\gavra_android\.github\workflows\unified-deploy-all.yml', 'r', encoding='utf-8') as f:
    lines = f.readlines()

new_lines = []
in_python_block = False
indent_str = "           " # 11 spaces, matching '           python3 -c "'

for line in lines:
    if 'python3 -c "' in line:
        in_python_block = True
        new_lines.append(line)
        continue
    
    if in_python_block:
        if line.strip() == '"':
            # End of block, check if it needs indentation
            new_lines.append(indent_str + '"\n')
            in_python_block = False
        else:
            # Indent the line
            new_lines.append(indent_str + line)
    else:
        new_lines.append(line)

with open(r'c:\Users\Bojan\gavra_android\.github\workflows\unified-deploy-all.yml', 'w', encoding='utf-8') as f:
    f.writelines(new_lines)

print("Indentation fixed.")
