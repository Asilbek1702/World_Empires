#!/usr/bin/env python3
"""Splits the generated continent into starting countries (Python stdlib only).

Reads data/regions/regions.json, writes data/countries/countries.json.
Deterministic: the same arguments always produce the same file.

Method: capitals are picked far apart (farthest-point sampling). Then the country with the
fewest regions repeatedly claims the free neighbor region closest to its capital.
Result: compact, connected, nearly equal-sized territories.

Usage (from the project root):
    python tools/map_generator/generate_countries.py --seed 20260101 --countries 6 \
        --regions data/regions/regions.json --out data/countries/countries.json [--preview p.png]
"""
import argparse
import json
import math
import random
import sys

FORMAT_VERSION = 1
NAMES = ["Aldoria", "Brevland", "Corvania", "Dravenia", "Eskara", "Falmark", "Garonia", "Hestria"]
COLORS = ["#c0392b", "#2e86c1", "#d4ac0d", "#8e44ad", "#16a085", "#e67e22", "#d35480", "#5d6d7e"]


def load_regions(path):
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    return {r["id"]: r for r in data["regions"]}


def dist(a, b):
    return math.hypot(a[0] - b[0], a[1] - b[1])


def pick_capitals(regions, count, rng):
    ids = sorted(regions)
    cx = sum(regions[i]["center"][0] for i in ids) / len(ids)
    cy = sum(regions[i]["center"][1] for i in ids) / len(ids)
    # first capital: far from the middle, with a little seeded randomness among the 10 farthest
    far = sorted(ids, key=lambda i: -dist(regions[i]["center"], (cx, cy)))[:10]
    capitals = [rng.choice(far)]
    while len(capitals) < count:
        best = max(ids, key=lambda i: min(dist(regions[i]["center"], regions[c]["center"]) for c in capitals))
        capitals.append(best)
    return capitals


def split(regions, capitals):
    owner = {c: n for n, c in enumerate(capitals)}
    sizes = [1] * len(capitals)
    active = set(range(len(capitals)))
    while len(owner) < len(regions) and active:
        country = min(active, key=lambda n: (sizes[n], n))
        capital_center = regions[capitals[country]]["center"]
        candidates = {
            nb for rid, n in owner.items() if n == country
            for nb in regions[rid]["neighbors"] if nb not in owner
        }
        if not candidates:
            active.discard(country)
            continue
        chosen = min(sorted(candidates), key=lambda r: dist(regions[r]["center"], capital_center))
        owner[chosen] = country
        sizes[country] += 1
    return owner


def write_json(path, countries):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write('{\n"format_version": %d,\n"countries": [\n' % FORMAT_VERSION)
        f.write(",\n".join(json.dumps(c, separators=(",", ":")) for c in countries))
        f.write("\n]\n}\n")


def write_preview(path, regions, countries):
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        print("Pillow not installed, preview skipped")
        return
    color_of = {}
    for c in countries:
        rgb = tuple(int(c["color"][i:i + 2], 16) for i in (1, 3, 5))
        for rid in c["regions"]:
            color_of[rid] = rgb
    scale = 0.75
    image = Image.new("RGB", (int(1600 * scale), int(1000 * scale)), (41, 69, 102))
    draw = ImageDraw.Draw(image)
    for rid, r in regions.items():
        draw.polygon([(x * scale, y * scale) for x, y in r["polygon"]], fill=color_of[rid], outline=(30, 30, 30))
    for c in countries:
        x, y = regions[c["capital_region"]]["center"]
        draw.ellipse((x * scale - 5, y * scale - 5, x * scale + 5, y * scale + 5), fill=(255, 255, 255), outline=(0, 0, 0))
    image.save(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=20260101)
    parser.add_argument("--countries", type=int, default=6)
    parser.add_argument("--regions", default="data/regions/regions.json")
    parser.add_argument("--out", default="data/countries/countries.json")
    parser.add_argument("--preview", default="")
    args = parser.parse_args()
    if not 4 <= args.countries <= len(NAMES):
        sys.exit("--countries must be between 4 and %d" % len(NAMES))

    regions = load_regions(args.regions)
    rng = random.Random(args.seed)
    capitals = pick_capitals(regions, args.countries, rng)
    owner = split(regions, capitals)
    if len(owner) != len(regions):
        sys.exit("Some regions were not claimed (map not connected?)")

    # ids follow the capital's x position, west to east
    order = sorted(range(len(capitals)), key=lambda n: regions[capitals[n]]["center"][0])
    countries = []
    for position, n in enumerate(order):
        members = sorted(r for r, o in owner.items() if o == n)
        countries.append({
            "id": "country_%05d" % (position + 1),
            "name": NAMES[position],
            "color": COLORS[position],
            "capital_region": capitals[n],
            "regions": members,
        })
    write_json(args.out, countries)
    if args.preview:
        write_preview(args.preview, regions, countries)
    print(json.dumps({"countries": len(countries), "sizes": [len(c["regions"]) for c in countries]}))


if __name__ == "__main__":
    main()
