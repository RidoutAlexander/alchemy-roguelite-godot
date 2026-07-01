class_name ThresholdCalculator
extends RefCounted


static func get_threshold_for_level(
	level: int,
	difficulty: int = GameDifficulty.Mode.HARD
) -> int:
	if difficulty == GameDifficulty.Mode.EASY:
		return _get_threshold_for_level(level, GameConstants.EASY_THRESHOLD_STEP)
	return _get_threshold_for_level(level, GameConstants.THRESHOLD_STEP_BASE)


static func _get_threshold_for_level(level: int, step: float) -> int:
	if level <= 1:
		return GameConstants.THRESHOLD_START
	var linear := GameConstants.THRESHOLD_START + step * (level - 1)
	var scaled := float(linear) * pow(
		GameConstants.THRESHOLD_LEVEL_GROWTH_MULTIPLIER,
		level - 1
	)
	return maxi(GameConstants.THRESHOLD_START, int(round(scaled)))