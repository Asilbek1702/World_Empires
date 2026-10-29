extends Node2D
## Drawn on top of fills and borders: capital markers and the selection outline.
## Reads WorldState and the parent MapView only.

const CITY_FILL := Color(0.95, 0.95, 0.9)
const CITY_RING := Color(0.05, 0.05, 0.05)
const CAPITAL_FILL := Color(1, 1, 1)
const CAPITAL_RING := Color(0, 0, 0)
const SELECTED_OUTLINE := Color(1.0, 0.95, 0.2)


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
	var selected_id: String = get_parent().selected_id
	if selected_id != "" and WorldState.regions.has(selected_id):
		var polygon: PackedVector2Array = (WorldState.regions[selected_id] as Region).polygon
		var points := polygon.duplicate()
		points.append(polygon[0])
		draw_polyline(points, SELECTED_OUTLINE, 4.0)
