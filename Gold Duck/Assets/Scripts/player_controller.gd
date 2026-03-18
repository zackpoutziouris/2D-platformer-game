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
var sprinting : bool = false
var target_speed = 1

# Slide
@export var slide_boost_multiplier := 2
@export var slide_duration := 0.5
@export var slide_decel := 5
var is_sliding := false
var slide_timer := 0.0
var slide_direction := 0

# Dive
@export var dive_speed := 600
var is_diving := false

# Direction
var facing := 1
var previous_facing := 1
var input_dir : int = 0.0
var velocity_dir : int = 1

# Get the gravity from the project settings to be synced with RigidBody nodes
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _input(event):
	drop_down_from_platform(event)

func _physics_process(delta):
	# ---- TIMERS ----
	update_dash_cooldown(delta)
	update_bhop_window()

	handle_bhop_landing()
	was_on_floor = is_on_floor()

	# ---- INPUT ----
	handle_horizontal_movement_input()
	update_sprint_state()

	handle_dash_input()
	handle_dive_input()
	handle_slide_input()
	handle_jump_input()
	
	update_crouch_state()

	# ---- STATE UPDATES ----
	update_jump_state()
	update_glide_state()

	# ---- HIGH PRIORITY ACTIONS ----
	if update_dash(delta):
		return
	
	if update_dive(delta):
		return

	# ---- PHYSICS ----
	apply_gravity(delta)

	# ---- GROUND RESETS ----
	handle_ground_resets()

	# ---- SLIDE ----
	if update_slide(delta):
		return

	# ---- SPECIAL LOCKS (CROUCH JUMP LOCKS HORIZONTAL MOVEMENT) ----
	if should_lock_crouch_jump():
		apply_crouch_jump_lock()
		return

	# ---- HORIZONTAL MOVEMENT AND ACCELERATION ----
	calculate_target_speed()
	handle_direction_switch()
	apply_horizontal_acceleration(delta)
	apply_horizontal_velocity()

	move_and_slide()





# ---- RESET FUNCTIONS WHEN TOUCHING THE GROUND ----
func handle_ground_resets():
	if !is_on_floor():
		return
	
	reset_dash_state()
	reset_air_direction()
	reset_crouch_jump_state()
	reset_double_jump_state()
	handle_bhop_reset()
	apply_ground_idle_stop()

func reset_air_direction():
	locked_air_direction = 0

func apply_ground_idle_stop():
	if input_dir == 0 and !is_sliding and move_speed_current > 5:
		move_speed_current *= 1.05
	if move_speed_current < 5:
		move_speed_current = 0

# ---- GRAVITY FUNCTIONS ----
func apply_gravity(delta):
	if is_on_floor():
		return
	
	if velocity.y < 0:
		apply_jump_gravity(delta)
	else:
		apply_fall_gravity(delta)

func apply_jump_gravity(delta):
	# Crouch jump ignores variable height
	if is_crouch_jump:
		velocity.y += gravity * delta
		return

	# Variable jump height (hold vs release)
	if Input.is_action_pressed("jump") and jump_hold_timer < max_jump_hold_time:
		velocity.y += gravity * jump_hold_gravity_scale * delta
		jump_hold_timer += delta
	else:
		velocity.y += gravity * jump_cut_gravity_scale * delta
		
func apply_fall_gravity(delta):
	velocity.y += gravity * delta
	apply_glide_effect()
	
# ---- DROP DOWN FROM PLATFORM FUNCTIONS ----
func drop_down_from_platform(event):
	# Handle jumping down from a see through platform utilizing masks
	if event.is_action_pressed("move_down"):
		set_collision_mask_value(10, false)
	else:		
		set_collision_mask_value(10, true)
	

# ---- GLIDE FUNCTIONS ----
func update_glide_state():
	if !is_on_floor() \
	and velocity.y > 0 \
	and Input.is_action_pressed("jump") \
	and !is_diving \
	and !is_dashing:
		
		is_gliding = true
		
		# preserve your current behaviour
		is_crouch_jump = false
		locked_air_direction = 0
	else:
		is_gliding = false

func apply_glide_effect():
	if !is_gliding:
		return
		
	if velocity.y > glide_fall_speed and velocity.y < fall_speed_limit_for_glide_to_work:
		velocity.y = glide_fall_speed

# ---- JUMP FUNCTIONS ----
func handle_jump_input():
	if !Input.is_action_just_pressed("jump"):
		return
	apply_bhop()
	apply_jump()

func apply_jump():
	if jumps_used >= max_jumps:
		return

	jump_force = jump_power * jump_multiplier
	var horizontal_jump_override := false

	# ----- CROUCH JUMP -----
	if try_crouch_jump():
		horizontal_jump_override = true

	# ----- SLIDE JUMP -----
	elif is_sliding:

		is_sliding = false
		locked_air_direction = slide_direction

	# ----- APPLY JUMP -----
	velocity.y = jump_force
	jump_hold_timer = 0.0
	jumps_used += 1

	# ----- DOUBLE JUMP -----
	if jumps_used == 2:
		did_double_jump = true
		
		# Release crouch jump directional lock
		is_crouch_jump = false
		locked_air_direction = 0

	# ensure slide/crouch states don't persist incorrectly
	is_sliding = false
	
	# ----- AIR HORIZONTAL PRESERVE -----
	if !horizontal_jump_override and !is_on_floor():
		if locked_air_direction != 0:
			velocity.x = locked_air_direction * move_speed_current
			
func update_jump_state():
	# Ledge fall counts as first jump
	if !is_on_floor() and jumps_used == 0:
		jumps_used = 1

func reset_double_jump_state():
	if is_on_floor():
		jumps_used = 0
		did_double_jump = false

# ---- CROUCH FUNCTIONS ----
func update_crouch_state():
	is_crouching = Input.is_action_pressed("crouch") and is_on_floor()

func try_crouch_jump() -> bool:
	if !is_crouching or is_sliding or !is_on_floor():
		return false
	
	# stationary crouch jump
	if abs(move_speed_current) < 1:
		jump_force *= crouch_jump_multiplier
		start_crouch_jump_back()
		return true
	
	# moving crouch hop
	jump_force *= crouch_hop_multiplier
	return false
	
func start_crouch_jump_back():
	is_crouch_jump = true
	
	locked_air_direction = -facing
	move_speed_current = base_speed * crouch_jump_back_boost
	velocity.x = locked_air_direction * move_speed_current

func should_lock_crouch_jump() -> bool:
	return is_crouch_jump and !is_on_floor()
	
func apply_crouch_jump_lock():
	velocity.x = locked_air_direction * move_speed_current
	move_and_slide()

func apply_crouch_speed(current_speed: float) -> float:
	if !is_crouching:
		return current_speed
	
	return current_speed * crouch_speed_multiplier

func reset_crouch_jump_state():
	if !is_crouch_jump:
		return
	
	# Hard stop horizontal momentum from a crouch jump
	velocity.x = 0.0
	move_speed_current = 0.0
	is_crouch_jump = false

# ---- SPRINT FUNCTIONS ----
func can_sprint() -> bool:
	return !is_crouching and is_on_floor()

func update_sprint_state():
	if can_sprint():
		sprinting = (
			Input.is_action_pressed("sprint")
			and direction != 0
		)
	else:
		sprinting = false

# ---- HORIZONTAL MOVEMENT FUNCTIONS ---- 
func handle_horizontal_movement_input():
	direction = Input.get_axis("move_left", "move_right")
	input_dir = signi(direction)
	
func calculate_target_speed():
	base_speed = speed * speed_multiplier
	target_speed = base_speed

	if is_crouching:
		target_speed = apply_crouch_speed(target_speed)
	elif sprinting:
		target_speed *= sprint_multiplier
		
func handle_direction_switch():
	velocity_dir = signi(velocity.x)

	# Ground switch
	if is_on_floor() and input_dir != 0 and velocity_dir != 0 and input_dir != velocity_dir:
		move_speed_current *= 0.25
		sprinting = false

	# Air switch penalty
	if !is_on_floor() and input_dir != 0 and input_dir != previous_facing:
		sprinting = false
		move_speed_current *= 0.35
		
func apply_horizontal_acceleration(delta):
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

func apply_horizontal_velocity():
	if is_on_floor():
		velocity.x = facing * move_speed_current
	else:
		if locked_air_direction != 0:
			velocity.x = locked_air_direction * move_speed_current

# ---- BHOP FUNCTIONS ----
func apply_bhop():
	if !can_bhop():
		reset_bhop()
		return
	
	increment_bhop_stack()
	apply_bhop_boosts()
	
func can_bhop() -> bool:
	return bhop_window_timer > 0 and abs(move_speed_current)> 5

func increment_bhop_stack():
	bhop_stacks = min(bhop_stacks + 1, bhop_max_stacks)

func apply_bhop_boosts():
	var stack_index = bhop_stacks - 1
	
	move_speed_current *= bhop_horizontal_boosts[stack_index]
	velocity.y *= bhop_vertical_boosts[stack_index]

func reset_bhop():
	bhop_stacks = 0

func update_bhop_window():
	if bhop_window_timer > 0:
		bhop_window_timer -= 1
		
func handle_bhop_landing():
	if is_on_floor() and !was_on_floor:
		bhop_window_timer = bhop_window_frames

func handle_bhop_reset():
	if is_on_floor() and abs(move_speed_current) < 5:
		bhop_stacks = 0

# ---- DASH FUNCTIONS ----
func handle_dash_input():
	if Input.is_action_just_pressed("dash") and can_dash() and !is_crouching and !is_diving:
		start_dash()

func update_dash(delta) -> bool:
	if !is_dashing:
		return false
	
	dash_timer -= delta
	dash_motion = Vector2(dash_direction * dash_speed * delta, 0)
	move_and_collide(dash_motion)
	
	if dash_timer <= 0:
		end_dash()
	
	return true

func update_dash_cooldown(delta):
	if dash_cooldown_timer > 0:
		dash_cooldown_timer -= delta

func end_dash():
	is_dashing = false
	dash_cooldown_timer = dash_cooldown

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

func reset_dash_state():
	dashes_used = 0

# ---- SLIDE FUNCTIONS ---- 
func handle_slide_input():
	if !Input.is_action_just_pressed("crouch"):
		return
		
	if can_start_slide():
		start_slide()

func can_start_slide() -> bool:
	return sprinting and is_on_floor() and !is_sliding and move_speed_current > 140

func start_slide():
	is_sliding = true
	slide_timer = slide_duration
	slide_direction = facing

	apply_slide_initial_boost()

func apply_slide_initial_boost():
	move_speed_current = max(move_speed_current, base_speed * sprint_multiplier)
	move_speed_current *= slide_boost_multiplier

func update_slide(delta) -> bool:
	if !is_sliding:
		return false
	
	apply_slide_physics(delta)
	
	if should_end_slide():
		end_slide()
	
	return true

func apply_slide_physics(delta):
	slide_timer -= delta

	apply_slide_deceleration(delta)
	apply_slide_velocity()
	
	move_and_slide()

func apply_slide_deceleration(delta):
	move_speed_current = lerpf(
		move_speed_current,
		0.0,
		clamp(slide_decel * delta, 0.0, 1.0)
	)
	
func apply_slide_velocity():
	velocity.x = slide_direction * move_speed_current

func should_end_slide() -> bool:
	return slide_timer <= 0 or abs(move_speed_current) < 5

func end_slide():
	is_sliding = false

# ---- DIVE FUNCTIONS ----
func handle_dive_input():
	if Input.is_action_just_pressed("move_down") and !is_on_floor() and !is_diving:
		start_dive()

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
	
func update_dive(delta)-> bool:
	if !is_diving:
		return false
	
	apply_dive_motion()
	move_and_slide()
	
	if should_end_dive():
		end_dive()
	
	return true
	
func apply_dive_motion():
	velocity.x = 0
	velocity.y = dive_speed
	
func should_end_dive() -> bool:
	return is_on_floor()

func end_dive():
	is_diving = false
	
 # ---- TP TO NEXT LEVEL FUNCTIONS ----
func teleport_to_location(new_location):
	position =  new_location
	camera.reset_smoothing()
