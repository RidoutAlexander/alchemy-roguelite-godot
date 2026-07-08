class_name HandSlotEffects
extends RefCounted

const HONEY_ID := IngredientEffects.HONEY_ID


static func compute_entries(
	hand_slots: Array,
	hand_slot_count: int,
	layout_slots: Array = [],
	play_steps: Array = [],
	owned_trinket_ids: Array = [],
	unicorn_cured_slots: Array = []
) -> Array:
	var reference := layout_slots if not layout_slots.is_empty() else hand_slots
	var per_slot: Array = []
	for _i in hand_slot_count:
		per_slot.append([])
	_append_honey_entries(per_slot, reference, hand_slot_count)
	_append_gecko_assistant_entries_from_steps(per_slot, play_steps)
	_append_pocket_watch_entries_from_steps(per_slot, play_steps)
	_append_unicorn_horn_entries(per_slot, unicorn_cured_slots)
	_append_pristine_feather_entries(per_slot, hand_slots, owned_trinket_ids)
	return per_slot


static func compute_honey_skipped_slots(
	slots: Array,
	hand_slot_count: int
) -> Dictionary:
	var skipped := {}
	for slot_index in range(1, hand_slot_count):
		if slot_index >= slots.size():
			continue
		var ingredient: IngredientData = slots[slot_index]
		if ingredient == null or ingredient.id != HONEY_ID:
			continue
		var left_ingredient: IngredientData = slots[slot_index - 1]
		if left_ingredient != null:
			skipped[slot_index - 1] = true
	return skipped


static func compute_gecko_stay_slots(
	hand_slots: Array,
	hand_slot_count: int,
	honey_skipped_slots: Dictionary,
	cauldron_count_before_hand: int,
	owned_trinket_ids: Array
) -> Dictionary:
	var stayed := {}
	if not TrinketEffects.has_gecko_assistant(owned_trinket_ids):
		return stayed

	var cauldron_count := cauldron_count_before_hand
	var gecko_stays_consumed := 0
	for slot_index in range(hand_slot_count):
		if honey_skipped_slots.has(slot_index):
			continue
		if slot_index >= hand_slots.size() or hand_slots[slot_index] == null:
			continue
		var ingredient: IngredientData = hand_slots[slot_index]
		if IngredientEffects.skips_hand_stay_interval_counter(ingredient):
			continue
		if TrinketEffects.gecko_assistant_stays_in_hand(
			cauldron_count,
			owned_trinket_ids,
			gecko_stays_consumed
		):
			stayed[slot_index] = true
			gecko_stays_consumed += 1
		else:
			cauldron_count += 1
	return stayed


static func _append_honey_entries(
	per_slot: Array,
	slots: Array,
	hand_slot_count: int
) -> void:
	for slot_index in range(1, hand_slot_count):
		if slot_index >= slots.size():
			continue
		var honey: IngredientData = slots[slot_index]
		if honey == null or honey.id != HONEY_ID:
			continue
		var left_ingredient: IngredientData = slots[slot_index - 1]
		if left_ingredient == null:
			continue
		if slot_index - 1 >= per_slot.size():
			continue
		per_slot[slot_index - 1].append(
			{
				"ingredient_id": HONEY_ID,
				"overlay_text": "",
			}
		)


static func _append_pocket_watch_entries_from_steps(
	per_slot: Array,
	play_steps: Array
) -> void:
	for slot_index in HandPlayPreview.pocket_watch_slots(play_steps):
		if slot_index >= 0 and slot_index < per_slot.size():
			per_slot[slot_index].append(
				{
					"trinket_id": TrinketEffects.POCKET_WATCH_ID,
					"overlay_text": "",
				}
			)


static func _append_gecko_assistant_entries_from_steps(
	per_slot: Array,
	play_steps: Array
) -> void:
	for step in play_steps:
		if not bool(step.get("gecko_stays", false)):
			continue
		var slot_index := int(step.get("slot_index", -1))
		if slot_index >= 0 and slot_index < per_slot.size():
			per_slot[slot_index].append(
				{
					"trinket_id": TrinketEffects.GECKO_ASSISTANT_ID,
					"overlay_text": "",
				}
			)


static func _append_unicorn_horn_entries(
	per_slot: Array,
	unicorn_cured_slots: Array
) -> void:
	for slot_index in unicorn_cured_slots:
		var cured_slot := int(slot_index)
		if cured_slot < 0 or cured_slot >= per_slot.size():
			continue
		per_slot[cured_slot].append(
			{
				"ingredient_id": IngredientEffects.UNICORN_HORN_ID,
				"overlay_text": "",
			}
		)


static func _append_pristine_feather_entries(
	per_slot: Array,
	hand_slots: Array,
	owned_trinket_ids: Array
) -> void:
	if not TrinketEffects.has_pristine_feather(owned_trinket_ids):
		return
	for slot_index in range(hand_slots.size()):
		if slot_index >= per_slot.size():
			continue
		var ingredient: IngredientData = hand_slots[slot_index]
		if not IngredientEffects.is_feather_ingredient(ingredient):
			continue
		per_slot[slot_index].append(
			{
				"trinket_id": TrinketEffects.PRISTINE_FEATHER_ID,
				"overlay_text": "",
			}
		)