class_name TrinketData
extends RefCounted

var id: String
var display_name: String
var description: String
var art: String
var reward_offerable: bool = true


func _init(
	p_id: String,
	p_display_name: String,
	p_description: String,
	p_art: String = "",
	p_reward_offerable: bool = true
) -> void:
	id = p_id
	display_name = p_display_name
	description = p_description
	art = p_art
	reward_offerable = p_reward_offerable


func get_art_filename() -> String:
	if art.strip_edges() != "":
		return art.strip_edges()
	return id