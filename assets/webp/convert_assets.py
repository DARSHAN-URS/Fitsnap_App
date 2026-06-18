import os
import sys

def convert_to_webp(source_dir, dest_dir):
    if not os.path.exists(dest_dir):
        os.makedirs(dest_dir)
        
    for filename in os.listdir(source_dir):
        if filename.lower().endswith(('.png', '.jpg', '.jpeg')):
            img_path = os.path.join(source_dir, filename)
            dest_path = os.path.join(dest_dir, os.path.splitext(filename)[0] + '.webp')
            try:
                from PIL import Image
                with Image.open(img_path) as img:
                    img.save(dest_path, 'webp', quality=85)
                print(f"Successfully converted {filename} to WebP.")
            except Exception as e:
                print(f"Error converting {filename}: {e}")

if __name__ == '__main__':
    # Directories
    current_dir = os.path.dirname(os.path.abspath(__file__)) # assets/webp
    src = os.path.join(os.path.dirname(current_dir), 'images') # assets/images
    dest = current_dir # assets/webp
    
    # Check if pillow is installed
    try:
        import PIL
    except ImportError:
        print("Pillow library is not installed. Please run: pip install Pillow")
        sys.exit(1)
        
    convert_to_webp(src, dest)
