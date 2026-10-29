class_name MapQueries
extends RefCounted
## Read-only helpers over a regions dictionary (RegionID -> Region).


## Returns the id of the region containing the point, or "" (sea).
static func find_region_at(regions: Dictionary, point: Vector2) -> String:
	for id in regions:
		var region: Region = regions[id]
		if Geometry2D.is_point_in_polygon(point, region.polygon):
			return id
	return ""


## Bounding rectangle of all region polygons. Rect2() for an empty map.
static func compute_bounds(regions: Dictionary) -> Rect2:
	var bounds := Rect2()
	var first := true
	for id in regions:
		for vertex in (regions[id] as Region).polygon:
			if first:
				bounds = Rect2(vertex, Vector2.ZERO)
				first = false
			else:
				bounds = bounds.expand(vertex)
	return bounds
