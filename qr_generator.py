#!/usr/bin/env python3
"""
🎯 QR CODE GENERATOR ZA GAVRA APLIKACIJU
Generiše QR kod za interno testiranje link
"""

import qrcode
from PIL import Image, ImageDraw, ImageFont
import os

def create_gavra_qr():
    """Kreira QR kod za Gavra aplikaciju"""
    
    # 🔗 Test link
    test_link = "https://play.google.com/apps/internaltest/4700043550950695533"
    
    # 🎨 QR kod konfiguracija
    qr = qrcode.QRCode(
        version=1,
        error_correction=qrcode.constants.ERROR_CORRECT_L,
        box_size=10,
        border=4,
    )
    
    qr.add_data(test_link)
    qr.make(fit=True)
    
    # 🖼️ Kreiraj QR kod sliku
    qr_img = qr.make_image(fill_color="black", back_color="white")
    
    # 📐 Kreiranje canvas-a sa tekstom
    canvas_width = 600
    canvas_height = 700
    canvas = Image.new('RGB', (canvas_width, canvas_height), 'white')
    
    # 📍 Pozicioniraj QR kod
    qr_size = 400
    qr_img_resized = qr_img.resize((qr_size, qr_size))
    qr_x = (canvas_width - qr_size) // 2
    qr_y = 80
    
    canvas.paste(qr_img_resized, (qr_x, qr_y))
    
    # ✏️ Dodaj tekst
    draw = ImageDraw.Draw(canvas)
    
    try:
        # Pokušaj da učitaš font
        title_font = ImageFont.truetype("arial.ttf", 32)
        subtitle_font = ImageFont.truetype("arial.ttf", 20)
        url_font = ImageFont.truetype("arial.ttf", 14)
    except:
        # Fallback na default font
        title_font = ImageFont.load_default()
        subtitle_font = ImageFont.load_default()
        url_font = ImageFont.load_default()
    
    # 📝 Naslov
    title = "GAVRA 013"
    title_bbox = draw.textbbox((0, 0), title, font=title_font)
    title_width = title_bbox[2] - title_bbox[0]
    title_x = (canvas_width - title_width) // 2
    draw.text((title_x, 20), title, fill="black", font=title_font)
    
    # 📝 Podnaslov
    subtitle = "Interno Testiranje"
    subtitle_bbox = draw.textbbox((0, 0), subtitle, font=subtitle_font)
    subtitle_width = subtitle_bbox[2] - subtitle_bbox[0]
    subtitle_x = (canvas_width - subtitle_width) // 2
    draw.text((subtitle_x, 500), subtitle, fill="gray", font=subtitle_font)
    
    # 📝 Instrukcije
    instruction1 = "Skeniraj QR kod telefonom"
    instruction2 = "ili klikni na link ispod:"
    
    inst1_bbox = draw.textbbox((0, 0), instruction1, font=subtitle_font)
    inst1_width = inst1_bbox[2] - inst1_bbox[0]
    inst1_x = (canvas_width - inst1_width) // 2
    draw.text((inst1_x, 530), instruction1, fill="black", font=subtitle_font)
    
    inst2_bbox = draw.textbbox((0, 0), instruction2, font=subtitle_font)
    inst2_width = inst2_bbox[2] - inst2_bbox[0]
    inst2_x = (canvas_width - inst2_width) // 2
    draw.text((inst2_x, 560), instruction2, fill="black", font=subtitle_font)
    
    # 📝 URL
    short_url = "play.google.com/apps/internaltest/..."
    url_bbox = draw.textbbox((0, 0), short_url, font=url_font)
    url_width = url_bbox[2] - url_bbox[0]
    url_x = (canvas_width - url_width) // 2
    draw.text((url_x, 600), short_url, fill="blue", font=url_font)
    
    # 💾 Sačuvaj sliku
    output_path = "gavra_qr_code.png"
    canvas.save(output_path)
    
    print(f"🎉 QR kod kreiran: {output_path}")
    print(f"🔗 Link: {test_link}")
    print(f"📱 Aplikacija: Gavra 013")
    
    return output_path

if __name__ == "__main__":
    create_gavra_qr()