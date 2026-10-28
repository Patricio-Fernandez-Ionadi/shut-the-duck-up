extends RefCounted
class_name MapCreatorGenerator

const CELL_EMPTY := 0
const CELL_ROOM := 1
const CELL_CORRIDOR := 2

var _config: MapCreatorConfig
var _rng := RandomNumberGenerator.new()
var _occupancy: Dictionary = {}
var _rooms: Array[MapCreatorRoom] = []
var _corridors: Array[MapCreatorCorridor] = []
var _blocked_sides: Dictionary = {}
var _next_room_id := 0
var _next_corridor_id := 0

func generate(config: MapCreatorConfig) -> MapCreatorLayout:
	if config == null:
		_config = MapCreatorConfig.new().sanitized_copy()
	else:
		_config = config.sanitized_copy()

	_rng = RandomNumberGenerator.new()
	var actual_seed := _config.layout_seed

	if actual_seed == 0:
		_rng.randomize()
		actual_seed = int(_rng.seed)
		print("MapCreator generated seed: %d" % actual_seed)
	else:
		_rng.seed = actual_seed

	_reset_state()

	var root_size := _random_room_size()
	var root := MapCreatorRoom.new(
		_next_room_id,
		Rect2i(Vector2i.ZERO, root_size)
	)
	_next_room_id += 1
	_rooms.append(root)
	_mark_rect(root.rect, CELL_ROOM)

	var attempts := 0
	while (
		_rooms.size() < _config.room_count
		and attempts < _config.max_attempts
	):
		attempts += 1
		var candidate := _pick_frontier()

		if candidate.is_empty():
			break

		var parent_id: int = candidate["room_id"]
		var parent_side: int = candidate["side"]

		if _try_grow(parent_id, parent_side):
			continue

		_blocked_sides[parent_id * 4 + parent_side] = true

	if _rooms.size() < _config.room_count:
		push_warning(
			"MapCreator generated %d/%d rooms after %d attempts"
			% [_rooms.size(), _config.room_count, attempts]
		)

	var layout := MapCreatorLayout.new()
	layout.layout_seed = actual_seed
	layout.tile_size = _config.tile_size
	layout.rooms = _rooms
	layout.corridors = _corridors
	layout.spawn_room_id = 0
	layout.exit_room_id = _find_farthest_room(0)
	_compute_bounds(layout)
	return layout

func _reset_state() -> void:
	_occupancy.clear()
	_rooms.clear()
	_corridors.clear()
	_blocked_sides.clear()
	_next_room_id = 0
	_next_corridor_id = 0

func _pick_frontier() -> Dictionary:
	var candidates: Array[Dictionary] = []

	for room in _rooms:
		for side in range(4):
			if room.has_door_on_side(side):
				continue
			if _blocked_sides.has(room.id * 4 + side):
				continue
			candidates.append({"room_id": room.id, "side": side})

	if candidates.is_empty():
		return {}

	return candidates[_rng.randi_range(0, candidates.size() - 1)]

func _try_grow(parent_id: int, parent_side: int) -> bool:
	var parent := _get_room(parent_id)
	if parent == null or parent.has_door_on_side(parent_side):
		return false

	var straight_side := MapCreatorTypes.opposite(parent_side)
	var perpendicular := MapCreatorTypes.perpendicular_sides(parent_side)
	var child_sides: Array[int] = []

	if _rng.randf() < 0.5:
		child_sides = [perpendicular[0], perpendicular[1], straight_side]
	else:
		child_sides = [straight_side, perpendicular[0], perpendicular[1]]

	for _size_attempt in range(6):
		var child_size := _random_room_size()

		for child_side in child_sides:
			var widths := _possible_widths(
				parent,
				parent_side,
				child_size,
				child_side
			)

			for width in widths:
				for _length_attempt in range(4):
					var placement := _build_placement(
						parent,
						parent_side,
						child_size,
						child_side,
						width
					)

					if placement.is_empty():
						continue
					if not _validate_placement(placement):
						continue

					_commit_placement(parent, placement)
					return true

	return false

func _possible_widths(
	parent: MapCreatorRoom,
	parent_side: int,
	child_size: Vector2i,
	child_side: int
) -> Array[int]:
	var parent_span := parent.side_span(parent_side)
	var child_span := child_size.y

	if (
		child_side == MapCreatorTypes.Side.NORTH
		or child_side == MapCreatorTypes.Side.SOUTH
	):
		child_span = child_size.x

	var max_width := mini(
		_config.corridor_width_max,
		mini(parent_span - 2, child_span - 2)
	)
	var widths: Array[int] = []

	if max_width < _config.corridor_width_min:
		return widths

	for width in range(_config.corridor_width_min, max_width + 1):
		widths.append(width)

	for i in range(widths.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var temp := widths[i]
		widths[i] = widths[j]
		widths[j] = temp

	return widths

func _build_placement(
	parent: MapCreatorRoom,
	parent_side: int,
	child_size: Vector2i,
	child_side: int,
	width: int
) -> Dictionary:
	var parent_door_center := parent.side_center(parent_side)
	var parent_direction := MapCreatorTypes.direction(parent_side)
	var child_direction := MapCreatorTypes.direction(child_side)
	var straight := child_side == MapCreatorTypes.opposite(parent_side)
	var dx := 0
	var dy := 0

	if straight:
		dx = _rng.randi_range(
			_config.corridor_length_min,
			_config.corridor_length_max
		)
	else:
		var min_segment := maxi(width, _config.corridor_length_min)
		dx = _rng.randi_range(min_segment, _config.corridor_length_max)
		dy = _rng.randi_range(min_segment, _config.corridor_length_max)

	var child_door_center: Vector2i

	if straight:
		child_door_center = parent_door_center + parent_direction * dx
	else:
		child_door_center = (
			parent_door_center
			+ parent_direction * dx
			- child_direction * dy
		)

	var child_rect := _rect_from_door(
		child_side,
		child_door_center,
		child_size
	)

	if child_rect.size.x <= 0 or child_rect.size.y <= 0:
		return {}

	var parent_door := MapCreatorDoor.new(
		parent.id,
		parent_side,
		parent_door_center,
		width
	)
	var child_door := MapCreatorDoor.new(
		-1,
		child_side,
		child_door_center,
		width
	)
	var segments: Array[Rect2i] = []

	if straight:
		var segment := _segment_rect(
			parent_door_center,
			child_door_center,
			width
		)
		if segment.size.x <= 0 or segment.size.y <= 0:
			return {}
		segments.append(segment)
	else:
		var turn := parent_door_center + parent_direction * dx
		var first := _segment_rect(parent_door_center, turn, width)
		var second := _segment_rect(turn, child_door_center, width)

		if (
			first.size.x <= 0
			or first.size.y <= 0
			or second.size.x <= 0
			or second.size.y <= 0
		):
			return {}

		segments.append(first)
		segments.append(second)

	return {
		"parent_id": parent.id,
		"parent_side": parent_side,
		"child_rect": child_rect,
		"child_side": child_side,
		"parent_door": parent_door,
		"child_door": child_door,
		"width": width,
		"segments": segments,
	}

func _validate_placement(placement: Dictionary) -> bool:
	var child_rect: Rect2i = placement["child_rect"]

	if not _is_rect_free(child_rect, _config.room_margin):
		return false

	var segments: Array[Rect2i] = placement["segments"]

	for segment in segments:
		for cell in _rect_cells(segment):
			if _occupancy.has(cell):
				return false
			if _rect_has_cell(child_rect, cell):
				return false

	return true

func _commit_placement(
	parent: MapCreatorRoom,
	placement: Dictionary
) -> void:
	var child_rect: Rect2i = placement["child_rect"]
	var child := MapCreatorRoom.new(_next_room_id, child_rect)
	_next_room_id += 1

	var parent_door: MapCreatorDoor = placement["parent_door"]
	var child_door: MapCreatorDoor = placement["child_door"]
	child_door.room_id = child.id

	parent.add_door(parent_door)
	child.add_door(child_door)

	var segments: Array[Rect2i] = placement["segments"]
	for segment in segments:
		_mark_rect(segment, CELL_CORRIDOR)

	_mark_rect(child_rect, CELL_ROOM)
	_rooms.append(child)

	var corridor := MapCreatorCorridor.new(
		_next_corridor_id,
		parent.id,
		child.id,
		parent_door,
		child_door,
		int(placement["width"]),
		segments
	)
	_next_corridor_id += 1
	_corridors.append(corridor)

func _is_rect_free(rect: Rect2i, margin: int) -> bool:
	var expanded := rect.grow(margin)

	for y in range(expanded.position.y, expanded.end.y):
		for x in range(expanded.position.x, expanded.end.x):
			if _occupancy.has(Vector2i(x, y)):
				return false

	return true

func _mark_rect(rect: Rect2i, cell_type: int) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			_occupancy[Vector2i(x, y)] = cell_type

func _get_room(room_id: int) -> MapCreatorRoom:
	for room in _rooms:
		if room.id == room_id:
			return room
	return null

func _random_room_size() -> Vector2i:
	return Vector2i(
		_rng.randi_range(_config.room_min_size.x, _config.room_max_size.x),
		_rng.randi_range(_config.room_min_size.y, _config.room_max_size.y)
	)

func _rect_from_door(
	side: int,
	door_center: Vector2i,
	size: Vector2i
) -> Rect2i:
	match side:
		MapCreatorTypes.Side.NORTH:
			return Rect2i(
				door_center.x - size.x / 2,
				door_center.y + 1,
				size.x,
				size.y
			)
		MapCreatorTypes.Side.EAST:
			return Rect2i(
				door_center.x - size.x,
				door_center.y - size.y / 2,
				size.x,
				size.y
			)
		MapCreatorTypes.Side.SOUTH:
			return Rect2i(
				door_center.x - size.x / 2,
				door_center.y - size.y,
				size.x,
				size.y
			)
		_:
			return Rect2i(
				door_center.x + 1,
				door_center.y - size.y / 2,
				size.x,
				size.y
			)

func _segment_rect(a: Vector2i, b: Vector2i, width: int) -> Rect2i:
	if a.x == b.x:
		return Rect2i(
			a.x - width / 2,
			mini(a.y, b.y),
			width,
			absi(a.y - b.y) + 1
		)

	if a.y == b.y:
		return Rect2i(
			mini(a.x, b.x),
			a.y - width / 2,
			absi(a.x - b.x) + 1,
			width
		)

	return Rect2i()

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

func _find_farthest_room(start_id: int) -> int:
	var adjacency := {}
	for room in _rooms:
		adjacency[room.id] = []

	for corridor in _corridors:
		adjacency[corridor.from_room_id].append(corridor.to_room_id)
		adjacency[corridor.to_room_id].append(corridor.from_room_id)

	var distances := {start_id: 0}
	var queue: Array[int] = [start_id]
	var head := 0
	var farthest := start_id
	var max_distance := 0

	while head < queue.size():
		var current: int = queue[head]
		head += 1

		for neighbor in adjacency[current]:
			if distances.has(neighbor):
				continue

			distances[neighbor] = distances[current] + 1

			if distances[neighbor] > max_distance:
				max_distance = distances[neighbor]
				farthest = neighbor

			queue.append(neighbor)

	return farthest

func _compute_bounds(layout: MapCreatorLayout) -> void:
	if _rooms.is_empty():
		layout.bounds_tiles = Rect2i()
		layout.bounds_px = Rect2()
		return

	var min_cell := Vector2i(2147483647, 2147483647)
	var max_cell := Vector2i(-2147483648, -2147483648)

	for room in _rooms:
		min_cell.x = mini(min_cell.x, room.rect.position.x)
		min_cell.y = mini(min_cell.y, room.rect.position.y)
		max_cell.x = maxi(max_cell.x, room.rect.end.x - 1)
		max_cell.y = maxi(max_cell.y, room.rect.end.y - 1)

	for corridor in _corridors:
		for segment in corridor.segments:
			min_cell.x = mini(min_cell.x, segment.position.x)
			min_cell.y = mini(min_cell.y, segment.position.y)
			max_cell.x = maxi(max_cell.x, segment.end.x - 1)
			max_cell.y = maxi(max_cell.y, segment.end.y - 1)

	var margin := _config.wall_margin
	var bounds := Rect2i(
		min_cell - Vector2i(margin, margin),
		max_cell - min_cell + Vector2i(1 + margin * 2, 1 + margin * 2)
	)
	var offset := -bounds.position

	if offset != Vector2i.ZERO:
		_shift_layout(offset)
		bounds.position = Vector2i.ZERO

	layout.bounds_tiles = bounds
	layout.bounds_px = Rect2(
		Vector2(bounds.position) * Vector2(layout.tile_size),
		Vector2(bounds.size) * Vector2(layout.tile_size)
	)

func _shift_layout(offset: Vector2i) -> void:
	for room in _rooms:
		room.rect = Rect2i(room.rect.position + offset, room.rect.size)

		for door in room.doors:
			door.center += offset

	for corridor in _corridors:
		for i in range(corridor.segments.size()):
			var segment := corridor.segments[i]
			corridor.segments[i] = Rect2i(
				segment.position + offset,
				segment.size
			)
