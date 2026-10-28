# NoiseRipple: onda visual temporal para hacer legible el sistema de ruido.
#
# RECIBE información de:
#   * NoiseSystem: crea una instancia por cada ruido emitido y la configura
#     con setup(origin, radius, kind).
#
# COMUNICA información a:
#   * Solo se dibuja a sí misma en el mundo y se elimina al terminar.
#     No modifica el estado de juego.

extends Node2D
class_name NoiseRipple

const DURATION := 0.75

var max_radius := 100.0
var ring_color := Color(1, 1, 1, 0.5)
var _elapsed := 0.0

func _ready() -> void:
	z_index = 5

func setup(origin: Vector2, radius: float, kind: String) -> void:
	# La posición es global porque la onda vive bajo la escena actual.
	global_position = origin
	max_radius = maxf(8.0, radius)

	match kind:
		"shot":
			ring_color = Color(1.0, 0.45, 0.3, 0.7)
		"honk":
			ring_color = Color(1.0, 0.9, 0.3, 0.65)
		"calm":
			ring_color = Color(0.5, 0.8, 1.0, 0.55)
		"distraction":
			ring_color = Color(0.55, 0.95, 1.0, 0.65)
		"footstep":
			ring_color = Color(0.7, 0.75, 0.8, 0.35)
		_:
			ring_color = Color(0.85, 0.85, 0.85, 0.5)

	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta

	if _elapsed >= DURATION:
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var progress := clampf(_elapsed / DURATION, 0.0, 1.0)
	var radius := max_radius * progress
	var alpha := (1.0 - progress) * ring_color.a

	draw_arc(
		Vector2.ZERO,
		radius,
		0.0,
		TAU,
		48,
		Color(ring_color, alpha),
		2.0
	)
