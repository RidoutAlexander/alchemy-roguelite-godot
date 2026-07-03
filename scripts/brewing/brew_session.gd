class_name BrewSession
extends RefCounted

const _AuraEffects := preload("res://scripts/brewing/aura_effects.gd")

signal brew_updated(context: BrewContext)
signal ingredient_drawn(context: BrewContext, ingredient: IngredientData)
signal frog_leg_escaped(ingredient: IngredientData)
signal eyeball_puzzle_requested(reserved: Array)
signal bat_wing_picker_requested(choices: Array)

var context := BrewContext.new()

var _chain_draws_remaining: int = 0
var _ambidextrous_draw_pending: bool = false
var _eyeball_reserved: Array[IngredientData] = []
var _eyeball_puzzle_active: bool = false
var _bat_wing_choices: Array[IngredientData] = []
var _bat_wing_picker_active: bool = false
var _unicorn_cures_next_explosive: bool = false
var _parrot_doubles_next: bool = false
var _voodoo_doll_arms_copy: bool = false
var _practice_restart_used: bool = false
var _frog_leg_save_pending: bool = false


func start_brew(
	level: int,
	aura: AuraData,
	bag: BagModel,
	explosion_limit_bonus: int = 0,
	boss_threshold_penalty: int = 0,
	boss_threshold_discount: int = 0,
	difficulty: int = GameDifficulty.Mode.HARD
) -> void:
	context.level = level
	var base_threshold := ThresholdCalculator.get_threshold_for_level(level, difficulty)
	context.threshold = base_threshold
	if GameConstants.is_boss_level(level):
		context.threshold += maxi(0, boss_threshold_penalty)
		context.threshold = maxi(0, context.threshold - maxi(0, boss_threshold_discount))
	context.threshold = _AuraEffects.apply_threshold_modifier(context.threshold, aura)
	context.current_aura = aura
	context.bag = bag
	context.score = 0
	context.explosiveness = 0
	context.explosion_limit = GameConstants.DEFAULT_EXPLOSION_LIMIT + explosion_limit_bonus
	if aura != null:
		context.explosion_limit += aura.explosion_limit_modifier
	context.outcome = BrewOutcome.Outcome.IN_PROGRESS
	context.drawn_this_brew.clear()
	context.cauldron_contents.clear()
	context.gold_gained_this_brew = 0
	context.boss_threshold_discount_gained = 0
	context.free_shop_rerolls_gained = 0
	_practice_restart_used = false
	_reset_draw_flow_state()
	bag.reset_for_brew(true)
	brew_updated.emit(context)


func can_practice_restart() -> bool:
	if _practice_restart_used:
		return false
	if context.outcome != BrewOutcome.Outcome.IN_PROGRESS:
		return false
	if context.is_exploded():
		return false
	if context.current_aura == null:
		return false
	return context.current_aura.id == GameConstants.PRACTICE_BREW_AURA_ID


func try_practice_restart() -> bool:
	if not can_practice_restart():
		return false
	_practice_restart_used = true
	context.score = 0
	context.explosiveness = 0
	context.drawn_this_brew.clear()
	context.cauldron_contents.clear()
	context.gold_gained_this_brew = 0
	context.boss_threshold_discount_gained = 0
	context.free_shop_rerolls_gained = 0
	_reset_draw_flow_state()
	context.bag.reset_for_brew()
	context.bag.shuffle_working_deck()
	brew_updated.emit(context)
	return true


func can_player_draw() -> bool:
	return (
		context.outcome == BrewOutcome.Outcome.IN_PROGRESS
		and _chain_draws_remaining <= 0
		and not _ambidextrous_draw_pending
		and not _eyeball_puzzle_active
		and not _bat_wing_picker_active
	)


func needs_eyeball_puzzle() -> bool:
	return _eyeball_reserved.size() > 0 and not _eyeball_puzzle_active


func needs_bat_wing_picker() -> bool:
	return _bat_wing_choices.size() > 0 and not _bat_wing_picker_active


func get_eyeball_reserved() -> Array[IngredientData]:
	return _eyeball_reserved.duplicate()


func get_bat_wing_choices() -> Array[IngredientData]:
	return _bat_wing_choices.duplicate()


func is_frog_leg_save_pending() -> bool:
	return _frog_leg_save_pending


func complete_frog_leg_save() -> void:
	if not _frog_leg_save_pending:
		return
	_frog_leg_save_pending = false
	_apply_end_of_brew_bonuses()
	context.outcome = BrewOutcome.Outcome.BANKED
	_finalize_brew()
	brew_updated.emit(context)


func begin_eyeball_puzzle() -> void:
	if _eyeball_reserved.is_empty():
		return
	_eyeball_puzzle_active = true


func begin_bat_wing_picker() -> void:
	if _bat_wing_choices.is_empty():
		return
	_bat_wing_picker_active = true


func complete_eyeball_puzzle(ordered: Array) -> void:
	if ordered.is_empty():
		return
	context.bag.apply_upcoming_draw_order(ordered)
	_eyeball_reserved.clear()
	_eyeball_puzzle_active = false
	brew_updated.emit(context)


func complete_bat_wing_picker(selected: IngredientData) -> void:
	if selected == null or _bat_wing_choices.is_empty():
		return

	var unselected: Array[IngredientData] = []
	for choice in _bat_wing_choices:
		if choice != selected:
			unselected.append(choice)
	context.bag.return_to_bag(unselected)

	_bat_wing_choices.clear()
	_bat_wing_picker_active = false
	_apply_ingredient(selected, true)
	if context.is_exploded():
		_chain_draws_remaining = 0
		_ambidextrous_draw_pending = false
		if not _try_frog_leg_save():
			_resolve_explosion()
	ingredient_drawn.emit(context, selected)
	brew_updated.emit(context)


func try_draw_ingredient() -> bool:
	if not can_player_draw():
		return false
	if not _draw_and_emit(false):
		return false
	_schedule_ambidextrous_pair_draw()
	return true


func try_advance_chain_draw() -> bool:
	if context.outcome != BrewOutcome.Outcome.IN_PROGRESS:
		_chain_draws_remaining = 0
		_ambidextrous_draw_pending = false
		return false
	if _ambidextrous_draw_pending:
		_ambidextrous_draw_pending = false
		return _draw_and_emit(true)
	if _chain_draws_remaining <= 0:
		return false
	_chain_draws_remaining -= 1
	return _draw_and_emit(true)


func on_ingredient_presentation_finished() -> void:
	if needs_bat_wing_picker():
		begin_bat_wing_picker()
		bat_wing_picker_requested.emit(get_bat_wing_choices())
		return
	if needs_eyeball_puzzle():
		begin_eyeball_puzzle()
		eyeball_puzzle_requested.emit(get_eyeball_reserved())


func try_end_brew() -> bool:
	if not context.can_end_brew() or not can_player_draw():
		return false
	_apply_end_of_brew_bonuses()
	if context.is_boss_level():
		context.outcome = BrewOutcome.Outcome.CLEARED
	else:
		context.outcome = BrewOutcome.Outcome.BANKED
	_finalize_brew()
	return true


func calculate_gold_reward() -> int:
	var score := context.score
	var base_reward := score if score <= 14 else 14 + int((score - 14) / 2)
	var total := base_reward + context.gold_gained_this_brew
	if _gloom_weed_doubles_gold():
		total *= 2
	return _AuraEffects.apply_gold_multiplier(total, context.current_aura)


func _draw_and_emit(_is_chain: bool) -> bool:
	var ingredient := context.bag.try_draw()
	if ingredient == null:
		if _is_chain:
			_chain_draws_remaining = 0
		_resolve_bag_empty()
		return false

	_apply_ingredient(ingredient, true)
	if context.is_exploded():
		_chain_draws_remaining = 0
		_ambidextrous_draw_pending = false
		if not _try_frog_leg_save():
			_resolve_explosion()

	ingredient_drawn.emit(context, ingredient)
	brew_updated.emit(context)
	return true


func _apply_ingredient(ingredient: IngredientData, track_draw: bool) -> void:
	if track_draw:
		context.drawn_this_brew.append(ingredient)

	var point_value := ingredient.point_value
	var explosive_add := ingredient.explosive_value
	var parrot_doubled_this_ingredient := _parrot_doubles_next
	if parrot_doubled_this_ingredient:
		point_value *= 2
		explosive_add *= 2
		_parrot_doubles_next = false
	if _AuraEffects.in_rhythm_doubles_ingredient(
		context.cauldron_contents.size(),
		context.current_aura
	):
		point_value *= 2
		explosive_add *= 2
	context.score += point_value
	if _unicorn_cures_next_explosive:
		if explosive_add > 0:
			explosive_add = 0
		_unicorn_cures_next_explosive = false
	context.explosiveness += explosive_add

	var effect := IngredientEffects.apply(ingredient, context)
	var bonus_multiplier := 2 if parrot_doubled_this_ingredient else 1
	var bonus_score_added := 0
	if effect.bonus_score > 0:
		bonus_score_added = effect.bonus_score * bonus_multiplier
		context.score += bonus_score_added
	if effect.chain_draws > 0:
		_chain_draws_remaining = effect.chain_draws
	if effect.reserve_for_eyeball > 0:
		_eyeball_reserved = context.bag.peek_upcoming_draws(effect.reserve_for_eyeball)
	if effect.cures_next_explosive:
		_unicorn_cures_next_explosive = true
	if effect.doubles_next_ingredient:
		_parrot_doubles_next = true
	if effect.bonus_gold > 0:
		context.gold_gained_this_brew += effect.bonus_gold * bonus_multiplier
	if effect.boss_threshold_discount > 0:
		context.boss_threshold_discount_gained += (
			effect.boss_threshold_discount * bonus_multiplier
		)
	if effect.free_shop_rerolls > 0:
		context.free_shop_rerolls_gained += effect.free_shop_rerolls * bonus_multiplier
	if effect.explosion_limit_bonus > 0:
		context.explosion_limit += effect.explosion_limit_bonus
	if effect.bat_wing_pick_count > 0:
		_bat_wing_choices = context.bag.take_random(effect.bat_wing_pick_count)
	if effect.voodoo_doll_arms_copy:
		_voodoo_doll_arms_copy = true
	elif _voodoo_doll_arms_copy and ingredient.id != IngredientEffects.VOODOO_DOLL_ID:
		_replace_voodoo_in_cauldron_with(ingredient)
		context.bag.replace_one_voodoo_doll_in_master_with(ingredient)
		_voodoo_doll_arms_copy = false

	if not context.is_exploded():
		return
	if ingredient.id == IngredientEffects.PHOENIX_FEATHER_ID:
		_trigger_phoenix_save()


func _try_frog_leg_save() -> bool:
	var frog_leg := _find_frog_leg_in_cauldron()
	if frog_leg == null:
		return false

	context.explosion_limit += 1
	_remove_from_cauldron(frog_leg)
	context.bag.remove_one_chip_from_master(frog_leg)
	_frog_leg_save_pending = true
	frog_leg_escaped.emit(frog_leg)
	return true


func _find_frog_leg_in_cauldron() -> IngredientData:
	for entry in context.cauldron_contents:
		if entry != null and entry.id == IngredientEffects.FROG_LEG_ID:
			return entry
	return null


func _replace_voodoo_in_cauldron_with(ingredient: IngredientData) -> void:
	if ingredient == null:
		return
	var voodoo_index := -1
	for i in context.cauldron_contents.size():
		var entry = context.cauldron_contents[i]
		if entry != null and entry.id == IngredientEffects.VOODOO_DOLL_ID:
			voodoo_index = i
			break
	if voodoo_index < 0:
		return
	if (
		not context.cauldron_contents.is_empty()
		and context.cauldron_contents[-1] == ingredient
	):
		context.cauldron_contents.pop_back()
	context.cauldron_contents[voodoo_index] = ingredient


func _trigger_phoenix_save() -> void:
	context.explosiveness = 0
	context.bag.reshuffle_after_phoenix(context.cauldron_contents)
	context.cauldron_contents.clear()


func _remove_from_cauldron(ingredient: IngredientData) -> void:
	var index := context.cauldron_contents.rfind(ingredient)
	if index >= 0:
		context.cauldron_contents.remove_at(index)


func _apply_end_of_brew_bonuses() -> void:
	_apply_leech_boss_discount()
	_apply_cinnamon_gold_bonus()


func _apply_cinnamon_gold_bonus() -> void:
	if context.score % 2 != 0:
		return
	var cinnamon_count := 0
	for ingredient in context.cauldron_contents:
		if ingredient != null and ingredient.id == IngredientEffects.CINNAMON_ID:
			cinnamon_count += 1
	if cinnamon_count <= 0:
		return
	context.gold_gained_this_brew += 2 * cinnamon_count


func _apply_leech_boss_discount() -> void:
	var reduction := IngredientEffects.leech_boss_threshold_reduction(context)
	if reduction > 0:
		context.boss_threshold_discount_gained += reduction


func _gloom_weed_doubles_gold() -> bool:
	if context.cauldron_contents.is_empty():
		return false
	var last := context.cauldron_contents[-1]
	return last != null and last.id == IngredientEffects.GLOOM_WEED_ID


func _resolve_explosion() -> void:
	context.outcome = BrewOutcome.Outcome.EXPLODED
	_finalize_brew()


func _resolve_bag_empty() -> void:
	if context.is_boss_level():
		context.outcome = (
			BrewOutcome.Outcome.CLEARED
			if context.score >= context.threshold
			else BrewOutcome.Outcome.BAG_EMPTY
		)
	elif context.score > 0:
		_apply_end_of_brew_bonuses()
		context.outcome = BrewOutcome.Outcome.BANKED
	else:
		context.outcome = BrewOutcome.Outcome.BAG_EMPTY
	_finalize_brew()


func _finalize_brew() -> void:
	_reset_draw_flow_state()
	context.bag.reset_for_brew()
	brew_updated.emit(context)


func _schedule_ambidextrous_pair_draw() -> void:
	if not _has_ambidextrous_aura():
		return
	if context.outcome != BrewOutcome.Outcome.IN_PROGRESS:
		return
	if context.is_exploded():
		return
	_ambidextrous_draw_pending = true


func _has_ambidextrous_aura() -> bool:
	return (
		context.current_aura != null
		and context.current_aura.id == GameConstants.AMBIDEXTROUS_AURA_ID
	)


func _reset_draw_flow_state() -> void:
	_chain_draws_remaining = 0
	_ambidextrous_draw_pending = false
	_eyeball_reserved.clear()
	_eyeball_puzzle_active = false
	_bat_wing_choices.clear()
	_bat_wing_picker_active = false
	_unicorn_cures_next_explosive = false
	_parrot_doubles_next = false
	_voodoo_doll_arms_copy = false
	_frog_leg_save_pending = false