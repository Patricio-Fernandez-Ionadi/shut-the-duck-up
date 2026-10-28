extends PanelContainer
class_name MapCreatorPreviewPanel

signal generate_requested
signal new_seed_requested
signal copy_seed_requested
signal fit_requested
signal show_wall_tiles_toggled(enabled: bool)
signal show_wall_masks_toggled(enabled: bool)
signal save_scene_requested

@onready var seed_edit: LineEdit = %SeedEdit
@onready var room_count: SpinBox = %RoomCount
@onready var room_min_width: SpinBox = %RoomMinWidth
@onready var room_min_height: SpinBox = %RoomMinHeight
@onready var room_max_width: SpinBox = %RoomMaxWidth
@onready var room_max_height: SpinBox = %RoomMaxHeight
@onready var corridor_width_min: SpinBox = %CorridorWidthMin
@onready var corridor_width_max: SpinBox = %CorridorWidthMax
@onready var corridor_length_min: SpinBox = %CorridorLengthMin
@onready var corridor_length_max: SpinBox = %CorridorLengthMax
@onready var room_margin: SpinBox = %RoomMargin
@onready var wall_margin: SpinBox = %WallMargin
@onready var tile_width: SpinBox = %TileWidth
@onready var tile_height: SpinBox = %TileHeight
@onready var new_seed_button: Button = %NewSeedButton
@onready var copy_seed_button: Button = %CopySeedButton
@onready var wall_tiles_check: CheckButton = %WallTilesCheck
@onready var wall_masks_check: CheckButton = %WallMasksCheck
@onready var save_scene_button: Button = %SaveSceneButton
@onready var generate_button: Button = %GenerateButton
@onready var fit_button: Button = %FitButton
@onready var status_label: Label = %Status

func _ready() -> void:
	generate_button.pressed.connect(_on_generate_pressed)
	new_seed_button.pressed.connect(_on_new_seed_pressed)
	copy_seed_button.pressed.connect(_on_copy_seed_pressed)
	wall_tiles_check.toggled.connect(_on_wall_tiles_toggled)
	wall_masks_check.toggled.connect(_on_wall_masks_toggled)
	save_scene_button.pressed.connect(_on_save_scene_pressed)
	fit_button.pressed.connect(_on_fit_pressed)
	seed_edit.text_submitted.connect(_on_seed_submitted)

func bind_config(config: MapCreatorConfig) -> void:
	if config == null:
		return

	seed_edit.text = str(config.layout_seed)
	room_count.value = config.room_count
	room_min_width.value = config.room_min_size.x
	room_min_height.value = config.room_min_size.y
	room_max_width.value = config.room_max_size.x
	room_max_height.value = config.room_max_size.y
	corridor_width_min.value = config.corridor_width_min
	corridor_width_max.value = config.corridor_width_max
	corridor_length_min.value = config.corridor_length_min
	corridor_length_max.value = config.corridor_length_max
	room_margin.value = config.room_margin
	wall_margin.value = config.wall_margin
	tile_width.value = config.tile_size.x
	tile_height.value = config.tile_size.y

func apply_to_config(config: MapCreatorConfig) -> void:
	if config == null:
		return

	config.layout_seed = int(seed_edit.text)
	config.room_count = int(room_count.value)
	config.room_min_size = Vector2i(
		int(room_min_width.value),
		int(room_min_height.value)
	)
	config.room_max_size = Vector2i(
		int(room_max_width.value),
		int(room_max_height.value)
	)
	config.corridor_width_min = int(corridor_width_min.value)
	config.corridor_width_max = int(corridor_width_max.value)
	config.corridor_length_min = int(corridor_length_min.value)
	config.corridor_length_max = int(corridor_length_max.value)
	config.room_margin = int(room_margin.value)
	config.wall_margin = int(wall_margin.value)
	config.tile_size = Vector2i(int(tile_width.value), int(tile_height.value))

func set_seed(seed: int) -> void:
	seed_edit.text = str(seed)

func set_status(text: String, is_error: bool = false) -> void:
	status_label.text = text
	status_label.modulate = (
		Color(1.0, 0.45, 0.45, 1.0)
		if is_error
		else Color(0.65, 0.9, 0.7, 1.0)
	)

func set_wall_tiles_visible(enabled: bool) -> void:
	wall_tiles_check.set_pressed_no_signal(enabled)

func set_wall_masks_visible(enabled: bool) -> void:
	wall_masks_check.set_pressed_no_signal(enabled)

func _on_generate_pressed() -> void:
	generate_requested.emit()

func _on_new_seed_pressed() -> void:
	new_seed_requested.emit()

func _on_copy_seed_pressed() -> void:
	copy_seed_requested.emit()

func _on_wall_tiles_toggled(enabled: bool) -> void:
	show_wall_tiles_toggled.emit(enabled)

func _on_wall_masks_toggled(enabled: bool) -> void:
	show_wall_masks_toggled.emit(enabled)

func _on_save_scene_pressed() -> void:
	save_scene_requested.emit()

func _on_fit_pressed() -> void:
	fit_requested.emit()

func _on_seed_submitted(_text: String) -> void:
	generate_requested.emit()
