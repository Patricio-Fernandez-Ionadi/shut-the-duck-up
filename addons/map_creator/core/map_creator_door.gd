extends RefCounted
class_name MapCreatorDoor

var room_id: int = -1
var side: int = MapCreatorTypes.Side.EAST
var center: Vector2i = Vector2i.ZERO
var width: int = 2

func _init(
	p_room_id: int = -1,
	p_side: int = MapCreatorTypes.Side.EAST,
	p_center: Vector2i = Vector2i.ZERO,
	p_width: int = 2
) -> void:
	room_id = p_room_id
	side = p_side
	center = p_center
	width = p_width

func to_dictionary() -> Dictionary:
	return {
		"room_id": room_id,
		"side": side,
		"center": [center.x, center.y],
		"width": width,
	}
