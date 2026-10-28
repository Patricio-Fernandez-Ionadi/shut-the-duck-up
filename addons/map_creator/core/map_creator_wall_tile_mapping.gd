extends Resource
class_name MapCreatorWallTileMapping

@export var tile_set: TileSet
@export var source_id: int = 0
@export var entries: Array[MapCreatorWallTileEntry] = []
@export var visual_margin: int = 1
@export var base_z_index: int = 0
@export var overlay_z_index: int = 10
@export var base_collision_enabled: bool = true
@export var overlay_collision_enabled: bool = false

func find_entry(
	layer: int,
	wall_mask: int,
	floor_mask: int
) -> MapCreatorWallTileEntry:
	var best: MapCreatorWallTileEntry = null
	var best_score := -1

	for entry in entries:
		if entry == null or entry.layer != layer:
			continue
		if not entry.matches(wall_mask, floor_mask):
			continue

		var score := entry.specificity()
		if score > best_score:
			best = entry
			best_score = score

	return best

func get_visual_margin_px(tile_size: Vector2i) -> Vector2i:
	return Vector2i(visual_margin, visual_margin) * tile_size

func validate() -> Array[String]:
	var errors: Array[String] = []

	if tile_set == null:
		errors.append("wall mapping has no tile_set")
	if source_id < 0:
		errors.append("wall mapping has invalid source_id")
	if entries.is_empty():
		errors.append("wall mapping has no entries")

	for i in range(entries.size()):
		if entries[i] == null:
			errors.append("wall mapping entry %d is null" % i)

	return errors
