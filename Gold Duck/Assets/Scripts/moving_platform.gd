extends Path2D
class_name MovingPlatform

@export var path_time = 1.0
@export var looping = false
@export var ease : Tween.EaseType
@export var transition : Tween.TransitionType
@export var path_follow_2D : PathFollow2D

# PLayer -> moving platform -> on leave to add the platforms velocity to the player
# In area scene, import moving platform, click Curve2D and then can move the path around, click on any point of the path to add a new point, right click to remove a point, 
# shift click to rotate a point, ctrl click to add more points in a path

func _ready():
	move_tween()
	
# Loops platform up and down over 1 second
func move_tween():
	var tween = get_tree().create_tween().set_loops()
	tween.tween_property(path_follow_2D, "progress_ratio", 1.0, path_time).set_ease(ease).set_trans(transition)
	if !looping:
		tween.tween_property(path_follow_2D, "progress_ratio", 0.0, path_time).set_ease(ease).set_trans(transition)
	else:
		tween.tween_property(path_follow_2D, "progress_ratio", 0.0, 0.0).set_ease(ease).set_trans(transition)
