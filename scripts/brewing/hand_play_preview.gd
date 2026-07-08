class_name HandPlayPreview
extends RefCounted

const _AuraEffects := preload("res://scripts/brewing/aura_effects.gd")

static var _BAT_WING_PICK_PLACEHOLDER: IngredientData


static func compute_steps(
	hand_slots: Array,
	hand_slot_count: int,
	cauldron_contents: Array,
	ingredients_added_before: int,
	owned_trinket_ids: Array,
	aura: AuraData,
	honey_skipped_override: Dictionary = {},
	gecko_stayed_override: Dictionary = {},
	parrot_doubles_next: bool = false,
	bat_wing_pick_overrides: Dictionary = {}
) -> Array:
	var steps: Array = []
	var honey_skipped := honey_skipped_override
	if honey_skipped.is_empty():
		honey_skipped = HandSlotEffects.compute_honey_skipped_slots(hand_slots, hand_slot_count)
	var interval_count_before := IngredientEffects.count_hand_stay_interval_plays(cauldron_contents)
	var gecko_stayed := gecko_stayed_override
	if gecko_stayed.is_empty():
		gecko_stayed = HandSlotEffects.compute_gecko_stay_slots(
			hand_slots,
			hand_slot_count,
			honey_skipped,
			interval_count_before,
			owned_trinket_ids
		)

	var sim_cauldron: Array = cauldron_contents.duplicate()
	var sim_ingredients_added := ingredients_added_before
	var parrot_repeats_next := parrot_doubles_next

	for slot_index in range(hand_slot_count):
		if honey_skipped.has(slot_index):
			continue
		if slot_index >= hand_slots.size() or hand_slots[slot_index] == null:
			continue

		var ingredient: IngredientData = hand_slots[slot_index]
		if gecko_stayed.has(slot_index):
			steps.append(
				{
					"slot_index": slot_index,
					"ingredient": ingredient,
					"plays_to_cauldron": false,
					"gecko_stays": true,
				}
			)
			continue

		var parrot_repeat_this := parrot_repeats_next
		parrot_repeats_next = false

		_record_hand_slot_play(
			steps,
			slot_index,
			ingredient,
			sim_cauldron,
			sim_ingredients_added,
			aura,
			owned_trinket_ids,
			bat_wing_pick_overrides,
			false,
			false
		)

		if ingredient.id == IngredientEffects.PARROT_ID:
			parrot_repeats_next = true

		if parrot_repeat_this:
			_record_hand_slot_play(
				steps,
				slot_index,
				ingredient,
				sim_cauldron,
				sim_ingredients_added,
				aura,
				owned_trinket_ids,
				bat_wing_pick_overrides,
				true,
				false
			)

		if TrinketEffects.feather_plays_twice(ingredient, owned_trinket_ids):
			_record_hand_slot_play(
				steps,
				slot_index,
				ingredient,
				sim_cauldron,
				sim_ingredients_added,
				aura,
				owned_trinket_ids,
				bat_wing_pick_overrides,
				false,
				true
			)

	return steps


static func _record_hand_slot_play(
	steps: Array,
	slot_index: int,
	ingredient: IngredientData,
	sim_cauldron: Array,
	sim_ingredients_added: int,
	aura: AuraData,
	owned_trinket_ids: Array,
	bat_wing_pick_overrides: Dictionary,
	parrot_repeat: bool,
	feather_repeat: bool
) -> void:
	_record_cauldron_play(
		steps,
		slot_index,
		ingredient,
		sim_cauldron,
		sim_ingredients_added,
		aura,
		owned_trinket_ids,
		{
			"parrot_repeat": parrot_repeat,
			"feather_repeat": feather_repeat,
		}
	)
	if ingredient != null and ingredient.id == IngredientEffects.BAT_WING_ID:
		_simulate_bat_wing_pick_chain(
			steps,
			slot_index,
			sim_cauldron,
			sim_ingredients_added,
			aura,
			owned_trinket_ids,
			bat_wing_pick_overrides,
			true
		)


static func _simulate_bat_wing_pick_chain(
	steps: Array,
	source_slot: int,
	sim_cauldron: Array,
	sim_ingredients_added: int,
	aura: AuraData,
	owned_trinket_ids: Array,
	bat_wing_pick_overrides: Dictionary,
	use_pick_override: bool
) -> void:
	var pick: IngredientData = _generic_bat_wing_pick()
	if use_pick_override and bat_wing_pick_overrides.has(source_slot):
		var override_pick: Variant = bat_wing_pick_overrides[source_slot]
		if override_pick is IngredientData:
			pick = override_pick
	_record_cauldron_play(
		steps,
		source_slot,
		pick,
		sim_cauldron,
		sim_ingredients_added,
		aura,
		owned_trinket_ids,
		{"bat_wing_pick": true}
	)
	if pick.id == IngredientEffects.BAT_WING_ID:
		_simulate_bat_wing_pick_chain(
			steps,
			source_slot,
			sim_cauldron,
			sim_ingredients_added,
			aura,
			owned_trinket_ids,
			bat_wing_pick_overrides,
			false
		)


static func _record_cauldron_play(
	steps: Array,
	slot_index: int,
	ingredient: IngredientData,
	sim_cauldron: Array,
	sim_ingredients_added: int,
	aura: AuraData,
	owned_trinket_ids: Array,
	extra_flags: Dictionary = {}
) -> void:
	var cauldron_count_before := sim_cauldron.size()
	var ingredients_added_before := sim_ingredients_added
	var counts_for_added := (
		ingredient != null
		and not IngredientEffects.skips_hand_stay_interval_counter(ingredient)
	)
	var bubbling_returns := (
		counts_for_added
		and _AuraEffects.bubbling_brew_returns_ingredient(
			ingredients_added_before,
			aura
		)
	)

	if ingredient != null:
		sim_cauldron.append(ingredient)
	if bubbling_returns:
		sim_cauldron.pop_back()
	if counts_for_added:
		sim_ingredients_added += 1

	steps.append(
		{
			"slot_index": slot_index,
			"ingredient": ingredient,
			"plays_to_cauldron": true,
			"gecko_stays": false,
			"cauldron_count_before": cauldron_count_before,
			"ingredients_added_before": ingredients_added_before,
			"in_rhythm_doubles": _AuraEffects.in_rhythm_doubles_ingredient(
				cauldron_count_before,
				aura
			),
			"pocket_watch_doubles": TrinketEffects.pocket_watch_doubles_ingredient(
				cauldron_count_before,
				owned_trinket_ids
			),
			"bubbling_returns": bubbling_returns,
			"parrot_repeat": bool(extra_flags.get("parrot_repeat", false)),
			"feather_repeat": bool(extra_flags.get("feather_repeat", false)),
			"bat_wing_pick": bool(extra_flags.get("bat_wing_pick", false)),
		}
	)


static func _generic_bat_wing_pick() -> IngredientData:
	if _BAT_WING_PICK_PLACEHOLDER == null:
		_BAT_WING_PICK_PLACEHOLDER = IngredientData.new(
			"__bat_wing_pick_preview__",
			"Pick",
			"",
			0,
			0,
			0,
			IngredientData.Rarity.COMMON
		)
	return _BAT_WING_PICK_PLACEHOLDER


static func in_rhythm_double_slots(steps: Array) -> Array[int]:
	var slots: Array[int] = []
	for step in steps:
		if not bool(step.get("plays_to_cauldron", false)):
			continue
		var slot_index := int(step.get("slot_index", -1))
		if slot_index < 0:
			continue
		if bool(step.get("in_rhythm_doubles", false)):
			slots.append(slot_index)
	return slots


static func bubbling_brew_slots(steps: Array) -> Array[int]:
	var slots: Array[int] = []
	for step in steps:
		if not bool(step.get("plays_to_cauldron", false)):
			continue
		var slot_index := int(step.get("slot_index", -1))
		if slot_index < 0:
			continue
		if bool(step.get("bubbling_returns", false)):
			slots.append(slot_index)
	return slots


static func pocket_watch_slots(steps: Array) -> Array[int]:
	var slots: Array[int] = []
	for step in steps:
		if not bool(step.get("plays_to_cauldron", false)):
			continue
		var slot_index := int(step.get("slot_index", -1))
		if slot_index < 0:
			continue
		if bool(step.get("pocket_watch_doubles", false)):
			slots.append(slot_index)
	return slots


static func countdown_for_aura(
	steps: Array,
	cauldron_count: int,
	ingredients_added: int,
	aura: AuraData
) -> int:
	if aura == null:
		return 0
	match aura.id:
		GameConstants.IN_RHYTHM_AURA_ID:
			return countdown_to_in_rhythm(steps, cauldron_count, aura)
		GameConstants.BUBBLING_BREW_AURA_ID:
			return countdown_to_bubbling_brew(steps, ingredients_added, aura)
	return 0


static func countdown_to_in_rhythm(
	steps: Array,
	cauldron_count: int,
	aura: AuraData
) -> int:
	if aura == null or aura.id != GameConstants.IN_RHYTHM_AURA_ID:
		return 0
	var plays_until := 0
	var projected_cauldron := cauldron_count
	for step in steps:
		if not bool(step.get("plays_to_cauldron", false)):
			continue
		plays_until += 1
		if bool(step.get("in_rhythm_doubles", false)):
			return plays_until
		projected_cauldron += 1
	return _AuraEffects.in_rhythm_countdown(projected_cauldron, aura)


static func countdown_to_bubbling_brew(
	steps: Array,
	ingredients_added: int,
	aura: AuraData
) -> int:
	if aura == null or aura.id != GameConstants.BUBBLING_BREW_AURA_ID:
		return 0
	var adds_until := 0
	var projected_added := ingredients_added
	for step in steps:
		if not bool(step.get("plays_to_cauldron", false)):
			continue
		var ingredient: IngredientData = step.get("ingredient")
		var counts_for_added := (
			ingredient != null
			and not IngredientEffects.skips_hand_stay_interval_counter(ingredient)
		)
		if not counts_for_added:
			continue
		adds_until += 1
		if bool(step.get("bubbling_returns", false)):
			return adds_until
		projected_added += 1
	return _AuraEffects.bubbling_brew_countdown(projected_added, aura)