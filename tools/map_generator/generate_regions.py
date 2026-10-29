#!/usr/bin/env python3
"""Procedural continent generator for WORLD EMPIRES (Python stdlib only).

Deterministic: the same arguments always produce the same file.
Pipeline: random sites -> Lloyd relaxation -> Voronoi cells -> grow one continent
from the highest "land score" -> fill inland holes -> terrain -> JSON.

Usage (from the project root):
    python tools/map_generator/generate_regions.py \
        --seed 20260101 --sites 600 --target 230 \
        --out data/regions/regions.json [--preview preview.png]
"""
import argparse
import heapq
import json
import math
import random
import sys

WIDTH = 1600.0
HEIGHT = 1000.0
MIN_BORDER = 2.0       # shared border shorter than this is not a neighbor link
EPS = 1e-7
FORMAT_VERSION = 1
TERRAINS = ["plains", "forest", "hills", "mountain", "desert"]


# ---------------------------------------------------------------- noise

def _hash01(ix, iy, seed):
    h = (ix * 374761393 + iy * 668265263 + seed * 2246822519) & 0xFFFFFFFF
    h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
    h ^= h >> 16
    return h / 0xFFFFFFFF


def _smooth(t):
    return t * t * (3.0 - 2.0 * t)


def value_noise(x, y, seed):
    x0, y0 = math.floor(x), math.floor(y)
    fx, fy = _smooth(x - x0), _smooth(y - y0)
    a = _hash01(x0, y0, seed)
    b = _hash01(x0 + 1, y0, seed)
    c = _hash01(x0, y0 + 1, seed)
    d = _hash01(x0 + 1, y0 + 1, seed)
    top = a + (b - a) * fx
    bottom = c + (d - c) * fx
    return top + (bottom - top) * fy


def fbm(x, y, seed, octaves=4):
    total = norm = 0.0
    amp, freq = 1.0, 1.0
    for octave in range(octaves):
        total += amp * value_noise(x * freq, y * freq, seed + octave * 101)
        norm += amp
        amp *= 0.5
        freq *= 2.0
    return total / norm


# ------------------------------------------------------------- voronoi

def _clip(poly, a, b, c, new_label):
    """Keep the half plane a*x + b*y <= c. poly = [(vertex, label of edge to next vertex)]."""
    out = []
    n = len(poly)
    for i in range(n):
        p, label_p = poly[i]
        q = poly[(i + 1) % n][0]
        dp = a * p[0] + b * p[1] - c
        dq = a * q[0] + b * q[1] - c
        p_in, q_in = dp <= 0.0, dq <= 0.0
        if p_in and q_in:
            out.append((p, label_p))
        elif p_in and not q_in:
            t = dp / (dp - dq)
            cut = (p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t)
            out.append((p, label_p))
            out.append((cut, new_label))
        elif (not p_in) and q_in:
            t = dp / (dp - dq)
            cut = (p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t)
            out.append((cut, label_p))
    return out


def _dedupe(poly):
    out = []
    n = len(poly)
    for i in range(n):
        p = poly[i][0]
        q = poly[(i + 1) % n][0]
        if math.hypot(p[0] - q[0], p[1] - q[1]) >= EPS:
            out.append(poly[i])
    return out


def voronoi_cell(index, sites):
    s = sites[index]
    poly = [((0.0, 0.0), -1), ((WIDTH, 0.0), -1), ((WIDTH, HEIGHT), -1), ((0.0, HEIGHT), -1)]
    others = sorted((j for j in range(len(sites)) if j != index),
                    key=lambda j: (sites[j][0] - s[0]) ** 2 + (sites[j][1] - s[1]) ** 2)
    radius = max(math.hypot(v[0] - s[0], v[1] - s[1]) for v, _ in poly)
    for j in others:
        t = sites[j]
        dist = math.hypot(t[0] - s[0], t[1] - s[1])
        if dist > 2.0 * radius:
            break
        a = 2.0 * (t[0] - s[0])
        b = 2.0 * (t[1] - s[1])
        c = (t[0] ** 2 + t[1] ** 2) - (s[0] ** 2 + s[1] ** 2)
        poly = _clip(poly, a, b, c, j)
        radius = max(math.hypot(v[0] - s[0], v[1] - s[1]) for v, _ in poly)
    return _dedupe(poly)


def centroid(poly):
    area = cx = cy = 0.0
    n = len(poly)
    for i in range(n):
        x0, y0 = poly[i][0]
        x1, y1 = poly[(i + 1) % n][0]
        cross = x0 * y1 - x1 * y0
        area += cross
        cx += (x0 + x1) * cross
        cy += (y0 + y1) * cross
    area *= 0.5
    if abs(area) < 1e-9:
        return (sum(v[0] for v, _ in poly) / n, sum(v[1] for v, _ in poly) / n)
    return (cx / (6.0 * area), cy / (6.0 * area))


def build_cells(sites):
    return [voronoi_cell(i, sites) for i in range(len(sites))]


# ------------------------------------------------------------ the map

def neighbor_graph(cells):
    """index -> set of neighbor indexes; also returns which cells touch the world edge."""
    border = []
    touches_edge = []
    for poly in cells:
        lengths = {}
        edge_len = 0.0
        n = len(poly)
        for i in range(n):
            (x0, y0), label = poly[i]
            x1, y1 = poly[(i + 1) % n][0]
            length = math.hypot(x1 - x0, y1 - y0)
            if label >= 0:
                lengths[label] = lengths.get(label, 0.0) + length
            else:
                edge_len += length
        border.append(lengths)
        touches_edge.append(edge_len > MIN_BORDER)
    graph = [set() for _ in cells]
    for i, lengths in enumerate(border):
        for j, length in lengths.items():
            if length >= MIN_BORDER and border[j].get(i, 0.0) >= MIN_BORDER:
                graph[i].add(j)
                graph[j].add(i)
    return graph, touches_edge


def land_score(x, y, seed):
    nx = (x - WIDTH / 2) / (WIDTH / 2)
    ny = (y - HEIGHT / 2) / (HEIGHT / 2)
    falloff = max(0.0, 1.0 - (nx * nx * 1.0 + ny * ny * 1.15) ** 0.85)
    return 0.62 * falloff + 0.38 * fbm(x / 260.0, y / 260.0, seed)


def grow_continent(scores, graph, target):
    start = max(range(len(scores)), key=lambda i: scores[i])
    land = {start}
    heap = [(-scores[j], j) for j in graph[start]]
    heapq.heapify(heap)
    while len(land) < target and heap:
        _, i = heapq.heappop(heap)
        if i in land:
            continue
        land.add(i)
        for j in graph[i]:
            if j not in land:
                heapq.heappush(heap, (-scores[j], j))
    return land


def fill_holes(land, graph, touches_edge):
    """Sea cells not connected to the world edge become land (no inland lakes in the MVP)."""
    sea = {i for i in range(len(graph)) if i not in land}
    reached = set()
    stack = [i for i in sea if touches_edge[i]]
    while stack:
        i = stack.pop()
        if i in reached:
            continue
        reached.add(i)
        stack.extend(j for j in graph[i] if j in sea and j not in reached)
    return land | (sea - reached)


def assign_terrain(indexes, centers, seed):
    elevation = {i: fbm(centers[i][0] / 180.0, centers[i][1] / 180.0, seed + 7) for i in indexes}
    moisture = {i: fbm(centers[i][0] / 220.0, centers[i][1] / 220.0, seed + 13) for i in indexes}
    by_elevation = sorted(indexes, key=lambda i: elevation[i], reverse=True)
    count = len(indexes)
    terrain = {}
    for rank, i in enumerate(by_elevation):
        if rank < count * 0.10:
            terrain[i] = "mountain"
        elif rank < count * 0.25:
            terrain[i] = "hills"
    rest = sorted((i for i in indexes if i not in terrain), key=lambda i: moisture[i])
    for rank, i in enumerate(rest):
        if rank < len(rest) * 0.17:
            terrain[i] = "desert"
        elif rank >= len(rest) * 0.72:
            terrain[i] = "forest"
        else:
            terrain[i] = "plains"
    return terrain


def generate(seed, site_count, target):
    rng = random.Random(seed)
    sites = [(rng.uniform(10, WIDTH - 10), rng.uniform(10, HEIGHT - 10)) for _ in range(site_count)]
    for _ in range(3):  # Lloyd relaxation: evens out cell sizes
        sites = [centroid(cell) for cell in build_cells(sites)]
    cells = build_cells(sites)
    graph, touches_edge = neighbor_graph(cells)
    scores = [land_score(x, y, seed) for x, y in sites]

    land = grow_continent(scores, graph, target)
    land = fill_holes(land, graph, touches_edge)
    centers = [centroid(cell) for cell in cells]
    terrain = assign_terrain(sorted(land), centers, seed)

    order = sorted(land, key=lambda i: (round(centers[i][1] / 40.0), centers[i][0]))
    new_id = {old: n + 1 for n, old in enumerate(order)}
    regions = []
    for old in order:
        polygon = [[round(v[0], 1), round(v[1], 1)] for v, _ in cells[old]]
        regions.append({
            "id": "region_%05d" % new_id[old],
            "center": [round(centers[old][0], 1), round(centers[old][1], 1)],
            "terrain": terrain[old],
            "polygon": polygon,
            "neighbors": sorted("region_%05d" % new_id[j] for j in graph[old] if j in land),
        })
    stats = {
        "regions": len(regions),
        "touch_world_edge": sum(1 for i in land if touches_edge[i]),
        "terrain": {t: sum(1 for r in regions if r["terrain"] == t) for t in TERRAINS},
    }
    return regions, stats


def write_json(path, seed, regions):
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write('{\n"format_version": %d,\n"seed": %d,\n"width": %d,\n"height": %d,\n"regions": [\n'
                % (FORMAT_VERSION, seed, WIDTH, HEIGHT))
        f.write(",\n".join(json.dumps(r, separators=(",", ":")) for r in regions))
        f.write("\n]\n}\n")


def write_preview(path, regions):
    try:
        from PIL import Image, ImageDraw
    except ImportError:
        print("Pillow not installed, preview skipped")
        return
    colors = {"plains": (158, 199, 115), "forest": (77, 140, 82), "hills": (184, 168, 115),
              "mountain": (148, 148, 158), "desert": (224, 204, 133)}
    scale = 0.75
    image = Image.new("RGB", (int(WIDTH * scale), int(HEIGHT * scale)), (41, 69, 102))
    draw = ImageDraw.Draw(image)
    for r in regions:
        pts = [(x * scale, y * scale) for x, y in r["polygon"]]
        draw.polygon(pts, fill=colors[r["terrain"]], outline=(40, 40, 40))
    image.save(path)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--seed", type=int, default=20260101)
    parser.add_argument("--sites", type=int, default=600)
    parser.add_argument("--target", type=int, default=230)
    parser.add_argument("--out", default="data/regions/regions.json")
    parser.add_argument("--preview", default="")
    args = parser.parse_args()

    regions, stats = generate(args.seed, args.sites, args.target)
    if not 150 <= len(regions) <= 300:
        sys.exit("Region count %d is outside 150..300" % len(regions))
    write_json(args.out, args.seed, regions)
    if args.preview:
        write_preview(args.preview, regions)
    print(json.dumps(stats))


if __name__ == "__main__":
    main()
