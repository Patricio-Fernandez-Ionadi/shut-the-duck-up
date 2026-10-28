# GuardEnemy: guardia con detección progresiva y alarma compartida.
#
# RECIBE información de:
#   * NoiseSystem (autoload): señal noise_emitted (investiga el origen del ruido).
#   * GameState: señal alarm_changed (converge a la última posición conocida).
#   * Grupo "player": instancia de PlayerCharacter para verla y perseguirla.
#   * Mundo físico: raycast de línea de visión (_can_see_player).
#   * PlayerCharacter: llama a take_hit()/take_down() cuando lo elimina.
#
# COMUNICA información a:
#   * GameState: add_detection() al iniciar una persecución y raise_alarm()
#     mientras mantiene al jugador a la vista.
#   * Su propio movimiento (move_and_slide) y dibujo (_draw) según el estado.
#   * Al morir se elimina del árbol (queue_free), dejando de emitir/recibir ruido.

extends CharacterBody2D
class_name GuardEnemy

# Estados de la máquina de comportamiento.
enum GuardState { PATROL, SUSPICIOUS, INVESTIGATE, SEARCH, CHASE }

# --- Configuración ajustable desde el Inspector ---
@export var patrol_offset := Vector2(150, 0)
@export var patrol_points := PackedVector2Array()
@export var move_speed: float = 75.0
@export var chase_speed_multiplier: float = 1.35
@export var hearing_multiplier: float = 1.0
@export var vision_range: float = 190.0
@export var vision_half_angle_degrees: float = 55.0
@export var detection_fill_rate: float = 55.0
@export var detection_decay_rate: float = 22.0
@export var suspicion_threshold: float = 35.0

# --- Estado interno ---
var state: GuardState = GuardState.PATROL
var awareness := 0.0  # 0-100; al llegar a 100 empieza la persecución.
var patrol_origin: Vector2
var patrol_target: Vector2
var investigate_target: Vector2
var player: PlayerCharacter = null
var alive := true

var _look_direction := Vector2.LEFT
var _last_known_position := Vector2.ZERO
var _search_timer := 0.0
var _no_sight_time := 0.0
var _alarm_refresh_timer := 0.0
var _patrol_points: Array[Vector2] = []
var _patrol_index := 0

func _ready() -> void:
	patrol_origin = global_position
	_build_patrol_points()
	patrol_target = _patrol_points[0]

	# El jugador busca guardias por grupo para el derribo silencioso.
	add_to_group("guards")

	# Se suscribe al ruido y a la alarma global.
	NoiseSystem.noise_emitted.connect(_on_noise_emitted)
	GameState.alarm_changed.connect(_on_alarm_changed)
	GameState.run_reset.connect(_on_run_reset)

func _exit_tree() -> void:
	# Evita dejar conexiones colgadas al ser eliminado o recargar la escena.
	if NoiseSystem.noise_emitted.is_connected(_on_noise_emitted):
		NoiseSystem.noise_emitted.disconnect(_on_noise_emitted)
	if GameState.alarm_changed.is_connected(_on_alarm_changed):
		GameState.alarm_changed.disconnect(_on_alarm_changed)
	if GameState.run_reset.is_connected(_on_run_reset):
		GameState.run_reset.disconnect(_on_run_reset)

func _build_patrol_points() -> void:
	# Los puntos exportados son offsets respecto de la posición de spawn.
	if patrol_points.size() > 0:
		for offset in patrol_points:
			_patrol_points.append(patrol_origin + offset)
	else:
		_patrol_points = [patrol_origin, patrol_origin + patrol_offset]

	if _patrol_points.is_empty():
		_patrol_points.append(patrol_origin)

func _physics_process(delta: float) -> void:
	if not alive:
		return

	# Obtiene al jugador por grupo si todavía no lo tiene.
	if player == null:
		player = get_tree().get_first_node_in_group("player") as PlayerCharacter

	var can_see := player != null and _can_see_player()
	_update_awareness(delta, can_see)

	# La transición a CHASE se evalúa antes de moverse.
	if awareness >= 100.0 and state != GuardState.CHASE:
		_start_chase()

	match state:
		GuardState.PATROL:
			_process_patrol(delta, can_see)
		GuardState.SUSPICIOUS:
			_process_suspicious(delta, can_see)
		GuardState.INVESTIGATE:
			_process_investigate(delta, can_see)
		GuardState.SEARCH:
			_process_search(delta, can_see)
		GuardState.CHASE:
			_process_chase(delta, can_see)

	move_and_slide()
	queue_redraw()

func _update_awareness(delta: float, can_see: bool) -> void:
	# La detección llena más rápido de cerca, si el jugador corre o hay alarma.
	if can_see:
		_no_sight_time = 0.0
		_last_known_position = player.global_position

		var distance := global_position.distance_to(player.global_position)
		var distance_factor := clampf(
			1.0 - distance / maxf(1.0, vision_range),
			0.3,
			1.0
		)
		var stance_factor := 1.0
		if player.is_crouching:
			stance_factor = 0.55
		elif player.is_sprinting:
			stance_factor = 1.35

		var alarm_factor := 1.4 if GameState.alarm_active else 1.0
		awareness = minf(
			100.0,
			awareness
			+ detection_fill_rate * distance_factor * stance_factor
			* alarm_factor * delta
		)
	else:
		_no_sight_time += delta

		# Pequeña demora antes de empezar a olvidar.
		if _no_sight_time > 0.4:
			awareness = maxf(
				0.0,
				awareness - detection_decay_rate * delta
			)

func _process_patrol(_delta: float, _can_see: bool) -> void:
	if awareness >= suspicion_threshold:
		state = GuardState.SUSPICIOUS
		velocity = Vector2.ZERO
		return

	if _patrol_points.size() <= 1:
		velocity = Vector2.ZERO
		return

	if global_position.distance_to(patrol_target) < 8.0:
		# Avanza al siguiente waypoint (ciclo).
		_patrol_index = (_patrol_index + 1) % _patrol_points.size()
		patrol_target = _patrol_points[_patrol_index]
		velocity = Vector2.ZERO
	else:
		_move_towards(patrol_target, move_speed)

func _process_suspicious(delta: float, can_see: bool) -> void:
	# Se detiene a mirar: la detección sigue subiendo hasta perseguir.
	velocity = Vector2.ZERO
	_search_timer = maxf(0.0, _search_timer - delta)

	if can_see and player != null:
		_look_direction = global_position.direction_to(player.global_position)
	elif not can_see and awareness < 20.0:
		state = GuardState.PATROL

func _process_investigate(delta: float, can_see: bool) -> void:
	if can_see and awareness >= suspicion_threshold:
		state = GuardState.SUSPICIOUS
		velocity = Vector2.ZERO
		return

	_search_timer -= delta

	if _search_timer <= 0.0:
		state = GuardState.PATROL
		velocity = Vector2.ZERO
		return

	if global_position.distance_to(investigate_target) < 10.0:
		state = GuardState.SEARCH
		_search_timer = maxf(_search_timer, 2.5)
		velocity = Vector2.ZERO
	else:
		_move_towards(investigate_target, move_speed)

func _process_search(delta: float, can_see: bool) -> void:
	if can_see and awareness >= suspicion_threshold:
		state = GuardState.SUSPICIOUS
		velocity = Vector2.ZERO
		return

	_search_timer -= delta

	if _search_timer <= 0.0:
		state = GuardState.PATROL
		awareness = minf(awareness, 10.0)
		velocity = Vector2.ZERO
		return

	if global_position.distance_to(investigate_target) > 10.0:
		_move_towards(investigate_target, move_speed)
	else:
		# Llegó al punto: se queda escaneando con la mirada.
		velocity = Vector2.ZERO
		_look_direction = _look_direction.rotated(delta * 1.8)

func _process_chase(delta: float, can_see: bool) -> void:
	if player == null:
		state = GuardState.SEARCH
		return

	if can_see:
		_last_known_position = player.global_position

		# Refresca la alarma global mientras mantiene contacto visual.
		_alarm_refresh_timer -= delta
		if _alarm_refresh_timer <= 0.0:
			_alarm_refresh_timer = 1.0
			GameState.raise_alarm(player.global_position)

		_move_towards(
			player.global_position,
			move_speed * chase_speed_multiplier
		)
	elif _no_sight_time > 1.5:
		# Perdió de vista: busca la última posición conocida.
		state = GuardState.SEARCH
		investigate_target = _last_known_position
		_search_timer = 4.0
		velocity = Vector2.ZERO
	else:
		_move_towards(
			_last_known_position,
			move_speed * chase_speed_multiplier
		)

func _start_chase() -> void:
	# Entrada a persecución: cuenta la detección y comparte la alarma.
	if state != GuardState.CHASE:
		GameState.add_detection()

	state = GuardState.CHASE
	awareness = 100.0
	_alarm_refresh_timer = 1.0

	if player != null:
		_last_known_position = player.global_position
		GameState.raise_alarm(player.global_position)

	_no_sight_time = 0.0

func _move_towards(target: Vector2, speed: float) -> void:
	var direction := global_position.direction_to(target)

	if direction.length_squared() > 0.001:
		_look_direction = direction
		velocity = direction * speed
	else:
		velocity = Vector2.ZERO

func _can_see_player() -> bool:
	# Visión en cono + línea de visión libre de obstáculos.
	if player == null:
		return false

	var offset := player.global_position - global_position

	if offset.length() > vision_range:
		return false

	if absf(
		_look_direction.angle_to(offset.normalized())
	) > deg_to_rad(vision_half_angle_degrees):
		return false

	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		player.global_position
	)
	query.exclude = [get_rid()]

	var hit := get_world_2d().direct_space_state.intersect_ray(query)

	return hit.is_empty() or hit.get("collider") == player

func _on_noise_emitted(
	origin: Vector2,
	radius: float,
	_source: String,
	_kind: String
) -> void:
	# Investiga ruidos dentro del alcance; nunca interrumpe una persecución.
	if not alive or state == GuardState.CHASE:
		return

	if global_position.distance_to(origin) > radius * hearing_multiplier:
		return

	investigate_target = origin
	_search_timer = 5.0
	state = GuardState.INVESTIGATE

func _on_alarm_changed(
	active: bool,
	pos: Vector2,
	_time_left: float
) -> void:
	# La alarma global hace converger a los guardias que no están persiguiendo.
	if not alive or not active or state == GuardState.CHASE:
		return

	investigate_target = pos
	_search_timer = 8.0
	state = GuardState.INVESTIGATE

func _on_run_reset() -> void:
	# Vuelve al estado inicial cuando main.gd reinicia la run.
	state = GuardState.PATROL
	awareness = 0.0
	_search_timer = 0.0
	_no_sight_time = 0.0
	_alarm_refresh_timer = 0.0
	_patrol_index = 0
	velocity = Vector2.ZERO

	if not _patrol_points.is_empty():
		patrol_target = _patrol_points[0]

func is_takedown_eligible(from_position: Vector2, max_range: float) -> bool:
	# Derribo válido: vivo, no persiguiendo, cerca y por detrás de su mirada.
	if not alive or state == GuardState.CHASE:
		return false

	if global_position.distance_to(from_position) > max_range:
		return false

	var to_player := (from_position - global_position).normalized()
	return _look_direction.dot(to_player) < -0.25

func take_hit() -> void:
	# Comunicación entrante desde PlayerCharacter (disparo).
	_die("kills")

func take_down() -> void:
	# Comunicación entrante desde PlayerCharacter (derribo silencioso).
	_die("takedowns")

func _die(stat_name: String) -> void:
	if not alive:
		return

	alive = false
	GameState.increment_stat(stat_name)
	queue_free()

func _draw() -> void:
	var body_color := Color("657080")

	match state:
		GuardState.SUSPICIOUS:
			body_color = Color("b89a4a")
		GuardState.INVESTIGATE:
			body_color = Color("b8864a")
		GuardState.SEARCH:
			body_color = Color("a86f3c")
		GuardState.CHASE:
			body_color = Color("b64b4b")

	draw_circle(Vector2.ZERO, 12.0, body_color)
	draw_line(
		Vector2.ZERO,
		_look_direction * 21.0,
		Color("ffe0b2"),
		3.0
	)

	_draw_detection_indicator()
	_draw_debug_overlay()

func _draw_detection_indicator() -> void:
	# Barra de detección y signo de estado sobre el guardia.
	if awareness > 0.5:
		var bar_width := 30.0
		var bar_position := Vector2(-bar_width * 0.5, -32.0)
		draw_rect(
			Rect2(bar_position, Vector2(bar_width, 4.0)),
			Color(0.0, 0.0, 0.0, 0.55)
		)

		var fill_color := (
			Color("e45b5b") if awareness >= 99.9 else Color("e4b64f")
		)
		draw_rect(
			Rect2(
				bar_position,
				Vector2(bar_width * awareness / 100.0, 4.0)
			),
			fill_color
		)

	var icon := ""
	var icon_color := Color("e4b64f")

	if state == GuardState.CHASE:
		icon = "!"
		icon_color = Color("e45b5b")
	elif (
		state == GuardState.SUSPICIOUS
		or state == GuardState.INVESTIGATE
		or state == GuardState.SEARCH
	):
		icon = "?"

	if icon != "":
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-20.0, -38.0),
			icon,
			HORIZONTAL_ALIGNMENT_CENTER,
			40.0,
			20,
			icon_color
		)

func _draw_debug_overlay() -> void:
	# F3: ruta de patrulla y cono de visión.
	if not GameState.debug_overlay:
		return

	if _patrol_points.size() > 1:
		for index in range(_patrol_points.size()):
			var from_point := to_local(_patrol_points[index])
			var to_point := to_local(
				_patrol_points[(index + 1) % _patrol_points.size()]
			)
			draw_line(from_point, to_point, Color(0.3, 0.6, 1.0, 0.35), 1.0)

	var cone := PackedVector2Array([Vector2.ZERO])
	var steps := 18
	var base_angle := _look_direction.angle()
	var half_angle := deg_to_rad(vision_half_angle_degrees)

	for index in range(steps + 1):
		var angle := (
			base_angle
			- half_angle
			+ (2.0 * half_angle) * (float(index) / float(steps))
		)
		cone.append(Vector2(cos(angle), sin(angle)) * vision_range)

	draw_colored_polygon(cone, Color(1.0, 0.85, 0.25, 0.08))
	draw_line(
		Vector2.ZERO,
		_look_direction * vision_range,
		Color(1.0, 0.85, 0.25, 0.35),
		1.0
	)
