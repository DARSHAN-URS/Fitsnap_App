import os
from PIL import Image

def create_padded_icon(input_path, output_path, scale_factor=0.55):
    try:
        # Open the original image
        img = Image.open(input_path).convert("RGBA")
        
        # Calculate new size
        new_w = int(img.width * scale_factor)
        new_h = int(img.height * scale_factor)
        
        # Resize image
        img_resized = img.resize((new_w, new_h), Image.Resampling.LANCZOS)
        
        # Create a new transparent image of the original size
        new_img = Image.new("RGBA", (img.width, img.height), (0, 0, 0, 0))
        
        # Paste the resized image into the center
        paste_x = (img.width - new_w) // 2
        paste_y = (img.height - new_h) // 2
        new_img.paste(img_resized, (paste_x, paste_y), img_resized)
        
        # Save the result
        new_img.save(output_path)
        print(f"Successfully created padded icon at {output_path}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    input_file = "assets/images/logo.png"
    output_file = "assets/images/logo_icon_foreground.png"
    
    if os.path.exists(input_file):
        create_padded_icon(input_file, output_file)
    else:
        print(f"Input file not found: {input_file}")
