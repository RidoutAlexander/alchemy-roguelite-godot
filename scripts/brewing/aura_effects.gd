class_name AuraEffects
extends RefCounted

# score_multiplier_percent in aura data adjusts the level threshold (e.g. Low Expectations, Under Pressure).


static func apply_threshold_modifier(threshold: int, aura: AuraData) -> int:
	if aura == null or aura.score_multiplier_percent == 100:
		return threshold
	return maxi(0, threshold * aura.score_multiplier_percent / 100)


static func apply_gold_multiplier(amount: int, aura: AuraData) -> int:
	if aura == null or aura.gold_multiplier_percent == 100:
		return amount
	return amount * aura.gold_multiplier_percent / 100


static func in_rhythm_doubles_ingredient(cauldron_count_before_add: int, aura: AuraData) -> bool:
	if aura == null or aura.id != GameConstants.IN_RHYTHM_AURA_ID:
		return false
	var count_after := cauldron_count_before_add + 1
	return count_after % 3 == 0


static func in_rhythm_countdown(cauldron_count: int, aura: AuraData) -> int:
	if aura == null or aura.id != GameConstants.IN_RHYTHM_AURA_ID:
		return 0
	var remainder := cauldron_count % 3
	if remainder == 0:
		return 3
	return 3 - remainder


static func uses_interval_countdown(aura: AuraData) -> bool:
	if aura == null:
		return false
	return (
		aura.id == GameConstants.IN_RHYTHM_AURA_ID
		or aura.id == GameConstants.BUBBLING_BREW_AURA_ID
	)


static func interval_countdown_from_state(
	aura: AuraData,
	cauldron_count: int,
	ingredients_added: int
) -> int:
	if aura == null:
		return 0
	match aura.id:
		GameConstants.IN_RHYTHM_AURA_ID:
			return in_rhythm_countdown(cauldron_count, aura)
		GameConstants.BUBBLING_BREW_AURA_ID:
			return bubbling_brew_countdown(ingredients_added, aura)
	return 0


static func in_rhythm_double_hand_slots(
	hand_slots: Array,
	cauldron_count_before_hand: int,
	aura: AuraData,
	hand_slot_count: int = 5
) -> Array[int]:
	if aura == null or aura.id != GameConstants.IN_RHYTHM_AURA_ID:
		return []

	var doubled_slots: Array[int] = []
	var cauldron_count := cauldron_count_before_hand
	for slot_index in hand_slot_count:
		if slot_index >= hand_slots.size() or hand_slots[slot_index] == null:
			continue
		if in_rhythm_doubles_ingredient(cauldron_count, aura):
			doubled_slots.append(slot_index)
		cauldron_count += 1
	return doubled_slots


static func bubbling_brew_returns_ingredient(
	ingredients_added_before: int,
	aura: AuraData
) -> bool:
	if aura == null or aura.id != GameConstants.BUBBLING_BREW_AURA_ID:
		return false
	var count_after := ingredients_added_before + 1
	return count_after % GameConstants.BUBBLING_BREW_INTERVAL == 0


static func bubbling_brew_countdown(ingredients_added: int, aura: AuraData) -> int:
	if aura == null or aura.id != GameConstants.BUBBLING_BREW_AURA_ID:
		return 0
	var interval := GameConstants.BUBBLING_BREW_INTERVAL
	var remainder := ingredients_added % interval
	if remainder == 0:
		return interval
	return interval - remainder


static func bubbling_brew_hand_slots(
	hand_slots: Array,
	ingredients_added_before_hand: int,
	aura: AuraData,
	hand_slot_count: int = 5
) -> Array[int]:
	if aura == null or aura.id != GameConstants.BUBBLING_BREW_AURA_ID:
		return []

	var bubbling_slots: Array[int] = []
	var ingredients_added := ingredients_added_before_hand
	for slot_index in hand_slot_count:
		if slot_index >= hand_slots.size() or hand_slots[slot_index] == null:
			continue
		if bubbling_brew_returns_ingredient(ingredients_added, aura):
			bubbling_slots.append(slot_index)
		ingredients_added += 1
	return bubbling_slots