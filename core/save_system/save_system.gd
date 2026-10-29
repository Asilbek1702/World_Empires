class_name SaveSystem
extends RefCounted
## Saves and loads WorldState as JSON.
## Writes to a temp file, verifies it, then renames it over the real save,
## so a crash mid-save never destroys the previous save.
## On failure, last_error holds a human-readable reason.

static var last_error: String = ""


## rng (optional): its current position is captured into the save.
static func save_to_json(path: String, state: Node, rng: Node = null) -> Error:
	last_error = ""
	if rng != null:
		state.rng_state = rng.get_state()

	var payload := {
		"header": SaveFileFormat.make_header({
			"date": str(state.game_date),
			"turn_number": state.game_date.turn_number,
			"saved_at_unix": int(Time.get_unix_time_from_system()),
		}),
		"world_state": state.to_dict(),
	}
	var text := JSON.stringify(payload, "\t")

	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
	var temp_path := path + ".tmp"
	var file := FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		var open_error := FileAccess.get_open_error()
		last_error = "Cannot write %s: %s" % [temp_path, error_string(open_error)]
		return open_error
	file.store_string(text)
	file.close()

	if FileAccess.get_file_as_string(temp_path) != text:
		_remove(temp_path)
		last_error = "Verification of %s failed" % temp_path
		return ERR_FILE_CORRUPT

	var rename_error := DirAccess.rename_absolute(
		ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(path))
	if rename_error != OK:
		_remove(temp_path)
		last_error = "Cannot replace %s: %s" % [path, error_string(rename_error)]
		return rename_error
	return OK


## rng (optional): seeded from the save and moved to the saved position.
## On any error neither state nor rng is changed.
static func load_from_json(path: String, state: Node, rng: Node = null) -> Error:
	last_error = ""
	if not FileAccess.file_exists(path):
		last_error = "File not found: %s" % path
		return ERR_FILE_NOT_FOUND

	var json := JSON.new()
	var parse_error := json.parse(FileAccess.get_file_as_string(path))
	if parse_error != OK:
		last_error = "Not valid JSON (line %d): %s" % [json.get_error_line(), json.get_error_message()]
		return ERR_PARSE_ERROR

	var root: Variant = json.data
	if not (root is Dictionary) or not root.has("header") or not root.has("world_state"):
		last_error = "Save file has no header or world_state"
		return ERR_INVALID_DATA

	var header_problem := SaveFileFormat.check_header(root["header"])
	if header_problem != "":
		last_error = header_problem
		return ERR_FILE_UNRECOGNIZED

	if not (root["world_state"] is Dictionary):
		last_error = "world_state is not an object"
		return ERR_INVALID_DATA
	var state_error: Error = state.from_dict(root["world_state"])
	if state_error != OK:
		last_error = "world_state data is invalid"
		return state_error

	if rng != null:
		rng.set_seed(state.rng_seed)
		rng.set_state(state.rng_state)
	return OK


static func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
