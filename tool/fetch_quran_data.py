"""
Fetch Quran data from api.alquran.cloud and bundle as JSON assets for offline use.
Downloads: Arabic Uthmani text + English translation (Asad) for all 114 surahs.
Generates: surahs_meta.json (lightweight index), page_index.json (page mapping),
           and individual surah JSON files (001.json - 114.json).
"""
import json
import os
import sys
import time
import urllib.request

API_BASE = "https://api.alquran.cloud/v1"
OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "assets", "data", "quran")
SURAHS_DIR = os.path.join(OUTPUT_DIR, "surahs")
EDITIONS = "quran-uthmani,en.asad"

def fetch_json(url):
    """Fetch JSON from URL with retry."""
    for attempt in range(3):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "Aura-App/1.0"})
            with urllib.request.urlopen(req, timeout=30) as resp:
                return json.loads(resp.read().decode("utf-8"))
        except Exception as e:
            if attempt == 2:
                raise
            print(f"  Retry {attempt+1}: {e}")
            time.sleep(2)

def fetch_surah(number):
    """Fetch a single surah with Arabic + English text."""
    url = f"{API_BASE}/surah/{number}/editions/{EDITIONS}"
    print(f"Fetching surah {number}/114...", end=" ", flush=True)
    data = fetch_json(url)
    print("OK")

    arabic_data = data["data"][0]
    english_data = data["data"][1]

    surah = {
        "number": arabic_data["number"],
        "name": arabic_data["name"],
        "englishName": arabic_data["englishName"],
        "englishNameTranslation": arabic_data["englishNameTranslation"],
        "revelationType": arabic_data["revelationType"],
        "numberOfAyahs": arabic_data["numberOfAyahs"],
        "ayahs": []
    }

    for i, ar_ayah in enumerate(arabic_data["ayahs"]):
        en_ayah = english_data["ayahs"][i]
        surah["ayahs"].append({
            "number": ar_ayah["number"],
            "numberInSurah": ar_ayah["numberInSurah"],
            "text": ar_ayah["text"],
            "translation": en_ayah["text"],
            "juz": ar_ayah["juz"],
            "page": ar_ayah["page"],
            "ruku": ar_ayah.get("ruku", 0),
            "sajda": bool(ar_ayah.get("sajda")),
        })

    return surah

def build_surahs_meta(all_surahs):
    """Build lightweight metadata index."""
    meta_list = []
    for s in all_surahs:
        pages = [a["page"] for a in s["ayahs"]]
        juzs = [a["juz"] for a in s["ayahs"]]
        meta_list.append({
            "number": s["number"],
            "name": s["name"],
            "englishName": s["englishName"],
            "englishNameTranslation": s["englishNameTranslation"],
            "revelationType": s["revelationType"],
            "numberOfAyahs": s["numberOfAyahs"],
            "startPage": min(pages),
            "endPage": max(pages),
            "startJuz": min(juzs),
            "endJuz": max(juzs),
        })
    return meta_list

def build_page_index(all_surahs):
    """Build page -> ayah mapping for page-based navigation."""
    # Collect all ayahs with their page info
    all_ayahs = []
    for s in all_surahs:
        for a in s["ayahs"]:
            all_ayahs.append({
                "surah": s["number"],
                "ayah": a["numberInSurah"],
                "globalAyah": a["number"],
                "page": a["page"],
                "juz": a["juz"],
            })

    # Group by page
    page_map = {}
    for a in all_ayahs:
        p = a["page"]
        if p not in page_map:
            page_map[p] = []
        page_map[p].append(a)

    # Build sorted index
    page_index = []
    for p in sorted(page_map.keys()):
        ayahs_on_page = page_map[p]
        page_index.append({
            "page": p,
            "juz": ayahs_on_page[0]["juz"],
            "surahs": _merge_surahs(ayahs_on_page),
        })

    return page_index

def _merge_surahs(ayahs_on_page):
    """Merge consecutive ayahs of same surah into ranges."""
    surahs = []
    current = None

    for a in ayahs_on_page:
        if current and current["surah"] == a["surah"] and current["endAyah"] == a["ayah"] - 1:
            current["endAyah"] = a["ayah"]
            current["endGlobalAyah"] = a["globalAyah"]
        else:
            if current:
                surahs.append(current)
            current = {
                "surah": a["surah"],
                "startAyah": a["ayah"],
                "endAyah": a["ayah"],
                "startGlobalAyah": a["globalAyah"],
                "endGlobalAyah": a["globalAyah"],
            }
    if current:
        surahs.append(current)

    return surahs

def main():
    os.makedirs(SURAHS_DIR, exist_ok=True)

    print("=" * 60)
    print("Quran Data Fetcher for Aura App")
    print("=" * 60)

    # Fetch all 114 surahs
    all_surahs = []
    for i in range(1, 115):
        surah = fetch_surah(i)
        all_surahs.append(surah)

        # Save individual surah file
        filename = f"{i:03d}.json"
        filepath = os.path.join(SURAHS_DIR, filename)
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(surah, f, ensure_ascii=False, indent=2)

    print(f"\nSaved 114 surah files to {SURAHS_DIR}")

    # Build and save surahs_meta.json
    meta = build_surahs_meta(all_surahs)
    meta_path = os.path.join(OUTPUT_DIR, "surahs_meta.json")
    with open(meta_path, "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)
    print(f"Saved surahs_meta.json ({len(meta)} entries)")

    # Build and save page_index.json
    page_index = build_page_index(all_surahs)
    page_path = os.path.join(OUTPUT_DIR, "page_index.json")
    with open(page_path, "w", encoding="utf-8") as f:
        json.dump(page_index, f, ensure_ascii=False, indent=2)
    print(f"Saved page_index.json ({len(page_index)} pages)")

    # Print summary
    total_ayahs = sum(s["numberOfAyahs"] for s in all_surahs)
    total_pages = len(page_index)
    total_size = sum(
        os.path.getsize(os.path.join(SURAHS_DIR, f))
        for f in os.listdir(SURAHS_DIR)
    ) + os.path.getsize(meta_path) + os.path.getsize(page_path)

    print("\n" + "=" * 60)
    print("Summary:")
    print(f"  Surahs: 114")
    print(f"  Ayahs:  {total_ayahs}")
    print(f"  Pages:  {total_pages}")
    print(f"  Total size: {total_size / 1024:.1f} KB ({total_size / 1024 / 1024:.2f} MB)")
    print("=" * 60)

if __name__ == "__main__":
    main()
