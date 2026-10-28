# Duck: pato que acompaña al jugador.
#
# RECIBE información de:
#   * PlayerCharacter: escribe directamente en duck.agitation al correr y al
#     disparar; llama a calm() con la tecla E y reposiciona el nodo cada frame.
#   * Grupo "guards": detecta guardias persiguiendo cerca para asustarse.
#   * Su propio temporizador: la agitación sube/baja con el tiempo y el estado.
#
# COMUNICA información a:
#   * NoiseSystem (autoload): emite ruido al graznar y al ser calmado.
#   * GameState: incrementa el contador de graznidos.
#   * main.gd/HUD: expone agitation (barra y ánimo) y la señal agitation_changed.

extends Node2D
class_name Duck

signal agitation_changed(value: float)

# Umbrales de ánimo usados por el HUD y el comportamiento.
const CALM_MAX := 35.0
const ALTERED_MIN := 70.0

# --- Configuración ajustable desde el Inspector ---
@export var agitation_rise_per_second: float = 2.0
@export var idle_decay_per_second: float = 4.0
@export var danger_radius: float = 160.0
@export var danger_rise_per_second: float = 6.0
@export var honk_interval_min: float = 5.0
@export var honk_interval_max: float = 9.0
@export var panic_honk_interval_min: float = 2.0
@export var panic_honk_interval_max: float = 4.0
@export var honk_radius: float = 250.0
@export var calm_cooldown: float = 0.8

# --- Estado interno ---
var agitation: float = 15.0
var _honk_timer: float = 4.0
var _calm_cooldown_timer := 0.0
var _pulse_time := 0.0
var _player: PlayerCharacter = null
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_player = get_parent() as PlayerCharacter
	_rng.randomize()
	_reset_honk_timer()
	queue_redraw()

func _process(delta: float) -> void:
	_calm_cooldown_timer = maxf(0.0, _calm_cooldown_timer - delta)
	_pulse_time += delta

	# 1) La agitación sube con el tiempo y se enfría si el jugador se queda quieto.
	agitation += agitation_rise_per_second * delta

	if _player != null and _player.velocity.length() < 5.0:
		agitation -= idle_decay_per_second * delta

	# 2) Los guardias persiguiendo cerca asustan al pato.
	agitation += _danger_pressure() * delta

	agitation = clampf(agitation, 0.0, 100.0)

	# 3) Temporizador de graznidos: a mayor agitación, más seguido y más fuerte.
	_honk_timer -= delta

	if _honk_timer <= 0.0:
		if _rng.randf() < agitation / 100.0:
			_honk()
		_reset_honk_timer()

	queue_redraw()

func _danger_pressure() -> float:
	# Suma presión si hay algún guardia en CHASE dentro del radio de peligro.
	for node in get_tree().get_nodes_in_group("guards"):
		var guard := node as GuardEnemy
		if guard == null or not guard.alive:
			continue
		if guard.state != GuardEnemy.GuardState.CHASE:
			continue
		if global_position.distance_to(guard.global_position) <= danger_radius:
			return danger_rise_per_second

	return 0.0

func _honk() -> void:
	NoiseSystem.emit_noise(
		global_position,
		honk_radius * (0.65 + agitation / 100.0),
		"¡CUAC!",
		"honk"
	)
	GameState.increment_stat("honks")

func calm() -> bool:
	# Llamado por PlayerCharacter ("E"). Devuelve false si está en cooldown.
	if _calm_cooldown_timer > 0.0:
		return false

	_calm_cooldown_timer = calm_cooldown
	agitation = maxf(0.0, agitation - 35.0)
	agitation_changed.emit(agitation)

	NoiseSystem.emit_noise(
		global_position,
		65.0,
		"Calmar al pato",
		"calm"
	)

	return true

func _reset_honk_timer() -> void:
	# Interpola entre el intervalo tranquilo y el alterado según la agitación.
	var ratio := clampf(agitation / 100.0, 0.0, 1.0)
	var min_interval := lerpf(
		honk_interval_min,
		panic_honk_interval_min,
		ratio
	)
	var max_interval := lerpf(
		honk_interval_max,
		panic_honk_interval_max,
		ratio
	)
	_honk_timer = _rng.randf_range(min_interval, max_interval)

func _draw() -> void:
	# El color del pato refleja su ánimo.
	var body_color := Color("f5d742")
	if agitation >= ALTERED_MIN:
		body_color = Color("e07a3a")
	elif agitation >= CALM_MAX:
		body_color = Color("e8b83a")

	# Aro de alerta cuando está alterado.
	if agitation >= ALTERED_MIN:
		var pulse := 0.55 + 0.25 * sin(_pulse_time * 6.0)
		draw_arc(
			Vector2.ZERO,
			15.0,
			0.0,
			TAU,
			24,
			Color(0.9, 0.3, 0.2, pulse),
			1.5
		)

	draw_circle(Vector2.ZERO, 10.0, body_color)
	draw_circle(Vector2(3, -3), 2.0, Color("242424"))

	draw_colored_polygon(
		PackedVector2Array([
			Vector2(8, 0),
			Vector2(16, 3),
			Vector2(8, 5),
		]),
		Color("ee8b32")
	)

	draw_line(
		Vector2(-4, 9),
		Vector2(-5, 13),
		Color("ee8b32"),
		2.0
	)
	draw_line(
		Vector2(3, 9),
		Vector2(4, 13),
		Color("ee8b32"),
		2.0
	)
