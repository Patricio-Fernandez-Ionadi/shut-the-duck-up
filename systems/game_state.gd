# GameState: estado global de la partida (autoload "GameState").
#
# RECIBE información de:
#   * Level/main.gd: inicio y reinicio de la misión, extracción completada.
#   * GuardEnemy: detecciones y subida de alarma.
#   * PlayerCharacter: disparos, derribos y bajas.
#   * Duck y NoiseSystem: contadores de ruido/graznidos.
#
# COMUNICA información a:
#   * HUD: alarma, resultados y reinicio de la partida (señales).
#   * GuardEnemy: señal alarm_changed para que converjan a la última posición.
#   * Level/main.gd: estado de la misión y estadísticas de la run.

extends Node

# La misión termina solo al extraer; no hay derrota en este sandbox.
enum RunState { PLAYING, COMPLETE }

signal mission_completed(results: Dictionary)
signal run_reset()
signal alarm_changed(active: bool, position: Vector2, time_left: float)

const ALARM_DURATION := 10.0

var state: RunState = RunState.PLAYING
var elapsed_time := 0.0
var debug_overlay := false

# --- Alarma global ---
var alarm_active := false
var alarm_position := Vector2.ZERO
var alarm_time_left := 0.0

# --- Estadísticas de la run ---
var stats: Dictionary = {}

func _ready() -> void:
	_reset_stats()

func _process(delta: float) -> void:
	# El reloj corre mientras la misión está en juego.
	if state == RunState.PLAYING:
		elapsed_time += delta

	# La alarma decae sola si los guardias dejan de verte.
	if alarm_active:
		alarm_time_left = maxf(0.0, alarm_time_left - delta)

		if alarm_time_left <= 0.0:
			alarm_active = false
			alarm_changed.emit(false, alarm_position, 0.0)

func reset_run() -> void:
	# Se llama al entrar al nivel o al reiniciar la escena.
	state = RunState.PLAYING
	elapsed_time = 0.0
	alarm_active = false
	alarm_position = Vector2.ZERO
	alarm_time_left = 0.0
	_reset_stats()
	run_reset.emit()

func raise_alarm(position: Vector2, duration: float = ALARM_DURATION) -> void:
	# Activa o refresca la alarma global en la posición conocida del jugador.
	alarm_active = true
	alarm_position = position
	alarm_time_left = maxf(alarm_time_left, duration)
	alarm_changed.emit(true, alarm_position, alarm_time_left)

func add_detection() -> void:
	increment_stat("detections")

func increment_stat(stat_name: String, amount: int = 1) -> void:
	stats[stat_name] = int(stats.get(stat_name, 0)) + amount

func is_playing() -> bool:
	return state == RunState.PLAYING

func is_complete() -> bool:
	return state == RunState.COMPLETE

func complete_mission() -> void:
	if state != RunState.PLAYING:
		return

	state = RunState.COMPLETE
	mission_completed.emit(get_results())

func get_results() -> Dictionary:
	# Copia plana para que el HUD no pueda alterar las estadísticas.
	var rank := get_rank()

	return {
		"time": elapsed_time,
		"detections": int(stats.get("detections", 0)),
		"kills": int(stats.get("kills", 0)),
		"takedowns": int(stats.get("takedowns", 0)),
		"gunshots": int(stats.get("gunshots", 0)),
		"bottles": int(stats.get("bottles", 0)),
		"honks": int(stats.get("honks", 0)),
		"loot": int(stats.get("loot", 0)),
		"noise_events": int(stats.get("noise_events", 0)),
		"rank": rank,
		"rank_title": get_rank_title(rank),
	}

func get_rank() -> String:
	# Rango según sigilo, limpieza y velocidad; el loot es opcional.
	var detections := int(stats.get("detections", 0))
	var kills := int(stats.get("kills", 0))
	var gunshots := int(stats.get("gunshots", 0))
	var honks := int(stats.get("honks", 0))

	if (
		detections == 0
		and kills == 0
		and gunshots == 0
		and honks <= 2
		and elapsed_time <= 180.0
	):
		return "S"

	if detections <= 1 and kills == 0 and gunshots <= 1 and honks <= 5:
		return "A"

	if detections <= 3 and kills <= 1 and gunshots <= 3:
		return "B"

	return "C"

func get_rank_title(rank: String) -> String:
	match rank:
		"S":
			return "Fantasma"
		"A":
			return "Profesional"
		"B":
			return "Superviviente"
		_:
			return "Ruidoso"

func _reset_stats() -> void:
	stats = {
		"detections": 0,
		"kills": 0,
		"takedowns": 0,
		"gunshots": 0,
		"bottles": 0,
		"honks": 0,
		"loot": 0,
		"noise_events": 0,
	}
