class_name HandSlotEffects
extends RefCounted

const HONEY_ID := IngredientEffects.HONEY_ID


static func compute_entries(
	hand_slots: Array,
	hand_slot_count: int,
	layout_slots: Array = []
) -> Array:
	var reference := layout_slots if not layout_slots.is_empty() else hand_slots
	var per_slot: Array = []
	for _i in hand_slot_count:
		per_slot.append([])
	_append_honey_entries(per_slot, reference, hand_slot_count)
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