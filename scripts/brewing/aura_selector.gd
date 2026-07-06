class_name AuraSelector
extends RefCounted

var _content: DefaultContent
var _rng := RandomNumberGenerator.new()


func _init(content: DefaultContent) -> void:
	_content = content
	_rng.randomize()


func pick_aura_for_level(level: int, last_aura_id: String) -> AuraData:
	var pool := AuraData.Pool.BOSS if level % GameConstants.BOSS_AURA_INTERVAL == 0 else AuraData.Pool.NORMAL
	var candidates: Array = []
	for aura in _content.auras_for_pool(pool, level):
		if aura.id != last_aura_id:
			candidates.append(aura)
	if candidates.is_empty():
		candidates = _content.auras_for_pool(pool, level)
	if candidates.is_empty():
		return null
	_shuffle_candidates(candidates)
	return candidates[_rng.randi_range(0, candidates.size() - 1)]


func _shuffle_candidates(candidates: Array) -> void:
	for i in range(candidates.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = candidates[i]
		candidates[i] = candidates[j]
		candidates[j] = tmp