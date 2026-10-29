extends Node2D
## Draws country borders: thick lines on every edge between regions with different owners.
## Borders are never drawn by hand: they follow Region.country_id, so a captured
## region moves the border automatically (it recomputes on region_owner_changed).
## The player's borders are drawn in a highlight color.
## Also draws the coastline.

const COAST_COLOR := Color(0.04, 0.08, 0.14)
const BORDER_COLOR := Color(0.08, 0.08, 0.1, 0.95)
const PLAYER_BORDER_COLOR := Color(1.0, 1.0, 1.0, 0.95)

var _geometry: Dictionary = {"shared": {}, "coast": PackedVector2Array()}
var _border_lines: PackedVector2Array = PackedVector2Array()
var _player_lines: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	WorldState.state_replaced.connect(_on_state_replaced)
	WorldState.region_owner_changed.connect(_on_region_owner_changed)
	WorldState.player_country_changed.connect(_on_player_country_changed)
	_on_state_replaced()


func _on_state_replaced() -> void:
	_geometry = BorderGeometry.build(WorldState.regions)
	recompute()


func _on_region_owner_changed(_region_id: String, _old_owner: String, _new_owner: String) -> void:
	recompute()


func _on_player_country_changed(_country_id: String) -> void:
	recompute()


## Rebuilds the line lists from the current owners.
func recompute() -> void:
	var player := WorldState.get_player_country()
	var player_id := player.id if player != null else ""
	var lines := BorderGeometry.split_by_owner(_geometry["shared"], WorldState.regions, player_id)
	_border_lines = lines["borders"]
	_player_lines = lines["player"]
	queue_redraw()


func _draw() -> void:
	var coast: PackedVector2Array = _geometry["coast"]
	if not coast.is_empty():
		draw_multiline(coast, COAST_COLOR, 2.0)
	if not _border_lines.is_empty():
		draw_multiline(_border_lines, BORDER_COLOR, 3.0)
	if not _player_lines.is_empty():
		draw_multiline(_player_lines, PLAYER_BORDER_COLOR, 4.0)
