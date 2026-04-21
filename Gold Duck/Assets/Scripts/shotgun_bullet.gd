extends CharacterBody2D

@export var speed: float = 600
var direction: Vector2 = Vector2.ZERO

func _physics_process(_delta):
	velocity = direction * speed
	move_and_slide()
