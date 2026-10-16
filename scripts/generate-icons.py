import struct
import zlib
import os
import math
import subprocess

def make_png(width, height, draw_fn):
    raw_data = bytearray()
    for y in range(height):
        raw_data.append(0) # Filter type 0 (None)
        for x in range(width):
            r, g, b, a = draw_fn(x, y, width, height)
            raw_data.extend([r, g, b, a])
            
    def chunk(tag, data):
        return struct.pack("!I", len(data)) + tag + data + struct.pack("!I", zlib.crc32(tag + data) & 0xffffffff)

    header = b"\x89PNG\r\n\x1a\n"
    ihdr_data = struct.pack("!IIBBBBB", width, height, 8, 6, 0, 0, 0)
    ihdr = chunk(b"IHDR", ihdr_data)
    idat = chunk(b"IDAT", zlib.compress(bytes(raw_data), 9))
    iend = chunk(b"IEND", b"")
    return header + ihdr + idat + iend

def liquid_glass_drawer(x, y, w, h):
    nx = x / float(w)
    ny = y / float(h)
    
    # Squircle mask
    cx = nx - 0.5
    cy = ny - 0.5
    dx = max(0.0, abs(cx) - (0.5 - 0.18))
    dy = max(0.0, abs(cy) - (0.5 - 0.18))
    dist = math.sqrt(dx*dx + dy*dy)
    if dist > 0.18:
        return (0, 0, 0, 0) # transparent
    
    # Outer specular edge
    is_top_border = (dist > 0.14 and ny < 0.45)
    
    # Liquid Glass Gradient background: daylight porcelain to luminous sky blue
    # (#f0f9ff to #dbeafe)
    t = (nx + ny) * 0.5
    r = int(240 - t * 25)
    g = int(249 - t * 25)
    b = int(255 - t * 5)
    
    if is_top_border:
        return (255, 255, 255, 255)
    
    # Stylized 3D Glass Keycap / Bubble in Center [0.22, 0.26] to [0.78, 0.74]
    if nx >= 0.22 and nx <= 0.78 and ny >= 0.26 and ny <= 0.74:
        # Keycap squircle
        k_cx = (nx - 0.50) / 0.28
        k_cy = (ny - 0.50) / 0.24
        k_dx = max(0.0, abs(k_cx) - 0.7)
        k_dy = max(0.0, abs(k_cy) - 0.7)
        k_dist = math.sqrt(k_dx*k_dx + k_dy*k_dy)
        
        if k_dist <= 0.3:
            # Inside the keycap: Deep Royal Cobalt gradient (#0284c7 to #2563eb)
            kt = (nx + ny) * 0.5
            kr = int(2 + kt * 35)
            kg = int(132 - kt * 33)
            kb = int(235 - kt * 20)
            
            # Three crisp white typing indicator dots
            dots = [0.36, 0.50, 0.64]
            for dx_center in dots:
                dot_dist = math.sqrt((nx - dx_center)**2 + (ny - 0.50)**2)
                if dot_dist < 0.045:
                    return (255, 255, 255, 255) # white dot
            
            # Top specular inside keycap
            if ny < 0.38 and k_dist < 0.25:
                kr = min(255, kr + 60)
                kg = min(255, kg + 60)
                kb = min(255, kb + 30)
                
            return (kr, kg, kb, 255)
            
    return (r, g, b, 255)

base_dir = "/Volumes/ExternalSSD/Projects/lazytype"
os.makedirs(f"{base_dir}/extension/icons", exist_ok=True)
os.makedirs(f"{base_dir}/phone/public/icons", exist_ok=True)

# Generate PWA & Extension Icons
web_sizes = {
    f"{base_dir}/extension/icons/icon-16.png": 16,
    f"{base_dir}/extension/icons/icon-48.png": 48,
    f"{base_dir}/extension/icons/icon-128.png": 128,
    f"{base_dir}/phone/public/icons/icon-192.png": 192,
    f"{base_dir}/phone/public/icons/icon-512.png": 512,
}

for path, size in web_sizes.items():
    png_data = make_png(size, size, liquid_glass_drawer)
    with open(path, "wb") as f:
        f.write(png_data)
    print(f"Generated {path} ({size}x{size})")

# Build macOS AppIcon.iconset -> AppIcon.icns
iconset_dir = f"{base_dir}/dist/AppIcon.iconset"
os.makedirs(iconset_dir, exist_ok=True)

mac_sizes = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
]

for filename, size in mac_sizes:
    png_data = make_png(size, size, liquid_glass_drawer)
    target_path = os.path.join(iconset_dir, filename)
    with open(target_path, "wb") as f:
        f.write(png_data)

icns_path = f"{base_dir}/dist/AppIcon.icns"
try:
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", icns_path], check=True)
    print(f"Generated macOS AppIcon.icns at {icns_path}")
except Exception as e:
    print(f"iconutil warning: {e}")
