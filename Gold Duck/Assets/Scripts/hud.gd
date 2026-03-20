extends Control
class_name HUD

@export var energy_cell_label : Label
@export var portal_label : Label
@export var stopwatch_label : Label

var stopwatch : Stopwatch

func _ready() -> void:
	stopwatch = get_tree().get_first_node_in_group("stopwatch")
	
func _process(delta: float) -> void:
	update_stopwatch_label()
	
func update_stopwatch_label():
	stopwatch_label.text = stopwatch.time_to_string()

func update_energy_cell_label(number : int):
	energy_cell_label.text = "x " + str(number)
	
func portal_opened():
	portal_label.text = "Portal open!"

func portal_closed():
	portal_label.text = "Portal closed. Find 4 energy cells to open the portal!"
