extends RefCounted
class_name MapCreatorLayoutGeometry

var layout: MapCreatorLayout = null
var wall_thickness: int = 1
var floor_cells: Dictionary = {}
var wall_cells: Dictionary = {}
var wall_runs: Array[Rect2i] = []
var bounds_tiles: Rect2i = Rect2i()
var bounds_px: Rect2 = Rect2()
var spawn_position_px: Vector2 = Vector2.ZERO
var exit_position_px: Vector2 = Vector2.ZERO

func build(
	p_layout: MapCreatorLayout,
	p_wall_thickness: int = 1
) -> void:
	layout = p_layout
	wall_thickness = maxi(1, p_wall_thickness)
	floor_cells.clear()
	wall_cells.clear()
	wall_runs.clear()

	if layout == null:
		bounds_tiles = Rect2i()
		bounds_px = Rect2()
		spawn_position_px = Vector2.ZERO
		exit_position_px = Vector2.ZERO
		return

	for room in layout.rooms:
		_add_rect_cells(floor_cells, room.rect)

	for corridor in layout.corridors:
		for segment in corridor.segments:
			_add_rect_cells(floor_cells, segment)

	_build_wall_cells()
	_compute_bounds()
	_build_wall_runs()

	spawn_position_px = get_room_center_px(
		layout.get_room(layout.spawn_room_id)
	)
	exit_position_px = get_room_center_px(
		layout.get_room(layout.exit_room_id)
	)

func is_floor_cell(cell: Vector2i) -> bool:
	return floor_cells.has(cell)

func is_wall_cell(cell: Vector2i) -> bool:
	return wall_cells.has(cell)

func get_spawn_cell() -> Vector2i:
	if layout == null:
		return Vector2i.ZERO
	return _room_center_cell(layout.get_room(layout.spawn_room_id))

func get_exit_cell() -> Vector2i:
	if layout == null:
		return Vector2i.ZERO
	return _room_center_cell(layout.get_room(layout.exit_room_id))

func get_room_center_px(room: MapCreatorRoom) -> Vector2:
	if room == null or layout == null:
		return Vector2.ZERO

	var tile := Vector2(layout.tile_size.x, layout.tile_size.y)
	var center := Vector2(room.rect.position) + Vector2(room.rect.size) * 0.5
	return center * tile

func validate() -> Array[String]:
	var errors: Array[String] = []

	if layout == null:
		errors.append("geometry has no layout")
		return errors

	if floor_cells.is_empty():
		errors.append("geometry has no floor cells")
	if wall_cells.is_empty():
		errors.append("geometry has no wall cells")

	var overlap_count := 0
	for cell in floor_cells.keys():
		if wall_cells.has(cell):
			overlap_count += 1
	if overlap_count > 0:
		errors.append("%d cells are both floor and wall" % overlap_count)

	if not is_floor_cell(get_spawn_cell()):
		errors.append("spawn cell is not on floor")
	if not is_floor_cell(get_exit_cell()):
		errors.append("exit cell is not on floor")

	for room in layout.rooms:
		for door in room.doors:
			if not is_floor_cell(door.center):
				errors.append(
					"room %d door at %s is not on floor"
					% [room.id, door.center]
				)

	for cell in floor_cells.keys():
		if not _rect_has_cell(bounds_tiles, cell):
			errors.append("floor cell %s is outside geometry bounds" % cell)
			break

	for cell in wall_cells.keys():
		if not _rect_has_cell(bounds_tiles, cell):
			errors.append("wall cell %s is outside geometry bounds" % cell)
			break

	var covered := {}
	var duplicate_count := 0
	for run in wall_runs:
		if run.size.x <= 0 or run.size.y <= 0:
			errors.append("wall run has invalid size %s" % run)
			continue

		var invalid_run := false
		for y in range(run.position.y, run.end.y):
			for x in range(run.position.x, run.end.x):
				var cell := Vector2i(x, y)
				if not wall_cells.has(cell):
					invalid_run = true
					break
				if covered.has(cell):
					duplicate_count += 1
				covered[cell] = true
			if invalid_run:
				break

		if invalid_run:
			errors.append("wall run %s includes non-wall cells" % run)

	if duplicate_count > 0:
		errors.append(
			"%d wall cells are covered by more than one run"
			% duplicate_count
		)
	if covered.size() != wall_cells.size():
		errors.append(
			"wall runs cover %d of %d wall cells"
			% [covered.size(), wall_cells.size()]
		)

	return errors

func to_dictionary() -> Dictionary:
	var run_data: Array = []
	for run in wall_runs:
		run_data.append([
			run.position.x,
			run.position.y,
			run.size.x,
			run.size.y,
		])

	return {
		"floor_count": floor_cells.size(),
		"wall_count": wall_cells.size(),
		"wall_runs": run_data,
		"bounds_tiles": [
			bounds_tiles.position.x,
			bounds_tiles.position.y,
			bounds_tiles.size.x,
			bounds_tiles.size.y,
		],
		"spawn_position_px": [spawn_position_px.x, spawn_position_px.y],
		"exit_position_px": [exit_position_px.x, exit_position_px.y],
	}

func _add_rect_cells(target: Dictionary, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			target[Vector2i(x, y)] = true

func _build_wall_cells() -> void:
	for floor_cell in floor_cells.keys():
		for dy in range(-wall_thickness, wall_thickness + 1):
			for dx in range(-wall_thickness, wall_thickness + 1):
				var cell: Vector2i = floor_cell + Vector2i(dx, dy)
				if not floor_cells.has(cell):
					wall_cells[cell] = true

func _compute_bounds() -> void:
	var cells: Array = floor_cells.keys()
	cells.append_array(wall_cells.keys())

	if cells.is_empty():
		bounds_tiles = Rect2i()
		bounds_px = Rect2()
		return

	var first: Vector2i = cells[0]
	var min_cell := first
	var max_cell := first

	for cell_value in cells:
		var cell: Vector2i = cell_value
		min_cell.x = mini(min_cell.x, cell.x)
		min_cell.y = mini(min_cell.y, cell.y)
		max_cell.x = maxi(max_cell.x, cell.x)
		max_cell.y = maxi(max_cell.y, cell.y)

	bounds_tiles = Rect2i(
		min_cell,
		max_cell - min_cell + Vector2i.ONE
	)

	var tile := Vector2(layout.tile_size.x, layout.tile_size.y)
	bounds_px = Rect2(
		Vector2(bounds_tiles.position) * tile,
		Vector2(bounds_tiles.size) * tile
	)

func _build_wall_runs() -> void:
	var remaining := wall_cells.duplicate()
	var cells: Array = remaining.keys()
	cells.sort_custom(_cell_less_than)

	for cell_value in cells:
		var cell: Vector2i = cell_value
		if not remaining.has(cell):
			continue

		var width := 0
		while remaining.has(cell + Vector2i(width, 0)):
			width += 1

		var height := 1
		while true:
			var row_y: int = cell.y + height
			var can_expand := true
			for x in range(cell.x, cell.x + width):
				if not remaining.has(Vector2i(x, row_y)):
					can_expand = false
					break
			if not can_expand:
				break
			height += 1

		for y in range(cell.y, cell.y + height):
			for x in range(cell.x, cell.x + width):
				remaining.erase(Vector2i(x, y))

		wall_runs.append(Rect2i(cell, Vector2i(width, height)))

func _cell_less_than(a: Vector2i, b: Vector2i) -> bool:
	if a.y == b.y:
		return a.x < b.x
	return a.y < b.y

func _room_center_cell(room: MapCreatorRoom) -> Vector2i:
	if room == null:
		return Vector2i.ZERO
	return room.rect.position + Vector2i(
		room.rect.size.x / 2,
		room.rect.size.y / 2
	)

func _rect_has_cell(rect: Rect2i, cell: Vector2i) -> bool:
	return (
		cell.x >= rect.position.x
		and cell.y >= rect.position.y
		and cell.x < rect.end.x
		and cell.y < rect.end.y
	)
