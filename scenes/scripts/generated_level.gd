extends Node2D
class_name GeneratedLevel

@export var config: MapCreatorConfig
@export var wall_mapping: MapCreatorWallTileMapping
@export var floor_tile_set: TileSet
@export var floor_source_id: int = 1
@export var floor_atlas_coords: Vector2i = Vector2i.ZERO
@export var floor_alternative_tile: int = 0
@export var debug_print: bool = false

@onready var floor_layer: TileMapLayer = $Floor
@onready var wall_base_layer: TileMapLayer = $WallBase
@onready var wall_overlay_layer: TileMapLayer = $WallOverlay
@onready var player: PlayerCharacter = $Player
@onready var exit_zone: ExitZone = $Exit

var layout: MapCreatorLayout
var geometry: MapCreatorLayoutGeometry

func _ready() -> void:
	_build_level()

func _build_level() -> void:
	var effective_config := config
	if effective_config == null:
		effective_config = MapCreatorConfig.new()
	effective_config = effective_config.sanitized_copy()

	layout = MapCreatorGenerator.new().generate(effective_config)
	geometry = MapCreatorLayoutGeometry.new()
	geometry.build(layout, 1)

	for error in layout.validate():
		push_warning(error)
	for error in geometry.validate():
		push_warning(error)

	_build_floor()
	_build_walls()
	_place_actors()
	_configure_camera()

	if debug_print:
		print(
			"GeneratedLevel seed=%d rooms=%d floor=%d walls=%d"
			% [
				layout.layout_seed,
				layout.rooms.size(),
				geometry.floor_cells.size(),
				geometry.wall_cells.size(),
			]
		)

func _build_floor() -> void:
	if floor_layer == null or floor_tile_set == null:
		push_warning("GeneratedLevel has no floor tile set")
		return

	floor_layer.tile_set = floor_tile_set
	floor_layer.z_index = -10
	floor_layer.clear()

	for cell_value in geometry.floor_cells.keys():
		var cell: Vector2i = cell_value
		floor_layer.set_cell(
			cell,
			floor_source_id,
			floor_atlas_coords,
			floor_alternative_tile
		)

func _build_walls() -> void:
	if wall_base_layer == null or wall_overlay_layer == null:
		return

	if wall_mapping == null:
		wall_base_layer.clear()
		wall_overlay_layer.clear()
		push_warning("GeneratedLevel has no wall mapping")
		return

	var renderer := MapCreatorWallTileRenderer.new()
	renderer.setup(
		wall_mapping,
		geometry,
		wall_base_layer,
		wall_overlay_layer
	)
	var stats := renderer.render()

	for error in stats.get("mapping_errors", []):
		push_warning(error)

	if debug_print:
		print(
			"GeneratedLevel walls: base=%d overlay=%d fallback=%d/%d"
			% [
				stats.get("base_cells", 0),
				stats.get("overlay_cells", 0),
				stats.get("base_fallback", 0),
				stats.get("overlay_fallback", 0),
			]
		)

func _place_actors() -> void:
	if player != null:
		player.position = geometry.spawn_position_px
	if exit_zone != null:
		exit_zone.position = geometry.exit_position_px

func _configure_camera() -> void:
	if player == null:
		return

	var camera := player.get_node_or_null("Camera2D") as Camera2D
	if camera == null:
		return

	var margin := layout.tile_size
	if wall_mapping != null:
		margin = wall_mapping.get_visual_margin_px(layout.tile_size)

	var bounds := geometry.bounds_px
	var expanded := Rect2(
		bounds.position - Vector2(margin),
		bounds.size + Vector2(margin * 2)
	)

	camera.limit_left = int(expanded.position.x)
	camera.limit_top = int(expanded.position.y)
	camera.limit_right = int(expanded.end.x)
	camera.limit_bottom = int(expanded.end.y)
