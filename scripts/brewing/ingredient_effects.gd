class_name IngredientEffects
extends RefCounted

const LIGHTNING_ID := "lightning_in_a_bottle"
const EYEBALL_ID := "eyeball"
const RED_MUSHROOM_ID := "red_mushroom"
const PUMPKIN_ID := "pumpkin"
const JACK_O_LANTERN_ID := "jackolantern"
const UNICORN_HORN_ID := "unicorn_horn"
const PARROT_ID := "parrot"
const FEATHER_ID := "feather"
const MANDRAKE_ID := "mandrake"
const BAT_WING_ID := "bat_wing"
const SPIDER_ID := "spider"
const VOODOO_DOLL_ID := "voodoo_doll"
const FROG_LEG_ID := "frog_leg"
const PHOENIX_FEATHER_ID := "pheonix_feather"
const GLOOM_WEED_ID := "gloom_weed"
const LEECH_ID := "leech"
const THORNS_ID := "thorns"
const GARLIC_ID := "garlic"
const NEWT_TAIL_ID := "newt_tail"
const CINNAMON_ID := "cinnamon"
const SAGE_ID := "sage"

const LIGHTNING_CHAIN_DRAWS := 3
const RED_MUSHROOM_PUMPKIN_CAP := 3
const BAT_WING_PICK_COUNT := 3
const SPIDER_STREAK_CAP := 4


class EffectResult:
	var bonus_score: int = 0
	var chain_draws: int = 0
	var reserve_for_eyeball: int = 0
	var cures_next_explosive: bool = false
	var doubles_next_ingredient: bool = false
	var bonus_gold: int = 0
	var boss_threshold_discount: int = 0
	var explosion_limit_bonus: int = 0
	var bat_wing_pick_count: int = 0
	var voodoo_doll_arms_copy: bool = false
	var free_shop_rerolls: int = 0


static func apply(ingredient: IngredientData, context: BrewContext) -> EffectResult:
	var result := EffectResult.new()
	if ingredient == null or context == null:
		return result

	if ingredient.explosive_value > 0:
		var newt_tail_count := _count_ingredient_id(
			context.cauldron_contents,
			NEWT_TAIL_ID
		)
		if newt_tail_count > 0:
			result.bonus_score = newt_tail_count

	context.cauldron_contents.append(ingredient)

	match ingredient.id:
		RED_MUSHROOM_ID:
			var pumpkin_count := _count_pumpkin_like(context.cauldron_contents)
			result.bonus_score = mini(RED_MUSHROOM_PUMPKIN_CAP, pumpkin_count)
		LIGHTNING_ID:
			result.chain_draws = LIGHTNING_CHAIN_DRAWS
		EYEBALL_ID:
			result.reserve_for_eyeball = 3
		UNICORN_HORN_ID:
			result.cures_next_explosive = true
		PARROT_ID:
			result.doubles_next_ingredient = true
		FEATHER_ID:
			result.bonus_gold = 1
		MANDRAKE_ID:
			result.boss_threshold_discount = 1
		BAT_WING_ID:
			result.bat_wing_pick_count = BAT_WING_PICK_COUNT
		SPIDER_ID:
			result.bonus_score = _spider_streak_bonus(context.cauldron_contents)
		VOODOO_DOLL_ID:
			result.voodoo_doll_arms_copy = true
		THORNS_ID:
			result.bonus_score = maxi(0, context.explosiveness)
		GARLIC_ID:
			if _count_ingredient_id(context.cauldron_contents, GARLIC_ID) <= 1:
				result.explosion_limit_bonus = 1
		SAGE_ID:
			result.free_shop_rerolls = 1
		_:
			pass

	return result


static func _spider_streak_bonus(contents: Array) -> int:
	var streak := 0
	for i in range(contents.size() - 2, -1, -1):
		var entry = contents[i]
		if entry != null and entry.id == SPIDER_ID:
			streak += 1
		else:
			break
	return mini(SPIDER_STREAK_CAP, streak)


static func leech_boss_threshold_reduction(context: BrewContext) -> int:
	if context == null or context.score <= 0:
		return 0
	var leech_count := _count_ingredient_id(context.cauldron_contents, LEECH_ID)
	if leech_count <= 0:
		return 0
	return (context.score / 10) * leech_count


static func _count_ingredient_id(contents: Array, ingredient_id: String) -> int:
	var count := 0
	for entry in contents:
		if entry != null and entry.id == ingredient_id:
			count += 1
	return count


static func _count_pumpkin_like(contents: Array) -> int:
	var count := 0
	for entry in contents:
		if entry == null:
			continue
		if entry.id == PUMPKIN_ID or entry.id == JACK_O_LANTERN_ID:
			count += 1
	return count