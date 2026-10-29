#!/usr/bin/env python3
"""Places cities on the map (Python stdlib only).

Reads data/regions/regions.json and data/countries/countries.json,
writes data/cities/cities.json. Deterministic: same arguments -> same file.

Rules: every capital region gets a city (level "city"). More cities are added greedily
in the richest regions (area * terrain density), never in a region that touches another
city, so cities are spread out. The richest 30% of the other cities are "town", the rest
"settlement". One city per region.

Usage (from the project root):
    python tools/map_generator/generate_cities.py --seed 20260101
"""
import argparse
import json
import random

FORMAT_VERSION = 1
DENSITY = {"plains": 150000, "forest": 70000, "hills": 60000, "mountain": 25000, "desert": 20000}
START = ["ka", "ra", "mo", "li", "ve", "tor", "sen", "dar", "bel", "nor", "an", "el", "is",
         "or", "ul", "gar", "hal", "wen", "mar", "ost", "vik", "thal", "bra", "cor"]
END = ["burg", "ford", "holm", "stad", "grad", "ia", "on", "ar", "heim", "mere", "wick", "port"]


def polygon_area(points):
    total = 0.0
    for i, (x0, y0) in enumerate(points):
        x1, y1 = points[(i + 1) % len(points)]
        total += x0 * y1 - x1 * y0
    return abs(total) * 0.5


def make_name(rng, used):
    for _ in range(1000):
        name = (rng.choice(START) + rng.choice(START) + rng.choice(END)).capitalize()
        if name not in used:
            used.add(name)
            return name
    raise RuntimeError("could not make a unique name")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=20260101)
    parser.add_argument("--regions", default="data/regions/regions.json")
    parser.add_argument("--countries", default="data/countries/countries.json")
    parser.add_argument("--out", default="data/cities/cities.json")
    args = parser.parse_args()

    with open(args.regions, encoding="utf-8") as f:
        regions = {r["id"]: r for r in json.load(f)["regions"]}
    with open(args.countries, encoding="utf-8") as f:
        countries = json.load(f)["countries"]

    score = {rid: polygon_area(r["polygon"]) * DENSITY[r["terrain"]] for rid, r in regions.items()}
    capitals = sorted(c["capital_region"] for c in countries)

    chosen = list(capitals)
    blocked = set(chosen)
    for rid in capitals:
        blocked.update(regions[rid]["neighbors"])
    for rid in sorted(regions, key=lambda r: (-score[r], r)):
        if rid in blocked:
            continue
        chosen.append(rid)
        blocked.add(rid)
        blocked.update(regions[rid]["neighbors"])

    others = sorted((r for r in chosen if r not in capitals), key=lambda r: (-score[r], r))
    towns = set(others[: int(len(others) * 0.30)])

    rng = random.Random(args.seed)
    used = set()
    cities = []
    for n, rid in enumerate(sorted(chosen)):
        level = "city" if rid in capitals else ("town" if rid in towns else "settlement")
        cities.append({"id": "city_%05d" % (n + 1), "name": make_name(rng, used),
                       "region_id": rid, "level": level})

    with open(args.out, "w", encoding="utf-8", newline="\n") as f:
        f.write('{\n"format_version": %d,\n"cities": [\n' % FORMAT_VERSION)
        f.write(",\n".join(json.dumps(c, separators=(",", ":")) for c in cities))
        f.write("\n]\n}\n")
    levels = {}
    for c in cities:
        levels[c["level"]] = levels.get(c["level"], 0) + 1
    print(json.dumps({"cities": len(cities), "levels": levels}))


if __name__ == "__main__":
    main()
