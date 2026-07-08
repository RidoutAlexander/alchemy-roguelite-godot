extends SceneTree

## Run with:
## godot --headless --path "<project>" --script res://tools/verify_project_load.gd


func _init() -> void:
	var main_scene := load("res://scenes/main_menu.tscn")
	if main_scene == null:
		push_error("Failed to load main_menu.tscn")
		quit(1)
		return
	var card_scene := load("res://scenes/ui/ingredient_card.tscn")
	if card_scene == null:
		push_error("Failed to load ingredient_card.tscn")
		quit(1)
		return
	print("PASS: project scenes load without script errors")
	quit(0)