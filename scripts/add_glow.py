from PIL import Image, ImageFilter, ImageDraw, ImageChops
import os

# Paths
source_path = r"c:\Users\Bojan\gavra_android\assets\logo_original.png"
base_path = r"c:\Users\Bojan\gavra_android\android\app\src\main\res"

# Sizes for adaptive icons (108dp base)
sizes = {
    "mdpi": 108,
    "hdpi": 162,
    "xhdpi": 216,
    "xxhdpi": 324,
    "xxxhdpi": 432
}

def add_glow_effect(img, size, glow_color=(0, 212, 255), glow_radius=None):
    """Add cyan glow effect and shadow to image"""
    
    if glow_radius is None:
        glow_radius = int(size * 0.04)  # 4% of size
    
    logo_size = int(size * 0.72)
    offset = (size - logo_size) // 2
    
    # Create canvas
    canvas = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    
    # Resize logo
    logo = img.resize((logo_size, logo_size), Image.Resampling.LANCZOS)
    
    # Create glow layers
    for i, blur_amount in enumerate([glow_radius * 3, glow_radius * 2, glow_radius]):
        alpha = 40 + i * 20  # Increasing alpha for inner layers
        
        # Create colored version for glow
        glow_layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
        
        # Extract alpha channel and colorize
        if logo.mode == 'RGBA':
            r, g, b, a = logo.split()
        else:
            logo = logo.convert('RGBA')
            r, g, b, a = logo.split()
        
        # Create cyan colored glow
        cyan_r = Image.new('L', logo.size, glow_color[0])
        cyan_g = Image.new('L', logo.size, glow_color[1])
        cyan_b = Image.new('L', logo.size, glow_color[2])
        
        # Adjust alpha for glow intensity
        glow_alpha = a.point(lambda x: min(x, alpha))
        
        colored_glow = Image.merge('RGBA', (cyan_r, cyan_g, cyan_b, glow_alpha))
        
        # Paste and blur
        glow_layer.paste(colored_glow, (offset, offset))
        glow_layer = glow_layer.filter(ImageFilter.GaussianBlur(blur_amount))
        
        # Composite
        canvas = Image.alpha_composite(canvas, glow_layer)
    
    # Add subtle shadow
    shadow_offset = int(size * 0.015)
    shadow_layer = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    
    # Create dark shadow from logo alpha
    if logo.mode == 'RGBA':
        _, _, _, a = logo.split()
    shadow_alpha = a.point(lambda x: int(x * 0.4))
    black = Image.new('L', logo.size, 0)
    shadow = Image.merge('RGBA', (black, black, black, shadow_alpha))
    shadow_layer.paste(shadow, (offset + shadow_offset, offset + shadow_offset))
    shadow_layer = shadow_layer.filter(ImageFilter.GaussianBlur(3))
    
    canvas = Image.alpha_composite(canvas, shadow_layer)
    
    # Paste original logo on top
    canvas.paste(logo, (offset, offset), logo)
    
    return canvas

# Load original
print(f"Loading: {source_path}")
original = Image.open(source_path).convert('RGBA')

# Generate all sizes
for density, size in sizes.items():
    result = add_glow_effect(original, size)
    
    output_dir = os.path.join(base_path, f"drawable-{density}")
    os.makedirs(output_dir, exist_ok=True)
    
    output_path = os.path.join(output_dir, "ic_launcher_foreground.png")
    result.save(output_path, 'PNG')
    print(f"Created: {density} ({size}px)")

# Copy xxxhdpi to drawable folder as fallback
import shutil
src = os.path.join(base_path, "drawable-xxxhdpi", "ic_launcher_foreground.png")
dst = os.path.join(base_path, "drawable", "ic_launcher_foreground.png")
shutil.copy2(src, dst)
print(f"Copied to drawable/")

print("\n✅ Glow effect added to all icons!")
