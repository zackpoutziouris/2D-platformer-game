extends Node2D

@export var player_controller : PlayerController
@export var animation_player : AnimationPlayer
@export var sprite : Sprite2D
@export var sprint_anim_speed := 1.5

func play_if_not(anim: String):
	if animation_player.current_animation != anim:
		animation_player.play(anim)

func _process(delta):
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
		play_if_not("dash")
		return
		
	# Double jump plays once
	if player_controller.did_double_jump && player_controller.velocity.y < 0:
		play_if_not("double-jump")
		return

	# =========================
	# AIR STATES
	# =========================
	if player_controller.velocity.y < 0:
		play_if_not("jump")
		return
	elif player_controller.velocity.y > 0:
		play_if_not("fall")
		return
	
	# =========================
	# CROUCH STATES
	# =========================
	if player_controller.is_crouching:
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
		if player_controller.is_sprinting:
			animation_player.speed_scale = sprint_anim_speed

		play_if_not("walk")
	else:
		play_if_not("idle")
