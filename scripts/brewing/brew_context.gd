class_name BrewContext
extends RefCounted

var level: int
var threshold: int
var score: int
var explosiveness: int
var explosion_limit: int
var outcome: int = BrewOutcome.Outcome.IN_PROGRESS
var current_aura: AuraData
var bag: BagModel
var drawn_this_brew: Array[IngredientData] = []
var cauldron_contents: Array[IngredientData] = []
var ingredients_added_to_cauldron: int = 0
var gold_gained_this_brew: int = 0
var boss_threshold_discount_gained: int = 0
var free_shop_rerolls_gained: int = 0
var owned_trinket_ids: Array[String] = []


func is_boss_level() -> bool:
	return GameConstants.is_boss_level(level)


func can_end_brew() -> bool:
	if outcome != BrewOutcome.Outcome.IN_PROGRESS:
		return false
	if is_boss_level():
		return false
	return score > 0


func is_exploded() -> bool:
	return explosiveness >= explosion_limit