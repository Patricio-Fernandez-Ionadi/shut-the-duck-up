class_name PlayerMenu extends CanvasLayer
# PlayerMenu: menú in-game abierto con Tab (acción "open_player_menu").
# No pausa el árbol: solo muestra el overlay y devuelve el cursor.

#region ─── Constructor ────────────────────────────────────────────────────────
@onready var menu_root: Control = $Root
@onready var close_button: Button = %CloseButton
@onready var restart_button: Button = %RestartButton
@onready var quit_button: Button = %QuitButton

var _open := false
const open_pos_x_target:float = -6.0
const closed_pos_x_target:float = 1145
const duration_animation: float = .3
#endregion ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	close_button.pressed.connect(_close)
	restart_button.pressed.connect(_on_restart_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

func _process(_delta: float) -> void:
	if _open and Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("open_player_menu"):
		return

	if _open:
		_close()
	else:
		_open_menu()

	get_viewport().set_input_as_handled()

func _open_menu() -> void:
	_open = true
	_toggle_animation()

func _close() -> void:
	_open = false
	_toggle_animation()
	_restore_cursor()

func _toggle_animation():
	var target_x = open_pos_x_target if _open else closed_pos_x_target
	if _open:
		create_tween().tween_property(menu_root, "position:x", target_x, duration_animation)
	else:
		create_tween().tween_property(menu_root, "position:x", target_x, duration_animation)

func _restore_cursor() -> void:
	var player := get_tree().get_first_node_in_group("player") as Player
	var aiming := player != null and player.is_aiming
	Input.set_mouse_mode(
		Input.MOUSE_MODE_HIDDEN if aiming else Input.MOUSE_MODE_VISIBLE
	)

func _on_restart_pressed() -> void:
	_close()
	get_tree().reload_current_scene()

func _on_quit_pressed() -> void:
	get_tree().quit()
