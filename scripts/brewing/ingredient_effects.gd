class_name IngredientEffects
extends RefCounted

const _AuraEffects := preload("res://scripts/brewing/aura_effects.gd")
const _HandPlayPreview := preload("res://scripts/brewing/hand_play_preview.gd")

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
const JAR_OF_DIRT_MAX_USES := 5
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
const POISON_APPLE_DELAY_HANDS := 1
const POISON_APPLE_EXPLOSIVENESS_GAIN := 3
const STIRRING_SPOON_BONUS_HAND_COUNT := 1
const JUGGLING_CLUB_BONUS_HAND_COUNT := 3
const NEWT_TAIL_ID := "newt_tail"
const CINNAMON_ID := "cinnamon"
const SAGE_ID := "sage"
const EYE_OF_ENDER_ID := "eye_of_ender"
const LUCKY_COIN_ID := "lucky_coin"
const HONEY_ID := "honey"

const LIGHTNING_CHAIN_DRAWS := 3
const RED_MUSHROOM_MAX_PRE_DOUBLE_SCORE := 4
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
	var cobbler_retroactive_slot: int = -1
	var cobbler_retroactive_score: int = 0
	var cobbler_retroactive_explosiveness: int = 0
	var cobbler_apply_retroactive_immediately: bool = false


static func apply(
	ingredient: IngredientData,
	context: BrewContext,
	hand_play: Dictionary = {}
) -> EffectResult:
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

	var play_slot := int(hand_play.get("play_slot", -1))
	if play_slot >= 0:
		var resolved := resolve_hand_play_cobbler(
			ingredient,
			context.cauldron_contents,
			play_slot,
			int(hand_play.get("last_hand_slot", -1)),
			hand_play.get("hand_slots", []),
			hand_play.get("last_hand_ingredient"),
			hand_play.get("locked_slots", {})
		)
		_apply_resolved_cobbler_bonus(ingredient, result, resolved)
	else:
		var previous = (
			context.cauldron_contents[-1] if not context.cauldron_contents.is_empty() else null
		)
		var cobbler_bonus := _cobbler_adjacency_bonus_between(previous, ingredient)
		if (
			ingredient.id == COBBLER_ID
			and previous != null
			and is_boom_berry_id(previous.id)
		):
			_queue_immediate_cobbler_retroactive(result, cobbler_bonus)
		else:
			result.bonus_score += int(cobbler_bonus.get("score", 0))
			result.bonus_explosiveness += int(cobbler_bonus.get("explosiveness", 0))
	context.cauldron_contents.append(ingredient)
	if not skips_hand_stay_interval_counter(ingredient):
		context.ingredients_added_to_cauldron += 1

	match ingredient.id:
		RED_MUSHROOM_ID:
			result.bonus_score = _red_mushroom_bonus_score(
				ingredient,
				context.cauldron_contents,
				context.owned_trinket_ids
			)
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
			result.bonus_score = _rat_streak_bonus(
				context.cauldron_contents,
				context.owned_trinket_ids
			)
		VOODOO_DOLL_ID:
			result.voodoo_doll_arms_copy = true
		THORNS_ID:
			result.bonus_score = maxi(0, context.explosiveness)
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

	result.bonus_score += _pumpkin_trinket_bonus_if_equipped(
		ingredient,
		context.cauldron_contents,
		context.owned_trinket_ids,
		true
	)

	var limit_bonus := explosion_limit_bonus_for_played_ingredient(
		ingredient,
		context.cauldron_contents
	)
	if limit_bonus > 0:
		result.explosion_limit_bonus = limit_bonus

	return result


static func is_feather_ingredient_id(ingredient_id: String) -> bool:
	var normalized := str(ingredient_id).to_lower()
	if normalized == FEATHER_ID:
		return true
	return normalized.begins_with("feather_") or "_feather" in normalized


static func is_feather_ingredient(ingredient: IngredientData) -> bool:
	return ingredient != null and is_feather_ingredient_id(ingredient.id)


static func is_pumpkin_like_id(ingredient_id: String) -> bool:
	var normalized := str(ingredient_id).to_lower()
	return normalized == PUMPKIN_ID or normalized == JACK_O_LANTERN_ID


static func is_pumpkin_ingredient(ingredient: IngredientData) -> bool:
	return ingredient != null and is_pumpkin_like_id(ingredient.id)


static func card_display_description(ingredient: IngredientData) -> String:
	if ingredient == null:
		return ""
	if ingredient.id != JAR_OF_DIRT_ID:
		return ingredient.description
	var uses_left := jar_of_dirt_uses_remaining(ingredient)
	return "%s\n%d uses left" % [ingredient.description, uses_left]


static func jar_of_dirt_uses_remaining(ingredient: IngredientData) -> int:
	if ingredient == null or ingredient.id != JAR_OF_DIRT_ID:
		return 0
	if ingredient.jar_of_dirt_uses_remaining >= 0:
		return ingredient.jar_of_dirt_uses_remaining
	return JAR_OF_DIRT_MAX_USES


static func explosion_limit_bonus_for_played_ingredient(
	ingredient: IngredientData,
	cauldron_contents_with_played: Array
) -> int:
	if ingredient == null:
		return 0
	match ingredient.id:
		HOLY_GRAIL_ID:
			return 1
		GARLIC_ID:
			if _count_ingredient_id(cauldron_contents_with_played, GARLIC_ID) <= 1:
				return 1
	return 0


static func is_boom_berry_id(ingredient_id: String) -> bool:
	return ingredient_id.begins_with("boom_berry")


static func resolve_hand_play_cobbler(
	ingredient: IngredientData,
	cauldron_contents: Array,
	play_slot: int,
	last_hand_slot: int,
	hand_slots: Array,
	last_hand_ingredient: Variant = null,
	locked_slots: Dictionary = {}
) -> Dictionary:
	var previous = cauldron_contents[-1] if not cauldron_contents.is_empty() else null
	var bonus := _cobbler_adjacency_bonus_between(previous, ingredient)
	if int(bonus.get("score", 0)) == 0 and int(bonus.get("explosiveness", 0)) == 0:
		return {"bonus": bonus, "retroactive_slot": -1}
	var target_slot := _cobbler_bonus_target_slot(
		ingredient,
		previous,
		play_slot,
		last_hand_slot,
		hand_slots,
		last_hand_ingredient,
		locked_slots
	)
	if target_slot < 0:
		if not locked_slots.is_empty():
			var blocked_slot := _hand_boom_berry_slot_immediately_left(
				hand_slots,
				play_slot,
				{}
			)
			if blocked_slot >= 0 and locked_slots.has(blocked_slot):
				return {"bonus": {"score": 0, "explosiveness": 0}, "retroactive_slot": -1}
		if ingredient.id == COBBLER_ID:
			var last_ingredient: IngredientData = last_hand_ingredient as IngredientData
			if (
				last_hand_slot >= 0
				and not locked_slots.has(last_hand_slot)
				and last_ingredient != null
				and is_boom_berry_id(last_ingredient.id)
			):
				return {"bonus": bonus, "retroactive_slot": last_hand_slot}
			return {"bonus": {"score": 0, "explosiveness": 0}, "retroactive_slot": -1}
		return {
			"bonus": bonus,
			"retroactive_slot": -1,
			"apply_retroactive_immediately": true,
		}
	if target_slot == play_slot:
		if is_boom_berry_id(ingredient.id):
			return {"bonus": bonus, "retroactive_slot": -1, "apply_to_current": true}
		return {"bonus": {"score": 0, "explosiveness": 0}, "retroactive_slot": -1}
	return {"bonus": bonus, "retroactive_slot": target_slot}


static func _apply_resolved_cobbler_bonus(
	ingredient: IngredientData,
	result: EffectResult,
	resolved: Dictionary
) -> void:
	var bonus: Dictionary = resolved.get("bonus", {})
	var retroactive_slot := int(resolved.get("retroactive_slot", -1))
	if retroactive_slot >= 0:
		result.cobbler_retroactive_slot = retroactive_slot
		result.cobbler_retroactive_score = int(bonus.get("score", 0))
		result.cobbler_retroactive_explosiveness = int(bonus.get("explosiveness", 0))
		return
	if bool(resolved.get("apply_retroactive_immediately", false)):
		_queue_immediate_cobbler_retroactive(result, bonus)
		return
	if not bool(resolved.get("apply_to_current", false)):
		return
	result.bonus_score += int(bonus.get("score", 0))
	result.bonus_explosiveness += int(bonus.get("explosiveness", 0))


static func _queue_immediate_cobbler_retroactive(
	result: EffectResult,
	bonus: Dictionary
) -> void:
	result.cobbler_apply_retroactive_immediately = true
	result.cobbler_retroactive_score = int(bonus.get("score", 0))
	result.cobbler_retroactive_explosiveness = int(bonus.get("explosiveness", 0))


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


static func _hand_boom_berry_slot_immediately_left(
	hand_slots: Array,
	slot_index: int,
	locked_slots: Dictionary = {}
) -> int:
	var left_slot := slot_index - 1
	while left_slot >= 0:
		if locked_slots.has(left_slot):
			left_slot -= 1
			continue
		if hand_slots[left_slot] != null:
			if is_boom_berry_id(hand_slots[left_slot].id):
				return left_slot
			return -1
		left_slot -= 1
	return -1


static func _cobbler_bonus_target_slot(
	ingredient: IngredientData,
	previous: IngredientData,
	play_slot: int,
	last_hand_slot: int,
	hand_slots: Array,
	last_hand_ingredient: Variant = null,
	locked_slots: Dictionary = {}
) -> int:
	if ingredient == null or previous == null:
		return -1 if ingredient != null and ingredient.id == COBBLER_ID else play_slot
	if ingredient.id == COBBLER_ID and is_boom_berry_id(previous.id):
		var left_slot := _hand_boom_berry_slot_immediately_left(
			hand_slots,
			play_slot,
			locked_slots
		)
		if left_slot >= 0:
			return left_slot
		var last_ingredient: IngredientData = last_hand_ingredient as IngredientData
		if (
			last_hand_slot >= 0
			and not locked_slots.has(last_hand_slot)
			and last_ingredient != null
			and is_boom_berry_id(last_ingredient.id)
		):
			return last_hand_slot
		return -1
	if ingredient.id == COBBLER_ID:
		return -1
	if locked_slots.has(play_slot):
		return -1
	return play_slot


static func _apply_retroactive_cobbler_bonus_to_slot(
	target_slot: int,
	cobbler_bonus: Dictionary,
	pre_double_stats: Array,
	display_stats: Array,
	unicorn_cured_slots: Dictionary = {}
) -> void:
	if target_slot < 0 or target_slot >= pre_double_stats.size():
		return
	var prior_stats: Variant = pre_double_stats[target_slot]
	if not prior_stats is Dictionary:
		return
	var bonus_score := int(cobbler_bonus.get("score", 0))
	var bonus_explosive := int(cobbler_bonus.get("explosiveness", 0))
	if unicorn_cured_slots.has(target_slot):
		bonus_explosive = 0
	if bonus_score == 0 and bonus_explosive == 0:
		return
	var old_prior_pv := int(prior_stats.get("point_value", 0))
	var old_prior_ev := int(prior_stats.get("explosive_value", 0))
	prior_stats["point_value"] = old_prior_pv + bonus_score
	prior_stats["explosive_value"] = old_prior_ev + bonus_explosive
	if target_slot >= display_stats.size():
		return
	var display_entry: Variant = display_stats[target_slot]
	if not display_entry is Dictionary:
		return
	var display_pv := int(display_entry.get("point_value", 0))
	var display_ev := int(display_entry.get("explosive_value", 0))
	if old_prior_pv > 0:
		display_entry["point_value"] = display_pv + int(
			round(float(bonus_score * display_pv) / float(old_prior_pv))
		)
	else:
		display_entry["point_value"] = display_pv + bonus_score
	if old_prior_ev > 0:
		display_entry["explosive_value"] = display_ev + int(
			round(float(bonus_explosive * display_ev) / float(old_prior_ev))
		)
	else:
		display_entry["explosive_value"] = display_ev + bonus_explosive


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
	var last_hand_ingredient: IngredientData = null
	var play_order: Array[int] = []
	for slot_index in range(hand_slots.size()):
		if hand_slots[slot_index] != null:
			play_order.append(slot_index)

	for play_slot in play_order:
		var ingredient: IngredientData = hand_slots[play_slot]
		var previous = sequence[-1] if not sequence.is_empty() else null
		var bonus := _cobbler_adjacency_bonus_between(previous, ingredient)
		if int(bonus.get("score", 0)) > 0 or int(bonus.get("explosiveness", 0)) > 0:
			var target_slot := _cobbler_bonus_target_slot(
				ingredient,
				previous,
				play_slot,
				last_hand_slot,
				hand_slots,
				last_hand_ingredient
			)
			if target_slot >= 0 and target_slot < bonuses.size():
				bonuses[target_slot]["score"] += int(bonus.get("score", 0))
				bonuses[target_slot]["explosiveness"] += int(bonus.get("explosiveness", 0))

		sequence.append(ingredient)
		last_hand_slot = play_slot
		last_hand_ingredient = ingredient

	return bonuses


static func compute_unicorn_cured_hand_slots(
	hand_slots: Array,
	cauldron_contents: Array,
	aura: AuraData,
	hand_slot_count: int = 5,
	growth_potion_doubles_remaining: int = 0,
	modifiers: Dictionary = {},
	severed_layout_slots: Array = []
) -> Array[int]:
	var cured_slots: Array[int] = []
	compute_hand_display_stats(
		hand_slots,
		cauldron_contents,
		aura,
		hand_slot_count,
		growth_potion_doubles_remaining,
		modifiers,
		severed_layout_slots,
		cured_slots
	)
	return cured_slots


static func compute_hand_display_stats(
	hand_slots: Array,
	cauldron_contents: Array,
	aura: AuraData,
	hand_slot_count: int = 5,
	growth_potion_doubles_remaining: int = 0,
	modifiers: Dictionary = {},
	severed_layout_slots: Array = [],
	unicorn_cured_slots: Variant = null
) -> Array:
	var display_stats: Array = []
	for _slot_index in hand_slot_count:
		display_stats.append(null)

	var severed_reference := (
		severed_layout_slots if not severed_layout_slots.is_empty() else hand_slots
	)
	var owned_trinket_ids: Array = modifiers.get("owned_trinket_ids", [])
	var play_steps := _HandPlayPreview.compute_steps(
		hand_slots,
		hand_slot_count,
		cauldron_contents,
		int(modifiers.get("ingredients_added_to_cauldron", 0)),
		owned_trinket_ids,
		aura,
		modifiers.get("honey_skipped_override", {}),
		modifiers.get("gecko_stayed_override", {}),
		bool(modifiers.get("parrot_doubles_next", false)),
		modifiers.get("bat_wing_pick_overrides", {})
	)

	var sim_cauldron: Array = cauldron_contents.duplicate()
	var doubles_remaining := growth_potion_doubles_remaining
	var parrot_doubles_next := bool(modifiers.get("parrot_doubles_next", false))
	var unicorn_cures_next := bool(modifiers.get("unicorn_cures_next", false))
	var ice_cube_shields := int(modifiers.get("ice_cube_shields", 0))
	var sim_explosiveness := int(modifiers.get("explosiveness", 0))
	var explosion_limit := int(modifiers.get("explosion_limit", GameConstants.DEFAULT_EXPLOSION_LIMIT))
	var last_hand_slot := -1
	var last_hand_ingredient: IngredientData = null
	var pre_double_stats: Array = []
	var unicorn_cured_slot_lookup: Dictionary = {}
	for _slot_index in hand_slot_count:
		pre_double_stats.append(null)

	for step in play_steps:
		if not bool(step.get("plays_to_cauldron", false)):
			continue
		var play_slot := int(step.get("slot_index", -1))
		if play_slot < 0 or play_slot >= hand_slots.size():
			continue
		var ingredient: IngredientData = step.get("ingredient")
		if ingredient == null:
			continue
		if (
			bool(step.get("parrot_repeat", false))
			or bool(step.get("feather_repeat", false))
			or bool(step.get("bat_wing_pick", false))
		):
			sim_cauldron.append(ingredient)
			if bool(step.get("bubbling_returns", false)):
				sim_cauldron.pop_back()
			last_hand_slot = play_slot
			last_hand_ingredient = ingredient
			if ingredient.id == PARROT_ID:
				parrot_doubles_next = true
			continue
		if ingredient.id == BAT_WING_ID:
			var bw_point := ingredient.point_value
			var bw_explosive := ingredient.explosive_value
			pre_double_stats[play_slot] = {
				"point_value": bw_point,
				"explosive_value": bw_explosive,
			}
			if doubles_remaining > 0:
				bw_point *= 2
				bw_explosive *= 2
				doubles_remaining -= 1
			if parrot_doubles_next:
				parrot_doubles_next = false
			if bool(step.get("in_rhythm_doubles", false)):
				bw_point *= 2
				bw_explosive *= 2
			if bool(step.get("pocket_watch_doubles", false)):
				bw_point *= 2
				bw_explosive *= 2
			var bw_explosive_add := bw_explosive
			if unicorn_cures_next:
				if bw_explosive_add > 0:
					bw_explosive_add = 0
					if unicorn_cured_slots is Array:
						unicorn_cured_slots.append(play_slot)
					unicorn_cured_slot_lookup[play_slot] = true
				unicorn_cures_next = false
			display_stats[play_slot] = {
				"point_value": bw_point,
				"explosive_value": bw_explosive_add,
			}
			sim_explosiveness += bw_explosive_add
			sim_cauldron.append(ingredient)
			last_hand_slot = play_slot
			last_hand_ingredient = ingredient
			continue
		var cauldron_count := int(step.get("cauldron_count_before", sim_cauldron.size()))
		if parrot_doubles_next:
			parrot_doubles_next = false
		var point_value := ingredient.point_value
		var explosive_value := ingredient.explosive_value

		if ingredient.id == SEVERED_RIGHT_HAND_ID:
			point_value += _count_hand_ingredients_to_left(severed_reference, play_slot)
		if ingredient.id == SEVERED_LEFT_HAND_ID:
			point_value += _count_hand_ingredients_to_right(severed_reference, play_slot)

		var previous = sim_cauldron[-1] if not sim_cauldron.is_empty() else null
		var cobbler_bonus := _cobbler_adjacency_bonus_between(previous, ingredient)
		if int(cobbler_bonus.get("score", 0)) > 0 or int(cobbler_bonus.get("explosiveness", 0)) > 0:
			var target_slot := _cobbler_bonus_target_slot(
				ingredient,
				previous,
				play_slot,
				last_hand_slot,
				hand_slots,
				last_hand_ingredient
			)
			if target_slot == play_slot and is_boom_berry_id(ingredient.id):
				point_value += int(cobbler_bonus.get("score", 0))
				explosive_value += int(cobbler_bonus.get("explosiveness", 0))
			elif target_slot >= 0:
				_apply_retroactive_cobbler_bonus_to_slot(
					target_slot,
					cobbler_bonus,
					pre_double_stats,
					display_stats,
					unicorn_cured_slot_lookup
				)

		var effect_bonuses := _preview_card_effect_bonuses(
			ingredient,
			sim_cauldron,
			sim_explosiveness,
			owned_trinket_ids
		)
		point_value += int(effect_bonuses.get("bonus_score", 0))
		explosive_value += int(effect_bonuses.get("bonus_explosiveness", 0))
		point_value -= int(effect_bonuses.get("score_penalty", 0))

		pre_double_stats[play_slot] = {
			"point_value": point_value,
			"explosive_value": explosive_value,
		}

		if doubles_remaining > 0:
			point_value *= 2
			explosive_value *= 2
			doubles_remaining -= 1
		if bool(step.get("in_rhythm_doubles", false)):
			point_value *= 2
			explosive_value *= 2
		if bool(step.get("pocket_watch_doubles", false)):
			point_value *= 2
			explosive_value *= 2

		var preview_cauldron := sim_cauldron.duplicate()
		preview_cauldron.append(ingredient)
		explosion_limit += explosion_limit_bonus_for_played_ingredient(
			ingredient,
			preview_cauldron
		)

		var explosive_add := explosive_value
		if unicorn_cures_next:
			if explosive_add > 0:
				explosive_add = 0
				if unicorn_cured_slots is Array:
					unicorn_cured_slots.append(play_slot)
				unicorn_cured_slot_lookup[play_slot] = true
			unicorn_cures_next = false
		if ice_cube_shields > 0:
			if (
				explosive_add > 0
				and sim_explosiveness + explosive_add >= explosion_limit
			):
				explosive_add = 0
			ice_cube_shields -= 1
		elif (
			ingredient.id == CHICKEN_ID
			and explosive_add > 0
			and sim_explosiveness + explosive_add >= explosion_limit
		):
			explosive_add = 0

		display_stats[play_slot] = {
			"point_value": point_value,
			"explosive_value": explosive_add,
		}

		sim_explosiveness += explosive_add
		sim_cauldron.append(ingredient)
		if bool(step.get("bubbling_returns", false)):
			sim_cauldron.pop_back()
		last_hand_slot = play_slot
		last_hand_ingredient = ingredient
		cauldron_count = sim_cauldron.size()
		if ingredient.id == PARROT_ID:
			parrot_doubles_next = true
		if ingredient.id == UNICORN_HORN_ID:
			unicorn_cures_next = true
		if ingredient.id == ICE_CUBE_ID:
			ice_cube_shields = ICE_CUBE_SHIELD_COUNT

	return display_stats


static func skips_hand_stay_interval_counter(ingredient: IngredientData) -> bool:
	return ingredient != null and ingredient.id == BAT_WING_ID


static func count_hand_stay_interval_plays(cauldron_contents: Array) -> int:
	var count := 0
	for entry in cauldron_contents:
		if entry == null or skips_hand_stay_interval_counter(entry):
			continue
		count += 1
	return count


static func count_trailing_pumpkin_streak(
	cauldron_contents: Array,
	exclude_last_entry: bool = false
) -> int:
	var streak := 0
	var last_index := cauldron_contents.size() - 1
	if exclude_last_entry:
		last_index -= 1
	for i in range(last_index, -1, -1):
		var entry = cauldron_contents[i]
		if entry != null and is_pumpkin_like_id(entry.id):
			streak += 1
		else:
			break
	return streak


static func _preview_card_effect_bonuses(
	ingredient: IngredientData,
	cauldron_contents: Array,
	explosiveness: int,
	owned_trinket_ids: Array = []
) -> Dictionary:
	var bonus_score := 0
	var bonus_explosiveness := 0
	var score_penalty := 0
	if ingredient == null:
		return {
			"bonus_score": bonus_score,
			"bonus_explosiveness": bonus_explosiveness,
			"score_penalty": score_penalty,
		}

	if ingredient.explosive_value > 0:
		bonus_score += _count_ingredient_id(cauldron_contents, NEWT_TAIL_ID)

	match ingredient.id:
		RED_MUSHROOM_ID:
			var preview_contents := cauldron_contents.duplicate()
			preview_contents.append(ingredient)
			bonus_score = _red_mushroom_bonus_score(
				ingredient,
				preview_contents,
				owned_trinket_ids
			)
		RAT_ID:
			# Hand preview simulates before the current card is appended, unlike play.
			bonus_score = mini(
				TrinketEffects.rat_streak_cap(owned_trinket_ids),
				count_trailing_rat_streak(cauldron_contents, false)
			)
		THORNS_ID:
			bonus_score = maxi(0, explosiveness)
		FISH_BONES_ID:
			score_penalty = 1
		_:
			pass

	bonus_score += _pumpkin_trinket_bonus_if_equipped(
		ingredient,
		cauldron_contents,
		owned_trinket_ids,
		false
	)

	return {
		"bonus_score": bonus_score,
		"bonus_explosiveness": bonus_explosiveness,
		"score_penalty": score_penalty,
	}


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


static func _rat_streak_bonus(
	contents: Array,
	owned_trinket_ids: Array = []
) -> int:
	return mini(
		TrinketEffects.rat_streak_cap(owned_trinket_ids),
		count_trailing_rat_streak(contents, true)
	)


static func count_trailing_rat_streak(
	cauldron_contents: Array,
	exclude_last_entry: bool = false
) -> int:
	var streak := 0
	var last_index := cauldron_contents.size() - 1
	if exclude_last_entry:
		last_index -= 1
	for i in range(last_index, -1, -1):
		var entry = cauldron_contents[i]
		if entry != null and entry.id == RAT_ID:
			streak += 1
		else:
			break
	return streak


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


static func _red_mushroom_bonus_score(
	ingredient: IngredientData,
	contents: Array,
	owned_trinket_ids: Array = []
) -> int:
	if ingredient == null:
		return 0
	var total_before_doubles := mini(
		TrinketEffects.red_mushroom_max_pre_double_score(owned_trinket_ids),
		ingredient.point_value + _count_pumpkin_like(contents)
	)
	return total_before_doubles - ingredient.point_value


static func _count_pumpkin_like(contents: Array) -> int:
	var count := 0
	for entry in contents:
		if entry == null:
			continue
		if is_pumpkin_like_id(entry.id):
			count += 1
	return count


static func _pumpkin_trinket_bonus_if_equipped(
	ingredient: IngredientData,
	cauldron_contents: Array,
	owned_trinket_ids: Array,
	exclude_last_entry: bool
) -> int:
	if not is_pumpkin_ingredient(ingredient):
		return 0
	if not TrinketEffects.has_pumpkin_trinket(owned_trinket_ids):
		return 0
	return TrinketEffects.pumpkin_trinket_bonus_score(
		cauldron_contents,
		exclude_last_entry
	)