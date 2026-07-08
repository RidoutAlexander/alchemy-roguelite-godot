class_name RunManager
extends RefCounted

var current_level: int = 1
var difficulty_mode: int = GameDifficulty.Mode.HARD
var lives: int = GameConstants.STARTING_LIVES
var bonus_life_slot_unlocked: bool = false
var gold: int = 0
var boss_threshold_penalty: int = 0
var boss_threshold_discount: int = 0
var total_run_score: int = 0
var best_single_brew_this_run: int = 0
var deepest_level_reached: int = 0
var last_aura_id: String = ""
var locked_level_aura_id: String = ""
var locked_level_aura_level: int = 0
var current_aura: AuraData
var current_shop_offers: Array = []
var pending_boss_boom_berry_reward_ids: Array[String] = []
var pending_trinket_reward_ids: Array[String] = []
var pending_level_advance: bool = false
var free_shop_rerolls: int = 0
var pending_extra_mulligans: int = 0
var owned_trinket_ids: Array[String] = []

var bag := BagModel.new()
var brew_session: BrewSession

var _content: DefaultContent
var _aura_selector: AuraSelector
var _shop_service: ShopService


func find_ingredient(ingredient_id: String) -> IngredientData:
	return _content.find_ingredient(ingredient_id)


func find_trinket(trinket_id: String) -> TrinketData:
	return _content.find_trinket(trinket_id)


func get_owned_trinkets() -> Array[TrinketData]:
	var result: Array[TrinketData] = []
	var seen: Dictionary = {}
	for trinket_id in owned_trinket_ids:
		var normalized := _normalize_trinket_id(trinket_id)
		if normalized == "" or seen.has(normalized):
			continue
		seen[normalized] = true
		var trinket := find_trinket(normalized)
		if trinket != null:
			result.append(trinket)
	return result


func has_trinket(trinket_id: String) -> bool:
	var normalized := _normalize_trinket_id(trinket_id)
	return normalized != "" and normalized in owned_trinket_ids


func grant_trinket(trinket_id: String) -> bool:
	var normalized := _normalize_trinket_id(trinket_id)
	if normalized == "" or find_trinket(normalized) == null:
		return false
	if has_trinket(normalized):
		return false
	owned_trinket_ids.append(normalized)
	return true


func acquire_trinket(trinket_id: String) -> bool:
	var normalized := _normalize_trinket_id(trinket_id)
	if not grant_trinket(normalized):
		return false
	TrinketEffects.apply_acquire_effects(normalized, self)
	return true


func consume_trinket(trinket_id: String) -> bool:
	var normalized := _normalize_trinket_id(trinket_id)
	var index := owned_trinket_ids.find(normalized)
	if index < 0:
		return false
	owned_trinket_ids.remove_at(index)
	return true


func _init(content: DefaultContent) -> void:
	_content = content
	brew_session = BrewSession.new()
	brew_session.bind_ingredient_lookup(
		func(ingredient_id: String) -> IngredientData:
			return _content.find_ingredient(ingredient_id)
	)
	_aura_selector = AuraSelector.new(content)
	_shop_service = ShopService.new(content)


func start_new_run(difficulty: int = GameDifficulty.Mode.HARD) -> void:
	current_level = 1
	difficulty_mode = difficulty
	lives = GameConstants.STARTING_LIVES
	bonus_life_slot_unlocked = false
	gold = 0
	boss_threshold_penalty = 0
	boss_threshold_discount = 0
	total_run_score = 0
	best_single_brew_this_run = 0
	deepest_level_reached = 0
	last_aura_id = ""
	locked_level_aura_id = ""
	locked_level_aura_level = 0
	current_aura = null
	current_shop_offers.clear()
	pending_boss_boom_berry_reward_ids.clear()
	free_shop_rerolls = 0
	pending_extra_mulligans = 0
	owned_trinket_ids.clear()
	pending_trinket_reward_ids.clear()
	pending_level_advance = false
	bag.set_master_bag(_content.flatten_starter_bag())


func load_from_save(data: Dictionary) -> void:
	current_level = int(data.get("currentLevel", 1))
	difficulty_mode = GameDifficulty.from_save_value(data.get("difficulty", "hard"))
	lives = int(data.get("lives", GameConstants.STARTING_LIVES))
	bonus_life_slot_unlocked = bool(data.get("bonusLifeSlotUnlocked", false))
	gold = int(data.get("gold", 0))
	boss_threshold_penalty = int(
		data.get("bossThresholdPenalty", data.get("bossCarryoverScore", 0))
	)
	boss_threshold_discount = int(data.get("bossThresholdDiscount", 0))
	free_shop_rerolls = int(data.get("freeShopRerolls", 0))
	pending_extra_mulligans = int(data.get("pendingExtraMulligans", 0))
	total_run_score = int(data.get("totalRunScore", 0))
	best_single_brew_this_run = int(data.get("bestSingleBrewThisRun", 0))
	deepest_level_reached = int(data.get("deepestLevelReached", 0))
	last_aura_id = str(data.get("lastAuraId", ""))
	locked_level_aura_id = str(
		data.get("lockedLevelAuraId", data.get("lockedBossAuraId", ""))
	)
	locked_level_aura_level = int(
		data.get("lockedLevelAuraLevel", data.get("lockedBossAuraLevel", 0))
	)
	current_aura = _content.find_aura(str(data.get("currentAuraId", "")))
	owned_trinket_ids.clear()
	pending_trinket_reward_ids.clear()
	pending_level_advance = bool(data.get("pendingLevelAdvance", false))
	for trinket_id in data.get("ownedTrinketIds", []):
		grant_trinket(str(trinket_id))
	if has_trinket(TrinketEffects.BEATING_HEART_ID):
		bonus_life_slot_unlocked = true
	for trinket_id in data.get("pendingTrinketRewardIds", []):
		_append_unique_pending_trinket_offer(str(trinket_id))
	_sanitize_pending_trinket_reward_ids()
	var chips: Array[IngredientData] = []
	if data.has("bagChips"):
		for chip_data in data.get("bagChips", []):
			if typeof(chip_data) != TYPE_DICTIONARY:
				continue
			var chip := _content.create_bag_chip_from_save(chip_data)
			if chip != null:
				chips.append(chip)
	else:
		for ingredient_id in data.get("bagIngredientIds", []):
			var ingredient := _content.find_ingredient(str(ingredient_id))
			if ingredient != null:
				chips.append(ingredient.duplicate_for_bag())
	bag.set_master_bag(chips)
	current_shop_offers.clear()
	for offer_data in data.get("shopOffers", []):
		if offer_data == null:
			current_shop_offers.append(null)
			continue
		if typeof(offer_data) != TYPE_DICTIONARY:
			current_shop_offers.append(null)
			continue
		var ingredient := _content.find_ingredient(str(offer_data.get("ingredientId", "")))
		if ingredient == null:
			current_shop_offers.append(null)
			continue
		var offer := ShopService.ShopOffer.new()
		offer.ingredient = ingredient
		offer.price = int(offer_data.get("price", ingredient.shop_cost))
		_apply_shop_offer_modifiers(offer)
		current_shop_offers.append(offer)
	_sanitize_shop_offers()


func _sanitize_shop_offers() -> void:
	for slot_index in current_shop_offers.size():
		var offer = current_shop_offers[slot_index]
		if offer == null or offer.ingredient == null:
			continue
		if (
			offer.ingredient.is_legendary()
			and bag.has_master_ingredient(offer.ingredient.id)
		):
			current_shop_offers[slot_index] = null


func _apply_shop_offer_modifiers(offer) -> void:
	if offer == null or offer.ingredient == null:
		return
	offer.price = TrinketEffects.shop_price_for_ingredient(
		offer.ingredient,
		owned_trinket_ids
	)


func to_save_data() -> Dictionary:
	var shop_offers: Array = []
	for offer in current_shop_offers:
		if offer == null:
			shop_offers.append(null)
			continue
		shop_offers.append({
			"ingredientId": offer.ingredient.id,
			"price": offer.price,
		})
	return {
		"hasActiveRun": true,
		"currentLevel": current_level,
		"difficulty": GameDifficulty.to_save_value(difficulty_mode),
		"lives": lives,
		"bonusLifeSlotUnlocked": bonus_life_slot_unlocked,
		"gold": gold,
		"bossThresholdPenalty": boss_threshold_penalty,
		"bossThresholdDiscount": boss_threshold_discount,
		"freeShopRerolls": free_shop_rerolls,
		"pendingExtraMulligans": pending_extra_mulligans,
		"bagChips": bag.get_master_chip_save_data(),
		"lastAuraId": last_aura_id,
		"lockedLevelAuraId": locked_level_aura_id,
		"lockedLevelAuraLevel": locked_level_aura_level,
		"currentAuraId": current_aura.id if current_aura else "",
		"totalRunScore": total_run_score,
		"bestSingleBrewThisRun": best_single_brew_this_run,
		"deepestLevelReached": deepest_level_reached,
		"ownedTrinketIds": owned_trinket_ids.duplicate(),
		"pendingTrinketRewardIds": pending_trinket_reward_ids.duplicate(),
		"pendingLevelAdvance": pending_level_advance,
		"shopOffers": shop_offers,
	}


func get_upcoming_brew_level() -> int:
	if pending_level_advance:
		return current_level + 1
	return current_level


func ensure_aura_locked_for_upcoming_brew() -> AuraData:
	return _ensure_aura_locked_for_level(get_upcoming_brew_level())


func begin_brew() -> void:
	if not GameManager.may_enter_game_scene():
		push_error("begin_brew blocked until Ready is pressed on run prep")
		return
	current_aura = _pick_aura_for_brew()
	if current_aura != null:
		last_aura_id = current_aura.id
	var extra_mulligans := pending_extra_mulligans
	pending_extra_mulligans = 0
	brew_session.start_brew(
		current_level,
		current_aura,
		bag,
		0,
		boss_threshold_penalty,
		boss_threshold_discount,
		difficulty_mode,
		extra_mulligans,
		owned_trinket_ids.duplicate()
	)


func resolve_brew() -> Dictionary:
	var context := brew_session.context
	boss_threshold_discount += context.boss_threshold_discount_gained
	free_shop_rerolls += context.free_shop_rerolls_gained
	var gold_earned := brew_session.calculate_gold_reward()
	gold += gold_earned
	total_run_score += context.score
	best_single_brew_this_run = maxi(best_single_brew_this_run, context.score)
	var cleared := (
		context.outcome == BrewOutcome.Outcome.CLEARED
		or context.outcome == BrewOutcome.Outcome.BANKED
	)
	if cleared:
		deepest_level_reached = maxi(deepest_level_reached, current_level)
		_clear_locked_level_aura()
		if context.outcome == BrewOutcome.Outcome.BANKED:
			var leech_reduction := IngredientEffects.leech_boss_threshold_reduction(context)
			if leech_reduction <= 0:
				boss_threshold_penalty += maxi(0, context.threshold - context.score)
		elif GameConstants.is_boss_level(current_level):
			boss_threshold_penalty = 0
			boss_threshold_discount = 0
			_grant_boss_boom_berry_reward()
			_roll_trinket_reward_offers()
	else:
		var had_life := lives > 0
		lives = maxi(0, lives - 1)
		if had_life:
			gold += GameConstants.LIFE_LOSS_GOLD_GRANT
	pending_level_advance = cleared
	prepare_shop_for_current_level()
	return {
		"outcome": context.outcome,
		"score": context.score,
		"gold_earned": gold_earned,
		"cleared": cleared,
		"lives_remaining": lives,
	}


func leave_shop_after_clear() -> void:
	pending_level_advance = false
	current_level += 1
	prepare_shop_for_current_level()


func prepare_shop_for_current_level() -> void:
	current_shop_offers = _shop_service.generate_offers(
		current_level,
		gold,
		GameConstants.SHOP_SLOT_COUNT,
		owned_trinket_ids,
		bag
	)


func get_shop_reroll_cost() -> int:
	if free_shop_rerolls > 0:
		return 0
	return GameConstants.REROLL_COST


func get_shop_mulligan_cost() -> int:
	return GameConstants.SHOP_MULLIGAN_COST


func get_brew_mulligan_cost() -> int:
	return GameConstants.BREW_MULLIGAN_COST


func try_buy_brew_mulligan() -> bool:
	if gold < GameConstants.BREW_MULLIGAN_COST:
		return false
	if not brew_session.can_purchase_mulligan():
		return false
	gold -= GameConstants.BREW_MULLIGAN_COST
	brew_session.grant_purchased_mulligan()
	return true


func try_buy_shop_mulligan() -> bool:
	if gold < GameConstants.SHOP_MULLIGAN_COST:
		return false
	gold -= GameConstants.SHOP_MULLIGAN_COST
	pending_extra_mulligans += 1
	return true


func try_reroll_shop() -> bool:
	if free_shop_rerolls > 0:
		free_shop_rerolls = maxi(0, free_shop_rerolls - 1)
	elif gold < GameConstants.REROLL_COST:
		return false
	else:
		gold -= GameConstants.REROLL_COST
	current_shop_offers = _shop_service.generate_offers(
		current_level,
		gold,
		GameConstants.SHOP_SLOT_COUNT,
		owned_trinket_ids,
		bag
	)
	return true


func take_pending_boss_boom_berry_reward() -> Array[IngredientData]:
	if pending_boss_boom_berry_reward_ids.is_empty():
		return []
	var reward_ids := pending_boss_boom_berry_reward_ids.duplicate()
	pending_boss_boom_berry_reward_ids.clear()
	var rewards: Array[IngredientData] = []
	for berry_id in reward_ids:
		var ingredient := _content.find_ingredient(berry_id)
		if ingredient != null:
			rewards.append(ingredient)
	return rewards


func try_purchase_offer(index: int) -> bool:
	if index < 0 or index >= current_shop_offers.size():
		return false
	var offer = current_shop_offers[index]
	if offer == null:
		return false
	if gold < offer.price:
		return false
	if not bag.can_add_to_master_bag(offer.ingredient):
		return false
	gold -= offer.price
	bag.add_to_master_bag(offer.ingredient)
	current_shop_offers[index] = null
	return true


func _pick_aura_for_brew() -> AuraData:
	return _ensure_aura_locked_for_level(current_level)


func _ensure_aura_locked_for_level(level: int) -> AuraData:
	if locked_level_aura_level == level and locked_level_aura_id != "":
		var locked := _content.find_aura(locked_level_aura_id)
		if locked != null:
			return locked
	var picked := _aura_selector.pick_aura_for_level(level, last_aura_id)
	if picked != null:
		locked_level_aura_id = picked.id
		locked_level_aura_level = level
	return picked


func _grant_boss_boom_berry_reward() -> void:
	var reward_ids := GameConstants.boss_boom_berry_reward_ids(current_level)
	if reward_ids.is_empty():
		return
	var granted_ids: Array[String] = []
	for berry_id in reward_ids:
		var ingredient := _content.find_ingredient(berry_id)
		if ingredient == null:
			continue
		bag.add_to_master_bag(ingredient)
		granted_ids.append(berry_id)
	if granted_ids.is_empty():
		return
	pending_boss_boom_berry_reward_ids = granted_ids


func _clear_locked_level_aura() -> void:
	locked_level_aura_id = ""
	locked_level_aura_level = 0


func has_pending_trinket_reward() -> bool:
	return not pending_trinket_reward_ids.is_empty()


func get_pending_trinket_rewards() -> Array[TrinketData]:
	_sanitize_pending_trinket_reward_ids()
	var result: Array[TrinketData] = []
	var seen: Dictionary = {}
	for trinket_id in pending_trinket_reward_ids:
		var normalized := _normalize_trinket_id(trinket_id)
		if normalized == "" or seen.has(normalized) or has_trinket(normalized):
			continue
		seen[normalized] = true
		var trinket := find_trinket(normalized)
		if trinket != null:
			result.append(trinket)
	return result


func try_select_trinket_reward(trinket_id: String) -> bool:
	var normalized := _normalize_trinket_id(trinket_id)
	if normalized == "" or has_trinket(normalized):
		return false
	if normalized not in pending_trinket_reward_ids:
		return false
	if not acquire_trinket(normalized):
		return false
	pending_trinket_reward_ids.clear()
	return true


func _roll_trinket_reward_offers() -> void:
	pending_trinket_reward_ids.clear()
	var pool := _build_unowned_trinket_pool()
	pool.shuffle()
	var offer_count := mini(3, pool.size())
	for index in offer_count:
		_append_unique_pending_trinket_offer(pool[index])


func _normalize_trinket_id(trinket_id: String) -> String:
	return str(trinket_id).strip_edges()


func _build_unowned_trinket_pool() -> Array[String]:
	var pool: Array[String] = []
	var seen: Dictionary = {}
	for trinket in _content.all_trinkets():
		if trinket == null:
			continue
		var normalized := _normalize_trinket_id(trinket.id)
		if normalized == "" or seen.has(normalized) or has_trinket(normalized):
			continue
		if find_trinket(normalized) == null:
			continue
		if not trinket.reward_offerable:
			continue
		seen[normalized] = true
		pool.append(normalized)
	return pool


func _append_unique_pending_trinket_offer(trinket_id: String) -> bool:
	var normalized := _normalize_trinket_id(trinket_id)
	if normalized == "" or find_trinket(normalized) == null:
		return false
	if has_trinket(normalized) or normalized in pending_trinket_reward_ids:
		return false
	pending_trinket_reward_ids.append(normalized)
	return true


func _sanitize_pending_trinket_reward_ids() -> void:
	var sanitized: Array[String] = []
	for trinket_id in pending_trinket_reward_ids:
		var normalized := _normalize_trinket_id(trinket_id)
		if normalized == "" or find_trinket(normalized) == null:
			continue
		if has_trinket(normalized) or normalized in sanitized:
			continue
		sanitized.append(normalized)
	pending_trinket_reward_ids = sanitized