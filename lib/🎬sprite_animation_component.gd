class_name SpriteAnimationComponent extends Node

# ─── SPRITE ANIMATION COMPONENT ───────────────────────────────────────────────
# Archivo: res://lib/🎬sprite_animation_component.gd
# Propósito:
#   Controlar un AnimatedSprite2D a partir de un estado lógico y una
#   dirección. No conoce el gameplay ni los input de la entidad.
# Recibe:
#   - play(state, direction) o play_directional(state, vector).
# Comunica con:
#   - AnimatedSprite2D: reproduce la animación resuelta.
#   - Señal animation_changed(state, direction, animation_name).
# Usado por:
#   - Player, NPCs y enemigos que tengan un AnimatedSprite2D.
#
# CONFIGURACIÓN ESPECÍFICA:
#   El AnimatedSprite2D debe tener animaciones cuyos nombres coincidan con
#   las plantillas de `animation_map`.
#
#   * `animation_map` traduce estado lógico -> plantilla. El token
#     {direction} se reemplaza por la dirección actual.
#   * `direction_names` debe tener 4 u 8 entradas en orden horario
#     comenzando por la derecha. Por defecto usa los mismos nombres que
#     MovementTopDownComponent.FACING_8.
#   * Si una plantilla no incluye {direction}, la animación no depende
#     de la dirección.
#   * Si falta la animación, se intenta `fallback_state` y se emite un
#     warning una sola vez por estado.
#
#   Ejemplo Player (nodo Animation hermano del sprite):
#     sprite_path   = NodePath("../AnimatedSprite2D")
#     animation_map = {
#         "idle": "idle_{direction}",
#         "run":  "run_{direction}",
#         "shot": "shot_{direction}",
#     }
#
#   Ejemplo NPC con animaciones propias y solo algunas direcciones:
#     animation_map = {
#         "idle": "npc_idle",
#         "walk": "npc_walk_{direction}",
#     }
#     direction_names = [&"right", &"down", &"left", &"up"]
#     fallback_state  = &"idle"
#
#   Uso desde la entidad dueña:
#     animation.play(&"run", movement.facing)
#     animation.play_directional(&"idle", facing_direction)
# ──────────────────────────────────────────────────────────────────────────────

#region ─── Constructor ────────────────────────────────────────────────────────
signal animation_changed(
	state: StringName, direction: StringName, animation_name: StringName
)

## Ruta al AnimatedSprite2D. Por defecto asume que es un hermano.
@export var sprite_path: NodePath = ^"../AnimatedSprite2D"
## Estado lógico -> plantilla de animación. Admite el token {direction}.
@export var animation_map: Dictionary = {}
## Nombres de dirección en orden horario desde la derecha.
@export var direction_names: Array[StringName] = [
	&"right", &"down_right", &"down", &"down_left",
	&"left", &"up_left", &"up", &"up_right",
]
## Estado y dirección usados al entrar al árbol.
@export var initial_state: StringName = &"idle"
@export var initial_direction: StringName = &"right"
## Reproduce el estado inicial automáticamente.
@export var auto_play: bool = true
## Estado al que se cae si falta una animación (vacío = sin fallback).
@export var fallback_state: StringName = &"idle"

var current_state: StringName = &""
var current_direction: StringName = &""

var _sprite: AnimatedSprite2D
var _current_animation: StringName = &""
# Evita repetir el mismo warning en cada frame.
var _warned_states: Dictionary = {}
#endregion ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	_sprite = _resolve_sprite()

	if _sprite == null:
		push_warning(
			"SpriteAnimationComponent: no se encontró un AnimatedSprite2D."
		)
		return

	if _sprite.sprite_frames == null:
		push_warning(
			"SpriteAnimationComponent: el AnimatedSprite2D no tiene "
			+ "SpriteFrames asignado."
		)
		return

	current_state = initial_state
	current_direction = initial_direction

	if auto_play:
		play(initial_state, initial_direction)

#region ─── API pública ────────────────────────────────────────────────────────
func play(
	state: StringName,
	direction_name: StringName = &"",
	restart: bool = false
) -> bool:
	# Reproduce el estado pedido. Si no se pasa dirección, conserva la actual.
	if _sprite == null or _sprite.sprite_frames == null:
		return false

	var direction := direction_name
	if direction == &"":
		direction = current_direction
	if direction == &"":
		direction = initial_direction

	var resolved_state := state
	var animation_name := _resolve_animation_name(resolved_state, direction)

	# Fallback: permite que un estado sin arte propio use otro estado.
	if (
		animation_name == &""
		and fallback_state != &""
		and fallback_state != state
	):
		resolved_state = fallback_state
		animation_name = _resolve_animation_name(resolved_state, direction)

	if animation_name == &"":
		_warn_missing_state(state)
		return false

	current_state = resolved_state
	current_direction = direction

	# Evita reiniciar la animación cuando ya se está reproduciendo.
	if animation_name == _current_animation and not restart:
		return true

	_current_animation = animation_name
	_sprite.play(animation_name)
	animation_changed.emit(current_state, current_direction, animation_name)
	return true

func play_directional(
	state: StringName,
	direction: Vector2,
	restart: bool = false
) -> bool:
	# Convierte un vector de facing al nombre de dirección configurado.
	var direction_name := get_direction_name(direction)
	return play(state, direction_name, restart)

func set_direction(direction_name: StringName) -> bool:
	# Cambia solo la dirección y vuelve a resolver el estado actual.
	if direction_name == &"" or current_state == &"":
		return false
	if direction_name == current_direction:
		return true
	return play(current_state, direction_name)

func get_direction_name(direction: Vector2) -> StringName:
	# Cuantiza el ángulo al sector más cercano. El índice 0 apunta a la
	# derecha y avanza en sentido horario (Y positiva = abajo).
	if direction.length_squared() < 0.0001 or direction_names.is_empty():
		if current_direction != &"":
			return current_direction
		return initial_direction

	var count := direction_names.size()
	var angle_step := TAU / float(count)
	var index := posmod(roundi(direction.angle() / angle_step), count)
	return direction_names[index]

func has_state(state: StringName) -> bool:
	return _get_template(state) != ""

func get_current_animation() -> StringName:
	return _current_animation
#endregion ─────────────────────────────────────────────────────────────────────

#region ─── Internos ───────────────────────────────────────────────────────────
func _resolve_sprite() -> AnimatedSprite2D:
	if sprite_path != NodePath() and has_node(sprite_path):
		var node := get_node(sprite_path)
		if node is AnimatedSprite2D:
			return node as AnimatedSprite2D

	# Fallback útil si se agrega el componente sin configurar la ruta.
	var parent := get_parent()
	if parent != null:
		var found := parent.find_child("AnimatedSprite2D", true, false)
		if found is AnimatedSprite2D:
			return found as AnimatedSprite2D

	return null

func _get_template(state: StringName) -> String:
	# El Inspector puede guardar las claves como String o StringName.
	if animation_map.has(state):
		return String(animation_map[state])

	var state_key := String(state)
	if animation_map.has(state_key):
		return String(animation_map[state_key])

	return ""

func _resolve_animation_name(
	state: StringName,
	direction: StringName
) -> StringName:
	if _sprite == null or _sprite.sprite_frames == null:
		return &""

	var template := _get_template(state)
	if template.is_empty():
		return &""

	var animation_name := StringName(
		template.replace("{direction}", String(direction))
	)

	if not _sprite.sprite_frames.has_animation(animation_name):
		return &""

	return animation_name

func _warn_missing_state(state: StringName) -> void:
	if _warned_states.has(state):
		return

	_warned_states[state] = true
	push_warning(
		"SpriteAnimationComponent: falta la animación para el estado '%s'."
		% String(state)
	)
#endregion ─────────────────────────────────────────────────────────────────────

# --- API ---
# signal animation_changed(state: StringName, direction: StringName, animation_name: StringName)
# @export var sprite_path: NodePath
# @export var animation_map: Dictionary
# @export var direction_names: Array[StringName]
# @export var initial_state: StringName
# @export var initial_direction: StringName
# @export var auto_play: bool
# @export var fallback_state: StringName
# var current_state: StringName, current_direction: StringName
# func play(state: StringName, direction: StringName = &"", restart := false) -> bool
# func play_directional(state: StringName, direction: Vector2, restart := false) -> bool
# func set_direction(direction_name: StringName) -> bool
# func get_direction_name(direction: Vector2) -> StringName
# func has_state(state: StringName) -> bool
# func get_current_animation() -> StringName
