class_name TrinketEffects
extends RefCounted

const PUMPKIN_TRINKET_ID := "pumpkin_trinket"
const RED_MUSHROOM_TRINKET_ID := "red_mushroom_trinket"
const RAT_TRINKET_ID := "rat_trinket"
const JAR_OF_FLIES_ID := "jar_of_flies"
const POCKET_WATCH_ID := "pocket_watch"
const TIME_TURNER_ID := "time_turner"
const JAR_OF_FROGLEGS_ID := "jar_of_froglegs"
const VOODOO_DOLL_TRINKET_ID := "voodoo_doll_trinket"
const PRISTINE_FEATHER_ID := "pristine_feather"
const BEATING_HEART_ID := "beating_heart"
const BEATING_HEART_BOOM_BERRY_ID := "boom_berry_3"
const GECKO_ASSISTANT_ID := "gecko_assistant"

const POCKET_WATCH_INTERVAL := 21
const GECKO_ASSISTANT_INTERVAL := 9
const VOODOO_DOLL_TRINKET_SHOP_COST := 6

const RED_MUSHROOM_BASE_MAX_PRE_DOUBLE_SCORE := 4
const RED_MUSHROOM_TRINKET_MAX_PRE_DOUBLE_SCORE := 6
const PUMPKIN_TRINKET_STREAK_CAP := 3
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


static func has_pocket_watch(trinket_ids: Array) -> bool:
	return has_trinket(trinket_ids, POCKET_WATCH_ID)


static func has_time_turner(trinket_ids: Array) -> bool:
	return has_trinket(trinket_ids, TIME_TURNER_ID)


static func has_jar_of_froglegs(trinket_ids: Array) -> bool:
	return has_trinket(trinket_ids, JAR_OF_FROGLEGS_ID)


static func has_voodoo_doll_trinket(trinket_ids: Array) -> bool:
	return has_trinket(trinket_ids, VOODOO_DOLL_TRINKET_ID)


static func has_pristine_feather(trinket_ids: Array) -> bool:
	return has_trinket(trinket_ids, PRISTINE_FEATHER_ID)


static func has_beating_heart(trinket_ids: Array) -> bool:
	return has_trinket(trinket_ids, BEATING_HEART_ID)


static func has_gecko_assistant(trinket_ids: Array) -> bool:
	return has_trinket(trinket_ids, GECKO_ASSISTANT_ID)


static func apply_acquire_effects(trinket_id: String, run: RunManager) -> void:
	if run == null:
		return
	if trinket_id == BEATING_HEART_ID:
		run.bonus_life_slot_unlocked = true
		run.lives = mini(GameConstants.MAX_LIVES, run.lives + 1)
		var boom_berry := run.find_ingredient(BEATING_HEART_BOOM_BERRY_ID)
		if boom_berry != null:
			run.bag.add_to_master_bag(boom_berry)


static func feather_plays_twice(ingredient: IngredientData, trinket_ids: Array) -> bool:
	return (
		IngredientEffects.is_feather_ingredient(ingredient)
		and has_pristine_feather(trinket_ids)
	)


static func shop_price_for_ingredient(ingredient: IngredientData, trinket_ids: Array) -> int:
	if ingredient == null:
		return 0
	if (
		has_voodoo_doll_trinket(trinket_ids)
		and ingredient.id == IngredientEffects.VOODOO_DOLL_ID
	):
		return VOODOO_DOLL_TRINKET_SHOP_COST
	return ingredient.shop_cost


static func shop_rarity_for_ingredient(
	ingredient: IngredientData,
	trinket_ids: Array
) -> IngredientData.Rarity:
	if ingredient == null:
		return IngredientData.Rarity.COMMON
	if (
		has_voodoo_doll_trinket(trinket_ids)
		and ingredient.id == IngredientEffects.VOODOO_DOLL_ID
	):
		return IngredientData.Rarity.COMMON
	return ingredient.rarity


static func pocket_watch_doubles_ingredient(
	cauldron_count_before_add: int,
	trinket_ids: Array
) -> bool:
	if not has_pocket_watch(trinket_ids):
		return false
	var count_after := cauldron_count_before_add + 1
	return count_after % POCKET_WATCH_INTERVAL == 0


static func pocket_watch_countdown(cauldron_count: int, trinket_ids: Array) -> int:
	if not has_pocket_watch(trinket_ids):
		return 0
	var remainder := cauldron_count % POCKET_WATCH_INTERVAL
	if remainder == 0:
		return POCKET_WATCH_INTERVAL
	return POCKET_WATCH_INTERVAL - remainder


static func gecko_assistant_stays_in_hand(
	cauldron_count_before_add: int,
	trinket_ids: Array,
	stays_consumed_this_hand: int = 0
) -> bool:
	if not has_gecko_assistant(trinket_ids):
		return false
	var effective_count := cauldron_count_before_add + stays_consumed_this_hand
	var count_after := effective_count + 1
	return count_after % GECKO_ASSISTANT_INTERVAL == 0


static func gecko_assistant_countdown(cauldron_count: int, trinket_ids: Array) -> int:
	if not has_gecko_assistant(trinket_ids):
		return 0
	var remainder := cauldron_count % GECKO_ASSISTANT_INTERVAL
	if remainder == 0:
		return GECKO_ASSISTANT_INTERVAL
	return GECKO_ASSISTANT_INTERVAL - remainder


static func pumpkin_trinket_bonus_score(
	cauldron_contents: Array,
	for_current_play: bool
) -> int:
	return mini(
		PUMPKIN_TRINKET_STREAK_CAP,
		IngredientEffects.count_trailing_pumpkin_streak(
			cauldron_contents,
			for_current_play
		)
	)


static func pumpkin_trinket_buff_streak(cauldron_contents: Array) -> int:
	return mini(
		PUMPKIN_TRINKET_STREAK_CAP,
		IngredientEffects.count_trailing_pumpkin_streak(cauldron_contents, false)
	)


static func red_mushroom_max_pre_double_score(trinket_ids: Array) -> int:
	if has_red_mushroom_trinket(trinket_ids):
		return RED_MUSHROOM_TRINKET_MAX_PRE_DOUBLE_SCORE
	return RED_MUSHROOM_BASE_MAX_PRE_DOUBLE_SCORE


static func rat_streak_cap(trinket_ids: Array) -> int:
	if has_rat_trinket(trinket_ids):
		return RAT_TRINKET_STREAK_CAP
	return RAT_BASE_STREAK_CAP