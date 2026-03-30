extends CharacterBody2D
class_name PlayerController

# Base movement
@export var speed : float = 4
@export var jump_power: float = 9
@export var camera : Camera2D
@export var air_control_when_change_direction : float = 0.8
@export var ground_accel : float = 6.0
@export var ground_decel : float = 14.0
var speed_multiplier: float = 30
var jump_multiplier: float = -30
var direction : float = 0.0
var jump_force : float = 0.0
var base_speed : float = 1
var move_speed_current : float = 0.0
var air_control : float = 0.0

# Variable jump tuning
@export var jump_hold_gravity_scale : float = 0.6
@export var jump_cut_gravity_scale : float = 2.2
@export var max_jump_hold_time : float = 0.25
var jump_hold_timer : float = 0.0

# Double jump
var jumps_used : int = 0
var max_jumps : int = 2   # jump + double jump
var did_double_jump : bool = false
var locked_air_direction : int = 0
var horizontal_jump_override : bool = false

# Glide
@export var glide_fall_speed : float = 70
@export var fall_speed_limit_for_glide_to_work : float = 500
@export var glide_walk_control : float = 1.0
var is_gliding : bool = false

# B-Hop system
@export var bhop_window_frames : int = 5
@export var bhop_horizontal_boosts : Array[float] = [2, 2.5, 3]
@export var bhop_vertical_boosts : Array[float] = [2, 2.5, 3]
@export var bhop_max_stacks : int = 3
var bhop_window_timer : int = 0
var bhop_stacks : int = 0
var was_on_floor : bool = false

# Dash system
@export var dash_distance : float = 45
@export var dash_time : float = 0.12
@export var dash_cooldown : float = 0.25
var is_dashing : bool = false
var dash_timer : float = 0.0
var dash_direction : int = 1
var dash_cooldown_timer : float = 0.0
var dash_speed : float = 0.0
var dashes_used : int = 0
var max_air_dashes : int = 1
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
var sprint_momentum : bool = false
var target_speed : float = 1

# Slide
@export var slide_boost_multiplier : float = 1.7
@export var slide_duration : float = 0.9
@export var slide_decel : float = 5
var is_sliding : bool = false
var slide_timer : float = 0.0
var slide_direction : int = 0
var can_landing_slide : bool = false
var slide_has_bhop_boost : bool = false
var stored_slide_bhop_stacks : int = 0
var bhop_slide_buffer : int = 0
var bhop_slide_buffer_max : int = 5
var wants_landing_slide : bool = false
var last_slide_jump_stacks : int = 0

# Dive
@export var dive_speed : float = 165
var is_diving : bool = false

# Direction
@export var direction_switch_duration : float = 0.1
var facing : int = 1
var previous_facing : int = 1
var input_dir : int = 0
var velocity_dir : int = 1
var direction_switch_timer : float = 0.0

# Get the gravity from the project settings to be synced with RigidBody nodes
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _input(event):
	move_down_platform_input_and_action(event)
	dive_input(event)

func _physics_process(delta):
	dash_timer_check(delta)
	bhop_timer_check()
	landing_slide_input()
	handle_landing()
	ledge_fall_check()
	
	reset_on_player_touch_ground()
	handle_player_in_air()
	
	gravity_and_variable_timed_jumps(delta)
	
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
	
	if update_crouch_jump_lock():
		return
	
	handle_air_direction_penalty()
	calculate_target_speed()
	handle_ground_direction_switch(delta)

	handle_acceleration_air_ground(delta)
	apply_horizontal_velocity()
	
	move_and_slide()





# ---- Player Mechanics ---- 
func reset_on_player_touch_ground():
	if is_on_floor():
		jumps_used = 0
		did_double_jump = false
		dashes_used = 0
		locked_air_direction = 0
		last_slide_jump_stacks = 0
			
		if is_on_floor() and input_dir == 0 and !is_sliding:
			move_speed_current = 0.0

		is_crouch_jump = false
		
		if is_on_floor() and abs(move_speed_current) < 5:
			bhop_stacks = 0

func handle_player_in_air():
	if !is_on_floor():
		is_sliding = false

func move_down_platform_input_and_action(event):
	if event.is_action_pressed("move_down"):
		set_collision_mask_value(10, false)
	else:		
		set_collision_mask_value(10, true)

func dive_input(event):
	if event.is_action_pressed("move_down") and !is_on_floor():
		start_dive()

func dash_timer_check(delta):
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

func bhop_timer_check():
	if bhop_window_timer > 0:
		bhop_window_timer -= 1
	if bhop_slide_buffer > 0:
		bhop_slide_buffer -= 1

func handle_landing():
	if is_on_floor() and !was_on_floor:
		bhop_window_timer = bhop_window_frames
		
		if wants_landing_slide and !is_sliding and abs(velocity.x) > 100:
			if bhop_slide_buffer > 0:
				stored_slide_bhop_stacks = bhop_stacks
				slide_has_bhop_boost = stored_slide_bhop_stacks > 0
			else:
				stored_slide_bhop_stacks = 0
				slide_has_bhop_boost = false
			
			perform_landing_slide()
			bhop_slide_buffer = 0
	
	was_on_floor = is_on_floor()

func movement_left_right_input():
	direction = Input.get_axis("move_left", "move_right")
	input_dir = sign(direction)

func glide_input():
	if !is_on_floor() and velocity.y > 0 and Input.is_action_pressed("jump") and !is_diving and !is_dashing:
		is_gliding = true
		is_crouch_jump = false
		locked_air_direction = 0
	else:
		is_gliding = false

func dash_input():
	if Input.is_action_just_pressed("dash") and can_dash() and !is_crouching and !is_diving:
		start_dash()

func jump_input():
	if Input.is_action_just_pressed("jump"):
		if bhop_window_timer > 0 and abs(move_speed_current) > 50:
			bhop_stacks = min(bhop_stacks + 1, bhop_max_stacks)
			if !is_sliding:
				var stack_index = bhop_stacks - 1
				move_speed_current *= bhop_horizontal_boosts[stack_index]
				velocity.y *= bhop_vertical_boosts[stack_index]
		else:
			bhop_stacks = 0
		
		perform_jump()

func slide_input():
	if Input.is_action_just_pressed("crouch") and sprint_momentum and is_on_floor() and !is_sliding and abs(velocity.x) > 150:
		perform_slide()

func crouch_input():
	is_crouching = Input.is_action_pressed("crouch") and is_on_floor()

func sprint_input():
	if is_on_floor():
		sprint_momentum = (
			Input.is_action_pressed("sprint")
			and direction != 0
			and !is_crouching
		)

func gravity_and_variable_timed_jumps(delta):
	if !is_on_floor():
		if velocity.y < 0:
			if is_crouch_jump:
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

	if is_crouching and !is_sliding and is_on_floor():
		crouch_jump()
	elif is_sliding:
		slide_jump()

	velocity.y = jump_force
	jump_hold_timer = 0.0
	jumps_used += 1

	if jumps_used == 2:
		did_double_jump = true

		is_crouch_jump = false
		locked_air_direction = 0

func crouch_jump():
	if abs(move_speed_current) < 1:
		jump_force *= crouch_jump_multiplier
		is_crouch_jump = true

		locked_air_direction = -facing
		move_speed_current = base_speed * crouch_jump_back_boost
		velocity.x = locked_air_direction * move_speed_current
		horizontal_jump_override = true
	else:
		jump_force *= crouch_hop_multiplier

func slide_jump():
	if slide_has_bhop_boost and stored_slide_bhop_stacks > 0:
		var stack_index = stored_slide_bhop_stacks - 1
		
		move_speed_current *= bhop_horizontal_boosts[stack_index]
		velocity.y *= bhop_vertical_boosts[stack_index]

		last_slide_jump_stacks = stored_slide_bhop_stacks
	else:
		last_slide_jump_stacks = 0

	bhop_stacks = 0
	stored_slide_bhop_stacks = 0
	slide_has_bhop_boost = false

func ledge_fall_check():
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
	
	is_crouch_jump = false
	jump_hold_timer = max_jump_hold_time
	
	if !is_on_floor():
		dashes_used += 1

func finish_dash(delta):
	if is_dashing:
		dash_timer -= delta
		
		dash_motion = Vector2(dash_direction * dash_speed * delta, 0)
		move_and_collide(dash_motion)
		
		if dash_timer <= 0:
			is_dashing = false
			dash_cooldown_timer = dash_cooldown
			
			move_speed_current = target_speed
			locked_air_direction = dash_direction
		
		return

func can_dash() -> bool:
	if dash_cooldown_timer > 0:
		return false

	if is_on_floor():
		return true

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

	if slide_timer <= 0 or abs(move_speed_current) < 5 or !is_on_floor():
		is_sliding = false
	
	return true

func landing_slide_input():
	if !is_on_floor():
		wants_landing_slide = Input.is_action_pressed("crouch")
		
		if Input.is_action_just_pressed("crouch"):
			bhop_slide_buffer = bhop_slide_buffer_max

func perform_landing_slide():
	is_sliding = true
	slide_timer = slide_duration
	slide_direction = facing
	
	move_speed_current = max(abs(velocity.x), base_speed)
	move_speed_current *= slide_boost_multiplier

func start_dive():
	if is_on_floor():
		return
	
	is_diving = true

	is_sliding = false
	is_dashing = false
	is_gliding = false
	
	velocity.x = 0
	move_speed_current = 0

func finish_dive():
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

func handle_acceleration_air_ground(delta):
	if direction != 0:
		if is_on_floor():
			move_speed_current = lerpf(
				move_speed_current,
				target_speed,
				clamp(ground_accel * delta, 0.0, 1.0)
			)
		else:
			if !is_crouch_jump:
				air_control = air_control_when_change_direction

				if is_gliding:
					air_control = glide_walk_control

				if input_dir != 0:
					locked_air_direction = input_dir
					move_speed_current = lerpf(
						move_speed_current,
						base_speed,
						clamp(ground_accel * air_control * delta, 0.0, 1.0)
					)

		previous_facing = facing
		if !is_crouch_jump:
			facing = input_dir
	else:
		if is_on_floor():
			move_speed_current = lerpf(
				move_speed_current,
				0.0,
				clamp(ground_decel * delta, 0.0, 1.0)
			)

func apply_horizontal_velocity():
	if is_on_floor():
		velocity.x = facing * move_speed_current
	else:
		if locked_air_direction != 0:
			velocity.x = locked_air_direction * move_speed_current

# ---- Additional level mechanics ----
func teleport_to_location(new_location):
	position =  new_location
	camera.reset_smoothing()
