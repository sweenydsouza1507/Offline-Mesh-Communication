import os
import time
import urllib.request
import math

# ── Mangalore city (wide area) ────────────────────────────────────────────────
MANGALORE = {
    'name': 'Mangalore',
    'north': 13.0200,
    'south': 12.7800,
    'east':  74.9200,
    'west':  74.7800,
    'zooms': [13, 14],
}

# ── Vamanjoor (very detailed) ─────────────────────────────────────────────────
VAMANJOOR = {
    'name': 'Vamanjoor',
    'north': 12.9100,
    'south': 12.8800,
    'east':  74.8600,
    'west':  74.8300,
    'zooms': [15, 16, 17, 18],
}

OUTPUT_DIR = "assets/tiles"

def deg2tile(lat, lon, zoom):
    lat_r = math.radians(lat)
    n = 2 ** zoom
    x = int((lon + 180.0) / 360.0 * n)
    y = int((1.0 - math.asinh(math.tan(lat_r)) / math.pi) / 2.0 * n)
    return x, y

def count_tiles(area):
    total = 0
    for zoom in area['zooms']:
        x_min, y_max = deg2tile(area['south'], area['west'], zoom)
        x_max, y_min = deg2tile(area['north'], area['east'], zoom)
        total += (x_max - x_min + 1) * (y_max - y_min + 1)
    return total

def download_area(area):
    print(f"\n{'='*50}")
    print(f"Downloading: {area['name']}")
    print(f"Zooms: {area['zooms']}")
    total_tiles = count_tiles(area)
    print(f"Total tiles: {total_tiles}")
    print('='*50)

    downloaded = 0
    skipped = 0
    failed = 0
    done = 0

    for zoom in area['zooms']:
        x_min, y_max = deg2tile(area['south'], area['west'], zoom)
        x_max, y_min = deg2tile(area['north'], area['east'], zoom)
        count = (x_max - x_min + 1) * (y_max - y_min + 1)
        print(f'\nZoom {zoom}: {count} tiles')

        for x in range(x_min, x_max + 1):
            for y in range(y_min, y_max + 1):
                path = os.path.join(OUTPUT_DIR, str(zoom), str(x))
                os.makedirs(path, exist_ok=True)
                filepath = os.path.join(path, f'{y}.png')
                done += 1
                progress = (done / total_tiles) * 100

                if os.path.exists(filepath):
                    skipped += 1
                    continue

                url = f'https://tile.openstreetmap.org/{zoom}/{x}/{y}.png'
                headers = {'User-Agent': 'CrowdLink/1.0 (educational project)'}
                try:
                    req = urllib.request.Request(url, headers=headers)
                    with urllib.request.urlopen(req, timeout=15) as response:
                        with open(filepath, 'wb') as f:
                            f.write(response.read())
                    downloaded += 1
                    print(f'  [{progress:.0f}%] ✓ {zoom}/{x}/{y}')
                    time.sleep(0.3)
                except Exception as e:
                    print(f'  [{progress:.0f}%] ✗ {zoom}/{x}/{y}: {e}')
                    failed += 1

    return downloaded, skipped, failed

def generate_pubspec():
    lines = []
    for dirpath, dirnames, filenames in os.walk(OUTPUT_DIR):
        for f in sorted(filenames):
            if f.endswith('.png'):
                full = os.path.join(dirpath, f).replace('\\', '/')
                # normalize to assets/tiles/...
                idx = full.find('assets/tiles')
                if idx >= 0:
                    rel = full[idx:]
                    lines.append(f'    - {rel}')
    with open('tile_paths.txt', 'w') as f:
        f.write('\n'.join(sorted(set(lines))))
    print(f'\n📋 tile_paths.txt generated with {len(lines)} entries')

def main():
    print('🗺  CrowdLink Offline Map Downloader')
    print('   Mangalore city + Vamanjoor zoom 18')
    os.makedirs(OUTPUT_DIR, exist_ok=True)

    m_count = count_tiles(MANGALORE)
    v_count = count_tiles(VAMANJOOR)
    total = m_count + v_count

    print(f'\n📊 Tiles to download:')
    print(f'   Mangalore (zoom 13-14): {m_count} tiles')
    print(f'   Vamanjoor (zoom 15-18): {v_count} tiles')
    print(f'   Total: {total} tiles')
    print(f'   Estimated size: ~{total * 20 // 1024}MB')

    t_dl, t_sk, t_fail = 0, 0, 0
    for area in [MANGALORE, VAMANJOOR]:
        dl, sk, fail = download_area(area)
        t_dl += dl
        t_sk += sk
        t_fail += fail

    print(f'\n{"="*50}')
    print(f'✅ COMPLETE!')
    print(f'   Downloaded: {t_dl} | Skipped: {t_sk} | Failed: {t_fail}')

    total_size = 0
    for dirpath, dirnames, filenames in os.walk(OUTPUT_DIR):
        for f in filenames:
            total_size += os.path.getsize(os.path.join(dirpath, f))
    print(f'   Total size: {total_size / 1024 / 1024:.1f} MB')
    generate_pubspec()
    print('\n🎉 Done! Paste tile_paths.txt into pubspec.yaml flutter.assets')

if __name__ == '__main__':
    main()