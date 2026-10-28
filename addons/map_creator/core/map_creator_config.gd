extends Resource
class_name MapCreatorConfig

@export var layout_seed: int = 0
@export_range(1, 64, 1) var room_count: int = 8
@export var room_min_size: Vector2i = Vector2i(8, 6)
@export var room_max_size: Vector2i = Vector2i(18, 14)
@export_range(2, 4, 1) var corridor_width_min: int = 2
@export_range(2, 4, 1) var corridor_width_max: int = 4
@export var corridor_length_min: int = 3
@export var corridor_length_max: int = 8
@export var room_margin: int = 2
@export var wall_margin: int = 2
@export var tile_size: Vector2i = Vector2i(16, 16)
@export var max_attempts: int = 20000

func sanitized_copy() -> MapCreatorConfig:
	var result := MapCreatorConfig.new()
	result.layout_seed = layout_seed
	result.room_count = maxi(1, room_count)
	result.room_min_size = Vector2i(
		maxi(3, room_min_size.x),
		maxi(3, room_min_size.y)
	)
	result.room_max_size = Vector2i(
		maxi(result.room_min_size.x, room_max_size.x),
		maxi(result.room_min_size.y, room_max_size.y)
	)
	result.corridor_width_min = clampi(corridor_width_min, 2, 4)
	result.corridor_width_max = clampi(
		corridor_width_max,
		result.corridor_width_min,
		4
	)
	result.corridor_length_min = maxi(2, corridor_length_min)
	result.corridor_length_max = maxi(
		result.corridor_length_min,
		corridor_length_max
	)
	result.corridor_length_max = maxi(
		result.corridor_length_max,
		result.corridor_width_max
	)
	result.room_margin = maxi(0, room_margin)
	result.wall_margin = maxi(0, wall_margin)
	result.tile_size = Vector2i(maxi(1, tile_size.x), maxi(1, tile_size.y))
	result.max_attempts = maxi(100, max_attempts)
	return result
