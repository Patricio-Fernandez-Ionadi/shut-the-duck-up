extends Node2D
class_name MapCreatorPreviewMaskOverlay

var geometry: MapCreatorLayoutGeometry
var tile_size: Vector2i = Vector2i(16, 16)
var wall_masks: Dictionary = {}
var floor_masks: Dictionary = {}
var show_masks: bool = false

func _draw() -> void:
	if not show_masks or geometry == null:
		return

	var tile := Vector2(tile_size)
	var font := ThemeDB.fallback_font

	for cell_value in wall_masks.keys():
		var cell: Vector2i = cell_value
		var wall_mask: int = wall_masks[cell]
		var floor_mask: int = floor_masks.get(cell, 0)
		var rect := Rect2(Vector2(cell) * tile, tile)
		var color := Color.from_hsv(
			float(wall_mask) / 16.0,
			0.65,
			1.0,
			0.35
		)

		draw_rect(rect, color, true)
		draw_rect(rect, color.lightened(0.25), false, 1.0)
		draw_string(
			font,
			rect.position + Vector2(1.0, 9.0),
			"%d/%d" % [wall_mask, floor_mask],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			7,
			Color(1.0, 1.0, 1.0, 0.95)
		)
