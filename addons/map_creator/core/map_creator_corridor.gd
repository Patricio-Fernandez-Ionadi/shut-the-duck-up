extends RefCounted
class_name MapCreatorCorridor

var id: int = -1
var from_room_id: int = -1
var to_room_id: int = -1
var from_door: MapCreatorDoor = null
var to_door: MapCreatorDoor = null
var width: int = 2
var segments: Array[Rect2i] = []

func _init(
	p_id: int = -1,
	p_from_room_id: int = -1,
	p_to_room_id: int = -1,
	p_from_door: MapCreatorDoor = null,
	p_to_door: MapCreatorDoor = null,
	p_width: int = 2,
	p_segments: Array[Rect2i] = []
) -> void:
	id = p_id
	from_room_id = p_from_room_id
	to_room_id = p_to_room_id
	from_door = p_from_door
	to_door = p_to_door
	width = p_width
	segments = p_segments

func to_dictionary() -> Dictionary:
	var segment_data: Array = []
	for segment in segments:
		segment_data.append([
			segment.position.x,
			segment.position.y,
			segment.size.x,
			segment.size.y,
		])

	return {
		"id": id,
		"from_room_id": from_room_id,
		"to_room_id": to_room_id,
		"width": width,
		"segments": segment_data,
	}
