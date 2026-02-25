extends CharacterBody2D
class_name PlayerController

@export var speed = 4
@export var jump_power = 10
@export var camera : Camera2D

var speed_multiplier = 30
var jump_multiplier = -30
var direction = 0

var jumps_used := 0
var max_jumps := 2   # jump + double jump
var did_double_jump := false

# Dash system
@export var dash_speed := 450.0
@export var dash_time := 0.15
@export var dash_vertical_damping := 0.85

var is_dashing := false
var dash_timer := 0.0
var dash_direction := 1
var dashes_used := 0
var max_air_dashes := 1

# Facing direction
var facing := 1

#const SPEED = 300.0
#const JUMP_VELOCITY = -400.0

# Get the gravity from the project settings to be synced with RigidBody nodes
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _input(event):
	# Handle jump down
	if event.is_action_pressed("move_down"):
		set_collision_mask_value(10, false)
	else:		
		set_collision_mask_value(10, true)

func _physics_process(delta):
	# ----- DASH -----
	if is_dashing:
		dash_timer -= delta

		# Maintain strong horizontal speed
		velocity.x = dash_direction * dash_speed

		# Slightly reduce vertical velocity instead of freezing it
		velocity.y *= dash_vertical_damping

		# Apply reduced gravity during dash (optional but feels better)
		velocity.y += gravity * delta * 0.35

		if dash_timer <= 0:
			is_dashing = false

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
	if Input.is_action_just_pressed("dash"):
		if can_dash():
			start_dash()

	# ----- MOVEMENT -----
	direction = Input.get_axis("move_left", "move_right")

	if direction:
		velocity.x = direction * speed * speed_multiplier
		facing = sign(direction)
	else:
		velocity.x = move_toward(velocity.x, 0, speed * speed_multiplier)

	move_and_slide()
	
func start_dash():
	is_dashing = true
	dash_timer = dash_time
	dash_direction = facing

	if !is_on_floor():
		dashes_used += 1
	
func can_dash() -> bool:
	# Always allow ground dash
	if is_on_floor():
		return true

	# Allow limited air dashes
	return dashes_used < max_air_dashes

func teleport_to_location(new_location):
	position =  new_location
	camera.reset_smoothing()
