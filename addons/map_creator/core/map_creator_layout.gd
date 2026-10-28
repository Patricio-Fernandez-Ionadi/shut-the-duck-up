extends RefCounted
class_name MapCreatorLayout

var layout_seed: int = 0
var tile_size: Vector2i = Vector2i(16, 16)
var rooms: Array[MapCreatorRoom] = []
var corridors: Array[MapCreatorCorridor] = []
var bounds_tiles: Rect2i = Rect2i()
var bounds_px: Rect2 = Rect2()
var spawn_room_id: int = -1
var exit_room_id: int = -1

func get_room(room_id: int) -> MapCreatorRoom:
	for room in rooms:
		if room.id == room_id:
			return room
	return null

func validate() -> Array[String]:
	var errors: Array[String] = []

	if rooms.is_empty():
		errors.append("layout has no rooms")
		return errors

	var room_ids := {}
	for room in rooms:
		if room.id < 0:
			errors.append("room has invalid id %d" % room.id)
		if room_ids.has(room.id):
			errors.append("duplicate room id %d" % room.id)
		room_ids[room.id] = true

		if room.rect.size.x <= 0 or room.rect.size.y <= 0:
			errors.append("room %d has invalid size" % room.id)
		if not _rect_contains_rect(bounds_tiles, room.rect):
			errors.append("room %d is outside layout bounds" % room.id)

		for door in room.doors:
			if door.width < 2 or door.width > 4:
				errors.append(
					"room %d has invalid door width %d" % [room.id, door.width]
				)
			if not _door_fits(room, door):
				errors.append("room %d has a door that does not fit" % room.id)

	for i in range(rooms.size()):
		for j in range(i + 1, rooms.size()):
			if rooms[i].rect.intersects(rooms[j].rect):
				errors.append(
					"rooms %d and %d overlap" % [rooms[i].id, rooms[j].id]
				)

	for corridor in corridors:
		if not room_ids.has(corridor.from_room_id):
			errors.append("corridor %d has invalid from_room_id" % corridor.id)
		if not room_ids.has(corridor.to_room_id):
			errors.append("corridor %d has invalid to_room_id" % corridor.id)

		for segment in corridor.segments:
			if not _rect_contains_rect(bounds_tiles, segment):
				errors.append(
					"corridor %d has a segment outside bounds" % corridor.id
				)

			for cell in _rect_cells(segment):
				for room in rooms:
					if _rect_has_cell(room.rect, cell):
						errors.append(
							"corridor %d crosses room %d"
							% [corridor.id, room.id]
						)
						break

	if not room_ids.has(spawn_room_id):
		errors.append("spawn_room_id is invalid")
	if not room_ids.has(exit_room_id):
		errors.append("exit_room_id is invalid")

	if _connected_room_count(spawn_room_id) != rooms.size():
		errors.append("layout is not fully connected")

	return errors

func to_dictionary() -> Dictionary:
	var room_data: Array = []
	for room in rooms:
		room_data.append(room.to_dictionary())

	var corridor_data: Array = []
	for corridor in corridors:
		corridor_data.append(corridor.to_dictionary())

	return {
		"layout_seed": layout_seed,
		"tile_size": [tile_size.x, tile_size.y],
		"bounds_tiles": [
			bounds_tiles.position.x,
			bounds_tiles.position.y,
			bounds_tiles.size.x,
			bounds_tiles.size.y,
		],
		"bounds_px": [
			bounds_px.position.x,
			bounds_px.position.y,
			bounds_px.size.x,
			bounds_px.size.y,
		],
		"spawn_room_id": spawn_room_id,
		"exit_room_id": exit_room_id,
		"rooms": room_data,
		"corridors": corridor_data,
	}

func _door_fits(room: MapCreatorRoom, door: MapCreatorDoor) -> bool:
	if door.width <= 0:
		return false

	var start := 0

	if (
		door.side == MapCreatorTypes.Side.NORTH
		or door.side == MapCreatorTypes.Side.SOUTH
	):
		start = door.center.x - door.width / 2
		return (
			start >= room.rect.position.x
			and start + door.width <= room.rect.end.x
		)

	start = door.center.y - door.width / 2
	return (
		start >= room.rect.position.y
		and start + door.width <= room.rect.end.y
	)

func _rect_contains_rect(outer: Rect2i, inner: Rect2i) -> bool:
	return (
		inner.position.x >= outer.position.x
		and inner.position.y >= outer.position.y
		and inner.end.x <= outer.end.x
		and inner.end.y <= outer.end.y
	)

func _rect_has_cell(rect: Rect2i, cell: Vector2i) -> bool:
	return (
		cell.x >= rect.position.x
		and cell.y >= rect.position.y
		and cell.x < rect.end.x
		and cell.y < rect.end.y
	)

func _rect_cells(rect: Rect2i) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			cells.append(Vector2i(x, y))
	return cells

func _connected_room_count(start_id: int) -> int:
	var adjacency := {}
	for room in rooms:
		adjacency[room.id] = []

	for corridor in corridors:
		if (
			adjacency.has(corridor.from_room_id)
			and adjacency.has(corridor.to_room_id)
		):
			adjacency[corridor.from_room_id].append(corridor.to_room_id)
			adjacency[corridor.to_room_id].append(corridor.from_room_id)

	if not adjacency.has(start_id):
		return 0

	var visited := {start_id: true}
	var queue: Array[int] = [start_id]
	var head := 0

	while head < queue.size():
		var current: int = queue[head]
		head += 1

		for neighbor in adjacency[current]:
			if visited.has(neighbor):
				continue
			visited[neighbor] = true
			queue.append(neighbor)

	return visited.size()
