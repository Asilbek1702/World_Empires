extends Camera2D
## Map camera. Pan: WASD / arrows, or drag with the middle or right mouse button.
## Zoom: mouse wheel (zooms toward the cursor).

const ZOOM_STEP := 1.15
const MIN_ZOOM := 0.3
const MAX_ZOOM := 4.0
const PAN_SPEED := 700.0  # screen pixels per second
const EDGE_MARGIN := 250.0  # world units the camera may leave the map by

var world_bounds: Rect2 = Rect2(0, 0, 1600, 1000)

var _dragging: bool = false


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button := event as InputEventMouseButton
		match button.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				_zoom_at(button.position, ZOOM_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				_zoom_at(button.position, 1.0 / ZOOM_STEP)
			MOUSE_BUTTON_MIDDLE, MOUSE_BUTTON_RIGHT:
				_dragging = button.pressed
	elif event is InputEventMouseMotion and _dragging:
		position -= (event as InputEventMouseMotion).relative / zoom.x
		_clamp_position()


func _process(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		direction.y += 1.0
	if direction != Vector2.ZERO:
		position += direction.normalized() * PAN_SPEED * delta / zoom.x
		_clamp_position()


## Centers the camera on the bounds and zooms so all of it is visible.
func fit_to(bounds: Rect2) -> void:
	world_bounds = bounds
	var view := get_viewport_rect().size
	var fit := minf(view.x / bounds.size.x, view.y / bounds.size.y) * 0.9
	zoom = Vector2.ONE * clampf(fit, MIN_ZOOM, MAX_ZOOM)
	position = bounds.get_center()


func _zoom_at(screen_position: Vector2, factor: float) -> void:
	var view_center := get_viewport_rect().size * 0.5
	var before := position + (screen_position - view_center) / zoom.x
	zoom = Vector2.ONE * clampf(zoom.x * factor, MIN_ZOOM, MAX_ZOOM)
	var after := position + (screen_position - view_center) / zoom.x
	position += before - after
	_clamp_position()


func _clamp_position() -> void:
	var limit := world_bounds.grow(EDGE_MARGIN)
	position = position.clamp(limit.position, limit.end)
