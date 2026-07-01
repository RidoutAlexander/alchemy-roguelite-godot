class_name BagModel
extends RefCounted

var _master_chips: Array[IngredientData] = []
var _working_chips: Array[IngredientData] = []
var _forced_draw_queue: Array[IngredientData] = []
var _rng := RandomNumberGenerator.new()


func set_master_bag(chips: Array) -> void:
	_master_chips.clear()
	for chip in chips:
		if chip != null:
			_master_chips.append(chip)
	reset_for_brew()


func add_to_master_bag(ingredient: IngredientData) -> void:
	if ingredient != null:
		_master_chips.append(ingredient)


func reset_for_brew(shuffle: bool = false) -> void:
	_working_chips = _master_chips.duplicate()
	_forced_draw_queue.clear()
	if shuffle:
		shuffle_working_deck()


func shuffle_working_deck() -> void:
	_shuffle(_working_chips)


func remaining_count() -> int:
	return _working_chips.size() + _forced_draw_queue.size()


func master_ids() -> Array[String]:
	var ids: Array[String] = []
	for chip in _master_chips:
		ids.append(chip.id)
	return ids


func get_master_inventory() -> Array[Dictionary]:
	# UI-only aggregation: group every copy by ingredient id. Draw order / shuffle
	# uses _working_chips and is unrelated to how the bag overlay displays stacks.
	var counts: Dictionary = {}
	var order: Array[String] = []
	for chip in _master_chips:
		if chip == null:
			continue
		if not counts.has(chip.id):
			counts[chip.id] = {"ingredient": chip, "count": 0}
			order.append(chip.id)
		var entry: Dictionary = counts[chip.id]
		entry["count"] = int(entry["count"]) + 1

	var entries: Array[Dictionary] = []
	for id in order:
		entries.append(counts[id])
	return entries


func try_draw() -> IngredientData:
	if not _forced_draw_queue.is_empty():
		return _forced_draw_queue.pop_front()
	if _working_chips.is_empty():
		return null
	return _working_chips.pop_front()


func peek_next(count: int) -> Array[IngredientData]:
	var slots := mini(count, _working_chips.size())
	var peeked: Array[IngredientData] = []
	for i in slots:
		peeked.append(_working_chips[i])
	return peeked


func take_next(count: int) -> Array[IngredientData]:
	var picked: Array[IngredientData] = []
	var slots := mini(count, _working_chips.size())
	for _i in slots:
		picked.append(_working_chips.pop_front())
	return picked


func take_random(count: int) -> Array[IngredientData]:
	var picked: Array[IngredientData] = []
	var slots := mini(count, _working_chips.size())
	for _i in slots:
		var index := randi_range(0, _working_chips.size() - 1)
		picked.append(_working_chips[index])
		_working_chips.remove_at(index)
	return picked


func return_to_bag(ingredients: Array) -> void:
	for ingredient in ingredients:
		if ingredient != null:
			_working_chips.append(ingredient)


func replace_one_voodoo_doll_in_master_with(ingredient: IngredientData) -> void:
	if ingredient == null:
		return
	for i in _master_chips.size():
		if _master_chips[i] != null and _master_chips[i].id == IngredientEffects.VOODOO_DOLL_ID:
			_master_chips[i] = ingredient
			return


func reshuffle_after_phoenix(cauldron_contents: Array) -> void:
	for ingredient in cauldron_contents:
		if ingredient != null:
			_working_chips.append(ingredient)
	_forced_draw_queue.clear()
	_shuffle(_working_chips)


func set_forced_draw_queue(ingredients: Array) -> void:
	_forced_draw_queue.clear()
	for ingredient in ingredients:
		if ingredient != null:
			_forced_draw_queue.append(ingredient)


func _shuffle(chips: Array) -> void:
	if chips.size() < 2:
		return
	_rng.randomize()
	for i in range(chips.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var tmp = chips[i]
		chips[i] = chips[j]
		chips[j] = tmp