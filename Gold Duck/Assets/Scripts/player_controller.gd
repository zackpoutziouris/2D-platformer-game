extends CharacterBody2D
class_name PlayerController

# Base movement
@export var speed = 4
@export var jump_power = 10
@export var camera : Camera2D
var speed_multiplier = 30
var jump_multiplier = -30
var direction = 0
var current_speed = 0
var jump_force = 0.0

# Double jump
var jumps_used := 0
var max_jumps := 2   # jump + double jump
var did_double_jump := false

# Dash system
@export var dash_speed := 450.0
@export var dash_time := 0.15
@export var dash_cooldown := 0.25
@export var dash_vertical_damping := 0.85
@export var dash_gravity_scale := 0.35
var is_dashing := false
var dash_timer := 0.0
var dash_direction := 1
var dash_cooldown_timer := 0.0
var dashes_used := 0
var max_air_dashes := 1

# Crouch
@export var crouch_speed_multiplier : float = 0.5
var is_crouching : bool = false
@export var crouch_jump_multiplier : float = 1.3
@export var crouch_jump_horizontal_boost : float = 1

# Sprint
@export var sprint_multiplier : float = 1.6
@export var sprint_accel : float = 6.0
@export var ground_decel : float = 14.0
@export var air_control : float = 0.75

var is_sprinting : bool = false
var sprint_momentum : bool = false
var move_speed_current : float = 0.0
var previous_facing := 1

# Current side player is facing
var facing := 1

# Get the gravity from the project settings to be synced with RigidBody nodes
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _input(event):
	# Handle jump down
	if event.is_action_pressed("move_down"):
		set_collision_mask_value(10, false)
	else:		
		set_collision_mask_value(10, true)

func _physics_process(delta):
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta
		
	# ----- DASH -----
	if is_dashing:
		dash_timer -= delta

		# Strong horizontal burst
		velocity.x = dash_direction * dash_speed

		# Preserve motion but soften vertical speed
		velocity.y *= dash_vertical_damping
		velocity.y += gravity * delta * dash_gravity_scale

		if dash_timer <= 0:
			is_dashing = false
			dash_cooldown_timer = dash_cooldown

		move_and_slide()
		return

	# ----- GRAVITY -----
	if not is_on_floor():
		velocity.y += gravity * delta

	# ----- RESET JUMPS -----
	if is_on_floor():
		jumps_used = 0
		did_double_jump = false
		dashes_used = 0

	# ----- LEDGE FALL COUNTS AS FIRST JUMP -----
	if !is_on_floor() and jumps_used == 0 and velocity.y > 0:
		jumps_used = 1

	# ----- JUMP INPUT -----
	if Input.is_action_just_pressed("jump") and jumps_used < max_jumps:
		jump_force = jump_power * jump_multiplier
		
		# Crouch jump (only when crouched on the ground)
		if is_crouching and is_on_floor():
			jump_force *= crouch_jump_multiplier
			
			# Forward pop on crouch jump
			if direction != 0:
				velocity.x *= crouch_jump_horizontal_boost
				
		velocity.y = jump_force
		jumps_used += 1
		
		if jumps_used == 2:
			did_double_jump = true

	# ----- DASH INPUT -----
	if Input.is_action_just_pressed("dash") and can_dash() and !is_crouching:
		start_dash()
	
	# ----- CROUCH INPUT -----
	is_crouching = Input.is_action_pressed("crouch") and is_on_floor()
	
	# ----- SPRINT INPUT -----
	if is_on_floor():
		sprint_momentum = (
			Input.is_action_pressed("sprint")
			and direction != 0
			and !is_crouching
		)
		
	is_sprinting = sprint_momentum

	# ----- MOVEMENT -----
	direction = Input.get_axis("move_left", "move_right")
	var input_dir : int = signi(direction)
	
	if !is_on_floor() and input_dir != 0 and input_dir != previous_facing:
		sprint_momentum = false
		is_sprinting = false
		move_speed_current *= 0.35
	
	var base_speed = speed * speed_multiplier
	var target_speed = base_speed

	if is_crouching:
		target_speed *= crouch_speed_multiplier
	elif is_sprinting and is_on_floor():
		target_speed *= sprint_multiplier

	# Detect direction change
	var velocity_dir : int = signi(velocity.x)

	# --------------------------------
	# DIRECTION SWITCH (GROUND)
	# --------------------------------
	if is_on_floor() and input_dir != 0 and velocity_dir != 0 and input_dir != velocity_dir:
		move_speed_current *= 0.25   # heavy speed loss
		sprint_momentum = false      # must rebuild sprint

	# --------------------------------
	# ACCELERATION (GROUND)
	# --------------------------------
	if direction != 0:
		if is_on_floor():
			move_speed_current = lerpf(
				move_speed_current,
				target_speed,
				clamp(sprint_accel * delta, 0.0, 1.0)
			)
		else:
			# limited air control
			move_speed_current = lerpf(
				move_speed_current,
				target_speed,
				clamp(sprint_accel * air_control * delta, 0.0, 1.0)
			)

		previous_facing = facing
		facing = input_dir
	else:
		if is_on_floor():
			move_speed_current = lerpf(
				move_speed_current,
				0.0,
				clamp(ground_decel * delta, 0.0, 1.0)
			)

	# Apply velocity
	velocity.x = facing * move_speed_current

	move_and_slide()
	
func start_dash():
	is_dashing = true
	dash_timer = dash_time
	dash_direction = facing
	velocity.x += dash_direction * 150

	if !is_on_floor():
		dashes_used += 1
	
func can_dash() -> bool:
	if dash_cooldown_timer > 0:
		return false

	# Ground dash allowed (but cooldown limited)
	if is_on_floor():
		return true

	# Air dash limited
	return dashes_used < max_air_dashes

func teleport_to_location(new_location):
	position =  new_location
	camera.reset_smoothing()
