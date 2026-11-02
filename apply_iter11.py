#!/usr/bin/env python3
"""Applies Iteration 11 edits to existing project files. Run from the project root.
Unpack the new files first (same folder layout), then:  python apply_iter11.py
Idempotent: an edit that is already applied is skipped. Every code edit must match once."""
import pathlib
import sys

ROOT = pathlib.Path(".")
errors = []


def _read(path):
    data = (ROOT / path).read_bytes().decode("utf-8")
    return data, ("\r\n" in data)


def _write(path, text):
    (ROOT / path).write_bytes(text.encode("utf-8"))


def patch(path, old, new, required=True):
    if not (ROOT / path).exists():
        if required:
            errors.append("%s: file not found" % path)
        else:
            print("WARN   %s: file not found" % path)
        return
    text, crlf = _read(path)
    if crlf:
        old, new = old.replace("\n", "\r\n"), new.replace("\n", "\r\n")
    if new in text:
        print("skip   %s (already applied)" % path)
        return
    count = text.count(old)
    if count != 1:
        message = "%s: expected 1 match, found %d for: %r" % (path, count, old[:60])
        if required:
            errors.append(message)
        else:
            print("WARN   " + message)
        return
    _write(path, text.replace(old, new))
    print("patch  %s" % path)


def append(path, marker, block):
    text, crlf = _read(path)
    if marker in text:
        print("skip   %s (already applied)" % path)
        return
    if crlf:
        block = block.replace("\n", "\r\n")
    if not text.endswith("\n"):
        text += "\r\n" if crlf else "\n"
    _write(path, text + block)
    print("append %s" % path)


# --- Country: current research and its progress
patch("world/countries/country.gd",
      "var researched_technologies: Array[String] = []",
      'var researched_technologies: Array[String] = []\n'
      'var current_research: String = ""  # technology being researched, "" = none\n'
      'var research_progress: float = 0.0  # science collected for it, whole cents')
patch("world/countries/country.gd",
      '"researched_technologies": researched_technologies.duplicate(),',
      '"researched_technologies": researched_technologies.duplicate(),\n'
      '\t\t"current_research": current_research,\n'
      '\t\t"research_progress": research_progress,')
patch("world/countries/country.gd",
      'if not (d.get("is_player_controlled") is bool):',
      'if not (d.get("current_research") is String):\n'
      '\t\treturn null\n'
      '\tvar progress: Variant = d.get("research_progress")\n'
      '\tif not (typeof(progress) in [TYPE_INT, TYPE_FLOAT]) or not is_finite(progress) or progress < 0:\n'
      '\t\treturn null\n'
      '\tif not (d.get("is_player_controlled") is bool):')
patch("world/countries/country.gd",
      'country.is_player_controlled = d["is_player_controlled"]',
      'country.current_research = d["current_research"]\n'
      '\tcountry.research_progress = EconomyModel.round_money(float(d["research_progress"]))\n'
      '\tcountry.is_player_controlled = d["is_player_controlled"]')

# --- Economy: technology bonuses join the building bonuses
patch("economy/budget/economy_model.gd",
      "for region_id in country.regions:",
      "var tech_bonuses := TechnologyModel.country_bonuses(country)\n"
      "\tfor region_id in country.regions:")
patch("economy/budget/economy_model.gd",
      "var bonuses := ProductionModel.region_bonuses(region, cities) if not cities.is_empty() else {}",
      "var bonuses := tech_bonuses.duplicate()\n"
      "\t\tif not cities.is_empty():\n"
      "\t\t\tvar local := ProductionModel.region_bonuses(region, cities)\n"
      "\t\t\tfor type in local:\n"
      "\t\t\t\tbonuses[type] = float(bonuses.get(type, 0.0)) + float(local[type])")

# --- WorldState: signals and load check
patch("world/world_state.gd",
      "signal building_completed(city_id: String, building_id: String)",
      "signal building_completed(city_id: String, building_id: String)\n"
      "## Emitted when a country's current research or its progress changes.\n"
      "signal research_changed(country_id: String)\n"
      "## Emitted exactly once when a research finishes.\n"
      "signal technology_researched(country_id: String, technology_id: String)")
patch("world/world_state.gd",
      "\tgame_date = date\n",
      "\tif not WorldIntegrity.check_technologies(new_countries, TechnologyCatalog.get_all()).is_empty():\n"
      "\t\treturn ERR_INVALID_DATA\n\n"
      "\tgame_date = date\n")

# --- WorldIntegrity: technology rules
patch("world/world_integrity.gd",
      "problems.append_array(check_cities(state.cities, state.regions, BuildingCatalog.get_all()))",
      "problems.append_array(check_cities(state.cities, state.regions, BuildingCatalog.get_all()))\n"
      "\tproblems.append_array(check_technologies(state.countries, TechnologyCatalog.get_all()))")
append("world/world_integrity.gd", "static func check_technologies", '''

## Technologies: researched ones are known, unique and have their requirements researched;
## the current research is known, not yet researched, startable, and its progress is below the cost;
## progress without a current research must be 0. catalog: id -> Technology.
static func check_technologies(countries: Dictionary, catalog: Dictionary) -> Array[String]:
	var problems: Array[String] = []
	for cid in countries:
		var country: Country = countries[cid]
		var known := {}
		for tech_id in country.researched_technologies:
			if known.has(tech_id):
				problems.append("country %s has %s twice" % [cid, tech_id])
			elif not catalog.has(tech_id):
				problems.append("country %s knows unknown technology %s" % [cid, tech_id])
			known[tech_id] = true
		for tech_id in country.researched_technologies:
			if not catalog.has(tech_id):
				continue
			for required in (catalog[tech_id] as Technology).requires:
				if not known.has(required):
					problems.append("country %s has %s without its requirement %s" % [cid, tech_id, required])
		if country.research_progress < 0.0:
			problems.append("country %s has negative research progress" % cid)
		if country.current_research == "":
			if country.research_progress != 0.0:
				problems.append("country %s has research progress without a research" % cid)
		elif not catalog.has(country.current_research):
			problems.append("country %s researches unknown technology %s" % [cid, country.current_research])
		elif known.has(country.current_research):
			problems.append("country %s researches %s again" % [cid, country.current_research])
		else:
			var tech: Technology = catalog[country.current_research]
			for required in tech.requires:
				if not known.has(required):
					problems.append("country %s researches %s without %s" % [cid, tech.id, required])
			if country.research_progress >= float(tech.cost):
				problems.append("country %s has finished %s but it is not in the list" % [cid, tech.id])
	return problems
''')

# --- register the system
patch("core/game_systems.gd",
      "manager.register_system(EconomySystem.new())",
      "manager.register_system(EconomySystem.new())\n\tmanager.register_system(ResearchSystem.new())")

# --- scene
patch("main.tscn", "[gd_scene load_steps=7 format=3]", "[gd_scene load_steps=8 format=3]")
patch("main.tscn",
      '[ext_resource type="PackedScene" path="res://ui/panels/city_panel.tscn" id="6_city"]',
      '[ext_resource type="PackedScene" path="res://ui/panels/city_panel.tscn" id="6_city"]\n'
      '[ext_resource type="PackedScene" path="res://ui/panels/research_panel.tscn" id="7_research"]')
append("main.tscn", 'name="ResearchPanel"',
       '\n[node name="ResearchPanel" parent="." instance=ExtResource("7_research")]\n')

# --- debug HUD status line on completion
patch("ui/debug_hud.gd",
      "WorldState.building_completed.connect(_on_building_completed)",
      "WorldState.building_completed.connect(_on_building_completed)\n"
      "\tWorldState.technology_researched.connect(_on_technology_researched)")
patch("ui/debug_hud.gd",
      "func _on_trace_toggled(pressed: bool) -> void:",
      "func _on_technology_researched(country_id: String, technology_id: String) -> void:\n"
      "\tvar tech := TechnologyCatalog.get_technology(technology_id)\n"
      "\tvar country_name := country_id\n"
      "\tif WorldState.countries.has(country_id):\n"
      "\t\tcountry_name = (WorldState.countries[country_id] as Country).name\n"
      "\t_set_status(\"%s researched %s\" % [country_name, tech.name if tech != null else technology_id])\n\n\n"
      "func _on_trace_toggled(pressed: bool) -> void:")

# --- docs (a miss is only a warning)
patch("README.md", "Готовы итерации 0–10", "Готовы итерации 0–11", required=False)
patch("README.md",
      "| `technology/ military/ diplomacy/ ai/` | пока пусто (итерации 11–16) |",
      "| `technology/` | технологии и исследования (`ResearchSystem`, фаза WORLD_UPDATE) |\n"
      "| `military/ diplomacy/ ai/` | пока пусто (итерации 12–16) |", required=False)
patch("README.md", "| `data/` | карта, страны, города, здания (JSON) |",
      "| `data/` | карта, страны, города, здания, технологии (JSON) |", required=False)
patch("data/README.md", "Редактировать вручную можно `buildings/`.",
      "Редактировать вручную можно `buildings/` и `technologies/`.", required=False)
patch("data/README.md", "- `buildings/buildings.json` типы зданий: цена, срок, эффект",
      "- `buildings/buildings.json` типы зданий: цена, срок, эффект\n"
      "- `technologies/technologies.json` технологии: цена в науке, требования, эффект", required=False)
patch("ui/README.md", "- `panels/city_panel.*` город выбранного региона и заказ зданий",
      "- `panels/city_panel.*` город выбранного региона и заказ зданий\n"
      "- `panels/research_panel.*` исследования: текущая технология и список", required=False)

if errors:
    print("\nFAILED:")
    for message in errors:
        print("  " + message)
    sys.exit(1)
print("\nDone. Run tests/run_all.sh")
