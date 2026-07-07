class_name TrinketData
extends RefCounted

var id: String
var display_name: String
var description: String
var art: String


func _init(
	p_id: String,
	p_display_name: String,
	p_description: String,
	p_art: String = ""
) -> void:
	id = p_id
	display_name = p_display_name
	description = p_description
	art = p_art


func get_art_filename() -> String:
	if art.strip_edges() != "":
		return art.strip_edges()
	return id