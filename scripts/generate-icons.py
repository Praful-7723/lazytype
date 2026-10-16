import struct
import zlib
import os
import math

def make_png(width, height, draw_fn):
    # RGBA
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

def icon_drawer(x, y, w, h):
    # Normalized coords [0, 1]
    nx = x / float(w)
    ny = y / float(h)
    
    # Rounded squircle distance
    cx = nx - 0.5
    cy = ny - 0.5
    r_corner = 0.42
    # Simple rounded rect mask
    dx = max(0.0, abs(cx) - (0.5 - 0.15))
    dy = max(0.0, abs(cy) - (0.5 - 0.15))
    dist = math.sqrt(dx*dx + dy*dy)
    if dist > 0.15:
        return (0, 0, 0, 0) # transparent
    
    # Modern gradient: deep indigo (30, 41, 59) to electric blue/cyan (14, 165, 233)
    t = (nx + ny) * 0.5
    bg_r = int(24 + t * 10)
    bg_g = int(30 + t * 110)
    bg_b = int(70 + t * 170)
    
    # Inside icon: draw stylized keyboard / remote bubble
    # Message bubble bounds: [0.22, 0.25] to [0.78, 0.65]
    bx = nx >= 0.22 and nx <= 0.78
    by = ny >= 0.25 and ny <= 0.62
    
    # Speech bubble tail
    tail = (nx >= 0.30 and nx <= 0.42 and ny > 0.60 and ny <= 0.75 and (nx - 0.30) < (0.75 - ny)*0.8)
    
    if (bx and by) or tail:
        # Check inner keys (3 little typing dots or keyboard keys)
        dot1 = (nx - 0.35)**2 + (ny - 0.44)**2 < 0.045**2
        dot2 = (nx - 0.50)**2 + (ny - 0.44)**2 < 0.045**2
        dot3 = (nx - 0.65)**2 + (ny - 0.44)**2 < 0.045**2
        if dot1 or dot2 or dot3:
            return (bg_r, bg_g, bg_b, 255) # cutouts
        return (255, 255, 255, 255) # white bubble
        
    return (bg_r, bg_g, bg_b, 255)

os.makedirs("/Volumes/ExternalSSD/Projects/lazytype/extension/icons", exist_ok=True)
os.makedirs("/Volumes/ExternalSSD/Projects/lazytype/phone/public/icons", exist_ok=True)

sizes = {
    "/Volumes/ExternalSSD/Projects/lazytype/extension/icons/icon-16.png": 16,
    "/Volumes/ExternalSSD/Projects/lazytype/extension/icons/icon-48.png": 48,
    "/Volumes/ExternalSSD/Projects/lazytype/extension/icons/icon-128.png": 128,
    "/Volumes/ExternalSSD/Projects/lazytype/phone/public/icons/icon-192.png": 192,
    "/Volumes/ExternalSSD/Projects/lazytype/phone/public/icons/icon-512.png": 512,
}

for path, size in sizes.items():
    png_data = make_png(size, size, icon_drawer)
    with open(path, "wb") as f:
        f.write(png_data)
    print(f"Generated {path} ({size}x{size}, {len(png_data)} bytes)")
