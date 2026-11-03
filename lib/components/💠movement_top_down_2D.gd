class_name MovementTopDownComponent extends Node

# ─── MOVEMENT COMPONENT ───────────────────────────────────────────────────────
# Archivo: res://scripts/components/movement_component.gd
# Propósito:
#   Movimiento 4/8 direcciones por input, con facing y delegación opcional de
#   colisiones. No conoce la ciudad: si `collision_provider` implementa
#   `try_move(body, motion)` le delega el desplazamiento.
# Recibe:
#   - Input de las acciones configuradas (`action_left/right/up/down`).
#   - `collision_provider` (lo setea el composition root).
# Usa:
#   - `Component` como base.
# Comunica con:
#   - Señales `moved`, `stopped`, `facing_changed`.
# Usado por:
#   - Player, NPCs y enemigos que se muevan.
# ──────────────────────────────────────────────────────────────────────────────

#region ─── Constructor ────────────────────────────────────────────────────────
signal moved(motion: Vector2)
signal stopped()
signal facing_changed(facing: String)
@export_category("Attributes")
## Velocidad en píxeles/segundo.
@export var speed: float = 120.0

## Si es false, ignora el input (diálogos, UI, cinemáticas).
@export var input_enabled: bool = true

@export var action_left: StringName = &"left"
@export var action_right: StringName = &"right"
@export var action_up: StringName = &"up"
@export var action_down: StringName = &"down"

## Nodo que resuelve colisiones (`try_move(body, motion)`). Si es null, mueve
## `entity.position` directamente.
@export var collision_provider: Node = null

## Dirección actual: "down" | "up" | "left" | "right".
var facing: String = "down"
var is_moving: bool = false

@onready var parent = get_parent() as CharacterBody2D
#endregion ─────────────────────────────────────────────────────────────────────

func _physics_process(delta: float) -> void:
	var direction := _read_input()
	if direction == Vector2.ZERO:
		if is_moving:
			is_moving = false
			stopped.emit()
		return
	is_moving = true
	_update_facing(direction)
	move(direction.normalized() * speed * delta)

func _read_input() -> Vector2:
	var direction := Vector2.ZERO
	if not input_enabled:
		return direction
	if Input.is_action_pressed(action_left):
		direction.x -= 1.0
	if Input.is_action_pressed(action_right):
		direction.x += 1.0
	if Input.is_action_pressed(action_up):
		direction.y -= 1.0
	if Input.is_action_pressed(action_down):
		direction.y += 1.0
	return direction

func move(motion: Vector2) -> void:
	if motion == Vector2.ZERO:
		return
	parent.position += motion
	moved.emit(motion)

func set_input_enabled(value: bool) -> void:
	if input_enabled == value:
		return
	input_enabled = value
	if not input_enabled and is_moving:
		is_moving = false
		stopped.emit()

func _update_facing(direction: Vector2) -> void:
	var next := facing
	if absf(direction.x) > absf(direction.y):
		next = "right" if direction.x > 0.0 else "left"
	else:
		next = "down" if direction.y > 0.0 else "up"
	if next == facing:
		return
	facing = next
	facing_changed.emit(facing)

# --- API ---
# signal moved(motion: Vector2), stopped(), facing_changed(facing: String)
# @export var speed: float
# @export var input_enabled: bool
# @export var action_left/right/up/down: StringName
# @export var collision_provider: Node
# var facing: String, is_moving: bool
# func move(motion: Vector2) -> void
# func set_input_enabled(value: bool) -> void
