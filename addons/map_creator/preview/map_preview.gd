extends Node2D
class_name MapCreatorPreview

@export var config: MapCreatorConfig
@export var generate_on_ready: bool = true
@export var resize_window_on_ready: bool = true
@export var window_size_ratio: Vector2 = Vector2(0.8, 0.8)
@export var window_margin: int = 40
@export var panel_width_ratio: float = 0.2
@export var panel_min_width: float = 300.0
@export var panel_max_width: float = 480.0
@export var panel_margin: float = 16.0

var layout: MapCreatorLayout

var _working_config: MapCreatorConfig
var _panel_width: float = 0.0

@onready var camera: MapCreatorCameraController = $Camera2D
@onready var info_label: Label = $UI/Info
@onready var panel: MapCreatorPreviewPanel = $UI/Panel

func _ready() -> void:
	if config == null:
		config = MapCreatorConfig.new()

	_working_config = config.duplicate(true) as MapCreatorConfig
	if _working_config == null:
		_working_config = config.sanitized_copy()

	_setup_window()
	panel.generate_requested.connect(_on_generate_requested)
	panel.new_seed_requested.connect(_on_new_seed_requested)
	panel.fit_requested.connect(_on_fit_requested)
	get_viewport().size_changed.connect(_on_viewport_resized)
	panel.bind_config(_working_config)
	_update_panel_layout()

	await get_tree().process_frame
	_update_panel_layout()

	if generate_on_ready:
		_generate()

func regenerate() -> void:
	_generate()

func _setup_window() -> void:
	if not resize_window_on_ready:
		return
	if DisplayServer.get_name() == "headless":
		return

	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	if usable.size.x <= 0 or usable.size.y <= 0:
		return

	var target := Vector2i(
		int(float(usable.size.x) * clampf(window_size_ratio.x, 0.3, 1.0)),
		int(float(usable.size.y) * clampf(window_size_ratio.y, 0.3, 1.0))
	)
	target.x = mini(target.x, maxi(1, usable.size.x - window_margin))
	target.y = mini(target.y, maxi(1, usable.size.y - window_margin))

	var window := get_window()
	window.size = target
	window.position = usable.position + (usable.size - target) / 2

func _generate() -> void:
	if _working_config == null:
		return

	_working_config = _working_config.sanitized_copy()

	var generator := MapCreatorGenerator.new()
	layout = generator.generate(_working_config)
	_working_config.layout_seed = layout.layout_seed

	panel.bind_config(_working_config)
	_update_panel_layout()
	_update_info()
	_fit_camera()
	queue_redraw()

func _update_info() -> void:
	if layout == null or info_label == null:
		return

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

	var embedded_note := ""
	if get_window().is_embedded():
		embedded_note = (
			"\nVentana embebida: desactivá Embed Game para usar el tamaño configurado."
		)

	if errors.is_empty():
		panel.set_status("Layout válido." + embedded_note)
		return

	var visible_errors := PackedStringArray()
	for i in range(mini(3, errors.size())):
		visible_errors.append(errors[i])
	panel.set_status("\n".join(visible_errors) + embedded_note, true)

func _update_panel_layout() -> void:
	if panel == null:
		return

	var viewport_size := get_viewport_rect().size
	if viewport_size.x <= 0.0:
		return

	var total_width := clampf(
		viewport_size.x * panel_width_ratio,
		panel_min_width + panel_margin,
		panel_max_width + panel_margin
	)
	_panel_width = maxf(panel_min_width, total_width - panel_margin)
	panel.offset_left = -(_panel_width + panel_margin)
	panel.offset_right = -panel_margin
	panel.offset_top = panel_margin
	panel.offset_bottom = -panel_margin

func _get_map_area() -> Rect2:
	var viewport_size := get_viewport_rect().size
	if _panel_width <= 0.0:
		return Rect2(Vector2.ZERO, viewport_size)

	var map_width := maxf(1.0, viewport_size.x - (_panel_width + panel_margin))
	return Rect2(Vector2.ZERO, Vector2(map_width, viewport_size.y))

func _fit_camera() -> void:
	if layout == null or camera == null:
		return

	camera.set_layout_bounds(layout.bounds_px)
	camera.set_map_area(_get_map_area())
	camera.fit()

func _on_generate_requested() -> void:
	if _working_config == null:
		return
	panel.apply_to_config(_working_config)
	_generate()

func _on_new_seed_requested() -> void:
	if _working_config == null:
		return

	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var new_seed := int(rng.seed)
	if new_seed == 0:
		new_seed = 1

	_working_config.layout_seed = new_seed
	panel.set_seed(new_seed)
	panel.apply_to_config(_working_config)
	_generate()

func _on_fit_requested() -> void:
	_fit_camera()

func _on_viewport_resized() -> void:
	_update_panel_layout()
	_fit_camera()

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
