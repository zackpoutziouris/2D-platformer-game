extends Node
class_name Stopwatch

var time = 0.0
var stopped = false

func _ready() -> void:
	GameManager.area_started.connect(reset)

func _process(delta: float) -> void:
	if stopped: 
		return
	time += delta
	
func reset():
	time = 0.0
	
func time_to_string() -> String:
	# Turn the time var into a string for UI display
	var msec = fmod(time, 1) * 1000
	var sec = fmod(time, 60)
	var minutes = time / 60 
	# Format time to look like this: 00:00:000
	var format_string = "%02d : %02d : %02d"
	var actual_string = format_string % [minutes, sec, msec]
	return actual_string
