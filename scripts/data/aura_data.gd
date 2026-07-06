class_name AuraData
extends RefCounted

enum Pool { NORMAL, BOSS }

var id: String
var display_name: String
var description: String
var pool: Pool
var pool_unlock_level: int
var explosion_limit_modifier: int
var score_multiplier_percent: int
var gold_multiplier_percent: int


func _init(
	p_id: String,
	p_name: String,
	p_desc: String,
	p_pool: Pool,
	p_pool_unlock_level: int,
	p_explosion_mod: int,
	p_score_mult: int,
	p_gold_mult: int
) -> void:
	id = p_id
	display_name = p_name
	description = p_desc
	pool = p_pool
	pool_unlock_level = maxi(1, p_pool_unlock_level)
	explosion_limit_modifier = p_explosion_mod
	score_multiplier_percent = p_score_mult
	gold_multiplier_percent = p_gold_mult