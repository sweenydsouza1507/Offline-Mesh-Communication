import os
import time
import urllib.request
import math

# ── Vamanjoor bounding box ────────────────────────────────────────────────────
NORTH = 12.9100
SOUTH = 12.8800
EAST  = 74.8600
WEST  = 74.8300

# Zoom levels to download
ZOOM_LEVELS = [13, 14, 15, 16]

OUTPUT_DIR = "tiles"

def deg2tile(lat, lon, zoom):
    lat_r = math.radians(lat)
    n = 2 ** zoom
    x = int((lon + 180.0) / 360.0 * n)
    y = int((1.0 - math.asinh(math.tan(lat_r)) / math.pi) / 2.0 * n)
    return x, y

def download_tiles():
    total = 0
    skipped = 0
    failed = 0

    for zoom in ZOOM_LEVELS:
        x_min, y_max = deg2tile(SOUTH, WEST, zoom)
        x_max, y_min = deg2tile(NORTH, EAST, zoom)

        count = (x_max - x_min + 1) * (y_max - y_min + 1)
        print(f'\nZoom {zoom}: {count} tiles')

        for x in range(x_min, x_max + 1):
            for y in range(y_min, y_max + 1):
                path = os.path.join(OUTPUT_DIR, str(zoom), str(x))
                os.makedirs(path, exist_ok=True)
                filepath = os.path.join(path, f'{y}.png')

                if os.path.exists(filepath):
                    skipped += 1
                    continue

                url = f'https://tile.openstreetmap.org/{zoom}/{x}/{y}.png'
                headers = {'User-Agent': 'CrowdLink/1.0 (educational project)'}

                try:
                    req = urllib.request.Request(url, headers=headers)
                    with urllib.request.urlopen(req, timeout=10) as response:
                        with open(filepath, 'wb') as f:
                            f.write(response.read())
                    total += 1
                    print(f'  ✓ {zoom}/{x}/{y}')
                    time.sleep(0.5)  # be polite to OSM servers
                except Exception as e:
                    print(f'  ✗ {zoom}/{x}/{y}: {e}')
                    failed += 1

    print(f'\n✅ Done! Downloaded: {total} | Skipped: {skipped} | Failed: {failed}')
    print(f'📁 Tiles saved to: {os.path.abspath(OUTPUT_DIR)}')

    # Count total size
    total_size = 0
    for dirpath, dirnames, filenames in os.walk(OUTPUT_DIR):
        for f in filenames:
            total_size += os.path.getsize(os.path.join(dirpath, f))
    print(f'💾 Total size: {total_size / 1024 / 1024:.1f} MB')

if __name__ == '__main__':
    print('🗺  Downloading Vamanjoor tiles...')
    print(f'   Area: {SOUTH},{WEST} → {NORTH},{EAST}')
    print(f'   Zooms: {ZOOM_LEVELS}')
    download_tiles()