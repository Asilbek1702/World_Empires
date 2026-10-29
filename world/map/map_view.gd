extends Node2D
## Draws region fills (by owner) and handles region selection.
## Child nodes draw on top, in order: Borders (country borders), Overlay (capitals, selection).
## Reads WorldState only. It never changes the world.
## Left click selects a region (click on the sea deselects).
## Publishes Events.REGION_SELECTED with {"region_id": String} ("" = nothing selected).
## Listens to Events.COUNTRY_PREVIEWED: the previewed country is drawn lighter.

const SEA_COLOR := Color(0.16, 0.27, 0.40)
const OUTLINE_COLOR := Color(0.12, 0.12, 0.12, 0.55)
const TERRAIN_COLORS := {
	Region.Terrain.PLAINS: Color(0.62, 0.78, 0.45),
	Region.Terrain.FOREST: Color(0.30, 0.55, 0.32),
	Region.Terrain.HILLS: Color(0.72, 0.66, 0.45),
	Region.Terrain.MOUNTAIN: Color(0.58, 0.58, 0.62),
	Region.Terrain.DESERT: Color(0.88, 0.80, 0.52),
}
## How much of the terrain color shows through the country color.
const TERRAIN_TINT := 0.2

var selected_id: String = ""
var preview_country_id: String = ""

var _bounds: Rect2 = Rect2()

@onready var _camera: Camera2D = $Camera
@onready var _overlay: Node2D = $Overlay


func _ready() -> void:
	RenderingServer.set_default_clear_color(SEA_COLOR)
	WorldState.state_replaced.connect(_on_state_replaced)
	WorldState.region_owner_changed.connect(_on_region_owner_changed)
	EventBus.subscribe(Events.COUNTRY_PREVIEWED, _on_country_previewed)
	_on_state_replaced()


func _exit_tree() -> void:
	EventBus.unsubscribe(Events.COUNTRY_PREVIEWED, _on_country_previewed)


func _on_state_replaced() -> void:
	selected_id = ""
	preview_country_id = ""
	var new_bounds := MapQueries.compute_bounds(WorldState.regions)
	if new_bounds != _bounds and new_bounds.has_area():
		_camera.fit_to(new_bounds)
	_bounds = new_bounds
	_redraw_all()


func _on_region_owner_changed(_region_id: String, _old_owner: String, _new_owner: String) -> void:
	queue_redraw()


func _on_country_previewed(payload: Dictionary) -> void:
	preview_country_id = payload["country_id"]
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton):
		return
	var click := event as InputEventMouseButton
	if click.button_index != MOUSE_BUTTON_LEFT or not click.pressed:
		return
	select_region(MapQueries.find_region_at(WorldState.regions, get_global_mouse_position()))


func select_region(region_id: String) -> void:
	selected_id = region_id
	_redraw_all()
	EventBus.emit(Events.REGION_SELECTED, {"region_id": region_id})


func _redraw_all() -> void:
	queue_redraw()
	_overlay.queue_redraw()


func _draw() -> void:
	var regions: Dictionary = WorldState.regions
	var selected = regions.get(selected_id)
	for id in regions:
		var region: Region = regions[id]
		var fill := _fill_color(region)
		if id == selected_id:
			fill = fill.lightened(0.45)
		elif selected != null and (selected as Region).neighbors.has(id):
			fill = fill.lightened(0.2)
		elif preview_country_id != "" and region.country_id == preview_country_id:
			fill = fill.lightened(0.3)
		draw_colored_polygon(region.polygon, fill)
		var outline := region.polygon.duplicate()
		outline.append(region.polygon[0])
		draw_polyline(outline, OUTLINE_COLOR, -1.0)


## Country color with a little terrain shade. Unowned land shows plain, darker terrain.
func _fill_color(region: Region) -> Color:
	var terrain: Color = TERRAIN_COLORS[region.terrain]
	var country = WorldState.countries.get(region.country_id)
	if country == null:
		return terrain.darkened(0.25)
	return (country as Country).color.lerp(terrain, TERRAIN_TINT)
