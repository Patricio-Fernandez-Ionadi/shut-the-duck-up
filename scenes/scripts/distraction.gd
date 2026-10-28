# DistractionBottle: botella arrojadiza que genera ruido al impactar.
#
# RECIBE información de:
#   * PlayerCharacter: llama a throw_to(target) al lanzarla y le paga una carga.
#   * Mundo físico: raycast para detenerse contra paredes/coberturas.
#
# COMUNICA información a:
#   * NoiseSystem: emite el ruido de impacto (kind = "distraction"), que atrae
#     a los guardias y dibuja una onda visual.

extends Node2D
class_name DistractionBottle

const FLY_SPEED := 520.0
const IMPACT_NOISE_RADIUS := 230.0

var _target := Vector2.ZERO
var _flying := false

func _ready() -> void:
	z_index = 4

func throw_to(target: Vector2) -> void:
	_target = target
	_flying = true

func _process(delta: float) -> void:
	if not _flying:
		return

	var to_target := _target - global_position
	var step := FLY_SPEED * delta

	if to_target.length() <= step:
		global_position = _target
		_impact()
		return

	var next_position := global_position + to_target.normalized() * step
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		next_position
	)
	var hit := get_world_2d().direct_space_state.intersect_ray(query)

	if not hit.is_empty():
		# Se rompe contra la primera pared/cobertura.
		global_position = hit.get("position", next_position)
		_impact()
	else:
		global_position = next_position
		queue_redraw()

func _impact() -> void:
	_flying = false

	NoiseSystem.emit_noise(
		global_position,
		IMPACT_NOISE_RADIUS,
		"BOTELLA ROTA",
		"distraction"
	)
	queue_free()

func _draw() -> void:
	# Gráfico provisional de la botella.
	draw_circle(Vector2.ZERO, 4.0, Color("8fd3e8"))
	draw_circle(Vector2(1.0, -1.0), 1.5, Color("ffffff"))
