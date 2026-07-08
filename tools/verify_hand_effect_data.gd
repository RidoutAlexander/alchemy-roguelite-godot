extends SceneTree

## godot --headless --path "<project>" --script res://tools/verify_hand_effect_data.gd

const _HandSlotEffects := preload("res://scripts/brewing/hand_slot_effects.gd")
const _IngredientEffects := preload("res://scripts/brewing/ingredient_effects.gd")
const _BrewSession := preload("res://scripts/brewing/brew_session.gd")


func _init() -> void:
	var failures: Array[String] = []
	_test_honey_left_slot_gets_entry(failures)
	_test_brew_session_hand_phase_honey(failures)
	_test_brew_session_drawing_phase_honey(failures)
	if failures.is_empty():
		print("PASS: hand effect data path checks passed")
		quit(0)
	else:
		for failure in failures:
			print("FAIL: %s" % failure)
		quit(1)


func _test_honey_left_slot_gets_entry(failures: Array[String]) -> void:
	var honey := _make_ingredient(_IngredientEffects.HONEY_ID)
	var boom := _make_ingredient("boom_berry_2", 2, 2)
	var slots: Array = [boom, honey, null, null, null]
	var honey_skipped := _HandSlotEffects.compute_honey_skipped_slots(slots, 5)
	if not honey_skipped.has(0):
		failures.append("honey_skipped should mark left slot 0, got %s" % str(honey_skipped))

	var entries_per_slot := _HandSlotEffects.compute_entries(
		slots,
		5,
		[],
		[],
		[],
		[],
		false,
		{},
		honey_skipped,
		{}
	)
	var slot0: Array = entries_per_slot[0]
	var has_honey := false
	for entry in slot0:
		if str(entry.get("ingredient_id", "")) == _IngredientEffects.HONEY_ID:
			has_honey = true
	if not has_honey:
		failures.append(
			"slot 0 effect entries should include honey overlay, got %s" % str(slot0)
		)


func _test_brew_session_hand_phase_honey(failures: Array[String]) -> void:
	var session: BrewSession = _BrewSession.new()
	session._hand_phase = BrewSession.HandPhase.HAND
	var honey := _make_ingredient(_IngredientEffects.HONEY_ID)
	var boom := _make_ingredient("boom_berry_2", 2, 2)
	session._hand_slots = [boom, honey, null, null, null]
	session._refresh_hand_preview_locks()

	var effect_entries: Array = session.get_hand_slot_effect_entries()
	if effect_entries.is_empty():
		failures.append("get_hand_slot_effect_entries returned empty array")
		return
	var slot0: Array = effect_entries[0] if effect_entries.size() > 0 else []
	var has_honey := false
	for entry in slot0:
		if str(entry.get("ingredient_id", "")) == _IngredientEffects.HONEY_ID:
			has_honey = true
	if not has_honey:
		failures.append(
			"session hand effect slot 0 missing honey after sanitize, entries=%s preview_honey=%s"
			% [str(slot0), str(session._hand_preview_honey_slots)]
		)


func _test_brew_session_drawing_phase_honey(failures: Array[String]) -> void:
	var session: BrewSession = _BrewSession.new()
	session._hand_phase = BrewSession.HandPhase.DRAWING
	var honey := _make_ingredient(_IngredientEffects.HONEY_ID)
	var boom := _make_ingredient("boom_berry_2", 2, 2)
	var drawing_slots: Array = [boom, honey, null, null, null]
	var effect_entries: Array = session.get_hand_slot_effect_entries(drawing_slots)
	var slot0: Array = effect_entries[0] if effect_entries.size() > 0 else []
	var has_honey := false
	for entry in slot0:
		if str(entry.get("ingredient_id", "")) == _IngredientEffects.HONEY_ID:
			has_honey = true
	if not has_honey:
		failures.append(
			"drawing phase slot 0 should include honey overlay, got %s" % str(slot0)
		)


func _make_ingredient(
	id: String,
	points: int = 1,
	explosive: int = 0
) -> IngredientData:
	return IngredientData.new(
		id,
		id,
		"",
		points,
		explosive,
		0,
		IngredientData.Rarity.COMMON
	)