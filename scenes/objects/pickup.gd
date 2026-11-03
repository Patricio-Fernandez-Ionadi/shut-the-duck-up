# Pickup: objeto recogible (munición, botellas o documento opcional).
#
# RECIBE información de:
#   * Mundo físico: señal body_entered cuando el jugador lo toca.
#
# COMUNICA información a:
#   * PlayerCharacter: refill_ammo() o add_bottles().
#   * GameState: incrementa el contador de loot al recoger un documento.
#   * Se elimina del árbol al recogerse.

extends Area2D
class_name Pickup

@export_enum("ammo", "bottles", "loot") var kind: String = "ammo"
@export var amount: int = 1

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	queue_redraw()

func _on_body_entered(body: Node2D) -> void:
	if body is not PlayerCharacter:
		return

	var player := body as PlayerCharacter

	match kind:
		"ammo":
			player.refill_ammo(amount)
			player.status_message = "Munición +%d." % amount
		"bottles":
			player.add_bottles(amount)
			player.status_message = "Botellas +%d." % amount
		"loot":
			GameState.increment_stat("loot")
			player.status_message = "Documento recuperado."

	queue_free()

func _draw() -> void:
	var color := Color("e4b64f")

	match kind:
		"bottles":
			color = Color("8fd3e8")
		"loot":
			color = Color("5ebc83")

	draw_circle(Vector2.ZERO, 9.0, Color(0.0, 0.0, 0.0, 0.35))
	draw_circle(Vector2.ZERO, 8.0, color)

	# Símbolo simple por tipo para distinguirlos a distancia.
	match kind:
		"ammo":
			draw_rect(
				Rect2(Vector2(-3.0, -5.0), Vector2(6.0, 10.0)),
				Color("3a2a12")
			)
		"bottles":
			draw_line(
				Vector2(-4.0, 4.0),
				Vector2(4.0, -4.0),
				Color("1d4a58"),
				2.0
			)
		"loot":
			draw_colored_polygon(
				PackedVector2Array([
					Vector2(0.0, -5.0),
					Vector2(5.0, 0.0),
					Vector2(0.0, 5.0),
					Vector2(-5.0, 0.0),
				]),
				Color("143d26")
			)
