class_name HighScoreService
extends RefCounted


static func load_scores() -> Dictionary:
	if not FileAccess.file_exists("user://high_scores.json"):
		return _empty_scores()
	var file := FileAccess.open("user://high_scores.json", FileAccess.READ)
	if file == null:
		return _empty_scores()
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return _empty_scores()
	return parsed


static func apply_run_results(deepest_level: int, best_single_brew: int, total_run_score: int) -> Dictionary:
	var previous := load_scores()
	var comparison := {
		"previous": previous.duplicate(true),
		"new_deepest_level": deepest_level,
		"new_highest_single_brew": best_single_brew,
		"new_highest_run_total": total_run_score,
		"deepest_level_improved": deepest_level > int(previous.get("deepestLevel", 0)),
		"single_brew_improved": best_single_brew > int(previous.get("highestSingleBrew", 0)),
		"run_total_improved": total_run_score > int(previous.get("highestRunTotal", 0)),
	}
	previous["deepestLevel"] = maxi(int(previous.get("deepestLevel", 0)), deepest_level)
	previous["highestSingleBrew"] = maxi(int(previous.get("highestSingleBrew", 0)), best_single_brew)
	previous["highestRunTotal"] = maxi(int(previous.get("highestRunTotal", 0)), total_run_score)
	_save_scores(previous)
	return comparison


static func _empty_scores() -> Dictionary:
	return {
		"deepestLevel": 0,
		"highestSingleBrew": 0,
		"highestRunTotal": 0,
	}


static func _save_scores(data: Dictionary) -> void:
	var file := FileAccess.open("user://high_scores.json", FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()