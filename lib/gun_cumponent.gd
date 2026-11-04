class_name GunComponent extends Node2D
# ─── Componente reutilizable de arma ──────────────────────────────────────────
#
# No conoce al jugador ni al mouse: recibe "from" y "target" en coordenadas
# globales. Reutilizable en NPCs, torretas, jefes, etc.
#
# RECIBE: llamadas a try_fire / update_aim_target / start_reload / refill.
#
# COMUNICA:
#   * fired             → disparo consumido (el player reacciona: pato, status).
#   * hit_target        → impacto sobre un guardia vivo.
#   * ammo_changed      → HUD / feedback.
#   * reload_started / reload_finished → HUD / status.
#   * spread_changed    → crosshair (apertura de mira).
#   * target_status_changed → crosshair (hostil apuntado).
#   * NoiseSystem       → ruido del disparo.
#   * GuardEnemy.take_hit() → impacto.
# ──────────────────────────────────────────────────────────────────────────────

#region ─── Constructor ────────────────────────────────────────────────────────
signal fired()
signal hit_target(collider: Object)
signal ammo_changed(ammo: int, reserve: int)
signal reload_started()
signal reload_finished()
signal spread_changed(spread_ratio: float)
signal target_status_changed(is_hostile: bool)

@export var shot_range: float = 330.0
@export var shot_noise_radius: float = 520.0
@export var magazine_size: int = 6
@export var starting_reserve_ammo: int = 6
@export var reload_time: float = 1.4
@export var shot_cooldown: float = 0.35
@export var recoil_per_shot: float = 6.0
@export var max_aim_spread: float = 24.0
@export var spread_recovery: float = 10.0
@export var max_spread_angle_degrees: float = 6.0

# --- Estado interno ---
var ammo: int = 0
var reserve_ammo: int = 0
var is_reloading: bool = false
var aim_spread: float = 0.0

var _shot_cooldown_left: float = 0.0         # Segundos restantes antes de poder disparar.
var _reload_timer: float = 0.0               # Tiempo restante de recarga.
var _last_target_hostile: bool = false
#endregion ─────────────────────────────────────────────────────────────────────

func _ready() -> void:
	ammo = magazine_size
	reserve_ammo = starting_reserve_ammo
	ammo_changed.emit(ammo, reserve_ammo)

func _physics_process(delta: float) -> void:
	_shot_cooldown_left = maxf(0.0, _shot_cooldown_left - delta)
	_update_reload(delta)
	_recover_spread(delta)

#region ─── Disparo ────────────────────────────────────────────────────────────
func try_fire(from: Vector2, target: Vector2) -> bool:
	# Devuelve true si el disparo se consumió (ammo > 0, sin cooldown).
	# Devuelve false si no se pudo disparar (recargando, cooldown, sin ammo).
	if is_reloading or _shot_cooldown_left > 0.0:
		return false

	if ammo <= 0:
		# Disparar en seco inicia la recarga automáticamente.
		start_reload()
		return false

	_shot_cooldown_left = shot_cooldown
	ammo -= 1
	ammo_changed.emit(ammo, reserve_ammo)

	# Ruido global: guardias y HUD escuchan.
	NoiseSystem.emit_noise(from, shot_noise_radius, "¡DISPARO!", "shot")
	GameState.increment_stat("gunshots")

	# Dirección efectiva con desvío por pérdida de precisión.
	var base_dir := target - from
	if base_dir.length_squared() < 0.001:
		base_dir = Vector2.RIGHT
	else:
		base_dir = base_dir.normalized()

	var max_deviation := deg_to_rad(max_spread_angle_degrees) * get_spread_ratio()
	var direction := base_dir.rotated(randf_range(-max_deviation, max_deviation))
	var distance := minf(shot_range, from.distance_to(target))

	var hit := _raycast(from, from + direction * distance)

	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		if collider is GuardEnemy:
			var guard := collider as GuardEnemy
			if guard.alive:
				guard.take_hit()
				hit_target.emit(collider)

	fired.emit()

	# El disparo abre la mira; se recupera sola con el tiempo.
	aim_spread = minf(max_aim_spread, aim_spread + recoil_per_shot)
	spread_changed.emit(get_spread_ratio())

	if ammo <= 0:
		start_reload()

	return true

func update_aim_target(from: Vector2, target: Vector2) -> void:
	# Raycast "seco" para feedback de apuntado. Sin efectos secundarios.
	var to_target := target - from
	if to_target.length_squared() < 1.0:
		return
	var direction := to_target.normalized()
	var distance := minf(shot_range, to_target.length())
	var hit := _raycast(from, from + direction * distance)

	var hostile := false
	if not hit.is_empty():
		var collider: Object = hit.get("collider")
		if collider is GuardEnemy:
			var guard := collider as GuardEnemy
			hostile = guard.alive

	if hostile != _last_target_hostile:
		_last_target_hostile = hostile
		target_status_changed.emit(hostile)

func clear_aim_target() -> void:
	if _last_target_hostile:
		_last_target_hostile = false
		target_status_changed.emit(false)

func get_spread_ratio() -> float:
	return clampf(aim_spread / maxf(0.001, max_aim_spread), 0.0, 1.0)

func can_fire() -> bool:
	return not is_reloading and _shot_cooldown_left <= 0.0 and ammo > 0
#endregion ─────────────────────────────────────────────────────────────────────

#region ─── Recarga ────────────────────────────────────────────────────────────
func start_reload() -> void:
	if is_reloading or ammo >= magazine_size or reserve_ammo <= 0:
		return
	is_reloading = true
	_reload_timer = reload_time
	reload_started.emit()

func _update_reload(delta: float) -> void:
	if not is_reloading:
		return
	_reload_timer -= delta
	if _reload_timer <= 0.0:
		_finish_reload()

func _finish_reload() -> void:
	var needed := magazine_size - ammo
	var loaded := mini(needed, reserve_ammo)
	ammo += loaded
	reserve_ammo -= loaded
	is_reloading = false
	ammo_changed.emit(ammo, reserve_ammo)
	reload_finished.emit()

func refill(amount: int) -> void:
	reserve_ammo += maxi(0, amount)
	ammo_changed.emit(ammo, reserve_ammo)
#endregion ─────────────────────────────────────────────────────────────────────

#region ─── Internos ───────────────────────────────────────────────────────────
func _recover_spread(delta: float) -> void:
	if aim_spread <= 0.0:
		return
	var prev := aim_spread
	aim_spread = maxf(0.0, aim_spread - spread_recovery * delta)
	if aim_spread != prev:
		spread_changed.emit(get_spread_ratio())

func _raycast(from: Vector2, to: Vector2) -> Dictionary:
	var query := PhysicsRayQueryParameters2D.create(from, to)
	query.exclude = _excluded_rids()
	return get_world_2d().direct_space_state.intersect_ray(query)

func _excluded_rids() -> Array[RID]:
	# Excluye al dueño del arma (el padre, si es un cuerpo físico).
	var rids: Array[RID] = []
	var parent := get_parent()
	if parent is CollisionObject2D:
		rids.append((parent as CollisionObject2D).get_rid())
	return rids
#endregion ─────────────────────────────────────────────────────────────────────
