class_name IngredientEffects
extends RefCounted

const _AuraEffects := preload("res://scripts/brewing/aura_effects.gd")

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
const RAT_ID := "rat"
const SPIDER_ID := "spider"
const VOODOO_DOLL_ID := "voodoo_doll"
const FROG_LEG_ID := "frog_leg"
const PHOENIX_FEATHER_ID := "pheonix_feather"
const GLOOM_WEED_ID := "gloom_weed"
const LEECH_ID := "leech"
const THORNS_ID := "thorns"
const GARLIC_ID := "garlic"
const HOLY_GRAIL_ID := "holy_grail"
const ICE_CUBE_ID := "ice_cube"
const SHRUNKEN_HEAD_ID := "shrunken_head"
const JAR_OF_DIRT_ID := "jar_of_dirt"
const STIRRING_SPOON_ID := "stirring_spoon"
const JUGGLING_CLUB_ID := "juggling_club"
const FISH_BONES_ID := "fish_bones"
const FAIRY_IN_A_CAGE_ID := "fairy_in_a_cage"
const BOOBERRY_ID := "booberry"
const CHICKEN_ID := "chicken"
const POISON_APPLE_ID := "poison_apple"
const COBBLER_ID := "cobbler"
const GROWTH_POTION_ID := "growth_potion"
const SEVERED_RIGHT_HAND_ID := "severed_right_hand"
const SEVERED_LEFT_HAND_ID := "severed_left_hand"
const BOOBERRY_HAND_END_PENALTY := 2
const GROWTH_POTION_DOUBLE_COUNT := 4
const COBBLER_ADJACENT_BOOM_BERRY_SCORE := 10
const COBBLER_ADJACENT_BOOM_BERRY_EXPLOSIVENESS := 2
const POISON_APPLE_DELAY_HANDS := 2
const POISON_APPLE_EXPLOSIVENESS_GAIN := 3
const STIRRING_SPOON_BONUS_HAND_COUNT := 1
const JUGGLING_CLUB_BONUS_HAND_COUNT := 3
const NEWT_TAIL_ID := "newt_tail"
const CINNAMON_ID := "cinnamon"
const SAGE_ID := "sage"
const EYE_OF_ENDER_ID := "eye_of_ender"
const LUCKY_COIN_ID := "lucky_coin"

const LIGHTNING_CHAIN_DRAWS := 3
const RED_MUSHROOM_PUMPKIN_CAP := 3
const BAT_WING_PICK_COUNT := 3
const RAT_STREAK_CAP := 4
const ICE_CUBE_SHIELD_COUNT := 4
const SHRUNKEN_HEAD_HAND_SIZE := 4
const MANDRAKE_BOSS_THRESHOLD_DISCOUNT := 1
const LEECH_BOSS_THRESHOLD_PERCENT := 3


class EffectResult:
	var bonus_score: int = 0
	var score_penalty: int = 0
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
	var extra_mulligans: int = 0
	var ice_cube_shields: int = 0
	var next_hand_draw_count: int = 0
	var bag_grant_ingredient_id: String = ""
	var bonus_swap_hands: int = 0
	var vanish_next_ingredient: bool = false
	var poison_apple_delay_scheduled: bool = false
	var bonus_explosiveness: int = 0
	var growth_potion_doubles: int = 0


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

	var cobbler_bonus := _cobbler_adjacency_bonus_between(
		context.cauldron_contents[-1] if not context.cauldron_contents.is_empty() else null,
		ingredient
	)
	result.bonus_score += int(cobbler_bonus.get("score", 0))
	result.bonus_explosiveness += int(cobbler_bonus.get("explosiveness", 0))
	context.cauldron_contents.append(ingredient)

	match ingredient.id:
		RED_MUSHROOM_ID:
			var pumpkin_count := _count_pumpkin_like(context.cauldron_contents)
			result.bonus_score = mini(RED_MUSHROOM_PUMPKIN_CAP, pumpkin_count)
		LIGHTNING_ID:
			result.chain_draws = LIGHTNING_CHAIN_DRAWS
		EYEBALL_ID:
			result.reserve_for_eyeball = 5
		UNICORN_HORN_ID:
			result.cures_next_explosive = true
		PARROT_ID:
			result.doubles_next_ingredient = true
		FEATHER_ID:
			result.bonus_gold = 1
		MANDRAKE_ID:
			result.boss_threshold_discount = MANDRAKE_BOSS_THRESHOLD_DISCOUNT
		BAT_WING_ID:
			result.bat_wing_pick_count = BAT_WING_PICK_COUNT
		RAT_ID:
			result.bonus_score = _rat_streak_bonus(context.cauldron_contents)
		VOODOO_DOLL_ID:
			result.voodoo_doll_arms_copy = true
		THORNS_ID:
			result.bonus_score = maxi(0, context.explosiveness)
		GARLIC_ID:
			if _count_ingredient_id(context.cauldron_contents, GARLIC_ID) <= 1:
				result.explosion_limit_bonus = 1
		HOLY_GRAIL_ID:
			result.explosion_limit_bonus = 1
		ICE_CUBE_ID:
			result.ice_cube_shields = ICE_CUBE_SHIELD_COUNT
		SHRUNKEN_HEAD_ID:
			result.next_hand_draw_count = SHRUNKEN_HEAD_HAND_SIZE
		JAR_OF_DIRT_ID:
			result.bag_grant_ingredient_id = PUMPKIN_ID
		STIRRING_SPOON_ID:
			result.bonus_swap_hands = STIRRING_SPOON_BONUS_HAND_COUNT
		JUGGLING_CLUB_ID:
			result.bonus_swap_hands = JUGGLING_CLUB_BONUS_HAND_COUNT
		FISH_BONES_ID:
			result.score_penalty = 1
			result.bonus_gold = 2
		FAIRY_IN_A_CAGE_ID:
			result.vanish_next_ingredient = true
		POISON_APPLE_ID:
			result.poison_apple_delay_scheduled = true
		GROWTH_POTION_ID:
			result.growth_potion_doubles = GROWTH_POTION_DOUBLE_COUNT
		SAGE_ID:
			result.free_shop_rerolls = 1
		EYE_OF_ENDER_ID:
			result.extra_mulligans = 1
		_:
			pass

	return result


static func is_boom_berry_id(ingredient_id: String) -> bool:
	return ingredient_id.begins_with("boom_berry")


static func _cobbler_adjacency_bonus_between(
	previous: IngredientData,
	ingredient: IngredientData
) -> Dictionary:
	if previous == null or ingredient == null:
		return {"score": 0, "explosiveness": 0}
	if is_boom_berry_id(ingredient.id) and previous.id == COBBLER_ID:
		return {
			"score": COBBLER_ADJACENT_BOOM_BERRY_SCORE,
			"explosiveness": COBBLER_ADJACENT_BOOM_BERRY_EXPLOSIVENESS,
		}
	if ingredient.id == COBBLER_ID and is_boom_berry_id(previous.id):
		return {
			"score": COBBLER_ADJACENT_BOOM_BERRY_SCORE,
			"explosiveness": COBBLER_ADJACENT_BOOM_BERRY_EXPLOSIVENESS,
		}
	return {"score": 0, "explosiveness": 0}


static func compute_hand_cobbler_bonuses(
	hand_slots: Array,
	cauldron_contents: Array,
	hand_slot_count: int = 5
) -> Array:
	var bonuses: Array = []
	for _slot_index in hand_slot_count:
		bonuses.append({"score": 0, "explosiveness": 0})

	var sequence: Array = cauldron_contents.duplicate()
	var last_hand_slot := -1
	var play_order: Array[int] = []
	for slot_index in range(hand_slots.size()):
		if hand_slots[slot_index] != null:
			play_order.append(slot_index)

	for play_slot in play_order:
		var ingredient: IngredientData = hand_slots[play_slot]
		var previous = sequence[-1] if not sequence.is_empty() else null
		var bonus := _cobbler_adjacency_bonus_between(previous, ingredient)
		if int(bonus.get("score", 0)) > 0 or int(bonus.get("explosiveness", 0)) > 0:
			var target_slot := play_slot
			if ingredient.id == COBBLER_ID and is_boom_berry_id(previous.id):
				if last_hand_slot >= 0 and is_boom_berry_id(hand_slots[last_hand_slot].id):
					target_slot = last_hand_slot
				else:
					target_slot = -1
			if target_slot >= 0 and target_slot < bonuses.size():
				bonuses[target_slot]["score"] += int(bonus.get("score", 0))
				bonuses[target_slot]["explosiveness"] += int(bonus.get("explosiveness", 0))

		sequence.append(ingredient)
		last_hand_slot = play_slot

	return bonuses


static func compute_hand_display_stats(
	hand_slots: Array,
	cauldron_contents: Array,
	aura: AuraData,
	hand_slot_count: int = 5,
	growth_potion_doubles_remaining: int = 0
) -> Array:
	var cobbler_bonuses := compute_hand_cobbler_bonuses(
		hand_slots,
		cauldron_contents,
		hand_slot_count
	)
	var display_stats: Array = []
	for _slot_index in hand_slot_count:
		display_stats.append(null)

	var play_order: Array[int] = []
	for slot_index in range(hand_slots.size()):
		if hand_slots[slot_index] != null:
			play_order.append(slot_index)

	var cauldron_count := cauldron_contents.size()
	var doubles_remaining := growth_potion_doubles_remaining
	for play_index in play_order.size():
		var play_slot: int = play_order[play_index]
		var ingredient: IngredientData = hand_slots[play_slot]
		var point_value := ingredient.point_value
		var explosive_value := ingredient.explosive_value
		if doubles_remaining > 0:
			point_value *= 2
			explosive_value *= 2
			doubles_remaining -= 1
		if _AuraEffects.in_rhythm_doubles_ingredient(cauldron_count, aura):
			point_value *= 2
			explosive_value *= 2
		if ingredient.id == SEVERED_RIGHT_HAND_ID:
			point_value += _count_hand_ingredients_to_left(hand_slots, play_slot)
		if ingredient.id == SEVERED_LEFT_HAND_ID:
			point_value += _count_hand_ingredients_to_right(hand_slots, play_slot)
		if play_slot < cobbler_bonuses.size():
			var bonus: Dictionary = cobbler_bonuses[play_slot]
			point_value += int(bonus.get("score", 0))
			explosive_value += int(bonus.get("explosiveness", 0))
		display_stats[play_slot] = {
			"point_value": point_value,
			"explosive_value": explosive_value,
		}
		cauldron_count += 1

	return display_stats


static func _count_hand_ingredients_to_left(hand_slots: Array, slot_index: int) -> int:
	var count := 0
	for i in range(slot_index):
		if i < hand_slots.size() and hand_slots[i] != null:
			count += 1
	return count


static func _count_hand_ingredients_to_right(hand_slots: Array, slot_index: int) -> int:
	var count := 0
	for i in range(slot_index + 1, hand_slots.size()):
		if hand_slots[i] != null:
			count += 1
	return count


static func _rat_streak_bonus(contents: Array) -> int:
	var streak := 0
	for i in range(contents.size() - 2, -1, -1):
		var entry = contents[i]
		if entry != null and entry.id == RAT_ID:
			streak += 1
		else:
			break
	return mini(RAT_STREAK_CAP, streak)


static func leech_boss_threshold_reduction(context: BrewContext) -> int:
	if context == null or context.score <= 0:
		return 0
	var leech_count := _count_ingredient_id(context.cauldron_contents, LEECH_ID)
	if leech_count <= 0:
		return 0
	return context.score * LEECH_BOSS_THRESHOLD_PERCENT * leech_count / 100


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