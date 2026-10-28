extends Node2D
class_name MapCreatorPreview

@export var config: MapCreatorConfig
@export var generate_on_ready: bool = true
@export_range(1, 4, 1) var wall_thickness: int = 1
@export var resize_window_on_ready: bool = true
@export var window_size_ratio: Vector2 = Vector2(0.8, 0.8)
@export var window_margin: int = 40
@export var panel_width_ratio: float = 0.2
@export var panel_min_width: float = 300.0
@export var panel_max_width: float = 480.0
@export var panel_margin: float = 16.0
@export var wall_mapping: MapCreatorWallTileMapping
@export var show_wall_tiles: bool = true
@export var show_wall_masks: bool = false
@export_file("*.tscn") var generated_level_scene_path: String = ""
@export_dir var generated_scene_dir: String = ""

var layout: MapCreatorLayout
var geometry: MapCreatorLayoutGeometry

var _working_config: MapCreatorConfig
var _panel_width: float = 0.0
var _wall_stats: Dictionary = {}

@onready var camera: MapCreatorCameraController = $Camera2D
@onready var info_label: Label = $UI/Info
@onready var panel: MapCreatorPreviewPanel = $UI/Panel
@onready var wall_base_layer: TileMapLayer = $WallBase
@onready var wall_overlay_layer: TileMapLayer = $WallOverlay
@onready var mask_overlay: MapCreatorPreviewMaskOverlay = $MaskOverlay

func _ready() -> void:
	if config == null:
		config = MapCreatorConfig.new()

	_working_config = config.duplicate(true) as MapCreatorConfig
	if _working_config == null:
		_working_config = config.sanitized_copy()

	_setup_window()
	panel.generate_requested.connect(_on_generate_requested)
	panel.new_seed_requested.connect(_on_new_seed_requested)
	panel.copy_seed_requested.connect(_on_copy_seed_requested)
	panel.fit_requested.connect(_on_fit_requested)
	panel.show_wall_tiles_toggled.connect(_on_show_wall_tiles_toggled)
	panel.show_wall_masks_toggled.connect(_on_show_wall_masks_toggled)
	panel.save_scene_requested.connect(_on_save_scene_requested)
	get_viewport().size_changed.connect(_on_viewport_resized)
	panel.bind_config(_working_config)
	panel.set_wall_tiles_visible(show_wall_tiles)
	panel.set_wall_masks_visible(show_wall_masks)
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

	geometry = MapCreatorLayoutGeometry.new()
	geometry.build(layout, wall_thickness)
	_render_walls()

	panel.bind_config(_working_config)
	_update_panel_layout()
	_update_info()
	_fit_camera()
	queue_redraw()

func _render_walls() -> void:
	_wall_stats.clear()

	if wall_mapping == null or geometry == null:
		_clear_wall_layers()
		_update_mask_overlay()
		return

	var renderer := MapCreatorWallTileRenderer.new()
	renderer.setup(
		wall_mapping,
		geometry,
		wall_base_layer,
		wall_overlay_layer
	)
	_wall_stats = renderer.render()
	wall_base_layer.collision_enabled = false
	wall_overlay_layer.collision_enabled = false
	wall_base_layer.visible = show_wall_tiles
	wall_overlay_layer.visible = show_wall_tiles

	if mask_overlay != null:
		mask_overlay.geometry = geometry
		mask_overlay.tile_size = layout.tile_size
		mask_overlay.wall_masks = renderer.wall_masks
		mask_overlay.floor_masks = renderer.floor_masks
		mask_overlay.show_masks = show_wall_masks
		mask_overlay.queue_redraw()

func _clear_wall_layers() -> void:
	if wall_base_layer != null:
		wall_base_layer.clear()
		wall_base_layer.visible = false
	if wall_overlay_layer != null:
		wall_overlay_layer.clear()
		wall_overlay_layer.visible = false

func _update_mask_overlay() -> void:
	if mask_overlay == null:
		return
	mask_overlay.geometry = geometry
	if layout != null:
		mask_overlay.tile_size = layout.tile_size
	mask_overlay.wall_masks.clear()
	mask_overlay.floor_masks.clear()
	mask_overlay.show_masks = show_wall_masks
	mask_overlay.queue_redraw()

func _update_info() -> void:
	if layout == null or info_label == null:
		return

	var errors := layout.validate()
	var floor_count := 0
	var wall_count := 0
	var bounds_tiles := layout.bounds_tiles
	var wall_run_count := 0

	if geometry != null:
		errors.append_array(geometry.validate())
		floor_count = geometry.floor_cells.size()
		wall_count = geometry.wall_cells.size()
		bounds_tiles = geometry.bounds_tiles
		wall_run_count = geometry.wall_runs.size()

	if wall_mapping != null:
		errors.append_array(wall_mapping.validate())

	var mapping_note := ""
	if wall_mapping != null and not _wall_stats.is_empty():
		var stats_wall_count := int(_wall_stats.get("wall_cells", 0))
		var base_mapped := int(_wall_stats.get("base_mapped", 0))
		var overlay_mapped := int(_wall_stats.get("overlay_mapped", 0))
		var base_fallback := int(_wall_stats.get("base_fallback", 0))
		var overlay_fallback := int(_wall_stats.get("overlay_fallback", 0))

		mapping_note = " · map base %d/%d overlay %d/%d" % [
			base_mapped,
			stats_wall_count,
			overlay_mapped,
			stats_wall_count,
		]
		if base_fallback > 0 or overlay_fallback > 0:
			mapping_note += " fb %d/%d" % [
				base_fallback,
				overlay_fallback,
			]

	var status := "OK"
	if not errors.is_empty():
		status = "%d errores" % errors.size()
		for error in errors:
			push_warning(error)

	info_label.text = (
		"Map Creator — seed %d · rooms %d · corridors %d · "
		+ "floor %d · walls %d (%d runs) · bounds %dx%d tiles · %s%s"
	) % [
		layout.layout_seed,
		layout.rooms.size(),
		layout.corridors.size(),
		floor_count,
		wall_count,
		wall_run_count,
		bounds_tiles.size.x,
		bounds_tiles.size.y,
		status,
		mapping_note,
	]

	var embedded_note := ""
	if get_window().is_embedded():
		embedded_note = (
			"\nVentana embebida: desactivá Embed Game para usar el tamaño configurado."
		)

	if errors.is_empty():
		var status_text := "Geometría válida."
		if wall_mapping == null:
			status_text += " Sin mapping de paredes."
		elif not _wall_stats.is_empty():
			var stats_wall_count := int(_wall_stats.get("wall_cells", 0))
			var base_mapped := int(_wall_stats.get("base_mapped", 0))
			var overlay_mapped := int(_wall_stats.get("overlay_mapped", 0))
			status_text += " Mapping base %d/%d, overlay %d/%d." % [
				base_mapped,
				stats_wall_count,
				overlay_mapped,
				stats_wall_count,
			]
		panel.set_status(status_text + embedded_note)
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

	var bounds := layout.bounds_px
	if geometry != null:
		bounds = geometry.bounds_px

	camera.set_layout_bounds(bounds)
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

func _on_copy_seed_requested() -> void:
	if layout == null:
		return

	var seed_text := str(layout.layout_seed)
	if DisplayServer.get_name() == "headless":
		panel.set_status("Seed %s (headless: no se copió)." % seed_text)
		return

	DisplayServer.clipboard_set(seed_text)
	panel.set_status("Seed %s copiada al portapapeles." % seed_text)

func _on_fit_requested() -> void:
	_fit_camera()

func _on_show_wall_tiles_toggled(enabled: bool) -> void:
	show_wall_tiles = enabled
	if wall_base_layer != null:
		wall_base_layer.visible = enabled and wall_mapping != null
	if wall_overlay_layer != null:
		wall_overlay_layer.visible = enabled and wall_mapping != null
	queue_redraw()

func _on_show_wall_masks_toggled(enabled: bool) -> void:
	show_wall_masks = enabled
	if mask_overlay != null:
		mask_overlay.show_masks = enabled
		mask_overlay.queue_redraw()

func _on_save_scene_requested() -> void:
	if _working_config == null:
		panel.set_status("No hay configuración para guardar.", true)
		return

	panel.apply_to_config(_working_config)
	_generate()

	if layout == null or geometry == null:
		panel.set_status("No se pudo generar el layout.", true)
		return

	if (
		generated_level_scene_path.is_empty()
		or not ResourceLoader.exists(generated_level_scene_path)
	):
		panel.set_status(
			"No existe la escena base: %s" % generated_level_scene_path,
			true
		)
		return

	var output_dir := generated_scene_dir.strip_edges().trim_suffix("/")
	if output_dir.is_empty():
		panel.set_status("Configurá el directorio de escenas.", true)
		return

	var absolute_dir := ProjectSettings.globalize_path(output_dir)
	var dir_error := DirAccess.make_dir_recursive_absolute(absolute_dir)
	if dir_error != OK:
		panel.set_status(
			"No se pudo crear %s (error %d)." % [output_dir, dir_error],
			true
		)
		return

	var seed_value := layout.layout_seed
	var base_name := "seed_%d" % seed_value
	var config_path := output_dir.path_join(base_name + ".tres")
	var scene_path := output_dir.path_join(base_name + ".tscn")

	_working_config.layout_seed = seed_value
	var config_to_save := _working_config.duplicate(true) as MapCreatorConfig
	if config_to_save == null:
		config_to_save = _working_config.sanitized_copy()

	var config_error := ResourceSaver.save(config_to_save, config_path)
	if config_error != OK:
		panel.set_status(
			"No se pudo guardar %s (error %d)." % [config_path, config_error],
			true
		)
		return

	var scene_text := _build_seed_scene_text(config_path)
	var file := FileAccess.open(scene_path, FileAccess.WRITE)
	if file == null:
		panel.set_status("No se pudo escribir %s." % scene_path, true)
		return

	file.store_string(scene_text)
	file.close()
	panel.set_status(
		"Escena guardada: %s\nConfig: %s" % [scene_path, config_path]
	)

func _build_seed_scene_text(config_path: String) -> String:
	var ext_resources: Array[String] = []
	ext_resources.append(
		'[ext_resource type="PackedScene" path="%s" id="1_level"]'
		% generated_level_scene_path
	)
	ext_resources.append(
		'[ext_resource type="Resource" path="%s" id="2_config"]'
		% config_path
	)

	var mapping_line := ""
	if wall_mapping != null and not wall_mapping.resource_path.is_empty():
		ext_resources.append(
			'[ext_resource type="Resource" path="%s" id="3_mapping"]'
			% wall_mapping.resource_path
		)
		mapping_line = "\nwall_mapping = ExtResource(\"3_mapping\")"

	var text := "[gd_scene load_steps=%d format=3]\n\n" % (
		ext_resources.size() + 1
	)
	text += "\n".join(ext_resources)
	text += "\n\n[node name=\"Level_1\" instance=ExtResource(\"1_level\")]\n"
	text += "config = ExtResource(\"2_config\")"
	text += mapping_line
	text += "\n"
	return text

func _on_viewport_resized() -> void:
	_update_panel_layout()
	_fit_camera()

func _draw() -> void:
	if layout == null:
		return

	var tile := Vector2(layout.tile_size)
	var bounds := layout.bounds_px
	var bounds_tiles := layout.bounds_tiles

	if geometry != null:
		bounds = geometry.bounds_px
		bounds_tiles = geometry.bounds_tiles

	draw_rect(bounds, Color(0.04, 0.05, 0.07, 1.0), true)
	_draw_grid(bounds, tile, bounds_tiles)

	if geometry != null:
		var draw_placeholder_walls := (
			not show_wall_tiles
			or wall_mapping == null
			or int(_wall_stats.get("base_cells", 0)) == 0
		)

		if draw_placeholder_walls:
			var wall_color := Color(0.31, 0.34, 0.36, 1.0)
			var wall_edge := Color(0.47, 0.51, 0.54, 0.8)

			for run in geometry.wall_runs:
				var wall_rect := _rect_px(run, tile)
				draw_rect(wall_rect, wall_color, true)
				draw_rect(wall_rect, wall_edge, false, 1.0)

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

func _draw_grid(
	bounds: Rect2,
	tile: Vector2,
	bounds_tiles: Rect2i
) -> void:
	var step := 8
	var color := Color(1.0, 1.0, 1.0, 0.05)

	for x in range(bounds_tiles.position.x, bounds_tiles.end.x + 1, step):
		var px := float(x) * tile.x
		draw_line(
			Vector2(px, bounds.position.y),
			Vector2(px, bounds.end.y),
			color,
			1.0
		)

	for y in range(bounds_tiles.position.y, bounds_tiles.end.y + 1, step):
		var py := float(y) * tile.y
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
