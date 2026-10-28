extends Resource
class_name MapCreatorWallTileEntry

enum Layer { BASE, OVERLAY }

@export var wall_mask: int = -1
@export var floor_mask: int = -1
@export var layer: Layer = Layer.BASE
@export var atlas_coords: Vector2i = Vector2i.ZERO
@export var offset: Vector2i = Vector2i.ZERO
@export var alternative_tile: int = 0

func matches(p_wall_mask: int, p_floor_mask: int) -> bool:
	if wall_mask >= 0 and wall_mask != p_wall_mask:
		return false
	if floor_mask >= 0 and floor_mask != p_floor_mask:
		return false
	return true

func specificity() -> int:
	var score := 0
	if wall_mask >= 0:
		score += 2
	if floor_mask >= 0:
		score += 1
	return score

func is_fallback() -> bool:
	return wall_mask < 0 or floor_mask < 0
