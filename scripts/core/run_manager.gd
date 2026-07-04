class_name RunManager
extends RefCounted

var current_level: int = 1
var difficulty_mode: int = GameDifficulty.Mode.HARD
var lives: int = GameConstants.STARTING_LIVES
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
var free_shop_rerolls: int = 0
var bag := BagModel.new()
var brew_session: BrewSession

var _content: DefaultContent
var _aura_selector: AuraSelector
var _shop_service: ShopService


func _init(content: DefaultContent) -> void:
	_content = content
	brew_session = BrewSession.new()
	_aura_selector = AuraSelector.new(content)
	_shop_service = ShopService.new(content)


func start_new_run(difficulty: int = GameDifficulty.Mode.HARD) -> void:
	current_level = 1
	difficulty_mode = difficulty
	lives = GameConstants.STARTING_LIVES
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
	bag.set_master_bag(_content.flatten_starter_bag())


func load_from_save(data: Dictionary) -> void:
	current_level = int(data.get("currentLevel", 1))
	difficulty_mode = GameDifficulty.from_save_value(data.get("difficulty", "hard"))
	lives = int(data.get("lives", GameConstants.STARTING_LIVES))
	gold = int(data.get("gold", 0))
	boss_threshold_penalty = int(
		data.get("bossThresholdPenalty", data.get("bossCarryoverScore", 0))
	)
	boss_threshold_discount = int(data.get("bossThresholdDiscount", 0))
	free_shop_rerolls = int(data.get("freeShopRerolls", 0))
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
	var chips: Array[IngredientData] = []
	for ingredient_id in data.get("bagIngredientIds", []):
		var ingredient := _content.find_ingredient(str(ingredient_id))
		if ingredient != null:
			chips.append(ingredient)
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
		current_shop_offers.append(offer)
	_strip_shadow_banned_shop_offers()


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
		"gold": gold,
		"bossThresholdPenalty": boss_threshold_penalty,
		"bossThresholdDiscount": boss_threshold_discount,
		"freeShopRerolls": free_shop_rerolls,
		"bagIngredientIds": bag.master_ids(),
		"lastAuraId": last_aura_id,
		"lockedLevelAuraId": locked_level_aura_id,
		"lockedLevelAuraLevel": locked_level_aura_level,
		"currentAuraId": current_aura.id if current_aura else "",
		"totalRunScore": total_run_score,
		"bestSingleBrewThisRun": best_single_brew_this_run,
		"deepestLevelReached": deepest_level_reached,
		"shopOffers": shop_offers,
	}


func begin_brew() -> void:
	current_aura = _pick_aura_for_brew()
	if current_aura != null:
		last_aura_id = current_aura.id
	brew_session.start_brew(
		current_level,
		current_aura,
		bag,
		0,
		boss_threshold_penalty,
		boss_threshold_discount,
		difficulty_mode
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
	else:
		var had_life := lives > 0
		lives = maxi(0, lives - 1)
		if had_life:
			gold += GameConstants.LIFE_LOSS_GOLD_GRANT
	prepare_shop_for_current_level()
	return {
		"outcome": context.outcome,
		"score": context.score,
		"gold_earned": gold_earned,
		"cleared": cleared,
		"lives_remaining": lives,
	}


func leave_shop_after_clear() -> void:
	current_level += 1
	prepare_shop_for_current_level()


func prepare_shop_for_current_level() -> void:
	current_shop_offers = _shop_service.generate_offers(
		current_level,
		gold,
		GameConstants.SHOP_SLOT_COUNT,
		bag.master_ids()
	)


func get_shop_reroll_cost() -> int:
	if free_shop_rerolls > 0:
		return 0
	return GameConstants.REROLL_COST


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
		bag.master_ids()
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
	_strip_shadow_banned_shop_offers()
	return true


func _pick_aura_for_brew() -> AuraData:
	if locked_level_aura_level == current_level and locked_level_aura_id != "":
		var locked := _content.find_aura(locked_level_aura_id)
		if locked != null:
			return locked
	var picked := _aura_selector.pick_aura_for_level(current_level, last_aura_id)
	if picked != null:
		locked_level_aura_id = picked.id
		locked_level_aura_level = current_level
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


func _strip_shadow_banned_shop_offers() -> void:
	if not bag.has_master_ingredient(IngredientEffects.UNICORN_HORN_ID):
		return
	for i in current_shop_offers.size():
		var offer = current_shop_offers[i]
		if offer == null:
			continue
		if offer.ingredient.id == IngredientEffects.UNICORN_HORN_ID:
			current_shop_offers[i] = null


func _clear_locked_level_aura() -> void:
	locked_level_aura_id = ""
	locked_level_aura_level = 0