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
		velocity.y = jump_power * jump_multiplier
		jumps_used += 1
		
		if jumps_used == 2:
			did_double_jump = true

	# ----- DASH INPUT -----
	if Input.is_action_just_pressed("dash") and can_dash() and !is_crouching:
		start_dash()
	
	# ----- CROUCH INPUT -----
	is_crouching = Input.is_action_pressed("crouch") and is_on_floor()

	# ----- MOVEMENT -----
	direction = Input.get_axis("move_left", "move_right")
	current_speed = speed * speed_multiplier
	
	if is_crouching:
		current_speed *= crouch_speed_multiplier
	
	if direction:
		velocity.x = direction * current_speed
		facing = sign(direction)
	else:
		velocity.x = move_toward(velocity.x, 0, current_speed)

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
