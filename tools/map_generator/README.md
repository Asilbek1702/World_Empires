# Map generator

Builds `data/regions/regions.json`: one continent, 150-300 regions (default 230).
Python 3, standard library only. Pillow is optional (preview image).

    python tools/map_generator/generate_regions.py --seed 20260101 --sites 600 --target 230 \
        --out data/regions/regions.json --preview preview.png

Same arguments always give the same file. The shipped map was made with the defaults.
The game never runs the generator. It only reads the JSON.
After regenerating, run `tests/run_all.sh`: test_map_data.gd checks the new map.

## Countries

`generate_countries.py` reads the map and writes `data/countries/countries.json`
(6 countries by default, capitals far apart, compact connected territories, 36-41 regions each).

    python tools/map_generator/generate_countries.py --seed 20260101 --countries 6 \
        --regions data/regions/regions.json --out data/countries/countries.json --preview countries.png

Run the map generator first, then this one. After either, run `tests/run_all.sh`.

## Cities

`generate_cities.py` reads the map and the countries and writes `data/cities/cities.json`
(61 cities by default: every capital, then the richest regions, never in two neighboring regions).

    python tools/map_generator/generate_cities.py --seed 20260101

Order: map, then countries, then cities. After any of them, run `tests/run_all.sh`.

