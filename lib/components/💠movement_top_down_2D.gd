class_name MovementTopDownComponent extends Node

# ─── MOVEMENT COMPONENT ────────────────────────────────────
# Archivo: res://lib/components/💠movement_top_down_2D.gd
# Propósito:
#   Movimiento 4/8 direcciones por input, con facing. 
# Recibe:
#   - Input de las acciones configuradas (`action_left/right/up/down`).
# Comunica con:
#   - Señales `moved`, `stopped`, `facing_changed`.
# Usado por:
#   - Player, NPCs y enemigos que se muevan.
# ───────────────────────────────────────────────────────────

#region ─── Constructor ────────────────────────────────────────────────────────
# ─── COMPONENTS ────────────────────────────────────────────
@onready var parent = get_parent() as CharacterBody2D
# ─── SIGNALS ───────────────────────────────────────────────
signal moved(motion: Vector2)
signal stopped()
signal facing_changed(facing: String)
# ─── CONFIGURATION ─────────────────────────────────────────
enum FacingMode {
	FOUR_DIRECTIONS,
	EIGHT_DIRECTIONS
}

@export_category("Attributes")
## Habilita o deshabilita el input.
@export var input_enabled: bool = true
## Cantidad de direcciones de orientación.
@export var facing_mode: FacingMode = FacingMode.EIGHT_DIRECTIONS

@export_category("Input")
@export var action_left: StringName = &"move_left"
@export var action_right: StringName = &"move_right"
@export var action_up: StringName = &"move_up"
@export var action_down: StringName = &"move_down"

# ─── STATE ─────────────────────────────────────────────────

const FACING_8 := [
	"right", "down_right", "down", "down_left",
	"left", "up_left", "up", "up_right"
]

var facing: String = "right"
var is_moving: bool = false
#endregion ─────────────────────────────────────────────────────────────────────

# ─── MOVEMENT ──────────────────────────────────────────────
func apply_movement(direction: Vector2, movement_speed: float) -> void:
	parent.velocity = direction * movement_speed
	# si no se presiona tecla de movimiento
	if direction == Vector2.ZERO:
		if is_moving:
			is_moving = false
			stopped.emit()
		parent.velocity = Vector2.ZERO
		return
	
	is_moving = true
	_update_facing(direction)
	moved.emit(parent.velocity)

# ─── INPUTS ────────────────────────────────────────────────
func set_input_enabled(value: bool) -> void:
	if input_enabled == value:
		return
	input_enabled = value
	if not input_enabled and is_moving:
		is_moving = false
		stopped.emit()

func get_input_direction() -> Vector2:
	if not input_enabled:
		return Vector2.ZERO

	return Input.get_vector(
		action_left,
		action_right,
		action_up,
		action_down
	)

# ─── FACING ────────────────────────────────────────────────
func _update_facing(direction: Vector2) -> void:
	var next: String
	
	match facing_mode:
		FacingMode.FOUR_DIRECTIONS:
			if absf(direction.x) > absf(direction.y):
				next = "right" if direction.x > 0.0 else "left"
			else:
				next = "down" if direction.y > 0.0 else "up"

		FacingMode.EIGHT_DIRECTIONS:
			var angle := direction.angle()
			var index := posmod(
				roundi(angle / (PI / 4.0)),
				8
			)
			next = FACING_8[index]

	if next == facing:
		return

	facing = next
	facing_changed.emit(facing)

# --- API ---
# signal moved(motion: Vector2), stopped(), facing_changed(facing: String)
# @export var speed: float
# @export var input_enabled: bool
# @export var action_left/right/up/down: StringName
# var facing: String, is_moving: bool
# func move(motion: Vector2) -> void
# func set_input_enabled(value: bool) -> void
