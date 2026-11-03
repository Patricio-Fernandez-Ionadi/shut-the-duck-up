class_name PhysicsComponent extends Node

var parent: CharacterBody2D
var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

func _ready() -> void:
	parent = get_parent() as CharacterBody2D

func _physics_process(delta: float) -> void:
	if !parent.is_on_floor():
		parent.velocity.y += gravity * delta
		parent.move_and_slide()
