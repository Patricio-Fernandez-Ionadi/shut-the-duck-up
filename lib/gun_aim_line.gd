class_name AimLine extends Line2D
# Línea guía del apuntado. Vive como nodo hijo del Player
# (o en cualquier parte: se ancla al player cada frame).

@export var player: CharacterBody2D

const LINE_COLOR := Color(0.55, 0.9, 1.0, 0.55)


func _ready() -> void:
	if player == null:
		player = get_parent() as CharacterBody2D
	width = 2.0
	default_color = LINE_COLOR
	visible = false


func _process(_delta: float) -> void:
	if player == null or player.weapon == null:
		visible = false
		return

	if not player.is_aiming:
		visible = false
		return

	# Se ancla al jugador sin importar dónde esté en el árbol.
	global_position = player.global_position

	var to_mouse := player.get_global_mouse_position()
	var distance := minf(
		player.weapon.shot_range,
		player.global_position.distance_to(to_mouse)
	)
	points = PackedVector2Array([Vector2.ZERO, player.facing_direction * distance])
	visible = true
