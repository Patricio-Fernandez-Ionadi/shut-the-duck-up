# PlayerCharacter: personaje controlado por el jugador.
#
# RECIBE información de:
#   * Input del jugador: WASD/flechas (mover), Shift (correr), E (calmar pato),
#     clic derecho ("aim") y clic izquierdo ("shot").
#   * Cursor del mouse: posición global usada para apuntar y para limitar el tiro.
#   * Duck (nodo hijo): su nivel de agitación.
#   * Mundo físico: colisiones y raycast de disparo (direct_space_state).
#
# COMUNICA información a:
#   * Duck: ajusta su agitación al correr, lo reposiciona y lo calma con "E".
#   * NoiseSystem (autoload): emite ruido al disparar; lo escuchan los guardias
#     y el HUD de main.gd.
#   * GuardEnemy: le aplica el impacto con take_hit() cuando el rayo lo alcanza.
#   * main.gd: expone status_message, que se muestra en el HUD.

extends CharacterBody2D
class_name PlayerCharacter

signal shot_hit

# --- Configuración ajustable desde el Inspector ---
@export var walk_speed: float = 175.0
@export var sprint_speed: float = 255.0
@export var crouch_speed: float = 95.0
@export var shot_range: float = 330.0
@export var shot_noise_radius: float = 520.0
@export var footstep_noise_radius: float = 110.0
@export var magazine_size: int = 6
@export var starting_reserve_ammo: int = 6
@export var reload_time: float = 1.4
@export var takedown_range: float = 42.0
@export var throw_range: float = 380.0
@export var recoil_per_shot: float = 6.0
@export var max_aim_spread: float = 24.0
@export var spread_recovery: float = 10.0
@export var max_spread_angle_degrees: float = 6.0

# --- Referencias a nodos hijos ---
@onready var duck: Duck = $Duck

# --- Estado interno ---
var facing_direction := Vector2.RIGHT  # Mirada/apuntado actual (unidad).
var is_aiming := false                 # True mientras se mantiene clic derecho.
var is_crouching := false              # Postura agachada (más sigilo, menos ruido).
var is_sprinting := false              # Corriendo con movimiento (hace ruido).
var ammo := 0                          # Balas en el cargador.
var reserve_ammo := 0                  # Balas de reserva para recargar.
var bottles := 3                       # Distracciones arrojables disponibles.
var is_reloading := false
var status_message := "Llegá a la salida. E intentá que el pato no grazne."
var _shot_cooldown := 0.0              # Segundos restantes antes de poder disparar.
var _reload_timer := 0.0               # Tiempo restante de recarga.
var _footstep_timer := 0.0             # Temporizador de pasos audibles al correr.
var _cursor_hidden := false            # True si ocultamos el cursor del sistema.

# Feedback de apuntado: apertura de la mira y objetivo bajo el cursor.
var aim_spread := 0.0                  # Pérdida de precisión acumulada (px).
var aim_target_hostile := false        # True si la mira está sobre un guardia.

# Feedback de apuntado: línea guía en el mundo.
const AIM_LINE_COLOR := Color(0.55, 0.9, 1.0, 0.55)
const BOTTLE_SCENE := preload("res://scenes/objects/bottle.tscn")

func _ready() -> void:
	# Arranca con el cargador lleno y la reserva configurada.
	ammo = magazine_size
	reserve_ammo = starting_reserve_ammo

func _physics_process(delta: float) -> void:
	# 1) Temporizadores de disparo y recarga.
	_shot_cooldown = maxf(0.0, _shot_cooldown - delta)
	_update_reload(delta)

	# 2) Lectura del movimiento desde el InputMap del proyecto.
	var input_direction := Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	# 3) Apuntado:
	#    - Con "aim" (clic derecho) mantenido, la mirada sigue al cursor.
	#    - Sin apuntar, se conserva el comportamiento original: mirar hacia
	#      donde se mueve el jugador.
	is_aiming = Input.is_action_pressed("aim")

	if is_aiming:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length_squared() > 1.0:
			facing_direction = to_mouse.normalized()
	elif input_direction.length_squared() > 0.01:
		facing_direction = input_direction.normalized()

	# 4) La mira se dibuja en el HUD; acá ocultamos el cursor solo al apuntar.
	_update_aim_feedback(delta)

	# 5) Postura y velocidad: agacharse da sigilo; Shift corre (pero hace ruido).
	var is_moving := input_direction.length_squared() > 0.01
	is_crouching = Input.is_action_pressed("crouch")
	is_sprinting = Input.is_key_pressed(KEY_SHIFT) and is_moving and not is_crouching

	var speed := walk_speed
	if is_crouching:
		speed = crouch_speed
	elif is_sprinting:
		speed = sprint_speed

	velocity = input_direction * speed

	# 6) Correr agita al pato: comunicación directa con el nodo Duck.
	if is_sprinting:
		duck.agitation = minf(100.0, duck.agitation + 9.0 * delta)

	# 7) Movimiento con colisiones del mundo.
	move_and_slide()
	queue_redraw()

	# 8) Pasos audibles al correr (caminar/acurrucarse son silenciosos).
	if is_sprinting:
		_footstep_timer -= delta
		if _footstep_timer <= 0.0:
			_footstep_timer = 0.35
			NoiseSystem.emit_noise(
				global_position,
				footstep_noise_radius,
				"PASOS",
				"footstep"
			)
	else:
		_footstep_timer = 0.0

	# 9) El pato acompaña al jugador en un offset fijo (no rota con el apuntado).
	duck.global_position = global_position + Vector2(-18, 20)

	# 10) "E": calmar al pato. Duck.calm() reduce la agitación y emite ruido.
	if Input.is_action_just_pressed("calm_duck"):
		if duck.calm():
			status_message = (
				"Intentaste calmar al pato. "
				+ "También hiciste un poco de ruido."
			)
		else:
			status_message = (
				"El pato todavía está agitado: esperá un momento."
			)

	# 11) Clic izquierdo: disparar.
	if Input.is_action_just_pressed("shot"):
		_shot()

	# 12) "F": derribo silencioso si hay un guardia desprevenido de espaldas.
	if Input.is_action_just_pressed("interact"):
		_try_takedown()

	# 13) "Q": lanzar una botella hacia el cursor para distraer.
	if Input.is_action_just_pressed("throw_item"):
		_throw_bottle()

func _update_aim_feedback(delta: float) -> void:
	# La precisión se recupera sola cuando dejás de disparar.
	aim_spread = maxf(0.0, aim_spread - spread_recovery * delta)

	# El cursor del sistema solo se oculta mientras la mira lo reemplaza.
	var want_hidden := is_aiming and not GameState.is_complete()

	if want_hidden != _cursor_hidden:
		_cursor_hidden = want_hidden
		Input.set_mouse_mode(
			Input.MOUSE_MODE_HIDDEN if want_hidden else Input.MOUSE_MODE_VISIBLE
		)

	if not is_aiming:
		aim_target_hostile = false
		return

	var hit := _aim_hit()
	aim_target_hostile = false

	if not hit.is_empty():
		var target: Object = hit.get("collider")

		if target is GuardEnemy:
			var guard := target as GuardEnemy
			aim_target_hostile = guard.alive

func _aim_distance() -> float:
	# Con el cursor como mira, el disparo no supera el cursor.
	if is_aiming:
		return minf(
			shot_range,
			global_position.distance_to(get_global_mouse_position())
		)
	return shot_range

func _aim_hit() -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + _aim_direction() * _aim_distance()
	)
	query.exclude = [get_rid()]

	return get_world_2d().direct_space_state.intersect_ray(query)

func _aim_direction() -> Vector2:
	# Devuelve la dirección de apuntado actual.
	# - Apuntando: recalcula hacia el cursor para que el disparo sea exacto
	#   aunque el mouse se haya movido desde el último frame de física.
	# - Sin apuntar: usa la última dirección de mirada (la del movimiento).
	if is_aiming:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length_squared() > 1.0:
			return to_mouse.normalized()
	return facing_direction

func _shot() -> void:
	if is_reloading or _shot_cooldown > 0.0:
		return

	if ammo <= 0:
		# Disparar en seco inicia la recarga automáticamente.
		_start_reload()
		return

	_shot_cooldown = 0.35
	ammo -= 1

	# Comunica el ruido al bus global; guardias y HUD están suscritos.
	NoiseSystem.emit_noise(
		global_position,
		shot_noise_radius,
		"¡DISPARO!",
		"shot"
	)
	GameState.increment_stat("gunshots")

	# El estruendo también altera al pato.
	duck.agitation = minf(100.0, duck.agitation + 20.0)

	status_message = (
		"¡Disparaste! El ruido puede atraer "
		+ "a todos los guardias cercanos."
	)

	# Dirección efectiva del disparo con desvío por pérdida de precisión.
	var spread_ratio := clampf(
		aim_spread / maxf(0.001, max_aim_spread),
		0.0,
		1.0
	)
	var max_deviation := deg_to_rad(max_spread_angle_degrees) * spread_ratio
	var shot_direction := _aim_direction().rotated(
		randf_range(-max_deviation, max_deviation)
	)

	# Alcance: con el cursor como mira, el disparo no supera el cursor.
	var distance := _aim_distance()

	# Raycast contra el mundo; excluye el propio jugador.
	var query := PhysicsRayQueryParameters2D.create(
		global_position,
		global_position + shot_direction * distance
	)
	query.exclude = [get_rid()]

	var hit := get_world_2d().direct_space_state.intersect_ray(query)

	if not hit.is_empty():
		var target: Object = hit.get("collider")

		# Comunica el impacto al guardia alcanzado.
		if target is GuardEnemy:
			var guard := target as GuardEnemy
			if guard.alive:
				guard.take_hit()
				shot_hit.emit()

	# El disparo abre la mira; se recupera sola con el tiempo.
	aim_spread = minf(max_aim_spread, aim_spread + recoil_per_shot)

	if ammo <= 0:
		_start_reload()

func _update_reload(delta: float) -> void:
	if not is_reloading:
		return

	_reload_timer -= delta

	if _reload_timer <= 0.0:
		_finish_reload()

func _start_reload() -> void:
	if is_reloading or ammo >= magazine_size or reserve_ammo <= 0:
		return

	is_reloading = true
	_reload_timer = reload_time
	status_message = "Recargando…"

func _finish_reload() -> void:
	var needed := magazine_size - ammo
	var loaded := mini(needed, reserve_ammo)

	ammo += loaded
	reserve_ammo -= loaded
	is_reloading = false
	status_message = "Recarga completa."

func refill_ammo(amount: int) -> void:
	reserve_ammo += maxi(0, amount)

func add_bottles(amount: int) -> void:
	bottles += maxi(0, amount)

func _try_takedown() -> void:
	# Busca el guardia desprevenido más cercano que esté de espaldas.
	var best_guard: GuardEnemy = null
	var best_distance := takedown_range

	for node in get_tree().get_nodes_in_group("guards"):
		var guard := node as GuardEnemy
		if guard == null:
			continue
		if not guard.is_takedown_eligible(global_position, takedown_range):
			continue

		var distance := global_position.distance_to(guard.global_position)
		if distance <= best_distance:
			best_guard = guard
			best_distance = distance

	if best_guard != null:
		best_guard.take_down()
		status_message = "Derribo silencioso. El pato ni se enteró."
	else:
		status_message = "No hay un guardia desprevenido a tu espalda."

func _throw_bottle() -> void:
	if bottles <= 0:
		status_message = "No te quedan botellas."
		return

	var to_target := get_global_mouse_position() - global_position

	if to_target.length_squared() < 64.0:
		to_target = facing_direction * throw_range
	else:
		to_target = (
			to_target.normalized()
			* minf(throw_range, to_target.length())
		)

	var scene := get_tree().current_scene
	if scene == null:
		return

	var bottle := BOTTLE_SCENE.instantiate()
	# Se agrega a la escena del nivel para que se dibuje en coordenadas globales.
	scene.add_child(bottle)

	# Nace fuera del radio del jugador para no romperse contra su propio cuerpo.
	var spawn_offset := minf(20.0, to_target.length())
	bottle.global_position = (
		global_position + to_target.normalized() * spawn_offset
	)
	bottle.throw_to(global_position + to_target)

	bottles -= 1
	GameState.increment_stat("bottles")
	status_message = "Lanzaste una botella: el ruido los va a distraer."

func _exit_tree() -> void:
	# Restaura el cursor si el nodo se elimina mientras se apuntaba.
	if _cursor_hidden:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _draw() -> void:
	# --- Gráfico provisional del personaje ---
	draw_circle(Vector2.ZERO, 12.0, Color("426b9a"))
	draw_circle(Vector2(2, -3), 5.0, Color("e8c4a0"))

	# --- Indicador de mirada/disparo ---
	draw_line(
		Vector2.ZERO,
		facing_direction * 18.0,
		Color("f2f2f2"),
		3.0
	)

	# El feedback extra solo se dibuja mientras se mantiene clic derecho.
	if not is_aiming:
		return

	var aim_distance := minf(
		shot_range,
		global_position.distance_to(get_global_mouse_position())
	)

	# Línea guía desde el jugador hasta el alcance efectivo del disparo;
	# la mira se dibuja aparte en el HUD (scenes/ui/crosshair.tscn).
	draw_line(
		Vector2.ZERO,
		facing_direction * aim_distance,
		AIM_LINE_COLOR,
		2.0
	)
