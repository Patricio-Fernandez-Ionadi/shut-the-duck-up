extends RefCounted
class_name MapCreatorTypes

enum Side { NORTH, EAST, SOUTH, WEST }

const DIRECTIONS := [
	Vector2i(0, -1),
	Vector2i(1, 0),
	Vector2i(0, 1),
	Vector2i(-1, 0),
]

static func direction(side: int) -> Vector2i:
	return DIRECTIONS[side]

static func opposite(side: int) -> int:
	return (side + 2) % 4

static func perpendicular_sides(side: int) -> Array:
	return [(side + 1) % 4, (side + 3) % 4]

static func side_name(side: int) -> String:
	return ["N", "E", "S", "W"][side]
