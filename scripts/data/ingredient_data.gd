class_name IngredientData
extends RefCounted

enum Rarity { COMMON, UNCOMMON, RARE, EPIC, LEGENDARY }

var id: String
var art: String = ""
var display_name: String
var description: String
var point_value: int
var explosive_value: int
var shop_cost: int
var rarity: Rarity
var shop_available: bool = true


func _init(
	p_id: String,
	p_name: String,
	p_desc: String,
	p_points: int,
	p_explosive: int,
	p_cost: int,
	p_rarity: Rarity,
	p_shop_available: bool = true,
	p_art: String = ""
) -> void:
	id = p_id
	art = p_art
	display_name = p_name
	description = p_desc
	point_value = p_points
	explosive_value = p_explosive
	shop_cost = p_cost
	rarity = p_rarity
	shop_available = p_shop_available


func get_art_filename() -> String:
	return art if art != "" else id


func apply_on_draw(_context: BrewContext) -> void:
	pass