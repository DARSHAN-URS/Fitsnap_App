import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

def generate_screenshots():
    input_dir = r"c:\Users\Sunil\OneDrive\Desktop\HEALTH\screenshots\phone"
    output_dir = r"c:\Users\Sunil\OneDrive\Desktop\HEALTH\screenshots\10 inch"
    
    # Ensure output directory exists
    os.makedirs(output_dir, exist_ok=True)
    
    # Define screenshot configuration
    screenshot_data = [
        {
            "file": "1.jpeg",
            "title": "HEALTH DASHBOARD",
            "subtitle": "Track your daily calories, active status, and BMI",
            "name": "01_health_dashboard.png"
        },
        {
            "file": "2.jpeg",
            "title": "STRENGTH LOGGER",
            "subtitle": "Record weights, sets, reps, and muscle chains",
            "name": "02_strength_logger.png"
        },
        {
            "file": "3.jpeg",
            "title": "PROGRESS ANALYTICS",
            "subtitle": "Visualize your weight tracker, streaks, and achievements",
            "name": "03_progress_analytics.png"
        },
        {
            "file": "4.jpeg",
            "title": "WEEKLY CHALLENGES",
            "subtitle": "Push your limits with custom core & cardio tasks",
            "name": "04_weekly_challenges.png"
        },
        {
            "file": "5.jpeg",
            "title": "WORKOUT SUMMARY",
            "subtitle": "Analyze distance, duration, pace, and share stats",
            "name": "05_workout_summary.png"
        },
        {
            "file": "6.jpeg",
            "title": "NUTRITION TRACKER",
            "subtitle": "Log meals using AI camera, barcode, or text",
            "name": "06_nutrition_tracker.png"
        },
        {
            "file": "7.jpeg",
            "title": "LIVE ACTIVITY TRACKING",
            "subtitle": "Map walks and runs in real time with active GPS",
            "name": "07_live_tracking.png"
        }
    ]
    
    # Canvas Size
    canvas_w = 1200
    canvas_h = 1920
    
    # Generate background gradient canvas
    # Base gradient: Slate 900 (15, 23, 42) -> Slate 800 (30, 41, 59)
    base_grad = Image.new("RGB", (100, 100))
    for y in range(100):
        for x in range(100):
            t = (x + y) / 200.0
            r = int(15 * (1 - t) + 30 * t)
            g = int(23 * (1 - t) + 41 * t)
            b = int(42 * (1 - t) + 59 * t)
            base_grad.putpixel((x, y), (r, g, b))
    
    base_grad = base_grad.resize((canvas_w, canvas_h), Image.Resampling.BILINEAR)
    
    # Add neon glowing orbs to make the canvas look extremely premium
    # Teal orb (top-right)
    orb_teal = Image.new("RGBA", (100, 100), (0, 0, 0, 0))
    for y in range(100):
        for x in range(100):
            dist = ((x - 80)**2 + (y - 20)**2)**0.5
            if dist < 60:
                alpha = int(45 * (1 - dist / 60.0))
                orb_teal.putpixel((x, y), (0, 209, 178, alpha))
    orb_teal_resized = orb_teal.resize((canvas_w, canvas_h), Image.Resampling.BILINEAR)
    
    # Indigo orb (bottom-left)
    orb_indigo = Image.new("RGBA", (100, 100), (0, 0, 0, 0))
    for y in range(100):
        for x in range(100):
            dist = ((x - 20)**2 + (y - 80)**2)**0.5
            if dist < 70:
                alpha = int(50 * (1 - dist / 70.0))
                orb_indigo.putpixel((x, y), (99, 102, 241, alpha))
    orb_indigo_resized = orb_indigo.resize((canvas_w, canvas_h), Image.Resampling.BILINEAR)
    
    # Composite the glows together
    background = Image.alpha_composite(base_grad.convert("RGBA"), orb_teal_resized)
    background = Image.alpha_composite(background, orb_indigo_resized)
    
    # Load fonts
    font_paths_bold = ["C:\\Windows\\Fonts\\segoeuib.ttf", "C:\\Windows\\Fonts\\arialbd.ttf", "arial.ttf"]
    font_paths_regular = ["C:\\Windows\\Fonts\\segoeui.ttf", "C:\\Windows\\Fonts\\arial.ttf", "arial.ttf"]
    
    title_font = None
    for fp in font_paths_bold:
        try:
            title_font = ImageFont.truetype(fp, 56)
            break
        except:
            continue
    if not title_font:
        title_font = ImageFont.load_default()
        
    sub_font = None
    for fp in font_paths_regular:
        try:
            sub_font = ImageFont.truetype(fp, 32)
            break
        except:
            continue
    if not sub_font:
        sub_font = ImageFont.load_default()
        
    # Phone size & position
    phone_h = 1380
    phone_w = 621  # keeping 720:1600 aspect ratio (9:20 = 0.45) -> 621:1380
    paste_x = (canvas_w - phone_w) // 2
    paste_y = 290
    
    for item in screenshot_data:
        img_path = os.path.join(input_dir, item["file"])
        if not os.path.exists(img_path):
            print(f"Warning: {img_path} not found! Skipping...")
            continue
            
        print(f"Processing {item['file']} -> {item['name']}...")
        
        # Load screenshot
        screenshot = Image.open(img_path).convert("RGBA")
        
        # Resize screenshot to fit phone frame
        screenshot_resized = screenshot.resize((phone_w, phone_h), Image.Resampling.LANCZOS)
        
        # Create output image starting with the background
        canvas = background.copy()
        draw = ImageDraw.Draw(canvas)
        
        # 1. Create drop shadow layer
        shadow_layer = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
        shadow_mask = Image.new("L", (phone_w, phone_h), 0)
        shadow_draw = ImageDraw.Draw(shadow_mask)
        shadow_draw.rounded_rectangle((0, 0, phone_w, phone_h), radius=32, fill=160) # opacity of shadow
        
        shadow_img = Image.new("RGBA", (phone_w, phone_h), (0, 0, 0, 255))
        shadow_layer.paste(shadow_img, (paste_x, paste_y + 16), shadow_mask) # offset shadow downwards
        shadow_blurred = shadow_layer.filter(ImageFilter.GaussianBlur(radius=24))
        
        # Merge shadow with background
        canvas = Image.alpha_composite(canvas, shadow_blurred)
        
        # 2. Crop screenshot corners
        screen_mask = Image.new("L", (phone_w, phone_h), 0)
        screen_mask_draw = ImageDraw.Draw(screen_mask)
        screen_mask_draw.rounded_rectangle((0, 0, phone_w, phone_h), radius=32, fill=255)
        
        # Create a layer for the phone screen
        phone_layer = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
        phone_layer.paste(screenshot_resized, (paste_x, paste_y), screen_mask)
        
        # Merge phone screen
        canvas = Image.alpha_composite(canvas, phone_layer)
        
        # 3. Draw a modern bezel/frame on top
        bezel_layer = Image.new("RGBA", (canvas_w, canvas_h), (0, 0, 0, 0))
        bezel_draw = ImageDraw.Draw(bezel_layer)
        # Bezel border color: Light semi-transparent grey
        bezel_draw.rounded_rectangle(
            (paste_x, paste_y, paste_x + phone_w, paste_y + phone_h), 
            radius=32, 
            outline=(255, 255, 255, 45), 
            width=5
        )
        canvas = Image.alpha_composite(canvas, bezel_layer)
        
        # 4. Draw Typography
        draw = ImageDraw.Draw(canvas)
        
        # Render Title
        title_text = item["title"]
        title_bbox = draw.textbbox((0, 0), title_text, font=title_font)
        title_w = title_bbox[2] - title_bbox[0]
        title_x = (canvas_w - title_w) // 2
        draw.text((title_x, 90), title_text, fill=(255, 255, 255, 255), font=title_font)
        
        # Render Subtitle
        sub_text = item["subtitle"]
        sub_bbox = draw.textbbox((0, 0), sub_text, font=sub_font)
        sub_w = sub_bbox[2] - sub_bbox[0]
        sub_x = (canvas_w - sub_w) // 2
        draw.text((sub_x, 175), sub_text, fill=(148, 163, 184, 255), font=sub_font) # Slate 400
        
        # Save output image as a 24-bit PNG (without alpha channel for Play Store requirements)
        final_rgb = canvas.convert("RGB")
        out_path = os.path.join(output_dir, item["name"])
        final_rgb.save(out_path, "PNG")
        print(f"Saved {out_path}")
        
    print("Screenshot processing complete!")

if __name__ == "__main__":
    generate_screenshots()
