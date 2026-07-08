class_name HandPlayPreview
extends RefCounted

const _AuraEffects := preload("res://scripts/brewing/aura_effects.gd")


static func compute_steps(
	hand_slots: Array,
	hand_slot_count: int,
	cauldron_contents: Array,
	ingredients_added_before: int,
	owned_trinket_ids: Array,
	aura: AuraData
) -> Array:
	var steps: Array = []
	var honey_skipped := HandSlotEffects.compute_honey_skipped_slots(hand_slots, hand_slot_count)
	var interval_count_before := IngredientEffects.count_hand_stay_interval_plays(cauldron_contents)
	var gecko_stayed := HandSlotEffects.compute_gecko_stay_slots(
		hand_slots,
		hand_slot_count,
		honey_skipped,
		interval_count_before,
		owned_trinket_ids
	)

	var sim_cauldron: Array = cauldron_contents.duplicate()
	var sim_ingredients_added := ingredients_added_before

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

		var cauldron_count_before := sim_cauldron.size()
		var ingredients_added_before_step := sim_ingredients_added
		var counts_for_ingredients_added := (
			not IngredientEffects.skips_hand_stay_interval_counter(ingredient)
		)
		var bubbling_returns := (
			counts_for_ingredients_added
			and _AuraEffects.bubbling_brew_returns_ingredient(
				ingredients_added_before_step,
				aura
			)
		)

		sim_cauldron.append(ingredient)
		if bubbling_returns:
			sim_cauldron.pop_back()
		if counts_for_ingredients_added:
			sim_ingredients_added += 1

		steps.append(
			{
				"slot_index": slot_index,
				"ingredient": ingredient,
				"plays_to_cauldron": true,
				"gecko_stays": false,
				"cauldron_count_before": cauldron_count_before,
				"ingredients_added_before": ingredients_added_before_step,
				"in_rhythm_doubles": _AuraEffects.in_rhythm_doubles_ingredient(
					cauldron_count_before,
					aura
				),
				"pocket_watch_doubles": TrinketEffects.pocket_watch_doubles_ingredient(
					cauldron_count_before,
					owned_trinket_ids
				),
				"bubbling_returns": bubbling_returns,
			}
		)

	return steps


static func in_rhythm_double_slots(steps: Array) -> Array[int]:
	var slots: Array[int] = []
	for step in steps:
		if not bool(step.get("plays_to_cauldron", false)):
			continue
		if bool(step.get("in_rhythm_doubles", false)):
			slots.append(int(step.get("slot_index", -1)))
	return slots


static func bubbling_brew_slots(steps: Array) -> Array[int]:
	var slots: Array[int] = []
	for step in steps:
		if not bool(step.get("plays_to_cauldron", false)):
			continue
		if bool(step.get("bubbling_returns", false)):
			slots.append(int(step.get("slot_index", -1)))
	return slots


static func pocket_watch_slots(steps: Array) -> Array[int]:
	var slots: Array[int] = []
	for step in steps:
		if not bool(step.get("plays_to_cauldron", false)):
			continue
		if bool(step.get("pocket_watch_doubles", false)):
			slots.append(int(step.get("slot_index", -1)))
	return slots