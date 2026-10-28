extends RefCounted
class_name MapCreatorWallTileRenderer

var mapping: MapCreatorWallTileMapping
var geometry: MapCreatorLayoutGeometry
var base_layer: TileMapLayer
var overlay_layer: TileMapLayer
var wall_masks: Dictionary = {}
var floor_masks: Dictionary = {}
var stats: Dictionary = {}

func setup(
	p_mapping: MapCreatorWallTileMapping,
	p_geometry: MapCreatorLayoutGeometry,
	p_base_layer: TileMapLayer,
	p_overlay_layer: TileMapLayer
) -> void:
	mapping = p_mapping
	geometry = p_geometry
	base_layer = p_base_layer
	overlay_layer = p_overlay_layer

func render() -> Dictionary:
	wall_masks.clear()
	floor_masks.clear()
	stats = {
		"wall_cells": 0,
		"base_mapped": 0,
		"overlay_mapped": 0,
		"mapped_wall_cells": 0,
		"base_cells": 0,
		"overlay_cells": 0,
		"base_fallback": 0,
		"overlay_fallback": 0,
		"missing_base": 0,
		"missing_overlay": 0,
		"duplicate_base": 0,
		"duplicate_overlay": 0,
		"missing_base_masks": {},
		"missing_overlay_masks": {},
		"mapping_errors": [],
	}

	if mapping == null:
		stats["mapping_errors"] = ["wall mapping is null"]
		_clear_layer(base_layer)
		_clear_layer(overlay_layer)
		return stats

	stats["mapping_errors"] = mapping.validate()

	if geometry == null:
		stats["mapping_errors"].append("geometry is null")
		_clear_layer(base_layer)
		_clear_layer(overlay_layer)
		return stats

	if mapping.tile_set == null:
		_clear_layer(base_layer)
		_clear_layer(overlay_layer)
		return stats

	_prepare_layer(
		base_layer,
		mapping.base_z_index,
		mapping.base_collision_enabled
	)
	_prepare_layer(
		overlay_layer,
		mapping.overlay_z_index,
		mapping.overlay_collision_enabled
	)

	var base_placed := {}
	var overlay_placed := {}
	var cells: Array = geometry.wall_cells.keys()
	cells.sort_custom(_cell_less_than)
	stats["wall_cells"] = cells.size()

	for cell_value in cells:
		var cell: Vector2i = cell_value
		var wall_mask := _mask_for(cell, geometry.wall_cells)
		var floor_mask := _mask_for(cell, geometry.floor_cells)
		wall_masks[cell] = wall_mask
		floor_masks[cell] = floor_mask

		var base_entry := mapping.find_entry(
			MapCreatorWallTileEntry.Layer.BASE,
			wall_mask,
			floor_mask
		)
		var overlay_entry := mapping.find_entry(
			MapCreatorWallTileEntry.Layer.OVERLAY,
			wall_mask,
			floor_mask
		)

		if base_entry == null:
			stats["missing_base"] += 1
			_count_mask(stats["missing_base_masks"], wall_mask, floor_mask)
		else:
			stats["base_mapped"] += 1
			if base_entry.is_fallback():
				stats["base_fallback"] += 1
			if _place_entry(base_layer, base_entry, cell, base_placed):
				stats["base_cells"] += 1
			else:
				stats["duplicate_base"] += 1

		if overlay_entry == null:
			stats["missing_overlay"] += 1
			_count_mask(stats["missing_overlay_masks"], wall_mask, floor_mask)
		else:
			stats["overlay_mapped"] += 1
			if overlay_entry.is_fallback():
				stats["overlay_fallback"] += 1
			if _place_entry(
				overlay_layer,
				overlay_entry,
				cell,
				overlay_placed
			):
				stats["overlay_cells"] += 1
			else:
				stats["duplicate_overlay"] += 1

		if base_entry != null and overlay_entry != null:
			stats["mapped_wall_cells"] += 1

	return stats

func get_coverage_ratio() -> float:
	var total := int(stats.get("wall_cells", 0))
	if total <= 0:
		return 0.0
	return float(stats.get("mapped_wall_cells", 0)) / float(total)

func _prepare_layer(
	layer: TileMapLayer,
	z_index: int,
	collision_enabled: bool
) -> void:
	if layer == null:
		return

	layer.clear()
	layer.tile_set = mapping.tile_set
	layer.z_index = z_index
	layer.collision_enabled = collision_enabled

func _clear_layer(layer: TileMapLayer) -> void:
	if layer == null:
		return
	layer.clear()

func _place_entry(
	layer: TileMapLayer,
	entry: MapCreatorWallTileEntry,
	cell: Vector2i,
	placed: Dictionary
) -> bool:
	if layer == null:
		return false

	var output_cell := cell + entry.offset
	if placed.has(output_cell):
		return false

	layer.set_cell(
		output_cell,
		mapping.source_id,
		entry.atlas_coords,
		entry.alternative_tile
	)
	placed[output_cell] = true
	return true

func _mask_for(cell: Vector2i, cells: Dictionary) -> int:
	var mask := 0
	for i in range(MapCreatorTypes.DIRECTIONS.size()):
		if cells.has(cell + MapCreatorTypes.DIRECTIONS[i]):
			mask |= 1 << i
	return mask

func _count_mask(
	target: Dictionary,
	wall_mask: int,
	floor_mask: int
) -> void:
	var key := "%d/%d" % [wall_mask, floor_mask]
	target[key] = int(target.get(key, 0)) + 1

func _cell_less_than(a: Vector2i, b: Vector2i) -> bool:
	if a.y == b.y:
		return a.x < b.x
	return a.y < b.y
