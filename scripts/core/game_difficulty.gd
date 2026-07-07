class_name GameDifficulty
extends RefCounted

enum Mode { EASY, HARD }


static func from_save_value(value: Variant) -> int:
	var key := str(value).strip_edges().to_lower()
	if key == "easy":
		return Mode.EASY
	return Mode.HARD


static func to_save_value(mode: int) -> String:
	return "easy" if mode == Mode.EASY else "hard"


static func base_mulligans_per_brew(mode: int) -> int:
	return 2 if mode == Mode.EASY else 1