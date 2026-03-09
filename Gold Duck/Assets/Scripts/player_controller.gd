extends CharacterBody2D
class_name PlayerController

# Base movement
@export var speed: float = 4
@export var jump_power: float = 9
@export var camera : Camera2D
@export var air_control_when_change_direction : float = 0.8
var speed_multiplier: float = 30
var jump_multiplier: float = -30
var direction = 0
var jump_force = 0.0
var base_speed = 1
var move_speed_current : float = 0.0

# Variable jump tuning
@export var jump_hold_gravity_scale : float = 0.6
@export var jump_cut_gravity_scale : float = 2.2
@export var max_jump_hold_time : float = 0.25

var jump_hold_timer : float = 0.0

# Double jump
var jumps_used := 0
var max_jumps := 2   # jump + double jump
var did_double_jump := false
var locked_air_direction: int = 0

# Dash system
@export var dash_distance := 65
@export var dash_time := 0.12
@export var dash_cooldown := 0.25
var is_dashing := false
var dash_timer := 0.0
var dash_direction := 1
var dash_cooldown_timer := 0.0
var dash_speed := 0.0
var dashes_used := 0
var max_air_dashes := 1
var dash_motion : Vector2 = Vector2.ZERO

# Crouch
@export var crouch_speed_multiplier : float = 0.5
@export var crouch_jump_multiplier : float = 1.42
@export var crouch_hop_multiplier : float = 0.5
@export var crouch_jump_back_boost : float = 1
var is_crouching : bool = false
var is_crouch_jump : bool = false

# Sprint
@export var sprint_multiplier : float = 1.6
@export var sprint_accel : float = 6.0
@export var ground_decel : float = 14.0
var is_sprinting : bool = false
var sprint_momentum : bool = false
var target_speed = 1

# Slide
@export var slide_boost_multiplier := 5
@export var slide_duration := 1
@export var slide_decel := 5

var is_sliding := false
var slide_timer := 0.0
var slide_direction := 0

# Direction
var facing := 1
var previous_facing := 1
var input_dir : int = 0.0
var velocity_dir : int = 1

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
	
	# ----- MOVEMENT -----
	direction = Input.get_axis("move_left", "move_right")
	input_dir = signi(direction)
		
	# ----- DASH INPUT -----
	if Input.is_action_just_pressed("dash") and can_dash() and !is_crouching:
		start_dash()
	
	# ----- DASH -----
	if is_dashing:
		dash_timer -= delta

		dash_motion = Vector2(dash_direction * dash_speed * delta, 0)
		move_and_collide(dash_motion)

		if dash_timer <= 0:
			is_dashing = false
			dash_cooldown_timer = dash_cooldown

		return

	# ----- GRAVITY -----
	if not is_on_floor():
		if velocity.y < 0:
			if is_crouch_jump:
				# Always full jump height
				velocity.y += gravity * delta
			else:
				if Input.is_action_pressed("jump") and jump_hold_timer < max_jump_hold_time:
					velocity.y += gravity * jump_hold_gravity_scale * delta
					jump_hold_timer += delta
				else:
					velocity.y += gravity * jump_cut_gravity_scale * delta
		else:
			velocity.y += gravity * delta

	# ----- RESET JUMPS -----
	if is_on_floor():
		jumps_used = 0
		did_double_jump = false
		dashes_used = 0
		locked_air_direction = 0

		if is_crouch_jump:
			# Hard stop horizontal momentum from crouch jump
			velocity.x = 0.0
			move_speed_current = 0.0
			
		if is_on_floor() and input_dir == 0:
			move_speed_current = 0.0

		is_crouch_jump = false

	# ----- LEDGE FALL COUNTS AS FIRST JUMP -----
	if !is_on_floor() and jumps_used == 0 and velocity.y > 0:
		jumps_used = 1

	# ----- JUMP INPUT -----
	if Input.is_action_just_pressed("jump"):
		perform_jump()
	
	# ----- SLIDE INPUT -----
	if Input.is_action_just_pressed("crouch") \
	and sprint_momentum \
	and is_on_floor() \
	and !is_sliding:

		start_slide()
	
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
		
	# ----- SLIDE MOVEMENT -----
	if is_sliding:
		slide_timer -= delta

		# allow cancelling by pressing opposite direction
		if input_dir != 0 and input_dir != slide_direction:
			is_sliding = false

		# decelerate
		move_speed_current = lerpf(
			move_speed_current,
			0.0,
			clamp(slide_decel * delta, 0.0, 1.0)
		)

		velocity.x = slide_direction * move_speed_current
		move_and_slide()

		if slide_timer <= 0 or abs(move_speed_current) < 5:
			is_sliding = false

		return
	
	# ------------------------------------------------
	# CROUCH JUMP LOCK (NO HORIZONTAL MODIFICATION)
	# ------------------------------------------------
	if is_crouch_jump and not is_on_floor():
		velocity.x = locked_air_direction * move_speed_current
		move_and_slide()
		return
	
	if !is_on_floor() and input_dir != 0 and input_dir != previous_facing:
		sprint_momentum = false
		is_sprinting = false
		move_speed_current *= 0.35
	
	base_speed = speed * speed_multiplier
	target_speed = base_speed

	if is_crouching:
		target_speed *= crouch_speed_multiplier
	elif sprint_momentum:
		target_speed *= sprint_multiplier

	# Detect direction change
	velocity_dir = signi(velocity.x)

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
			if not is_crouch_jump:
				if input_dir != 0:
					locked_air_direction = input_dir
					move_speed_current = lerpf(
						move_speed_current,
						target_speed,
						clamp(sprint_accel * air_control_when_change_direction * delta, 0.0, 1.0)
					)

		previous_facing = facing
		if not is_crouch_jump:
			facing = input_dir
	else:
		if is_on_floor():
			move_speed_current = lerpf(
				move_speed_current,
				0.0,
				clamp(ground_decel * delta, 0.0, 1.0)
			)

	# Apply velocity
	if is_on_floor():
		velocity.x = facing * move_speed_current
	else:
		if locked_air_direction != 0:
			velocity.x = locked_air_direction * move_speed_current

	move_and_slide()

func perform_jump():

	if jumps_used >= max_jumps:
		return

	jump_force = jump_power * jump_multiplier
	var horizontal_jump_override := false

	# ----- CROUCH JUMP -----
	if is_crouching and !is_sliding and is_on_floor():

		if abs(velocity.x) < 1:
			jump_force *= crouch_jump_multiplier
			is_crouch_jump = true

			locked_air_direction = -facing
			move_speed_current = base_speed * crouch_jump_back_boost
			velocity.x = locked_air_direction * move_speed_current
			horizontal_jump_override = true
		else:
			jump_force *= crouch_hop_multiplier

	# ----- SLIDE JUMP -----
	elif is_sliding:

		is_sliding = false
		locked_air_direction = slide_direction

	# ----- APPLY JUMP -----
	velocity.y = jump_force
	jump_hold_timer = 0.0
	jumps_used += 1

	if jumps_used == 2:
		did_double_jump = true
		
		# Release crouch jump directional lock
		is_crouch_jump = false
		locked_air_direction = 0

	# ensure slide/crouch states don't persist incorrectly
	if is_sliding:
		is_sliding = false

	if !horizontal_jump_override and !is_on_floor():
		if locked_air_direction != 0:
			velocity.x = locked_air_direction * move_speed_current

func start_dash():
	is_dashing = true
	dash_timer = dash_time
	dash_direction = facing
	
	dash_speed = dash_distance / dash_time
	
	# ----- HARD CANCEL ALL MOMENTUM -----
	velocity = Vector2.ZERO
	move_speed_current = 0.0
	locked_air_direction = 0
	is_crouch_jump = false
	jump_hold_timer = max_jump_hold_time

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

func start_slide():

	is_sliding = true
	slide_timer = slide_duration
	slide_direction = facing

	# initial burst
	move_speed_current = max(move_speed_current, base_speed * sprint_multiplier)
	move_speed_current *= slide_boost_multiplier

func teleport_to_location(new_location):
	position =  new_location
	camera.reset_smoothing()
