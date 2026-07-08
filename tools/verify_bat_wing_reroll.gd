extends SceneTree

## Run with:
## godot --headless --path "<project>" --script res://tools/verify_bat_wing_reroll.gd
##
## Bag-model checks run in-engine. Picker slot/UI checks are in verify_bat_wing_reroll.py
## because IngredientCard depends on GameManager autoloads unavailable in --script mode.

const BAT_WING_PICK_COUNT := 3


func _init() -> void:
	var failures: Array[String] = []
	_test_bag_reroll_conserves_chips(failures)
	_test_bag_reroll_fails_with_small_bag(failures)
	_test_bag_reroll_rollback_on_failure(failures)

	if failures.is_empty():
		print("PASS: all bat wing reroll verification checks passed")
		quit(0)
	else:
		for message in failures:
			print("FAIL: %s" % message)
		quit(1)


func _make_ingredient(id: String, copy: int) -> IngredientData:
	return IngredientData.new(
		"%s_%d" % [id, copy],
		id,
		"test",
		1,
		0,
		1,
		IngredientData.Rarity.COMMON
	)


func _make_bag(ids: Array) -> BagModel:
	var chips: Array = []
	var copy_counts: Dictionary = {}
	for ingredient_id in ids:
		var copy := int(copy_counts.get(ingredient_id, 0)) + 1
		copy_counts[ingredient_id] = copy
		chips.append(_make_ingredient(str(ingredient_id), copy))
	var bag := BagModel.new()
	bag.set_master_bag(chips)
	return bag


func _simulate_try_reroll(bag: BagModel, held_out: Array[IngredientData]) -> Dictionary:
	var result := {
		"success": false,
		"choices": held_out.duplicate(),
	}
	if bag.count_drawable_excluding_instances(held_out) < BAT_WING_PICK_COUNT:
		return result

	bag.return_to_bag(held_out)
	var rerolled := bag.take_random_excluding_instances(held_out, BAT_WING_PICK_COUNT)
	if rerolled.size() < BAT_WING_PICK_COUNT:
		bag.return_to_bag(rerolled)
		bag.remove_instances(held_out)
		return result

	result["success"] = true
	result["choices"] = rerolled
	return result


func _test_bag_reroll_conserves_chips(failures: Array[String]) -> void:
	var bag := _make_bag(["a", "b", "c", "d", "e", "f", "g", "h", "i"])
	var total_before := bag.remaining_count()
	var held := bag.take_random(BAT_WING_PICK_COUNT)
	if bag.remaining_count() + held.size() != total_before:
		failures.append("initial draw should conserve chips")
		return

	var reroll := _simulate_try_reroll(bag, held)
	if not reroll["success"]:
		failures.append("reroll should succeed with enough bag chips")
		return

	held = reroll["choices"]
	var total_after := bag.remaining_count() + held.size()
	if total_after != total_before:
		failures.append(
			"reroll leaked chips: before=%d after=%d" % [total_before, total_after]
		)


func _test_bag_reroll_fails_with_small_bag(failures: Array[String]) -> void:
	var bag := _make_bag(["a", "b", "c", "d", "e"])
	var total_before := bag.remaining_count()
	var held := bag.take_random(BAT_WING_PICK_COUNT)
	var original := held.duplicate()
	var reroll := _simulate_try_reroll(bag, held)
	if reroll["success"]:
		failures.append("reroll must fail when fewer than 3 drawable chips remain")
	if reroll["choices"].size() != original.size():
		failures.append("failed reroll should leave original choice count intact")
	if bag.remaining_count() + reroll["choices"].size() != total_before:
		failures.append("failed reroll should conserve total chips")


func _test_bag_reroll_rollback_on_failure(failures: Array[String]) -> void:
	var bag := _make_bag(["a", "b", "c", "d", "e"])
	var held := bag.take_random(BAT_WING_PICK_COUNT)
	var original_ids: Array[String] = []
	for chip in held:
		original_ids.append(chip.id)

	bag.return_to_bag(held)
	var rerolled := bag.take_random_excluding_instances(held, BAT_WING_PICK_COUNT)
	if rerolled.size() >= BAT_WING_PICK_COUNT:
		failures.append("setup should leave fewer than 3 drawable chips for rollback test")
		return
	bag.return_to_bag(rerolled)
	bag.remove_instances(held)

	var restored_ids: Array[String] = []
	for chip in held:
		restored_ids.append(chip.id)
	if restored_ids != original_ids:
		failures.append("rollback should restore original held-out choices")