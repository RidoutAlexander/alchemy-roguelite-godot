class_name TrinketEffects
extends RefCounted

const PUMPKIN_TRINKET_ID := "pumpkin_trinket"
const RED_MUSHROOM_TRINKET_ID := "red_mushroom_trinket"
const RAT_TRINKET_ID := "rat_trinket"
const JAR_OF_FLIES_ID := "jar_of_flies"

const RED_MUSHROOM_BASE_MAX_PRE_DOUBLE_SCORE := 4
const RED_MUSHROOM_TRINKET_MAX_PRE_DOUBLE_SCORE := 6
const RAT_BASE_STREAK_CAP := 4
const RAT_TRINKET_STREAK_CAP := 6


static func has_trinket(trinket_ids: Array, trinket_id: String) -> bool:
	return trinket_id in trinket_ids


static func has_pumpkin_trinket(trinket_ids: Array) -> bool:
	return has_trinket(trinket_ids, PUMPKIN_TRINKET_ID)


static func has_red_mushroom_trinket(trinket_ids: Array) -> bool:
	return has_trinket(trinket_ids, RED_MUSHROOM_TRINKET_ID)


static func has_rat_trinket(trinket_ids: Array) -> bool:
	return has_trinket(trinket_ids, RAT_TRINKET_ID)


static func has_jar_of_flies(trinket_ids: Array) -> bool:
	return has_trinket(trinket_ids, JAR_OF_FLIES_ID)


static func pumpkin_trinket_bonus_score(
	cauldron_contents: Array,
	for_current_play: bool
) -> int:
	return IngredientEffects.count_trailing_pumpkin_streak(
		cauldron_contents,
		for_current_play
	)


static func red_mushroom_max_pre_double_score(trinket_ids: Array) -> int:
	if has_red_mushroom_trinket(trinket_ids):
		return RED_MUSHROOM_TRINKET_MAX_PRE_DOUBLE_SCORE
	return RED_MUSHROOM_BASE_MAX_PRE_DOUBLE_SCORE


static func rat_streak_cap(trinket_ids: Array) -> int:
	if has_rat_trinket(trinket_ids):
		return RAT_TRINKET_STREAK_CAP
	return RAT_BASE_STREAK_CAP