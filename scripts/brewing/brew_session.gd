class_name BrewSession
extends RefCounted

const _AuraEffects := preload("res://scripts/brewing/aura_effects.gd")

const HAND_SLOT_COUNT := 5
const HAND_DRAW_COUNT := 5
const EYEBALL_PEEK_COUNT := 5
const EYEBALL_PREVIEW_COUNT := 3

enum HandPhase { BAG, DRAWING, HAND, PLAYING }

signal brew_updated(context: BrewContext)
signal hand_draw_batch_started(drawn: Array)
signal hand_card_played(
	context: BrewContext,
	ingredient: IngredientData,
	slot_index: int,
	parrot_doubled: bool
)
signal hand_mulligan_started(
	old_ingredient: IngredientData,
	new_ingredient: IngredientData,
	slot_index: int
)
signal ingredient_drawn(
	context: BrewContext,
	ingredient: IngredientData,
	parrot_doubled: bool
)
signal frog_leg_escaped(ingredient: IngredientData)
signal eyeball_puzzle_requested(reserved: Array)
signal bat_wing_picker_requested(choices: Array)

var context := BrewContext.new()

var _hand_phase: int = HandPhase.BAG
var _hand_slots: Array = []
var _hand_undo_stack: Array = []
var _hand_swap_allowance: int = 1
var _hand_swaps_used: int = 0
var _bonus_swap_next_hand: int = 0
var _lucky_coin_in_current_hand: bool = false
var _mulligan_allowance: int = 1
var _mulligans_used: int = 0
var _play_slot_cursor: int = 0
var _pending_hand_draw: Array = []
var _hand_draw_display_reserve: int = 0

var _chain_draws_remaining: int = 0
var _eyeball_reserved: Array[IngredientData] = []
var _eyeball_puzzle_active: bool = false
var _bat_wing_choices: Array[IngredientData] = []
var _bat_wing_picker_active: bool = false
var _unicorn_cures_next_explosive: bool = false
var _parrot_doubles_next: bool = false
var _voodoo_doll_arms_copy: bool = false
var _practice_restart_used: bool = false
var _frog_leg_save_pending: bool = false


func _init() -> void:
	_reset_hand_slots()


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
		context.threshold -= maxi(0, boss_threshold_discount)
	context.threshold = _AuraEffects.apply_threshold_modifier(context.threshold, aura)
	context.threshold = GameConstants.clamp_threshold_for_level(level, context.threshold)
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
	_mulligan_allowance = 1
	_mulligans_used = 0
	_bonus_swap_next_hand = 0
	_lucky_coin_in_current_hand = false
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


func get_hand_phase() -> int:
	return _hand_phase


func is_bag_phase() -> bool:
	return _hand_phase == HandPhase.BAG


func is_hand_interaction_blocked() -> bool:
	return _hand_phase in [HandPhase.DRAWING, HandPhase.HAND, HandPhase.PLAYING]


func can_press_bag() -> bool:
	return (
		context.outcome == BrewOutcome.Outcome.IN_PROGRESS
		and _hand_phase == HandPhase.BAG
		and _chain_draws_remaining <= 0
		and not _eyeball_puzzle_active
		and not _bat_wing_picker_active
	)


func can_player_draw() -> bool:
	return can_press_bag()


func can_play_hand() -> bool:
	return (
		context.outcome == BrewOutcome.Outcome.IN_PROGRESS
		and _hand_phase == HandPhase.HAND
		and _hand_has_any_card()
		and not _eyeball_puzzle_active
		and not _bat_wing_picker_active
	)


func can_swap_hand() -> bool:
	return _hand_phase == HandPhase.HAND and _hand_swaps_used < _hand_swap_allowance


func get_hand_swaps_remaining() -> int:
	return maxi(0, _hand_swap_allowance - _hand_swaps_used)


func get_mulligans_remaining() -> int:
	return maxi(0, _mulligan_allowance - _mulligans_used)


func get_in_rhythm_double_hand_slots() -> Array[int]:
	if _hand_phase != HandPhase.HAND:
		return []
	return _AuraEffects.in_rhythm_double_hand_slots(
		_hand_slots,
		context.cauldron_contents.size(),
		context.current_aura,
		HAND_SLOT_COUNT
	)


func get_bag_display_count() -> int:
	if context.bag == null:
		return 0
	return context.bag.remaining_count() + _hand_draw_display_reserve


func consume_hand_draw_display_reserve() -> void:
	_hand_draw_display_reserve = maxi(0, _hand_draw_display_reserve - 1)


func _reset_hand_draw_display_reserve() -> void:
	_hand_draw_display_reserve = 0


func can_undo_hand_swap() -> bool:
	return _hand_phase == HandPhase.HAND and not _hand_undo_stack.is_empty()


func can_mulligan() -> bool:
	return (
		_hand_phase == HandPhase.HAND
		and _mulligans_used < _mulligan_allowance
		and context.bag.remaining_count() > 0
	)


func is_mulligan_used_this_level() -> bool:
	return _mulligans_used >= _mulligan_allowance


func can_player_end_brew() -> bool:
	return (
		context.can_end_brew()
		and _hand_phase == HandPhase.BAG
		and _chain_draws_remaining <= 0
		and not _eyeball_puzzle_active
		and not _bat_wing_picker_active
	)


func get_hand_slots() -> Array:
	return _hand_slots.duplicate()


func get_hand_slot(slot_index: int) -> IngredientData:
	if slot_index < 0 or slot_index >= HAND_SLOT_COUNT:
		return null
	return _hand_slots[slot_index]


func needs_eyeball_puzzle() -> bool:
	return _eyeball_reserved.size() > 0 and not _eyeball_puzzle_active


func needs_bat_wing_picker() -> bool:
	return _bat_wing_choices.size() > 0 and not _bat_wing_picker_active


func get_eyeball_reserved() -> Array[IngredientData]:
	return _eyeball_reserved.duplicate()


func get_eyeball_preview() -> Array[IngredientData]:
	var preview: Array[IngredientData] = []
	for i in mini(EYEBALL_PREVIEW_COUNT, _eyeball_reserved.size()):
		preview.append(_eyeball_reserved[i])
	return preview


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


func complete_eyeball_puzzle(_ordered: Array = []) -> void:
	_eyeball_reserved.clear()
	_eyeball_puzzle_active = false
	brew_updated.emit(context)
	if _hand_phase == HandPhase.PLAYING:
		_play_next_hand_card()


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
	var parrot_doubled := _apply_ingredient(selected, true)
	if context.is_exploded():
		_chain_draws_remaining = 0
		if not _try_frog_leg_save():
			_resolve_explosion()
	ingredient_drawn.emit(context, selected, parrot_doubled)
	brew_updated.emit(context)


func try_draw_to_hand() -> bool:
	if not can_press_bag():
		return false

	var drawn: Array[IngredientData] = []
	for _i in HAND_DRAW_COUNT:
		var ingredient := context.bag.try_draw()
		if ingredient == null:
			break
		drawn.append(ingredient)

	if drawn.is_empty():
		_resolve_bag_empty()
		return false

	_hand_phase = HandPhase.DRAWING
	_hand_undo_stack.clear()
	_hand_swap_allowance = 1 + _bonus_swap_next_hand
	_bonus_swap_next_hand = 0
	_hand_swaps_used = 0
	_lucky_coin_in_current_hand = false
	_reset_hand_slots()
	_pending_hand_draw = drawn.duplicate()
	_hand_draw_display_reserve = drawn.size()
	hand_draw_batch_started.emit(drawn)
	brew_updated.emit(context)
	return true


func on_hand_draw_batch_finished() -> void:
	if _hand_phase != HandPhase.DRAWING:
		return
	_reset_hand_draw_display_reserve()
	for i in _pending_hand_draw.size():
		var slot_index := _pending_hand_draw.size() - 1 - i
		if slot_index >= 0 and slot_index < HAND_SLOT_COUNT:
			_hand_slots[slot_index] = _pending_hand_draw[i]
	_pending_hand_draw.clear()
	_hand_phase = HandPhase.HAND
	_hand_swaps_used = 0
	_note_lucky_coin_in_hand()
	brew_updated.emit(context)


func try_play_hand() -> bool:
	if not can_play_hand():
		return false
	_hand_phase = HandPhase.PLAYING
	_play_slot_cursor = 0
	_play_next_hand_card()
	return true


func swap_hand_slots(from_slot: int, to_slot: int) -> bool:
	if not can_swap_hand():
		return false
	if from_slot == to_slot:
		return false
	if not _is_valid_hand_slot(from_slot) or not _is_valid_hand_slot(to_slot):
		return false
	if _hand_slots[from_slot] == null and _hand_slots[to_slot] == null:
		return false

	_hand_undo_stack.append(_hand_slots.duplicate())
	var tmp = _hand_slots[from_slot]
	_hand_slots[from_slot] = _hand_slots[to_slot]
	_hand_slots[to_slot] = tmp
	_hand_swaps_used += 1
	brew_updated.emit(context)
	return true


func undo_hand_swap() -> bool:
	if not can_undo_hand_swap():
		return false
	_hand_slots = _hand_undo_stack.pop_back()
	_hand_swaps_used = maxi(0, _hand_swaps_used - 1)
	brew_updated.emit(context)
	return true


func try_mulligan(slot_index: int) -> bool:
	if not can_mulligan():
		return false
	if not _is_valid_hand_slot(slot_index):
		return false
	var old_ingredient: IngredientData = _hand_slots[slot_index]
	if old_ingredient == null:
		return false

	var replacements := context.bag.take_random(1)
	if replacements.is_empty():
		return false
	var new_ingredient: IngredientData = replacements[0]
	hand_mulligan_started.emit(old_ingredient, new_ingredient, slot_index)
	return true


func complete_mulligan(
	slot_index: int,
	old_ingredient: IngredientData,
	new_ingredient: IngredientData
) -> void:
	if not _is_valid_hand_slot(slot_index):
		return
	context.bag.return_to_bag([old_ingredient])
	_hand_slots[slot_index] = new_ingredient
	_mulligans_used += 1
	_note_lucky_coin_in_hand()
	brew_updated.emit(context)


func on_hand_play_presentation_finished() -> void:
	if _hand_phase != HandPhase.PLAYING:
		return
	if context.outcome != BrewOutcome.Outcome.IN_PROGRESS:
		return
	if needs_bat_wing_picker():
		begin_bat_wing_picker()
		bat_wing_picker_requested.emit(get_bat_wing_choices())
		return
	if needs_eyeball_puzzle():
		begin_eyeball_puzzle()
		eyeball_puzzle_requested.emit(get_eyeball_preview())
		return
	if try_advance_chain_draw():
		return
	_play_next_hand_card()


func try_advance_chain_draw() -> bool:
	if context.outcome != BrewOutcome.Outcome.IN_PROGRESS:
		_chain_draws_remaining = 0
		return false
	if _chain_draws_remaining <= 0:
		return false
	_chain_draws_remaining -= 1
	return _draw_and_emit(true)


func try_end_brew() -> bool:
	if not can_player_end_brew():
		return false
	_apply_end_of_brew_bonuses()
	if context.is_boss_level():
		context.outcome = BrewOutcome.Outcome.CLEARED
	else:
		context.outcome = BrewOutcome.Outcome.BANKED
	_finalize_brew()
	return true


func _play_next_hand_card() -> void:
	while _play_slot_cursor < HAND_SLOT_COUNT and _hand_slots[_play_slot_cursor] == null:
		_play_slot_cursor += 1

	if _play_slot_cursor >= HAND_SLOT_COUNT:
		_finish_hand_play()
		return

	var ingredient: IngredientData = _hand_slots[_play_slot_cursor]
	var slot_index := _play_slot_cursor
	_hand_slots[_play_slot_cursor] = null
	_play_slot_cursor += 1

	var parrot_doubled := _apply_ingredient(ingredient, true)
	if context.is_exploded():
		_chain_draws_remaining = 0
		if not _try_frog_leg_save():
			_resolve_explosion()

	hand_card_played.emit(context, ingredient, slot_index, parrot_doubled)
	brew_updated.emit(context)


func _finish_hand_play() -> void:
	_resolve_lucky_coin_hand_effect()
	_reset_hand_slots()
	_hand_undo_stack.clear()
	_hand_phase = HandPhase.BAG
	brew_updated.emit(context)


func _draw_and_emit(_is_chain: bool) -> bool:
	var ingredient := context.bag.try_draw()
	if ingredient == null:
		if _is_chain:
			_chain_draws_remaining = 0
		if _hand_phase == HandPhase.PLAYING:
			on_hand_play_presentation_finished()
		else:
			_resolve_bag_empty()
		return false

	var parrot_doubled := _apply_ingredient(ingredient, true)
	if context.is_exploded():
		_chain_draws_remaining = 0
		if not _try_frog_leg_save():
			_resolve_explosion()

	ingredient_drawn.emit(context, ingredient, parrot_doubled)
	brew_updated.emit(context)
	return true


func _apply_ingredient(ingredient: IngredientData, track_draw: bool) -> bool:
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
		_eyeball_reserved = context.bag.peek_upcoming_draws(EYEBALL_PEEK_COUNT)
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
	if effect.extra_mulligans > 0:
		_mulligan_allowance += effect.extra_mulligans * bonus_multiplier
	if effect.explosion_limit_bonus > 0:
		context.explosion_limit += effect.explosion_limit_bonus
	if effect.bat_wing_pick_count > 0:
		_bat_wing_choices = context.bag.take_random(effect.bat_wing_pick_count)
	if effect.voodoo_doll_arms_copy:
		_voodoo_doll_arms_copy = true
	else:
		_try_consume_voodoo_copy(ingredient)

	if not context.is_exploded():
		return parrot_doubled_this_ingredient
	if ingredient.id == IngredientEffects.PHOENIX_FEATHER_ID:
		_trigger_phoenix_save()
	return parrot_doubled_this_ingredient


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


func _try_consume_voodoo_copy(ingredient: IngredientData) -> void:
	if not _voodoo_doll_arms_copy or ingredient == null:
		return
	if ingredient.id in [IngredientEffects.VOODOO_DOLL_ID, IngredientEffects.BAT_WING_ID]:
		return
	if not _has_voodoo_in_cauldron():
		return
	_replace_voodoo_in_cauldron_with(ingredient)
	context.bag.replace_one_voodoo_doll_in_master_with(ingredient)
	_voodoo_doll_arms_copy = false


func _has_voodoo_in_cauldron() -> bool:
	for entry in context.cauldron_contents:
		if entry != null and entry.id == IngredientEffects.VOODOO_DOLL_ID:
			return true
	return false


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


func _reset_hand_slots() -> void:
	_hand_slots.clear()
	for _i in HAND_SLOT_COUNT:
		_hand_slots.append(null)


func _hand_has_any_card() -> bool:
	for slot in _hand_slots:
		if slot != null:
			return true
	return false


func _is_valid_hand_slot(slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < HAND_SLOT_COUNT


func _note_lucky_coin_in_hand() -> void:
	if _hand_contains_ingredient(IngredientEffects.LUCKY_COIN_ID):
		_lucky_coin_in_current_hand = true


func _hand_contains_ingredient(ingredient_id: String) -> bool:
	for slot in _hand_slots:
		if slot != null and slot.id == ingredient_id:
			return true
	return false


func _resolve_lucky_coin_hand_effect() -> void:
	if not _lucky_coin_in_current_hand:
		return
	if _hand_swaps_used <= 0:
		context.gold_gained_this_brew += 2
	else:
		_bonus_swap_next_hand += 1
	_lucky_coin_in_current_hand = false


func _reset_draw_flow_state() -> void:
	_hand_phase = HandPhase.BAG
	_reset_hand_slots()
	_hand_undo_stack.clear()
	_hand_swap_allowance = 1
	_hand_swaps_used = 0
	_bonus_swap_next_hand = 0
	_lucky_coin_in_current_hand = false
	_mulligan_allowance = 1
	_mulligans_used = 0
	_play_slot_cursor = 0
	_pending_hand_draw.clear()
	_reset_hand_draw_display_reserve()
	_chain_draws_remaining = 0
	_eyeball_reserved.clear()
	_eyeball_puzzle_active = false
	_bat_wing_choices.clear()
	_bat_wing_picker_active = false
	_unicorn_cures_next_explosive = false
	_parrot_doubles_next = false
	_voodoo_doll_arms_copy = false
	_frog_leg_save_pending = false


func calculate_gold_reward() -> int:
	var score := context.score
	var base_reward := score if score <= 14 else 14 + int((score - 14) / 2)
	var total := base_reward + context.gold_gained_this_brew
	if _gloom_weed_doubles_gold():
		total *= 2
	return _AuraEffects.apply_gold_multiplier(total, context.current_aura)