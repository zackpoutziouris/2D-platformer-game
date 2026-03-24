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

# Glide
@export var glide_fall_speed := 70
@export var fall_speed_limit_for_glide_to_work := 500
@export var glide_walk_control := 1.0
var is_gliding := false

# B-Hop system
@export var bhop_window_frames := 6
@export var bhop_horizontal_boosts := [2, 2.5, 3]
@export var bhop_vertical_boosts := [2, 2.5, 3]
@export var bhop_max_stacks := 3

var bhop_window_timer := 0
var bhop_stacks := 0
var was_on_floor := false

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
var sprint_momentum : bool = false
var target_speed = 1

# Slide
@export var slide_boost_multiplier := 1.7
@export var slide_duration := 0.9
@export var slide_decel := 5

var is_sliding := false
var slide_timer := 0.0
var slide_direction := 0

# Dive
@export var dive_speed := 165

var is_diving := false
var last_down_tap_time := 0.0
var down_double_tap_window := 0.25

# Direction
var facing := 1
var previous_facing := 1
var input_dir : int = 0
var velocity_dir : int = 1
var direction_switch_timer := 0.0
@export var direction_switch_duration := 0.1

# Get the gravity from the project settings to be synced with RigidBody nodes
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _input(event):
	move_down_platform_input_and_action(event)
	dive_input(event)

func _physics_process(delta):
	dash_timer_check(delta)
	bhop_timer_check()
	ledge_fall_check()
	
	reset_on_player_touch_ground()

	movement_left_right_input()
	glide_input()
	dash_input()
	jump_input()
	slide_input()
	crouch_input()
	sprint_input()

	finish_dash(delta)
	finish_dive()
	
	if update_slide(delta):
		return
	
	gravity_and_variable_timed_jumps(delta)
	
	if update_crouch_jump_lock():
		return
	
	handle_air_direction_penalty()
	calculate_target_speed()
	handle_ground_direction_switch(delta)

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

				var air_control = air_control_when_change_direction

				if is_gliding:
					air_control = glide_walk_control

				if input_dir != 0:
					locked_air_direction = input_dir
					move_speed_current = lerpf(
						move_speed_current,
						base_speed,
						clamp(sprint_accel * air_control * delta, 0.0, 1.0)
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





# ---- Player Mechanics ---- 
func reset_on_player_touch_ground():
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
			
		if is_on_floor() and input_dir == 0 and !is_sliding:
			move_speed_current = 0.0

		is_crouch_jump = false
		
		if is_on_floor() and abs(move_speed_current) < 5:
			bhop_stacks = 0

func move_down_platform_input_and_action(event):
	# Handle jump down
	if event.is_action_pressed("move_down"):
		set_collision_mask_value(10, false)
	else:		
		set_collision_mask_value(10, true)

func dive_input(event):
	# Player dive
	if event.is_action_pressed("move_down") and !is_on_floor():
		start_dive()

func dash_timer_check(delta):
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

func bhop_timer_check():
	if bhop_window_timer > 0:
		bhop_window_timer -= 1
		
	# Detect landing
	if is_on_floor() and !was_on_floor:
		bhop_window_timer = bhop_window_frames
		
	was_on_floor = is_on_floor()

func movement_left_right_input():
	# ----- MOVEMENT -----
	direction = Input.get_axis("move_left", "move_right")
	input_dir = signi(direction)

func glide_input():
	# ----- GLIDE INPUT -----
	if !is_on_floor() and velocity.y > 0 and Input.is_action_pressed("jump") and !is_diving and !is_dashing:
		is_gliding = true
		is_crouch_jump = false
		locked_air_direction = 0
	else:
		is_gliding = false

func dash_input():
	# ----- DASH INPUT -----
	if Input.is_action_just_pressed("dash") and can_dash() and !is_crouching and !is_diving:
		start_dash()

func jump_input():
	# ----- JUMP INPUT -----
	if Input.is_action_just_pressed("jump"):
		# ----- B-HOP CHECK -----
		if bhop_window_timer > 0 and abs(move_speed_current) > 5:
			
			bhop_stacks = min(bhop_stacks + 1, bhop_max_stacks)

			var stack_index = bhop_stacks - 1

			move_speed_current *= bhop_horizontal_boosts[stack_index]
			velocity.y *= bhop_vertical_boosts[stack_index]

		else:
			bhop_stacks = 0

		perform_jump()

func slide_input():
	# ----- SLIDE INPUT -----
	if Input.is_action_just_pressed("crouch") and sprint_momentum and is_on_floor() and !is_sliding and abs(velocity.x) > 150:
		perform_slide()

func crouch_input():
	# ----- CROUCH INPUT -----
	is_crouching = Input.is_action_pressed("crouch") and is_on_floor()

func sprint_input():
	# ----- SPRINT INPUT -----
	if is_on_floor():
		sprint_momentum = (
			Input.is_action_pressed("sprint")
			and direction != 0
			and !is_crouching
		)

func gravity_and_variable_timed_jumps(delta):
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
			if is_gliding:
				velocity.y += gravity * delta
				
				if velocity.y > glide_fall_speed and velocity.y < fall_speed_limit_for_glide_to_work:
					velocity.y = glide_fall_speed
			else: 
				velocity.y += gravity * delta

func perform_jump():
	if jumps_used >= max_jumps:
		return

	jump_force = jump_power * jump_multiplier
	var horizontal_jump_override := false

	# ----- CROUCH JUMP -----
	if is_crouching and !is_sliding and is_on_floor():

		if abs(move_speed_current) < 1:
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

func ledge_fall_check():
	# ----- LEDGE FALL COUNTS AS FIRST JUMP -----
	if !is_on_floor() and jumps_used == 0 and velocity.y > 0:
		jumps_used = 1

func update_crouch_jump_lock() -> bool:
	if !is_crouch_jump or is_on_floor():
		return false
	
	velocity.x = locked_air_direction * move_speed_current
	move_and_slide()
	
	return true

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

func finish_dash(delta):
	# ----- DASH -----
	if is_dashing:
		dash_timer -= delta
		
		dash_motion = Vector2(dash_direction * dash_speed * delta, 0)
		move_and_collide(dash_motion)
		
		if dash_timer <= 0:
			is_dashing = false
			dash_cooldown_timer = dash_cooldown
		
		return

func can_dash() -> bool:
	if dash_cooldown_timer > 0:
		return false
	
	# Ground dash allowed (but cooldown limited)
	if is_on_floor():
		return true

	# Air dash limited
	return dashes_used < max_air_dashes

func perform_slide():
	is_sliding = true
	slide_timer = slide_duration
	slide_direction = facing

	# initial burst
	move_speed_current = max(move_speed_current, base_speed * sprint_multiplier)
	move_speed_current *= slide_boost_multiplier

func update_slide(delta) -> bool:
	if !is_sliding:
		return false
	
	slide_timer -= delta

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
	
	return true
	
func start_dive():
	if is_on_floor():
		return
	
	is_diving = true
	
	# cancel existing movement
	is_sliding = false
	is_dashing = false
	is_gliding = false
	
	velocity.x = 0
	move_speed_current = 0

func finish_dive():
	# ----- DIVE -----
	if is_diving:
		velocity.x = 0
		velocity.y = dive_speed
		
		move_and_slide()
		
		if is_on_floor():
			is_diving = false
			
		return

func handle_air_direction_penalty():
	if !is_on_floor() and input_dir != 0 and input_dir != previous_facing:
		sprint_momentum = false
		move_speed_current *= 0.35

func handle_ground_direction_switch(delta):
	#velocity_dir = sign(velocity.x)
	
	if is_on_floor() and input_dir != 0 and input_dir != previous_facing:
		direction_switch_timer = direction_switch_duration
		sprint_momentum = false
	
	if direction_switch_timer > 0:
		direction_switch_timer -= delta
		move_speed_current *= 0.35

func calculate_target_speed():
	base_speed = speed * speed_multiplier
	target_speed = base_speed
	
	if is_crouching:
		target_speed *= crouch_speed_multiplier
	elif sprint_momentum:
		target_speed *= sprint_multiplier
	elif is_gliding:
		target_speed = base_speed

# ---- Additional level mechanics ----
func teleport_to_location(new_location):
	position =  new_location
	camera.reset_smoothing()
