class_name BrewSession
extends RefCounted

const _AuraEffects := preload("res://scripts/brewing/aura_effects.gd")
const _HandSlotEffects := preload("res://scripts/brewing/hand_slot_effects.gd")

const HAND_SLOT_COUNT := 5
const HAND_DRAW_COUNT := 5
const HAND_END_EFFECTS_DELAY := 0.5
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
signal time_turner_redraw_started(
	old_hand_entries: Array,
	new_hand: Array
)
signal ingredient_drawn(
	context: BrewContext,
	ingredient: IngredientData,
	parrot_doubled: bool
)
signal frog_leg_escaped(ingredient: IngredientData)
signal eyeball_puzzle_requested(reserved: Array)
signal bat_wing_picker_requested(choices: Array)
signal hand_end_effects_pending

var context := BrewContext.new()

var _hand_phase: int = HandPhase.BAG
var _hand_slots: Array = []
var _hand_start_slots: Array = []
var _hand_undo_stack: Array = []
var _hand_swap_allowance: int = 1
var _hand_swaps_used: int = 0
var _stirring_spoon_hands_remaining: int = 0
var _juggling_club_hands_remaining: int = 0
var _lucky_coin_swap_hands_remaining: int = 0
var _next_hand_draw_count: int = HAND_DRAW_COUNT
var _lucky_coin_in_current_hand: bool = false
var _brew_difficulty: int = GameDifficulty.Mode.HARD
var _brew_extra_mulligans: int = 0
var _purchased_mulligans_this_brew: int = 0
var _mulligan_allowance: int = 1
var _mulligans_used: int = 0
var _play_slot_cursor: int = 0
var _pending_hand_draw: Array = []
var _pending_hand_draw_target_slots: Array = []
var _hand_draw_display_reserve: int = 0
var _honey_skipped_slots: Dictionary = {}

var _chain_draws_remaining: int = 0
var _eyeball_reserved: Array[IngredientData] = []
var _eyeball_puzzle_active: bool = false
var _bat_wing_choices: Array[IngredientData] = []
var _bat_wing_picker_active: bool = false
var _bat_wing_reroll_used: bool = false
var _bat_wing_source_slot_index: int = -1
var _last_hand_play_slot: int = -1
var _last_hand_play_ingredient: IngredientData = null
var _pending_cobbler_slot_bonuses: Dictionary = {}
var _unicorn_cures_next_explosive: bool = false
var _ice_cube_shields_remaining: int = 0
var _parrot_doubles_next: bool = false
var _parrot_repeat_pending: bool = false
var _parrot_repeat_ingredient: IngredientData = null
var _parrot_repeat_from_hand: bool = false
var _parrot_repeat_hand_slot: int = -1
var _pristine_feather_repeat_pending: bool = false
var _pristine_feather_repeat_ingredient: IngredientData = null
var _pristine_feather_repeat_from_hand: bool = false
var _pristine_feather_repeat_hand_slot: int = -1
var _voodoo_doll_arms_copy: bool = false
var _practice_restart_used: bool = false
var _frog_leg_save_pending: bool = false
var _fairy_vanish_next_ingredient: bool = false
var _booberry_count_this_hand: int = 0
var _poison_apple_pending: Array = []
var _growth_potion_doubles_remaining: int = 0
var _hand_end_effects_pending: bool = false
var _brew_finalized: bool = false

var presented_score: int = 0
var presented_explosiveness: int = 0
var presented_gold_gained_this_brew: int = 0
var presented_boss_threshold_discount_gained: int = 0
var _presented_stat_snapshots: Array = []
var last_presented_stat_deltas: Dictionary = {
	"score": 0,
	"explosiveness": 0,
	"gold_reward": 0,
}
var last_play_fly_count: int = 1
var last_play_fairy_poof: bool = false
var _pending_gecko_stay_slot: int = -1
var _pending_bubbling_brew_return: IngredientData = null
var _jar_of_dirt_broke_poof_pending: bool = false
var _pending_time_turner_new_hand: Array = []
var _pending_time_turner_target_slots: Array = []
var _frog_legs_played_this_brew: Array[IngredientData] = []
var last_bag_grant_ingredient: IngredientData = null


func _init() -> void:
	_reset_hand_slots()


func start_brew(
	level: int,
	aura: AuraData,
	bag: BagModel,
	explosion_limit_bonus: int = 0,
	boss_threshold_penalty: int = 0,
	boss_threshold_discount: int = 0,
	difficulty: int = GameDifficulty.Mode.HARD,
	extra_mulligans: int = 0,
	owned_trinket_ids: Array[String] = []
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
	context.explosion_limit = _compute_base_explosion_limit(aura, explosion_limit_bonus)
	context.outcome = BrewOutcome.Outcome.IN_PROGRESS
	context.drawn_this_brew.clear()
	context.cauldron_contents.clear()
	context.gold_gained_this_brew = 0
	context.boss_threshold_discount_gained = 0
	context.free_shop_rerolls_gained = 0
	context.owned_trinket_ids = owned_trinket_ids.duplicate()
	_clear_presented_stat_snapshots()
	_reset_presented_stats()
	_practice_restart_used = false
	_brew_finalized = false
	_stirring_spoon_hands_remaining = 0
	_juggling_club_hands_remaining = 0
	_lucky_coin_swap_hands_remaining = 0
	_next_hand_draw_count = HAND_DRAW_COUNT
	_lucky_coin_in_current_hand = false
	_brew_difficulty = difficulty
	_brew_extra_mulligans = maxi(0, extra_mulligans)
	_purchased_mulligans_this_brew = 0
	_mulligans_used = 0
	_frog_legs_played_this_brew.clear()
	_reset_draw_flow_state()
	_refresh_mulligan_allowance()
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
	context.explosion_limit = _compute_base_explosion_limit(context.current_aura)
	context.drawn_this_brew.clear()
	context.cauldron_contents.clear()
	context.gold_gained_this_brew = 0
	context.boss_threshold_discount_gained = 0
	context.free_shop_rerolls_gained = 0
	_clear_presented_stat_snapshots()
	_reset_presented_stats()
	_reset_draw_flow_state()
	_purchased_mulligans_this_brew = 0
	_mulligans_used = 0
	_refresh_mulligan_allowance()
	context.bag.reset_for_brew()
	context.bag.shuffle_working_deck()
	brew_updated.emit(context)
	return true


func _refresh_mulligan_allowance() -> void:
	_mulligan_allowance = (
		GameDifficulty.base_mulligans_per_brew(_brew_difficulty)
		+ _brew_extra_mulligans
		+ _purchased_mulligans_this_brew
	)


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


func can_purchase_mulligan() -> bool:
	return (
		context.outcome == BrewOutcome.Outcome.IN_PROGRESS
		and not _brew_finalized
	)


func grant_purchased_mulligan() -> void:
	_purchased_mulligans_this_brew += 1
	_refresh_mulligan_allowance()
	brew_updated.emit(context)


func get_in_rhythm_double_hand_slots(slots_override: Array = []) -> Array[int]:
	if _hand_phase not in [HandPhase.HAND, HandPhase.PLAYING, HandPhase.DRAWING]:
		return []
	return _AuraEffects.in_rhythm_double_hand_slots(
		_resolve_display_hand_slots(slots_override),
		context.cauldron_contents.size(),
		context.current_aura,
		HAND_SLOT_COUNT
	)


func get_bubbling_brew_hand_slots(slots_override: Array = []) -> Array[int]:
	if _hand_phase not in [HandPhase.HAND, HandPhase.PLAYING, HandPhase.DRAWING]:
		return []
	return _AuraEffects.bubbling_brew_hand_slots(
		_resolve_display_hand_slots(slots_override),
		context.cauldron_contents.size(),
		context.current_aura,
		HAND_SLOT_COUNT
	)


func get_aura_preview_shake_hand_slots(slots_override: Array = []) -> Array[int]:
	var shake_slots: Array[int] = []
	shake_slots.append_array(get_in_rhythm_double_hand_slots(slots_override))
	shake_slots.append_array(get_bubbling_brew_hand_slots(slots_override))
	var unique: Dictionary = {}
	for slot_index in shake_slots:
		unique[int(slot_index)] = true
	var merged: Array[int] = []
	for slot_index in unique.keys():
		merged.append(int(slot_index))
	merged.sort()
	return merged


func get_hand_display_stats(slots_override: Array = []) -> Array:
	if _hand_phase not in [HandPhase.HAND, HandPhase.PLAYING, HandPhase.DRAWING]:
		return []
	return _compute_hand_display_stats(slots_override)


func get_hand_slot_effect_entries(slots_override: Array = []) -> Array:
	if _hand_phase not in [HandPhase.HAND, HandPhase.PLAYING, HandPhase.DRAWING]:
		return []
	var slots := _resolve_display_hand_slots(slots_override)
	var layout_slots: Array = []
	if _hand_phase == HandPhase.PLAYING and not _hand_start_slots.is_empty():
		layout_slots = _hand_start_slots
	return _HandSlotEffects.compute_entries(
		slots,
		HAND_SLOT_COUNT,
		layout_slots,
		context.cauldron_contents.size(),
		context.owned_trinket_ids
	)


func _resolve_display_hand_slots(slots_override: Array = []) -> Array:
	if not slots_override.is_empty():
		return slots_override
	return _hand_slots.duplicate()


func _compute_hand_display_stats(slots_override: Array = []) -> Array:
	var slots := _resolve_display_hand_slots(slots_override)
	var severed_layout_slots: Array = []
	if _hand_phase == HandPhase.PLAYING and not _hand_start_slots.is_empty():
		severed_layout_slots = _hand_start_slots
	return IngredientEffects.compute_hand_display_stats(
		slots,
		context.cauldron_contents,
		context.current_aura,
		HAND_SLOT_COUNT,
		_growth_potion_doubles_remaining,
		_build_hand_display_modifiers(),
		severed_layout_slots
	)


func _build_hand_display_modifiers() -> Dictionary:
	return {
		"parrot_doubles_next": _parrot_doubles_next,
		"unicorn_cures_next": _unicorn_cures_next_explosive,
		"ice_cube_shields": _ice_cube_shields_remaining,
		"explosiveness": context.explosiveness,
		"explosion_limit": context.explosion_limit,
		"owned_trinket_ids": context.owned_trinket_ids.duplicate(),
	}


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


func can_use_time_turner() -> bool:
	if _hand_phase != HandPhase.HAND:
		return false
	if context.outcome != BrewOutcome.Outcome.IN_PROGRESS:
		return false
	if not TrinketEffects.has_time_turner(context.owned_trinket_ids):
		return false
	var old_hand := _collect_hand_ingredients()
	if old_hand.is_empty():
		return false
	return context.bag.count_drawable_excluding_instances(old_hand) >= old_hand.size()


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


func sync_owned_trinkets(owned_trinket_ids: Array[String]) -> void:
	context.owned_trinket_ids = owned_trinket_ids.duplicate()
	brew_updated.emit(context)


func can_reroll_bat_wing_choices() -> bool:
	if (
		_bat_wing_reroll_used
		or _bat_wing_choices.size() < IngredientEffects.BAT_WING_PICK_COUNT
		or context.bag == null
	):
		return false
	if not TrinketEffects.has_jar_of_flies(context.owned_trinket_ids):
		return false
	return (
		context.bag.count_drawable_excluding_instances(_bat_wing_choices)
		>= IngredientEffects.BAT_WING_PICK_COUNT
	)


func try_reroll_bat_wing_choices() -> bool:
	if not can_reroll_bat_wing_choices():
		return false

	var held_out := _bat_wing_choices.duplicate()
	context.bag.return_to_bag(held_out)
	var rerolled := context.bag.take_random_excluding_instances(
		held_out,
		IngredientEffects.BAT_WING_PICK_COUNT
	)
	if rerolled.size() < IngredientEffects.BAT_WING_PICK_COUNT:
		context.bag.return_to_bag(rerolled)
		context.bag.remove_instances(held_out)
		_bat_wing_choices = held_out
		return false

	_bat_wing_choices = rerolled
	_bat_wing_reroll_used = true
	return true


func is_frog_leg_save_pending() -> bool:
	return _frog_leg_save_pending


func get_persistent_effect_entries() -> Array[BrewPersistentEffects.EffectEntry]:
	return BrewPersistentEffects.collect(self)


func get_ice_cube_shields_remaining() -> int:
	return _ice_cube_shields_remaining


func get_growth_potion_doubles_remaining() -> int:
	return _growth_potion_doubles_remaining


func get_pocket_watch_countdown() -> int:
	return TrinketEffects.pocket_watch_countdown(
		context.cauldron_contents.size(),
		context.owned_trinket_ids
	)


func get_gecko_assistant_countdown() -> int:
	return TrinketEffects.gecko_assistant_countdown(
		context.cauldron_contents.size(),
		context.owned_trinket_ids
	)


func consume_bubbling_brew_return_presentation() -> IngredientData:
	var ingredient := _pending_bubbling_brew_return
	_pending_bubbling_brew_return = null
	return ingredient


func consume_gecko_stay_presentation() -> Dictionary:
	var slot_index := _pending_gecko_stay_slot
	_pending_gecko_stay_slot = -1
	if slot_index < 0 or not _is_valid_hand_slot(slot_index):
		return {"stayed": false, "slot_index": -1}
	var ingredient: IngredientData = _hand_slots[slot_index]
	if ingredient == null:
		return {"stayed": false, "slot_index": -1}
	return {
		"stayed": true,
		"slot_index": slot_index,
		"ingredient": ingredient,
	}


func get_chain_draws_remaining() -> int:
	return _chain_draws_remaining


func consume_last_bag_grant_ingredient() -> IngredientData:
	var granted := last_bag_grant_ingredient
	last_bag_grant_ingredient = null
	return granted


func consume_jar_of_dirt_broke_poof() -> bool:
	var pending := _jar_of_dirt_broke_poof_pending
	_jar_of_dirt_broke_poof_pending = false
	return pending


func get_poison_apple_pending() -> Array:
	return _poison_apple_pending


func get_booberry_count_this_hand() -> int:
	return _booberry_count_this_hand


func get_stirring_spoon_hands_remaining() -> int:
	return _stirring_spoon_hands_remaining


func get_juggling_club_hands_remaining() -> int:
	return _juggling_club_hands_remaining


func get_next_hand_draw_count() -> int:
	return _next_hand_draw_count


func has_unicorn_cures_next_explosive() -> bool:
	return _unicorn_cures_next_explosive


func has_parrot_doubles_next() -> bool:
	return _parrot_doubles_next


func has_fairy_vanish_next_ingredient() -> bool:
	return _fairy_vanish_next_ingredient


func has_voodoo_doll_arms_copy() -> bool:
	return _voodoo_doll_arms_copy


func complete_frog_leg_save() -> void:
	if not _frog_leg_save_pending:
		return
	_frog_leg_save_pending = false
	enqueue_presented_stat_snapshot()
	brew_updated.emit(context)


func get_jar_of_froglegs_return_entries() -> Array:
	if not TrinketEffects.has_jar_of_froglegs(context.owned_trinket_ids):
		return []
	var entries: Array = []
	var seen: Dictionary = {}
	for ingredient in _frog_legs_played_this_brew:
		if ingredient == null or ingredient.id != IngredientEffects.FROG_LEG_ID:
			continue
		if seen.has(ingredient):
			continue
		seen[ingredient] = true
		entries.append(
			{
				"needs_restore": not context.bag.has_master_chip(ingredient),
			}
		)
	return entries


func restore_frog_leg_to_master_bag() -> void:
	var template := GameManager.run.find_ingredient(IngredientEffects.FROG_LEG_ID)
	if template != null:
		context.bag.add_to_master_bag(template)


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
		_continue_hand_play_resolution()


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
	_bat_wing_reroll_used = false
	var source_slot := _bat_wing_source_slot_index
	_bat_wing_source_slot_index = -1
	var from_hand := source_slot >= 0
	var parrot_doubled := _apply_ingredient(selected, true, from_hand, source_slot)
	if context.is_exploded():
		_chain_draws_remaining = 0
		if not _try_frog_leg_save():
			_resolve_explosion()
	if from_hand:
		hand_card_played.emit(context, selected, source_slot, parrot_doubled)
	else:
		ingredient_drawn.emit(context, selected, parrot_doubled)
	brew_updated.emit(context)


func try_draw_to_hand() -> bool:
	if not can_press_bag():
		return false

	var target_hand_size := _next_hand_draw_count
	_next_hand_draw_count = HAND_DRAW_COUNT
	var filled_slots := HAND_SLOT_COUNT - _count_empty_hand_slots()
	var draw_count := mini(
		_count_empty_hand_slots(),
		maxi(0, target_hand_size - filled_slots)
	)
	if draw_count <= 0:
		return false

	var drawn: Array[IngredientData] = []
	for _i in draw_count:
		var ingredient := context.bag.try_draw()
		if ingredient == null:
			break
		drawn.append(ingredient)

	if drawn.is_empty():
		_resolve_bag_empty()
		return false

	return _begin_hand_draw(drawn, drawn.size())


func try_draw_custom_hand_to_hand(ingredients: Array) -> bool:
	if not can_press_bag():
		return false
	if ingredients.size() != HAND_DRAW_COUNT:
		return false

	var drawn: Array[IngredientData] = []
	for item in ingredients:
		if item is IngredientData:
			drawn.append(item)
	if drawn.size() != HAND_DRAW_COUNT:
		return false

	_reset_hand_slots()
	return _begin_hand_draw(drawn, 0)


func _begin_hand_draw(drawn: Array[IngredientData], bag_display_reserve: int) -> bool:
	var explosiveness_before := context.explosiveness
	_tick_poison_apple_on_new_hand()
	if context.explosiveness != explosiveness_before:
		enqueue_presented_stat_snapshot()
	_hand_phase = HandPhase.DRAWING
	_hand_undo_stack.clear()
	_hand_swap_allowance = 1 + _compute_and_consume_hand_swap_bonus()
	_hand_swaps_used = 0
	_lucky_coin_in_current_hand = false
	_pending_hand_draw = drawn.duplicate()
	_pending_hand_draw_target_slots = _compute_hand_draw_target_slots(drawn.size())
	_hand_draw_display_reserve = bag_display_reserve
	hand_draw_batch_started.emit(drawn)
	brew_updated.emit(context)
	return true


func on_hand_draw_batch_finished() -> void:
	if _hand_phase != HandPhase.DRAWING:
		return
	_reset_hand_draw_display_reserve()
	for i in _pending_hand_draw.size():
		if i >= _pending_hand_draw_target_slots.size():
			break
		var slot_index: int = _pending_hand_draw_target_slots[i]
		if _is_valid_hand_slot(slot_index):
			_hand_slots[slot_index] = _pending_hand_draw[i]
	_pending_hand_draw.clear()
	_pending_hand_draw_target_slots.clear()
	_hand_phase = HandPhase.HAND
	_hand_swaps_used = 0
	_note_lucky_coin_in_hand()
	brew_updated.emit(context)


func try_play_hand() -> bool:
	if not can_play_hand():
		return false
	_hand_phase = HandPhase.PLAYING
	_hand_start_slots = _hand_slots.duplicate()
	_honey_skipped_slots = _compute_honey_skipped_slots()
	_play_slot_cursor = 0
	_last_hand_play_slot = -1
	_last_hand_play_ingredient = null
	_pending_cobbler_slot_bonuses.clear()
	_bat_wing_source_slot_index = -1
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

	_hand_undo_stack.append(Vector2i(from_slot, to_slot))
	var tmp = _hand_slots[from_slot]
	_hand_slots[from_slot] = _hand_slots[to_slot]
	_hand_slots[to_slot] = tmp
	_hand_swaps_used += 1
	brew_updated.emit(context)
	return true


func undo_hand_swap() -> bool:
	if not can_undo_hand_swap():
		return false
	var swap: Vector2i = _hand_undo_stack.pop_back()
	var from_slot := swap.x
	var to_slot := swap.y
	if not _is_valid_hand_slot(from_slot) or not _is_valid_hand_slot(to_slot):
		return false
	var tmp = _hand_slots[from_slot]
	_hand_slots[from_slot] = _hand_slots[to_slot]
	_hand_slots[to_slot] = tmp
	_hand_swaps_used = maxi(0, _hand_swaps_used - 1)
	brew_updated.emit(context)
	return true


func try_time_turner_redraw() -> bool:
	if not can_use_time_turner():
		return false

	var old_hand_entries := _collect_hand_entries()
	var old_hand := _collect_hand_ingredients()
	var draw_count := old_hand.size()
	context.bag.return_to_bag(old_hand)
	for slot_index in range(HAND_SLOT_COUNT):
		_hand_slots[slot_index] = null

	var drawn := context.bag.take_random_excluding_instances(old_hand, draw_count)
	if drawn.size() < draw_count:
		context.bag.remove_instances(drawn)
		context.bag.remove_instances(old_hand)
		for entry in old_hand_entries:
			var slot := int(entry.get("slot_index", -1))
			var ingredient: IngredientData = entry.get("ingredient")
			if _is_valid_hand_slot(slot) and ingredient != null:
				_hand_slots[slot] = ingredient
		return false

	_hand_undo_stack.clear()
	_pending_time_turner_new_hand = drawn.duplicate()
	_pending_time_turner_target_slots = _compute_hand_draw_target_slots(drawn.size())
	time_turner_redraw_started.emit(old_hand_entries, drawn)
	brew_updated.emit(context)
	return true


func get_pending_time_turner_target_slots() -> Array:
	return _pending_time_turner_target_slots.duplicate()


func complete_time_turner_redraw() -> void:
	var drawn: Array = _pending_time_turner_new_hand.duplicate()
	var target_slots := _pending_time_turner_target_slots.duplicate()
	_pending_time_turner_new_hand.clear()
	_pending_time_turner_target_slots.clear()
	for index in range(drawn.size()):
		if index >= target_slots.size():
			break
		var slot_index: int = target_slots[index]
		if _is_valid_hand_slot(slot_index):
			_hand_slots[slot_index] = drawn[index]
	_note_lucky_coin_in_hand()
	brew_updated.emit(context)


func try_mulligan(slot_index: int) -> bool:
	if not can_mulligan():
		return false
	if not _is_valid_hand_slot(slot_index):
		return false
	var old_ingredient: IngredientData = _hand_slots[slot_index]
	if old_ingredient == null:
		return false

	var replacements := context.bag.take_random_excluding_id(old_ingredient.id, 1)
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
	if _bat_wing_picker_active or _eyeball_puzzle_active:
		return
	_continue_hand_play_resolution()


func try_begin_parrot_repeat_play() -> bool:
	return _try_begin_parrot_repeat_play()


func try_begin_pristine_feather_repeat_play() -> bool:
	return _try_begin_pristine_feather_repeat_play()


func _continue_hand_play_resolution() -> void:
	if _bat_wing_picker_active or _eyeball_puzzle_active:
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
	if _try_begin_parrot_repeat_play():
		return
	if _try_begin_pristine_feather_repeat_play():
		return
	if _try_boss_early_clear():
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
	context.outcome = BrewOutcome.Outcome.BANKED
	_finalize_brew()
	return true


func _should_boss_early_clear() -> bool:
	return (
		context.is_boss_level()
		and context.outcome == BrewOutcome.Outcome.IN_PROGRESS
		and not context.is_exploded()
		and context.score >= context.threshold
	)


func _try_boss_early_clear() -> bool:
	if not _should_boss_early_clear():
		return false
	_hand_end_effects_pending = false
	_chain_draws_remaining = 0
	_apply_end_of_brew_bonuses()
	context.outcome = BrewOutcome.Outcome.CLEARED
	_finalize_brew(false)
	brew_updated.emit(context)
	return true


func _play_next_hand_card() -> void:
	while _play_slot_cursor < HAND_SLOT_COUNT:
		if _honey_skipped_slots.has(_play_slot_cursor):
			_play_slot_cursor += 1
			continue
		if _hand_slots[_play_slot_cursor] == null:
			_play_slot_cursor += 1
			continue
		break

	if _play_slot_cursor >= HAND_SLOT_COUNT:
		_request_finish_hand_play()
		return

	var ingredient: IngredientData = _hand_slots[_play_slot_cursor]
	var slot_index := _play_slot_cursor
	var stays_in_hand := TrinketEffects.gecko_assistant_stays_in_hand(
		context.cauldron_contents.size(),
		context.owned_trinket_ids
	)
	_hand_slots[_play_slot_cursor] = null
	_play_slot_cursor += 1

	var parrot_doubled := _apply_ingredient(ingredient, true, true, slot_index)
	if (
		stays_in_hand
		and context.outcome == BrewOutcome.Outcome.IN_PROGRESS
		and not last_play_fairy_poof
		and _pending_bubbling_brew_return != ingredient
	):
		_hand_slots[slot_index] = ingredient
		_pending_gecko_stay_slot = slot_index
	if context.is_exploded():
		_chain_draws_remaining = 0
		if not _try_frog_leg_save():
			_resolve_explosion()

	hand_card_played.emit(context, ingredient, slot_index, parrot_doubled)
	brew_updated.emit(context)


func has_pending_hand_end_effects() -> bool:
	return _hand_end_effects_pending


func cancel_pending_hand_end_effects() -> void:
	_hand_end_effects_pending = false


func apply_pending_hand_end_effects() -> void:
	if not _hand_end_effects_pending:
		return
	if _hand_phase != HandPhase.PLAYING:
		_hand_end_effects_pending = false
		return
	if context.outcome != BrewOutcome.Outcome.IN_PROGRESS:
		_hand_end_effects_pending = false
		return
	_hand_end_effects_pending = false
	_finish_hand_play()


func _request_finish_hand_play() -> void:
	if _hand_end_effects_pending:
		return
	_hand_end_effects_pending = true
	hand_end_effects_pending.emit()


func _finish_hand_play() -> void:
	var explosiveness_before := context.explosiveness
	_apply_booberry_end_of_hand_penalty()
	if context.explosiveness != explosiveness_before:
		enqueue_presented_stat_snapshot()
	_resolve_lucky_coin_hand_effect()
	_honey_skipped_slots.clear()
	_hand_start_slots.clear()
	_hand_undo_stack.clear()
	_hand_phase = HandPhase.BAG
	if not _hand_has_any_card():
		_reset_hand_slots()
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


func _apply_ingredient(
	ingredient: IngredientData,
	track_draw: bool,
	from_hand_play: bool = false,
	hand_slot_index: int = -1
) -> bool:
	if _try_vanish_ingredient_from_fairy(ingredient, track_draw):
		return false

	_note_booberry_played_this_hand(ingredient)
	last_play_fairy_poof = false
	var parrot_doubled_this_ingredient := _parrot_doubles_next
	if parrot_doubled_this_ingredient:
		_parrot_doubles_next = false

	last_play_fly_count = 1
	_apply_ingredient_play(ingredient, track_draw, from_hand_play, hand_slot_index)
	enqueue_presented_stat_snapshot()

	if (
		parrot_doubled_this_ingredient
		and context.outcome == BrewOutcome.Outcome.IN_PROGRESS
		and not context.is_exploded()
	):
		_parrot_repeat_pending = true
		_parrot_repeat_ingredient = ingredient
		_parrot_repeat_from_hand = from_hand_play
		_parrot_repeat_hand_slot = hand_slot_index
	if (
		TrinketEffects.feather_plays_twice(ingredient, context.owned_trinket_ids)
		and context.outcome == BrewOutcome.Outcome.IN_PROGRESS
		and not context.is_exploded()
	):
		_pristine_feather_repeat_pending = true
		_pristine_feather_repeat_ingredient = ingredient
		_pristine_feather_repeat_from_hand = from_hand_play
		_pristine_feather_repeat_hand_slot = hand_slot_index

	if context.is_exploded() and ingredient.id == IngredientEffects.PHOENIX_FEATHER_ID:
		_trigger_phoenix_save()
	return parrot_doubled_this_ingredient


func _try_begin_parrot_repeat_play() -> bool:
	if not _parrot_repeat_pending:
		return false
	if context.outcome != BrewOutcome.Outcome.IN_PROGRESS or context.is_exploded():
		_clear_parrot_repeat()
		return false

	var ingredient: IngredientData = _parrot_repeat_ingredient
	var from_hand := _parrot_repeat_from_hand
	var slot_index := _parrot_repeat_hand_slot
	_clear_parrot_repeat()

	last_play_fly_count = 1
	_apply_ingredient_play(ingredient, false)
	enqueue_presented_stat_snapshot()

	if context.is_exploded():
		_chain_draws_remaining = 0
		if not _try_frog_leg_save():
			_resolve_explosion()

	if from_hand:
		hand_card_played.emit(context, ingredient, slot_index, true)
	else:
		ingredient_drawn.emit(context, ingredient, true)
	brew_updated.emit(context)
	return true


func _clear_parrot_repeat() -> void:
	_parrot_repeat_pending = false
	_parrot_repeat_ingredient = null
	_parrot_repeat_from_hand = false
	_parrot_repeat_hand_slot = -1


func _try_begin_pristine_feather_repeat_play() -> bool:
	if not _pristine_feather_repeat_pending:
		return false
	if context.outcome != BrewOutcome.Outcome.IN_PROGRESS or context.is_exploded():
		_clear_pristine_feather_repeat()
		return false

	var ingredient: IngredientData = _pristine_feather_repeat_ingredient
	var from_hand := _pristine_feather_repeat_from_hand
	var slot_index := _pristine_feather_repeat_hand_slot
	_clear_pristine_feather_repeat()

	last_play_fly_count = 1
	_apply_ingredient_play(ingredient, false)
	enqueue_presented_stat_snapshot()

	if context.is_exploded():
		_chain_draws_remaining = 0
		if not _try_frog_leg_save():
			_resolve_explosion()

	if from_hand:
		hand_card_played.emit(context, ingredient, slot_index, true)
	else:
		ingredient_drawn.emit(context, ingredient, true)
	brew_updated.emit(context)
	return true


func _clear_pristine_feather_repeat() -> void:
	_pristine_feather_repeat_pending = false
	_pristine_feather_repeat_ingredient = null
	_pristine_feather_repeat_from_hand = false
	_pristine_feather_repeat_hand_slot = -1


func _count_hand_ingredients_to_left_from_start(slot_index: int) -> int:
	var count := 0
	for i in range(slot_index):
		if i < _hand_start_slots.size() and _hand_start_slots[i] != null:
			count += 1
	return count


func _count_hand_ingredients_to_right(slot_index: int) -> int:
	var count := 0
	for i in range(slot_index + 1, HAND_SLOT_COUNT):
		if i < _hand_slots.size() and _hand_slots[i] != null:
			count += 1
	return count


func _apply_ingredient_play(
	ingredient: IngredientData,
	track_draw: bool,
	from_hand_play: bool = false,
	hand_slot_index: int = -1
) -> void:
	if track_draw:
		context.drawn_this_brew.append(ingredient)
	if ingredient.id == IngredientEffects.FROG_LEG_ID:
		_frog_legs_played_this_brew.append(ingredient)

	var cauldron_count_before := context.cauldron_contents.size()
	var pending_cobbler := _consume_pending_cobbler_bonus(hand_slot_index, from_hand_play)
	var hand_play := {}
	if from_hand_play and hand_slot_index >= 0:
		hand_play = {
			"play_slot": hand_slot_index,
			"last_hand_slot": _last_hand_play_slot,
			"last_hand_ingredient": _last_hand_play_ingredient,
			"hand_slots": _hand_slots,
		}
	var effect := IngredientEffects.apply(ingredient, context, hand_play)
	_apply_cobbler_retroactive_routing(
		effect,
		from_hand_play,
		hand_slot_index
	)

	var point_value := (
		ingredient.point_value
		+ effect.bonus_score
		+ int(pending_cobbler.get("score", 0))
	)
	var explosive_add := (
		ingredient.explosive_value
		+ effect.bonus_explosiveness
		+ int(pending_cobbler.get("explosiveness", 0))
	)
	if effect.score_penalty > 0:
		point_value = maxi(0, point_value - effect.score_penalty)
	if from_hand_play and hand_slot_index >= 0:
		if ingredient.id == IngredientEffects.SEVERED_RIGHT_HAND_ID:
			point_value += _count_hand_ingredients_to_left_from_start(hand_slot_index)
		elif ingredient.id == IngredientEffects.SEVERED_LEFT_HAND_ID:
			point_value += _count_hand_ingredients_to_right(hand_slot_index)

	if _growth_potion_doubles_remaining > 0:
		point_value *= 2
		explosive_add *= 2
		_growth_potion_doubles_remaining -= 1
	if _AuraEffects.in_rhythm_doubles_ingredient(
		cauldron_count_before,
		context.current_aura
	):
		point_value *= 2
		explosive_add *= 2
	if TrinketEffects.pocket_watch_doubles_ingredient(
		cauldron_count_before,
		context.owned_trinket_ids
	):
		point_value *= 2
		explosive_add *= 2

	if effect.explosion_limit_bonus > 0:
		context.explosion_limit += effect.explosion_limit_bonus

	context.score += point_value
	var unicorn_blocks_explosive := _unicorn_cures_next_explosive
	if unicorn_blocks_explosive:
		if explosive_add > 0:
			explosive_add = 0
		_unicorn_cures_next_explosive = false
	if _ice_cube_shields_remaining > 0:
		if (
			explosive_add > 0
			and context.explosiveness + explosive_add >= context.explosion_limit
		):
			explosive_add = 0
		_ice_cube_shields_remaining -= 1
	if (
		ingredient.id == IngredientEffects.CHICKEN_ID
		and explosive_add > 0
		and context.explosiveness + explosive_add >= context.explosion_limit
	):
		explosive_add = 0
	context.explosiveness += explosive_add
	if effect.bonus_gold > 0:
		context.gold_gained_this_brew += effect.bonus_gold
	if effect.boss_threshold_discount > 0:
		context.boss_threshold_discount_gained += effect.boss_threshold_discount

	if effect.chain_draws > 0:
		_chain_draws_remaining = effect.chain_draws
	if effect.reserve_for_eyeball > 0:
		_eyeball_reserved = context.bag.peek_upcoming_draws(EYEBALL_PEEK_COUNT)
	if effect.cures_next_explosive:
		_unicorn_cures_next_explosive = true
	if ingredient.id == IngredientEffects.PARROT_ID:
		_parrot_doubles_next = true
	if effect.free_shop_rerolls > 0:
		context.free_shop_rerolls_gained += effect.free_shop_rerolls
	if effect.extra_mulligans > 0:
		_mulligan_allowance += effect.extra_mulligans
	if effect.ice_cube_shields > 0:
		_ice_cube_shields_remaining = effect.ice_cube_shields
	if effect.next_hand_draw_count > 0:
		_next_hand_draw_count = effect.next_hand_draw_count
	if effect.bag_grant_ingredient_id != "":
		var granted := GameManager.run.find_ingredient(effect.bag_grant_ingredient_id)
		if granted != null:
			context.bag.grant_ingredient_during_brew(granted)
			last_bag_grant_ingredient = granted
	if ingredient.id == IngredientEffects.JAR_OF_DIRT_ID:
		_consume_jar_of_dirt_use(ingredient)
	if effect.bonus_swap_hands > 0:
		if ingredient.id == IngredientEffects.STIRRING_SPOON_ID:
			_stirring_spoon_hands_remaining += effect.bonus_swap_hands
		elif ingredient.id == IngredientEffects.JUGGLING_CLUB_ID:
			_juggling_club_hands_remaining += effect.bonus_swap_hands
	if effect.vanish_next_ingredient:
		_fairy_vanish_next_ingredient = true
	if effect.poison_apple_delay_scheduled:
		_poison_apple_pending.append(
			{
				"hands_remaining": IngredientEffects.POISON_APPLE_DELAY_HANDS,
				"explosiveness": IngredientEffects.POISON_APPLE_EXPLOSIVENESS_GAIN,
			}
		)
	if effect.growth_potion_doubles > 0:
		_growth_potion_doubles_remaining += effect.growth_potion_doubles
	if effect.bat_wing_pick_count > 0:
		_bat_wing_choices = context.bag.take_random(effect.bat_wing_pick_count)
		_bat_wing_reroll_used = false
		if from_hand_play and hand_slot_index >= 0:
			_bat_wing_source_slot_index = hand_slot_index
		else:
			_bat_wing_source_slot_index = -1
	if effect.voodoo_doll_arms_copy:
		_voodoo_doll_arms_copy = true
	else:
		_try_consume_voodoo_copy(ingredient)

	if from_hand_play and hand_slot_index >= 0:
		_last_hand_play_slot = hand_slot_index
		_last_hand_play_ingredient = ingredient

	_try_bubbling_brew_return(ingredient, cauldron_count_before)


func _apply_cobbler_retroactive_routing(
	effect: IngredientEffects.EffectResult,
	from_hand_play: bool,
	hand_slot_index: int
) -> void:
	if effect.cobbler_apply_retroactive_immediately:
		_apply_immediate_cobbler_retroactive_bonus(effect)
		return
	if effect.cobbler_retroactive_slot < 0:
		return
	if (
		from_hand_play
		and hand_slot_index >= 0
		and effect.cobbler_retroactive_slot < hand_slot_index
	):
		_apply_immediate_cobbler_retroactive_bonus(effect)
		return
	_store_pending_cobbler_bonus(
		effect.cobbler_retroactive_slot,
		effect.cobbler_retroactive_score,
		effect.cobbler_retroactive_explosiveness
	)


func _apply_immediate_cobbler_retroactive_bonus(
	effect: IngredientEffects.EffectResult
) -> void:
	if effect.cobbler_retroactive_score != 0:
		context.score += effect.cobbler_retroactive_score
	if effect.cobbler_retroactive_explosiveness != 0:
		context.explosiveness += effect.cobbler_retroactive_explosiveness


func _try_bubbling_brew_return(
	ingredient: IngredientData,
	cauldron_count_before: int
) -> void:
	if ingredient == null:
		return
	if context.outcome != BrewOutcome.Outcome.IN_PROGRESS:
		return
	if not _AuraEffects.bubbling_brew_returns_ingredient(
		cauldron_count_before,
		context.current_aura
	):
		return
	_remove_from_cauldron(ingredient)
	context.bag.return_to_bag([ingredient])
	_pending_bubbling_brew_return = ingredient


func _consume_pending_cobbler_bonus(
	hand_slot_index: int,
	from_hand_play: bool
) -> Dictionary:
	if not from_hand_play or hand_slot_index < 0:
		return {"score": 0, "explosiveness": 0}
	if not _pending_cobbler_slot_bonuses.has(hand_slot_index):
		return {"score": 0, "explosiveness": 0}
	var bonus: Dictionary = _pending_cobbler_slot_bonuses[hand_slot_index]
	_pending_cobbler_slot_bonuses.erase(hand_slot_index)
	return bonus


func _store_pending_cobbler_bonus(
	slot_index: int,
	bonus_score: int,
	bonus_explosiveness: int
) -> void:
	if slot_index < 0 or (bonus_score == 0 and bonus_explosiveness == 0):
		return
	var existing: Dictionary = _pending_cobbler_slot_bonuses.get(slot_index, {})
	existing["score"] = int(existing.get("score", 0)) + bonus_score
	existing["explosiveness"] = int(existing.get("explosiveness", 0)) + bonus_explosiveness
	_pending_cobbler_slot_bonuses[slot_index] = existing


func _note_booberry_played_this_hand(ingredient: IngredientData) -> void:
	if _hand_phase != HandPhase.PLAYING:
		return
	if ingredient == null or ingredient.id != IngredientEffects.BOOBERRY_ID:
		return
	_booberry_count_this_hand += 1


func _apply_booberry_end_of_hand_penalty() -> void:
	if context.outcome != BrewOutcome.Outcome.IN_PROGRESS:
		_booberry_count_this_hand = 0
		return
	if _booberry_count_this_hand <= 0:
		return
	var penalty := _booberry_count_this_hand * IngredientEffects.BOOBERRY_HAND_END_PENALTY
	context.explosiveness = maxi(0, context.explosiveness - penalty)
	_booberry_count_this_hand = 0


func _tick_poison_apple_on_new_hand() -> void:
	if context.outcome != BrewOutcome.Outcome.IN_PROGRESS:
		_poison_apple_pending.clear()
		return
	if _poison_apple_pending.is_empty():
		return

	var triggered := false
	var index := 0
	while index < _poison_apple_pending.size():
		var entry: Dictionary = _poison_apple_pending[index]
		entry["hands_remaining"] = int(entry.get("hands_remaining", 0)) - 1
		if entry["hands_remaining"] <= 0:
			context.explosiveness += int(
				entry.get("explosiveness", IngredientEffects.POISON_APPLE_EXPLOSIVENESS_GAIN)
			)
			_poison_apple_pending.remove_at(index)
			triggered = true
			continue
		index += 1

	if not triggered:
		return

	if context.is_exploded():
		if not _try_frog_leg_save():
			_resolve_explosion()


func _compute_and_consume_hand_swap_bonus() -> int:
	var spoon_active := _stirring_spoon_hands_remaining > 0
	var juggling_active := _juggling_club_hands_remaining > 0
	var lucky_active := _lucky_coin_swap_hands_remaining > 0

	var bonus := 0
	if spoon_active:
		bonus += 1
	if juggling_active:
		bonus += 1
	if lucky_active:
		bonus += 1
	if spoon_active and juggling_active:
		bonus += 1

	if spoon_active:
		_stirring_spoon_hands_remaining -= 1
	if juggling_active:
		_juggling_club_hands_remaining -= 1
	if lucky_active:
		_lucky_coin_swap_hands_remaining -= 1

	return bonus


func _consume_jar_of_dirt_use(jar_chip: IngredientData) -> void:
	if jar_chip == null:
		return
	if jar_chip.jar_of_dirt_uses_remaining < 0:
		jar_chip.jar_of_dirt_uses_remaining = IngredientEffects.JAR_OF_DIRT_MAX_USES
	jar_chip.jar_of_dirt_uses_remaining -= 1
	if jar_chip.jar_of_dirt_uses_remaining > 0:
		return
	context.bag.remove_one_chip_from_master(jar_chip)
	_jar_of_dirt_broke_poof_pending = true


func _try_vanish_ingredient_from_fairy(
	ingredient: IngredientData,
	track_draw: bool
) -> bool:
	if not _fairy_vanish_next_ingredient:
		return false

	_fairy_vanish_next_ingredient = false
	if track_draw:
		context.drawn_this_brew.append(ingredient)
	context.bag.remove_one_chip_from_master(ingredient)
	last_play_fly_count = 1
	last_play_fairy_poof = true
	enqueue_presented_stat_snapshot()
	return true


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


func ensure_brew_finalized() -> void:
	if _brew_finalized:
		return
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


func _finalize_brew(clear_hand: bool = true) -> void:
	if _brew_finalized:
		return
	_brew_finalized = true
	_purchased_mulligans_this_brew = 0
	_refresh_mulligan_allowance()
	_clear_presented_stat_snapshots()
	sync_presented_stats_from_context()
	if clear_hand:
		_reset_draw_flow_state()
	else:
		_hand_end_effects_pending = false
		_chain_draws_remaining = 0
		_parrot_repeat_pending = false
		_clear_parrot_repeat()
	context.bag.reset_for_brew()
	brew_updated.emit(context)


func get_explosiveness_for_hud(presentation_in_progress: bool) -> int:
	if presentation_in_progress or _hand_phase == HandPhase.PLAYING:
		return presented_explosiveness
	return context.explosiveness


func get_explosion_limit_for_hud() -> int:
	return context.explosion_limit


func _compute_base_explosion_limit(
	aura: AuraData,
	explosion_limit_bonus: int = 0
) -> int:
	var limit := GameConstants.DEFAULT_EXPLOSION_LIMIT + explosion_limit_bonus
	if aura != null:
		limit += aura.explosion_limit_modifier
	return maxi(1, limit)


func _reset_presented_stats() -> void:
	presented_score = context.score
	presented_explosiveness = context.explosiveness
	presented_gold_gained_this_brew = context.gold_gained_this_brew
	presented_boss_threshold_discount_gained = context.boss_threshold_discount_gained
	_reset_presented_stat_deltas()


func sync_presented_stats_from_context() -> void:
	_reset_presented_stats()


func has_pending_stat_snapshots() -> bool:
	return not _presented_stat_snapshots.is_empty()


func enqueue_presented_stat_snapshot() -> void:
	_presented_stat_snapshots.append(
		{
			"score": context.score,
			"explosiveness": context.explosiveness,
			"gold_gained": context.gold_gained_this_brew,
			"boss_discount": context.boss_threshold_discount_gained,
		}
	)


func get_last_presented_stat_deltas() -> Dictionary:
	return last_presented_stat_deltas.duplicate()


func advance_presented_stats() -> void:
	var previous_score := presented_score
	var previous_explosiveness := presented_explosiveness
	var previous_gold_reward := calculate_display_gold_reward()

	if _presented_stat_snapshots.is_empty():
		sync_presented_stats_from_context()
		_reset_presented_stat_deltas()
		return

	var snapshot: Dictionary = _presented_stat_snapshots.pop_front()
	presented_score = int(snapshot.get("score", context.score))
	presented_explosiveness = int(snapshot.get("explosiveness", context.explosiveness))
	presented_gold_gained_this_brew = int(
		snapshot.get("gold_gained", context.gold_gained_this_brew)
	)
	presented_boss_threshold_discount_gained = int(
		snapshot.get("boss_discount", context.boss_threshold_discount_gained)
	)
	last_presented_stat_deltas = {
		"score": presented_score - previous_score,
		"explosiveness": presented_explosiveness - previous_explosiveness,
		"gold_reward": calculate_display_gold_reward() - previous_gold_reward,
	}


func _reset_presented_stat_deltas() -> void:
	last_presented_stat_deltas = {
		"score": 0,
		"explosiveness": 0,
		"gold_reward": 0,
	}


func _clear_presented_stat_snapshots() -> void:
	_presented_stat_snapshots.clear()


func get_pending_hand_draw_target_slots() -> Array:
	return _pending_hand_draw_target_slots.duplicate()


func _collect_hand_entries() -> Array:
	var entries: Array = []
	for slot_index in range(HAND_SLOT_COUNT):
		var ingredient: IngredientData = _hand_slots[slot_index]
		if ingredient == null:
			continue
		entries.append(
			{
				"slot_index": slot_index,
				"ingredient": ingredient,
			}
		)
	return entries


func _collect_hand_ingredients() -> Array[IngredientData]:
	var ingredients: Array[IngredientData] = []
	for slot_index in range(HAND_SLOT_COUNT):
		var ingredient: IngredientData = _hand_slots[slot_index]
		if ingredient != null:
			ingredients.append(ingredient)
	return ingredients


func _count_empty_hand_slots() -> int:
	var count := 0
	for slot in _hand_slots:
		if slot == null:
			count += 1
	return count


func _compute_hand_draw_target_slots(draw_count: int) -> Array:
	var targets: Array = []
	for slot_index in range(HAND_SLOT_COUNT - 1, -1, -1):
		if _hand_slots[slot_index] != null:
			continue
		targets.append(slot_index)
		if targets.size() >= draw_count:
			break
	return targets


func _compute_honey_skipped_slots() -> Dictionary:
	var skipped := {}
	for slot_index in range(1, HAND_SLOT_COUNT):
		if slot_index >= _hand_start_slots.size():
			continue
		var ingredient: IngredientData = _hand_start_slots[slot_index]
		if ingredient == null or ingredient.id != IngredientEffects.HONEY_ID:
			continue
		var left_ingredient: IngredientData = _hand_start_slots[slot_index - 1]
		if left_ingredient != null:
			skipped[slot_index - 1] = true
	return skipped


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
		_lucky_coin_swap_hands_remaining += 1
	_lucky_coin_in_current_hand = false


func _reset_draw_flow_state() -> void:
	_hand_end_effects_pending = false
	last_bag_grant_ingredient = null
	_hand_phase = HandPhase.BAG
	_reset_hand_slots()
	_hand_start_slots.clear()
	_hand_undo_stack.clear()
	_hand_swap_allowance = 1
	_hand_swaps_used = 0
	_stirring_spoon_hands_remaining = 0
	_juggling_club_hands_remaining = 0
	_lucky_coin_swap_hands_remaining = 0
	_next_hand_draw_count = HAND_DRAW_COUNT
	_lucky_coin_in_current_hand = false
	_play_slot_cursor = 0
	_pending_hand_draw.clear()
	_pending_hand_draw_target_slots.clear()
	_honey_skipped_slots.clear()
	_reset_hand_draw_display_reserve()
	_chain_draws_remaining = 0
	_eyeball_reserved.clear()
	_eyeball_puzzle_active = false
	_bat_wing_choices.clear()
	_bat_wing_picker_active = false
	_bat_wing_reroll_used = false
	_bat_wing_source_slot_index = -1
	_last_hand_play_slot = -1
	_last_hand_play_ingredient = null
	_pending_cobbler_slot_bonuses.clear()
	_unicorn_cures_next_explosive = false
	_ice_cube_shields_remaining = 0
	_parrot_doubles_next = false
	_clear_parrot_repeat()
	_clear_pristine_feather_repeat()
	_voodoo_doll_arms_copy = false
	_frog_leg_save_pending = false
	_fairy_vanish_next_ingredient = false
	_jar_of_dirt_broke_poof_pending = false
	_pending_bubbling_brew_return = null
	_pending_gecko_stay_slot = -1
	_pending_time_turner_new_hand.clear()
	_pending_time_turner_target_slots.clear()
	_frog_legs_played_this_brew.clear()
	_booberry_count_this_hand = 0
	_poison_apple_pending.clear()
	_growth_potion_doubles_remaining = 0


func calculate_gold_reward() -> int:
	return _calculate_gold_reward_from(
		context.score,
		context.gold_gained_this_brew
	)


func calculate_display_gold_reward() -> int:
	return _calculate_gold_reward_from(
		presented_score,
		presented_gold_gained_this_brew
	)


func _calculate_gold_reward_from(score: int, bonus_gold: int) -> int:
	var base_reward := score if score <= 14 else 14 + int((score - 14) / 2)
	var total := base_reward + bonus_gold
	if _gloom_weed_doubles_gold():
		total *= 2
	return _AuraEffects.apply_gold_multiplier(total, context.current_aura)