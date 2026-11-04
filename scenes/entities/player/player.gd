class_name Player extends CharacterBody2D
# CharacterBody2D: personaje controlado por el jugador.
# La lógica de disparo/recarga/mira vive en el nodo hijo Weapon (WeaponComponent).

#region ─── Constructor ────────────────────────────────────────────────────────
signal shot_hit
# Re-emitido por compat cuando el arma impacta a un guardia.

# --- Configuración ajustable desde el Inspector ---
@export var walk_speed: float = 175.0
@export var sprint_speed: float = 255.0
@export var crouch_speed: float = 95.0
@export var footstep_noise_radius: float = 110.0
@export var takedown_range: float = 42.0
@export var throw_range: float = 380.0

# --- Referencias a nodos hijos ---
@onready var duck: Duck = $Duck
@onready var weapon: GunComponent = $GunComponent
@onready var movement: MovementTopDownComponent = $Movement

# --- Estado interno ---
var facing_direction := Vector2.RIGHT
var is_aiming := false
var is_crouching := false
var is_sprinting := false
var bottles := 3
var status_message := "Llegá a la salida. E intentá que el pato no grazne."

var _footstep_timer := 0.0
var _cursor_hidden := false

const BOTTLE_SCENE := preload("res://scenes/objects/bottle.tscn")
#endregion ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	weapon.hit_target.connect(_on_weapon_hit_target)
	weapon.fired.connect(_on_weapon_fired)
	weapon.reload_started.connect(_on_weapon_reload_started)
	weapon.reload_finished.connect(_on_weapon_reload_finished)

func _physics_process(delta: float) -> void:
	
	# 1) Obtener movimiento desde el componente.
	var input_direction := movement.get_input_direction()
	var is_moving := input_direction != Vector2.ZERO

	# 2) Apuntado: con "aim" la mirada sigue al cursor; si no, a donde camina.
	is_aiming = Input.is_action_pressed("aim")

	if is_aiming:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length_squared() > 1.0:
			facing_direction = to_mouse.normalized()
	elif input_direction.length_squared() > 0.01:
		facing_direction = input_direction.normalized()

	_update_aim_feedback()

	# 3) Postura y velocidad.
	is_crouching = Input.is_action_pressed("crouch")
	is_sprinting = Input.is_action_pressed("sprint") and is_moving and not is_crouching

	var speed := walk_speed
	if is_crouching:
		speed = crouch_speed
	elif is_sprinting:
		speed = sprint_speed

	# 4) Movimiento físico.
	movement.apply_movement(input_direction, speed)
	print(facing_direction, movement.facing)
	# El cuerpo ejecuta el movimiento una sola vez.
	move_and_slide()
	
	# 5) Correr agita al pato..
	if is_sprinting:
		duck.agitation = minf(100.0, duck.agitation + 9.0 * delta)

	# 6) Pasos audibles al correr.
	if is_sprinting:
		_footstep_timer -= delta
		if _footstep_timer <= 0.0:
			_footstep_timer = 0.35
			NoiseSystem.emit_noise(
				global_position, footstep_noise_radius, "PASOS", "footstep"
			)
	else:
		_footstep_timer = 0.0

	# 7) El pato acompaña al jugador.
	#duck.global_position = global_position + Vector2(-18, 20)
	duck.global_position = global_position

	queue_redraw()

	# 8) "E": calmar al pato.
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

	# 8) Clic izquierdo: disparar (delegado al arma).
	#if Input.is_action_just_pressed("shot"):
		#weapon.try_fire(global_position, get_global_mouse_position())

	# 9) "F": derribo silencioso.
	if Input.is_action_just_pressed("interact"):
		_try_takedown()

	# 10) "Q": lanzar botella.
	if Input.is_action_just_pressed("throw_item"):
		_throw_bottle()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shot"):
		weapon.try_fire(global_position, get_global_mouse_position())

func _update_aim_feedback() -> void:
	# Oculta el cursor del sistema mientras la mira lo reemplaza.
	var want_hidden := is_aiming and not GameState.is_complete()

	if want_hidden != _cursor_hidden:
		_cursor_hidden = want_hidden
		Input.set_mouse_mode(
			Input.MOUSE_MODE_HIDDEN if want_hidden else Input.MOUSE_MODE_VISIBLE
		)

	if not is_aiming:
		weapon.clear_aim_target()
		return

	# El arma hace el raycast y emite target_status_changed al crosshair.
	weapon.update_aim_target(global_position, get_global_mouse_position())

#region ─── Callbacks del arma ────────────────────────────────────────────────
func _on_weapon_hit_target(_collider: Object) -> void:
	shot_hit.emit()


func _on_weapon_fired() -> void:
	duck.agitation = minf(100.0, duck.agitation + 20.0)
	status_message = (
		"¡Disparaste! El ruido puede atraer "
		+ "a todos los guardias cercanos."
	)


func _on_weapon_reload_started() -> void:
	status_message = "Recargando…"


func _on_weapon_reload_finished() -> void:
	status_message = "Recarga completa."
#endregion ─────────────────────────────────────────────────────────────────────

#region ─── API pública ──────────────────────────────────────────────────────
func refill_ammo(amount: int) -> void:
	weapon.refill(amount)


func add_bottles(amount: int) -> void:
	bottles += maxi(0, amount)
#endregion ─────────────────────────────────────────────────────────────────────

#region ─── Takedown / Botellas ──────────────────────────────────────────────
func _try_takedown() -> void:
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
	scene.add_child(bottle)

	var spawn_offset := minf(20.0, to_target.length())
	bottle.global_position = (
		global_position + to_target.normalized() * spawn_offset
	)
	bottle.throw_to(global_position + to_target)

	bottles -= 1
	GameState.increment_stat("bottles")
	status_message = "Lanzaste una botella: el ruido los va a distraer."
#endregion ─────────────────────────────────────────────────────────────────────

func _exit_tree() -> void:
	if _cursor_hidden:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _draw() -> void:
	# --- Indicador de mirada ---
	#draw_line(Vector2.ZERO, facing_direction * 18.0, Color("f2f2f2"), 3.0)
	pass
