import os
import sys
import subprocess

def get_ascii_portrait(image_path="assets/profile.jpg", out_w=40, out_h=24):
    """
    Crops the full subject (Ayush Singh) from assets/profile.jpg,
    capturing head, hair, face, neck, collar, shoulders, and kurta.
    """
    pixels = None
    width, height = 0, 0

    # 1. Try using Pillow
    try:
        from PIL import Image
        if os.path.exists(image_path):
            with Image.open(image_path) as img:
                img = img.convert("RGB")
                orig_w, orig_h = img.size
                
                # Crop around full subject (x: 20 to 380, y: 35 to 410)
                left = int(orig_w * 0.05)
                top = int(orig_h * 0.08)
                right = int(orig_w * 0.85)
                bottom = int(orig_h * 0.92)
                
                cropped = img.crop((left, top, right, bottom))
                width, height = cropped.size
                
                raw_data = cropped.load()
                pixels = []
                for y in range(height):
                    row_pixels = [raw_data[x, y] for x in range(width)]
                    pixels.append(row_pixels)
    except Exception:
        pixels = None

    # 2. Fallback to macOS sips
    if pixels is None and os.path.exists(image_path):
        bmp_path = "assets/subject_full.bmp"
        crop_jpg = "assets/subject_full.jpg"
        try:
            subprocess.run([
                "sips", "-c", "360", "320", "--cropOffset", "35", "0",
                image_path, "--out", crop_jpg
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
            
            subprocess.run([
                "sips", "-s", "format", "bmp", crop_jpg, "--out", bmp_path
            ], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)

            if os.path.exists(bmp_path):
                with open(bmp_path, "rb") as f:
                    hdr = f.read(54)
                    if len(hdr) == 54:
                        w = int.from_bytes(hdr[18:22], byteorder="little", signed=True)
                        h = int.from_bytes(hdr[22:26], byteorder="little", signed=True)
                        bpp = int.from_bytes(hdr[28:30], byteorder="little")
                        abs_h = abs(h)
                        row_size = int((bpp * w + 31) / 32) * 4
                        f.seek(54)
                        pixels = []
                        for _ in range(abs_h):
                            row_data = f.read(row_size)
                            row_pixels = []
                            for x in range(w):
                                b = row_data[x * 3]
                                g = row_data[x * 3 + 1]
                                r = row_data[x * 3 + 2]
                                row_pixels.append((r, g, b))
                            pixels.append(row_pixels)
                        if h > 0:
                            pixels.reverse()
                        width, height = w, abs_h
        except Exception:
            pixels = None

    if pixels is None or width == 0 or height == 0:
        return _fallback_ascii(out_w, out_h)

    # 3. ASCII conversion
    charset = " .':;=+*#%@"
    num_chars = len(charset)
    crop_top_pct = 0.08
    usable_h = height * (1.0 - crop_top_pct)

    ascii_lines = []
    for row in range(out_h):
        line = []
        y_start = int(height * crop_top_pct + row * usable_h / out_h)
        y_end   = int(height * crop_top_pct + (row + 1) * usable_h / out_h)
        
        for col in range(out_w):
            x_start = int(col * width / out_w)
            x_end   = int((col + 1) * width / out_w)
            
            total_r, total_g, total_b, count = 0, 0, 0, 0
            for y in range(y_start, min(y_end, height)):
                for x in range(x_start, min(x_end, width)):
                    r, g, b = pixels[y][x][:3]
                    total_r += r
                    total_g += g
                    total_b += b
                    count += 1
            
            if count == 0:
                line.append(" ")
                continue
            
            r = total_r / count
            g = total_g / count
            b = total_b / count
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            
            is_bg = False
            if row < 2 and (col < out_w * 0.24 or col > out_w * 0.62):
                is_bg = True
            elif row < out_h * 0.40 and col < out_w * 0.22:
                is_bg = True
            elif row < out_h * 0.42 and col > out_w * 0.58:
                is_bg = True
            elif row >= out_h * 0.42 and row < out_h * 0.65 and col > out_w * 0.68:
                is_bg = True
            elif row >= out_h * 0.65 and col > out_w * 0.76:
                is_bg = True
            elif row < out_h * 0.50 and lum > 135 and abs(r - g) < 18 and abs(r - b) < 18:
                is_bg = True
            
            if is_bg:
                line.append(" ")
            else:
                norm = 1.0 - (lum / 255.0)
                norm = (norm - 0.14) / (0.86 - 0.14)
                norm = max(0.0, min(1.0, norm))
                norm = norm ** 1.15
                
                idx = int(norm * (num_chars - 1))
                char = charset[max(0, min(num_chars - 1, idx))]
                
                if char in ("'", "`"):
                    char = " "
                if char in (".", ":", ";") and (col < out_w * 0.24 or col > out_w * 0.58):
                    char = " "
                line.append(char)
        
        ascii_lines.append("".join(line).rstrip())
    
    return ascii_lines

def _fallback_ascii(out_w, out_h):
    return [
        "           ;=+*+=++=+=;;;               ",
        "           ;=++==++=++;::               ",
        "          #%@%@@@@%++;:::               ",
        "          %%%@@@%@@*=::                 ",
        "          @@@@@#+**+:                   ",
        "          %%@%+=*%*;                    ",
        "          *++*=;=+;:                    ",
        "          %++#*++**;                    ",
        "          ++*%%%#**                     ",
        "          ++**#@%=;                     ",
        "       =++**+*%%%#+=:                   ",
        "    +++++++****###****                  ",
        " =+++++++*+*+*+*******=                 ",
        " +****+++++*+********#*:   +            ",
        " ******++++****+*****##+; ==            ",
        " ***##***********#*##%#*+=*             ",
        " *####********+**######*=+=*+*#*        ",
        " *#%%#*****#******##%##**#+*#**=        ",
        " *#%%*#***#**+****##%#*###= +*+         ",
        " ##%%************#*##**#= ++=**=        ",
        " ####**+*#********###*+**++#*+*+        ",
        " *#****+***+*******##**##**%%#*+        ",
        " *#*+**+#*********##%**###%%#%%#        ",
        " *##**+*#*********##%#***++**+++        ",
    ]

if __name__ == "__main__":
    lines = get_ascii_portrait()
    for l in lines:
        print(l)
