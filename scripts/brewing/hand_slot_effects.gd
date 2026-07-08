class_name HandSlotEffects
extends RefCounted

const HONEY_ID := IngredientEffects.HONEY_ID


static func compute_entries(
	hand_slots: Array,
	hand_slot_count: int,
	layout_slots: Array = [],
	cauldron_count_before_hand: int = 0,
	owned_trinket_ids: Array = []
) -> Array:
	var reference := layout_slots if not layout_slots.is_empty() else hand_slots
	var per_slot: Array = []
	for _i in hand_slot_count:
		per_slot.append([])
	_append_honey_entries(per_slot, reference, hand_slot_count)
	_append_pocket_watch_entries(
		per_slot,
		hand_slots,
		hand_slot_count,
		cauldron_count_before_hand,
		owned_trinket_ids
	)
	_append_gecko_assistant_entries(
		per_slot,
		hand_slots,
		hand_slot_count,
		cauldron_count_before_hand,
		owned_trinket_ids
	)
	_append_pristine_feather_entries(per_slot, hand_slots, owned_trinket_ids)
	return per_slot


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


static func _append_pocket_watch_entries(
	per_slot: Array,
	hand_slots: Array,
	hand_slot_count: int,
	cauldron_count_before_hand: int,
	owned_trinket_ids: Array
) -> void:
	if not TrinketEffects.has_pocket_watch(owned_trinket_ids):
		return

	var play_order: Array[int] = []
	for slot_index in range(hand_slots.size()):
		if hand_slots[slot_index] != null:
			play_order.append(slot_index)

	var cauldron_count := cauldron_count_before_hand
	for play_slot in play_order:
		if TrinketEffects.pocket_watch_doubles_ingredient(cauldron_count, owned_trinket_ids):
			if play_slot >= 0 and play_slot < per_slot.size():
				per_slot[play_slot].append(
					{
						"trinket_id": TrinketEffects.POCKET_WATCH_ID,
						"overlay_text": "",
					}
				)
		cauldron_count += 1


static func _append_gecko_assistant_entries(
	per_slot: Array,
	hand_slots: Array,
	hand_slot_count: int,
	cauldron_count_before_hand: int,
	owned_trinket_ids: Array
) -> void:
	if not TrinketEffects.has_gecko_assistant(owned_trinket_ids):
		return

	var play_order: Array[int] = []
	for slot_index in range(hand_slots.size()):
		if hand_slots[slot_index] != null:
			play_order.append(slot_index)

	var cauldron_count := cauldron_count_before_hand
	for play_slot in play_order:
		if TrinketEffects.gecko_assistant_stays_in_hand(cauldron_count, owned_trinket_ids):
			if play_slot >= 0 and play_slot < per_slot.size():
				per_slot[play_slot].append(
					{
						"trinket_id": TrinketEffects.GECKO_ASSISTANT_ID,
						"overlay_text": "",
					}
				)
		cauldron_count += 1


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