extends Node2D
class_name MapCreatorPreview

@export var config: MapCreatorConfig
@export var generate_on_ready: bool = true

var layout: MapCreatorLayout

@onready var camera: Camera2D = $Camera2D
@onready var info_label: Label = $UI/Info

func _ready() -> void:
	if config == null:
		config = MapCreatorConfig.new()

	if generate_on_ready:
		regenerate()

	get_viewport().size_changed.connect(_frame_camera)

func regenerate() -> void:
	var generator := MapCreatorGenerator.new()
	layout = generator.generate(config)

	if info_label != null:
		var errors := layout.validate()
		var status := "OK"
		if not errors.is_empty():
			status = "%d errores" % errors.size()
			for error in errors:
				push_warning(error)

		info_label.text = (
			"Map Creator — seed %d · rooms %d · corridors %d · "
			+ "bounds %dx%d tiles · %s"
		) % [
			layout.layout_seed,
			layout.rooms.size(),
			layout.corridors.size(),
			layout.bounds_tiles.size.x,
			layout.bounds_tiles.size.y,
			status,
		]

	_frame_camera()
	queue_redraw()

func _frame_camera() -> void:
	if layout == null or camera == null:
		return

	var bounds := layout.bounds_px
	if bounds.size.x <= 0.0 or bounds.size.y <= 0.0:
		return

	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	var fit := minf(
		viewport_size.x / bounds.size.x,
		viewport_size.y / bounds.size.y
	) * 0.9

	camera.position = bounds.get_center()
	camera.zoom = Vector2(fit, fit)

func _draw() -> void:
	if layout == null:
		return

	var tile := Vector2(layout.tile_size)
	var bounds := layout.bounds_px

	draw_rect(bounds, Color(0.04, 0.05, 0.07, 1.0), true)
	_draw_grid(bounds, tile)

	for corridor in layout.corridors:
		for segment in corridor.segments:
			draw_rect(
				_rect_px(segment, tile),
				Color(0.18, 0.32, 0.48, 0.85),
				true
			)

	for room in layout.rooms:
		var hue := float(room.id) / float(maxi(1, layout.rooms.size()))
		var fill := Color.from_hsv(hue, 0.35, 0.72, 0.9)
		var rect := _rect_px(room.rect, tile)

		draw_rect(rect, fill, true)
		draw_rect(rect, fill.lightened(0.35), false, 2.0)

	for room in layout.rooms:
		var rect := _rect_px(room.rect, tile)
		draw_string(
			ThemeDB.fallback_font,
			rect.position + Vector2(6.0, 20.0),
			"R%d" % room.id,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			14,
			Color(1.0, 1.0, 1.0, 0.9)
		)

		for door in room.doors:
			var door_position := Vector2(door.center) * tile + tile * 0.5
			draw_circle(
				door_position,
				maxf(2.0, float(door.width) * tile.x * 0.12),
				Color(1.0, 0.82, 0.25, 0.95)
			)

	_draw_marker(
		layout.get_room(layout.spawn_room_id),
		"SPAWN",
		Color(0.3, 1.0, 0.55, 1.0),
		tile
	)
	_draw_marker(
		layout.get_room(layout.exit_room_id),
		"EXIT",
		Color(1.0, 0.45, 0.35, 1.0),
		tile
	)

	draw_rect(bounds, Color(0.7, 0.8, 1.0, 0.6), false, 2.0)

func _draw_grid(bounds: Rect2, tile: Vector2) -> void:
	var step := 8
	var color := Color(1.0, 1.0, 1.0, 0.05)

	for x in range(0, layout.bounds_tiles.size.x + 1, step):
		var px := bounds.position.x + float(x) * tile.x
		draw_line(
			Vector2(px, bounds.position.y),
			Vector2(px, bounds.end.y),
			color,
			1.0
		)

	for y in range(0, layout.bounds_tiles.size.y + 1, step):
		var py := bounds.position.y + float(y) * tile.y
		draw_line(
			Vector2(bounds.position.x, py),
			Vector2(bounds.end.x, py),
			color,
			1.0
		)

func _draw_marker(
	room: MapCreatorRoom,
	text: String,
	color: Color,
	tile: Vector2
) -> void:
	if room == null:
		return

	var rect := _rect_px(room.rect, tile)
	var center := rect.get_center()

	draw_circle(center, 12.0, color)
	draw_string(
		ThemeDB.fallback_font,
		center + Vector2(16.0, 5.0),
		text,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		14,
		color
	)

func _rect_px(rect: Rect2i, tile: Vector2) -> Rect2:
	return Rect2(Vector2(rect.position) * tile, Vector2(rect.size) * tile)
