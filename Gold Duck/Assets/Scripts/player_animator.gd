extends Node2D

@export var player_controller : PlayerController
@export var animation_player : AnimationPlayer
@export var sprite : Sprite2D
@export var sprint_anim_speed := 1.5

@export var collision_stand : CollisionShape2D
@export var collision_air : CollisionShape2D
@export var collision_crouch : CollisionShape2D

func play_if_not(anim: String):
	if animation_player.current_animation != anim:
		animation_player.play(anim)

func set_collision(state: String):
	collision_stand.disabled = state != "stand"
	collision_air.disabled = state != "air"
	collision_crouch.disabled = state != "crouch"

func _process(_delta):
	animation_player.speed_scale = 1.0
	
	# --- Flip sprite ---
	if player_controller.facing == 1:
		sprite.flip_h = false
	elif player_controller.facing == -1:
		sprite.flip_h = true


	# =========================
	# PRIORITY ANIMATIONS
	# =========================
	# Dash overrides everything
	if player_controller.is_dashing:
		set_collision("air")
		play_if_not("dash")
		return
	
	# Dive
	if player_controller.is_diving:
		set_collision("stand")
		play_if_not("dive")
		return
	
	# Slide
	if player_controller.is_sliding:
		set_collision("crouch")
		play_if_not("slide")
		return
	
	# Double jump plays once
	if player_controller.did_double_jump && player_controller.velocity.y < 0:
		play_if_not("double-jump")
		return

	# =========================
	# AIR STATES
	# =========================
	# Glide
	if player_controller.is_gliding:
		set_collision("air")
		play_if_not("glide")
		return

	if player_controller.velocity.y < 0 and !player_controller.is_on_floor():
		set_collision("air")
		var stacks = player_controller.last_slide_jump_stacks
		
		if stacks == 0:
			stacks = player_controller.bhop_stacks
		
		match stacks:
			0:
				play_if_not("jump")
			1:
				play_if_not("bhop1")
			2:
				play_if_not("bhop2")
			_:
				play_if_not("bhop3")
		return
	elif player_controller.velocity.y > 0 and !player_controller.is_on_floor():
		set_collision("air")
		play_if_not("fall")
		return
	
	# =========================
	# CROUCH STATES
	# =========================
	if player_controller.is_crouching:
		set_collision("air")
		if abs(player_controller.velocity.x) > 3:
			play_if_not("crouch-walk")
		else:
			play_if_not("crouch")
		return
	
	# =========================
	# GROUND STATES
	# =========================
	if abs(player_controller.velocity.x) > 3 && player_controller.velocity.y == 0:
		# Speed up animation if sprinting
		if player_controller.sprint_momentum:
			animation_player.speed_scale = sprint_anim_speed
		
		set_collision("stand")
		play_if_not("walk")
	else:
		set_collision("stand")
		play_if_not("idle")
