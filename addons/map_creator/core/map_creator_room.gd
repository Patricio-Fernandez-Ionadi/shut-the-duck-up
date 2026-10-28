extends RefCounted
class_name MapCreatorRoom

var id: int = -1
var rect: Rect2i = Rect2i()
var doors: Array[MapCreatorDoor] = []

func _init(p_id: int = -1, p_rect: Rect2i = Rect2i()) -> void:
	id = p_id
	rect = p_rect

func side_span(side: int) -> int:
	if side == MapCreatorTypes.Side.NORTH or side == MapCreatorTypes.Side.SOUTH:
		return rect.size.x
	return rect.size.y

func side_center(side: int) -> Vector2i:
	var half_x := rect.size.x / 2
	var half_y := rect.size.y / 2

	match side:
		MapCreatorTypes.Side.NORTH:
			return Vector2i(rect.position.x + half_x, rect.position.y - 1)
		MapCreatorTypes.Side.EAST:
			return Vector2i(rect.end.x, rect.position.y + half_y)
		MapCreatorTypes.Side.SOUTH:
			return Vector2i(rect.position.x + half_x, rect.end.y)
		_:
			return Vector2i(rect.position.x - 1, rect.position.y + half_y)

func has_door_on_side(side: int) -> bool:
	for door in doors:
		if door.side == side:
			return true
	return false

func add_door(door: MapCreatorDoor) -> void:
	doors.append(door)

func to_dictionary() -> Dictionary:
	var door_data: Array = []
	for door in doors:
		door_data.append(door.to_dictionary())

	return {
		"id": id,
		"rect": [
			rect.position.x,
			rect.position.y,
			rect.size.x,
			rect.size.y,
		],
		"doors": door_data,
	}
