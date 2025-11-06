#!/usr/bin/env python3
"""
🚀 Gavra Android QR Code Generator
Generiše QR kod za direktan download aplikacije
"""

import qrcode
from PIL import Image, ImageDraw, ImageFont
import os
from datetime import datetime

def generate_qr_code():
    # URL za download
    url = "https://github.com/bojanbc83/gavra_android/releases/latest/download/app-release.apk"
    
    # Kreiraj QR kod
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_L,
        box_size=10,
        border=4,
    )
    
    qr.add_data(url)
    qr.make(fit=True)
    
    # Generiši sliku
    qr_img = qr.make_image(fill_color="black", back_color="white")
    
    # Konvertuj u RGB za dodavanje teksta
    img = qr_img.convert('RGB')
    
    # Dodaj prostor za tekst ispod
    width, height = img.size
    new_height = height + 100
    new_img = Image.new('RGB', (width, new_height), 'white')
    new_img.paste(img, (0, 0))
    
    # Dodaj tekst
    draw = ImageDraw.Draw(new_img)
    try:
        font = ImageFont.truetype("arial.ttf", 20)
        font_small = ImageFont.truetype("arial.ttf", 14)
    except:
        font = ImageFont.load_default()
        font_small = ImageFont.load_default()
    
    # Glavni tekst
    text1 = "📱 GAVRA ANDROID APP"
    text2 = "Skenuj za direktan download"
    text3 = f"Generated: {datetime.now().strftime('%d.%m.%Y %H:%M')}"
    
    # Centriran tekst
    text1_width = draw.textbbox((0, 0), text1, font=font)[2]
    text2_width = draw.textbbox((0, 0), text2, font=font_small)[2]
    text3_width = draw.textbbox((0, 0), text3, font=font_small)[2]
    
    draw.text(((width - text1_width) // 2, height + 10), text1, fill="black", font=font)
    draw.text(((width - text2_width) // 2, height + 40), text2, fill="gray", font=font_small)
    draw.text(((width - text3_width) // 2, height + 65), text3, fill="lightgray", font=font_small)
    
    # Sačuvaj sliku
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"gavra_android_qr_{timestamp}.png"
    
    new_img.save(filename)
    print(f"✅ QR kod sačuvan kao: {filename}")
    print(f"🔗 URL: {url}")
    print(f"📱 Veličina: {width}x{new_height}px")
    
    return filename

if __name__ == "__main__":
    print("🚀 Gavra Android QR Generator")
    print("=" * 40)
    
    try:
        filename = generate_qr_code()
        print(f"\n✨ Gotovo! Otvori: {filename}")
    except ImportError:
        print("❌ Potreban je qrcode paket!")
        print("💡 Instaliraj sa: pip install qrcode[pil]")
    except Exception as e:
        print(f"❌ Greška: {e}")