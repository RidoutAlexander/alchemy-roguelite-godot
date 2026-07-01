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