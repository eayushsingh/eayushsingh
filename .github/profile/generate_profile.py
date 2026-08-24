#!/usr/bin/env python3
import os
import sys

# Add script directory to sys.path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from ascii import get_ascii_portrait
from github_api import fetch_github_stats
from layout import get_profile_data
from svg import generate_svg

def main():
    root_dir = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
    generated_dir = os.path.join(root_dir, "generated")
    os.makedirs(generated_dir, exist_ok=True)
    
    photo_path = os.path.join(root_dir, "assets", "profile.jpg")
    
    print("--- [1/3] Processing Photograph to ASCII Portrait ---")
    import re
    java_path = os.path.join(root_dir, "Main.java")
    ascii_lines = []
    if os.path.exists(java_path):
        try:
            with open(java_path, "r", encoding="utf-8") as f:
                java_content = f.read()
            match = re.search(r"int\[\]\[\] BRIGHTNESS = \{(.*?)\};", java_content, re.DOTALL)
            if match:
                brightness_text = match.group(1).strip()
                rows = re.findall(r"\{(.*?)\}", brightness_text)
                ramp = " .:-=+*#%@"
                ramp_len = len(ramp)
                step = 256 // ramp_len
                for r in rows:
                    row_vals = [int(x) for x in r.split(",") if x.strip()]
                    if row_vals:
                        line = []
                        for val in row_vals:
                            darkness = 255 - val
                            ramp_pos = 0
                            threshold = step
                            while darkness >= threshold and ramp_pos < ramp_len - 1:
                                ramp_pos += 1
                                threshold += step
                            line.append(ramp[ramp_pos])
                        ascii_lines.append("".join(line))
        except Exception as e:
            print(f"Error parsing Main.java: {e}")
            
    if not ascii_lines:
        print("Fallback to image processing...")
        ascii_lines = get_ascii_portrait(photo_path, out_w=48, out_h=32)
    
    print(f"Generated {len(ascii_lines)} lines of ASCII portrait.")
    if len(ascii_lines) > 50:
        ascii_lines = ascii_lines[:50]
        print(f"Concised ASCII portrait to {len(ascii_lines)} lines.")

    print("--- [2/3] Fetching Live GitHub Metrics ---")
    profile = get_profile_data()
    stats = fetch_github_stats(profile["github_login"])
    print(f"Metrics: Repos={stats['repos']}, Stars={stats['stars']}, Followers={stats['followers']}")

    print("--- [3/3] Compiling SVG Cards ---")
    # Dark Mode SVG
    dark_svg = generate_svg(profile, ascii_lines, stats, theme="dark")
    dark_path = os.path.join(generated_dir, "profile-dark.svg")
    with open(dark_path, "w", encoding="utf-8") as f:
        f.write(dark_svg)
    print(f"Written: {dark_path}")

    # Light Mode SVG
    light_svg = generate_svg(profile, ascii_lines, stats, theme="light")
    light_path = os.path.join(generated_dir, "profile-light.svg")
    with open(light_path, "w", encoding="utf-8") as f:
        f.write(light_svg)
    print(f"Written: {light_path}")

    # Also keep assets/terminal.svg synchronized for backward compatibility
    terminal_path = os.path.join(root_dir, "assets", "terminal.svg")
    with open(terminal_path, "w", encoding="utf-8") as f:
        f.write(dark_svg)
    print(f"Written: {terminal_path}")

    print("Profile generation completed successfully!")

if __name__ == "__main__":
    main()
