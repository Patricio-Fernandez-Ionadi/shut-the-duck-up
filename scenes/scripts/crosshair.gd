# Crosshair: mira dibujada en pantalla dentro del CanvasLayer del HUD.
#
# RECIBE información de:
#   * GameHUD: sincroniza apuntado, apertura, objetivo hostil y recarga.
#   * PlayerCharacter (señal shot_hit): flash breve de impacto.
#
# COMUNICA información a:
#   * Solo se dibuja a sí misma; no modifica el estado de juego.

extends Control
class_name Crosshair

const NEUTRAL_COLOR := Color("8ce6ff")
const HOSTILE_COLOR := Color("e45b5b")
const OUTLINE_COLOR := Color(0.02, 0.03, 0.04, 0.65)
const HIT_COLOR := Color("ffffff")

# --- Configuración ajustable desde el Inspector ---
@export var base_gap: float = 7.0
@export var tick_length: float = 7.0
@export var thickness: float = 2.0
@export var dot_radius: float = 1.5
@export var max_visual_spread: float = 24.0
@export var hit_flash_duration: float = 0.12

# --- Estado interno ---
var _aiming := false
var _spread := 0.0
var _target_hostile := false
var _reloading := false
var _hit_flash := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	set_process(true)

func _process(delta: float) -> void:
	_hit_flash = maxf(0.0, _hit_flash - delta)

	if not _aiming:
		return

	# Se dibuja en coordenadas de pantalla, no del mundo.
	position = get_viewport().get_mouse_position()
	queue_redraw()

func set_aiming(value: bool) -> void:
	if _aiming == value:
		return

	_aiming = value
	visible = value

	if value:
		position = get_viewport().get_mouse_position()

	queue_redraw()

func set_spread(value: float) -> void:
	_spread = clampf(value, 0.0, max_visual_spread)

	if _aiming:
		queue_redraw()

func set_target_hostile(value: bool) -> void:
	if _target_hostile == value:
		return

	_target_hostile = value

	if _aiming:
		queue_redraw()

func set_reloading(value: bool) -> void:
	if _reloading == value:
		return

	_reloading = value

	if _aiming:
		queue_redraw()

func flash_hit() -> void:
	_hit_flash = hit_flash_duration

	if _aiming:
		queue_redraw()

func reset() -> void:
	_spread = 0.0
	_target_hostile = false
	_reloading = false
	_hit_flash = 0.0
	set_aiming(false)

func _draw() -> void:
	var color := HOSTILE_COLOR if _target_hostile else NEUTRAL_COLOR

	if _reloading:
		color = Color(color, 0.55)

	# La separación crece con la pérdida de precisión por disparos seguidos.
	var inner := base_gap + _spread
	var outer := inner + tick_length
	var directions := [
		Vector2.UP,
		Vector2.DOWN,
		Vector2.LEFT,
		Vector2.RIGHT,
	]

	for direction in directions:
		var from: Vector2 = direction * inner
		var to: Vector2 = direction * outer
		draw_line(from, to, OUTLINE_COLOR, thickness + 2.0, true)
		draw_line(from, to, color, thickness, true)

	# Punto central con contorno para leerse sobre fondos claros u oscuros.
	draw_circle(Vector2.ZERO, dot_radius + 1.0, OUTLINE_COLOR)
	draw_circle(Vector2.ZERO, dot_radius, color)

	if _reloading:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
		draw_arc(
			Vector2.ZERO,
			outer + 5.0,
			0.0,
			TAU,
			32,
			Color(color, 0.25 + 0.25 * pulse),
			1.5,
			true
		)

	if _hit_flash > 0.0:
		var alpha := _hit_flash / maxf(0.001, hit_flash_duration)
		var hit_color := Color(HIT_COLOR, alpha)
		var hit_size := 4.0
		draw_line(
			Vector2(-hit_size, -hit_size),
			Vector2(hit_size, hit_size),
			hit_color,
			2.0,
			true
		)
		draw_line(
			Vector2(-hit_size, hit_size),
			Vector2(hit_size, -hit_size),
			hit_color,
			2.0,
			true
		)
