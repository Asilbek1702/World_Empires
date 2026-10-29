class_name SaveFileFormat
extends RefCounted
## Save file header. Every save carries a format version and a game version.
## Migration between versions is added later; for now only the exact version loads.

const SAVE_VERSION := 1
const GAME_VERSION := "0.1.0"


static func make_header(metadata: Dictionary = {}) -> Dictionary:
	return {
		"save_version": SAVE_VERSION,
		"game_version": GAME_VERSION,
		"metadata": metadata,
	}


## Returns "" if the header is acceptable, otherwise a human-readable reason.
static func check_header(header: Variant) -> String:
	if not (header is Dictionary):
		return "Save header is missing"
	if not header.has("save_version"):
		return "Save header has no save_version"
	var version: Variant = header["save_version"]
	var is_number := typeof(version) == TYPE_INT or typeof(version) == TYPE_FLOAT
	if not is_number or version != floorf(float(version)):
		return "Save version is not a whole number"
	if int(version) != SAVE_VERSION:
		return "Incompatible save version %d (supported: %d)" % [int(version), SAVE_VERSION]
	return ""
