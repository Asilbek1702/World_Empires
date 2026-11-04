extends Node2D
## Drawn on top of fills and borders: capital markers and the selection outline.
## Reads WorldState and the parent MapView only.

const CITY_FILL := Color(0.95, 0.95, 0.9)
const CITY_RING := Color(0.05, 0.05, 0.05)
const CAPITAL_FILL := Color(1, 1, 1)
const CAPITAL_RING := Color(0, 0, 0)
const SELECTED_OUTLINE := Color(1.0, 0.95, 0.2)
const ARMY_RING := Color(0.05, 0.05, 0.05)
const ARMY_TEXT := Color(1, 1, 1)


func _ready() -> void:
	WorldState.military_changed.connect(queue_redraw)


func _draw() -> void:
	for id in WorldState.cities:
		var region_id: String = (WorldState.cities[id] as City).region_id
		if WorldState.regions.has(region_id):
			var spot: Vector2 = (WorldState.regions[region_id] as Region).center
			draw_rect(Rect2(spot - Vector2(5, 5), Vector2(10, 10)), CITY_RING)
			draw_rect(Rect2(spot - Vector2(3.5, 3.5), Vector2(7, 7)), CITY_FILL)
	for id in WorldState.countries:
		var capital_id: String = (WorldState.countries[id] as Country).capital_region
		if WorldState.regions.has(capital_id):
			var center: Vector2 = (WorldState.regions[capital_id] as Region).center
			draw_circle(center, 6.0, CAPITAL_RING)
			draw_circle(center, 4.0, CAPITAL_FILL)
	_draw_armies()
	var selected_id: String = get_parent().selected_id
	if selected_id != "" and WorldState.regions.has(selected_id):
		var polygon: PackedVector2Array = (WorldState.regions[selected_id] as Region).polygon
		var points := polygon.duplicate()
		points.append(polygon[0])
		draw_polyline(points, SELECTED_OUTLINE, 4.0)


## One flag per army below the region center: country color, unit count beside it.
func _draw_armies() -> void:
	var per_region := {}  # RegionID -> number of armies already drawn there
	for army_id in WorldState.armies:
		var army: Army = WorldState.armies[army_id]
		if not WorldState.regions.has(army.region_id):
			continue
		var slot: int = per_region.get(army.region_id, 0)
		per_region[army.region_id] = slot + 1
		var color := Color.WHITE
		if WorldState.countries.has(army.country_id):
			color = (WorldState.countries[army.country_id] as Country).color
		var origin: Vector2 = (WorldState.regions[army.region_id] as Region).center \
				+ Vector2(-8.0 + 36.0 * slot, 9.0)
		draw_rect(Rect2(origin, Vector2(16, 11)), ARMY_RING)
		draw_rect(Rect2(origin + Vector2(1.5, 1.5), Vector2(13, 8)), color)
		draw_string(ThemeDB.fallback_font, origin + Vector2(18, 10), str(army.units.size()),
				HORIZONTAL_ALIGNMENT_LEFT, -1, 11, ARMY_TEXT)
