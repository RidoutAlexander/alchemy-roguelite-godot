extends SceneTree

const _IngredientEffects := preload("res://scripts/brewing/ingredient_effects.gd")
const _TrinketEffects := preload("res://scripts/brewing/trinket_effects.gd")
const _DefaultContent := preload("res://scripts/data/default_content.gd")
const _BagModel := preload("res://scripts/brewing/bag_model.gd")
const _RunManager := preload("res://scripts/core/run_manager.gd")


func _init() -> void:
	var failures: Array[String] = []
	var content := _DefaultContent.create()

	_test_trinket_data(content, failures)
	_test_fairy_uses(content, failures)
	_test_empty_cage_cycle(content, failures)
	_test_reward_pool(content, failures)
	_test_bag_save_roundtrip(content, failures)

	if failures.is_empty():
		print("verify_fairy_vengeful: PASS")
		quit(0)
	else:
		for failure in failures:
			print("FAIL: %s" % failure)
		print("verify_fairy_vengeful: FAIL (%d)" % failures.size())
		quit(1)


func _test_trinket_data(content, failures: Array[String]) -> void:
	var trinket: TrinketData = content.find_trinket(_TrinketEffects.VENGEFUL_FAIRY_ID)
	if trinket == null:
		failures.append("vengeful_fairy trinket missing")
		return
	if trinket.reward_offerable:
		failures.append("vengeful_fairy should not be reward_offerable")
	var art_path := "res://assets/cards/trinkets/%s.png" % trinket.get_art_filename()
	if not ResourceLoader.exists(art_path):
		failures.append("vengeful_fairy art missing at %s" % art_path)


func _test_fairy_uses(content, failures: Array[String]) -> void:
	var fairy_template: IngredientData = content.find_ingredient(
		_IngredientEffects.FAIRY_IN_A_CAGE_ID
	)
	if fairy_template == null:
		failures.append("fairy template missing")
		return
	var chip := fairy_template.duplicate_for_bag()
	if chip.fairy_uses_remaining != _IngredientEffects.FAIRY_IN_A_CAGE_MAX_USES:
		failures.append("fairy chip should start with 5 uses")
	var description := _IngredientEffects.card_display_description(chip)
	if "5 uses left" not in description:
		failures.append("fairy card should show 5 uses left")


func _test_empty_cage_cycle(content, failures: Array[String]) -> void:
	var run := _RunManager.new(content)
	run.start_new_run()
	var session := run.brew_session
	var fairy_template: IngredientData = content.find_ingredient(
		_IngredientEffects.FAIRY_IN_A_CAGE_ID
	)
	var fairy_chip := fairy_template.duplicate_for_bag()
	run.bag.add_to_master_bag(fairy_chip)
	var aura: AuraData = content.find_aura("none")
	if aura == null and not content.auras.is_empty():
		aura = content.auras.values()[0]
	session.start_brew(1, aura, run.bag, 0, 0, 0, run.difficulty_mode, 0, run.owned_trinket_ids)

	for _i in _IngredientEffects.FAIRY_IN_A_CAGE_MAX_USES:
		session._apply_ingredient_play(fairy_chip, false, false, -1)

	if fairy_chip.fairy_uses_remaining != 0:
		failures.append("fairy uses should be 0 after 5 plays")
	if not session.consume_fairy_escaped_poof():
		failures.append("fairy escape poof should be pending after 5th play")
	if session.context.cauldron_contents.has(fairy_chip):
		failures.append("fairy should be removed from cauldron on escape")
	if run.bag.has_master_chip(fairy_chip):
		failures.append("fairy chip should be removed from master bag on escape")

	session.complete_fairy_escape_sequence(run)
	if not run.has_trinket(_TrinketEffects.VENGEFUL_FAIRY_ID):
		failures.append("vengeful fairy trinket should be granted after escape")
	if _IngredientEffects.EMPTY_CAGE_ID not in run.bag.master_ids():
		failures.append("empty cage should be granted after fairy escape")

	var empty_template: IngredientData = content.find_ingredient(_IngredientEffects.EMPTY_CAGE_ID)
	var empty_chip := empty_template.duplicate_for_bag()
	for _i in _IngredientEffects.EMPTY_CAGE_MAX_USES:
		session._apply_ingredient_play(empty_chip, false, false, -1)

	if not session.consume_empty_cage_recapture_pending():
		failures.append("empty cage recapture should be pending after 3rd play")
	var recaptured := session.complete_empty_cage_recapture(run)
	if run.has_trinket(_TrinketEffects.VENGEFUL_FAIRY_ID):
		failures.append("vengeful fairy should be removed after recapture")
	if recaptured == null:
		failures.append("recaptured fairy chip should not be null")
	elif recaptured.fairy_uses_remaining != _IngredientEffects.FAIRY_IN_A_CAGE_MAX_USES:
		failures.append("recaptured fairy should have 5 uses")


func _test_reward_pool(content, failures: Array[String]) -> void:
	var run := _RunManager.new(content)
	run.start_new_run()
	var pool: Array[String] = run._build_unowned_trinket_pool()
	if _TrinketEffects.VENGEFUL_FAIRY_ID in pool:
		failures.append("vengeful fairy should not appear in reward pool")


func _test_bag_save_roundtrip(content, failures: Array[String]) -> void:
	var fairy_template: IngredientData = content.find_ingredient(
		_IngredientEffects.FAIRY_IN_A_CAGE_ID
	)
	var chip := fairy_template.duplicate_for_bag()
	chip.fairy_uses_remaining = 2
	var bag := _BagModel.new()
	bag.add_to_master_bag(chip)
	var save_data := bag.get_master_chip_save_data()
	if save_data.is_empty() or int(save_data[0].get("fairyUses", -1)) != 2:
		failures.append("fairy uses should persist in bag save data")
	var restored: IngredientData = content.create_bag_chip_from_save(save_data[0])
	if restored.fairy_uses_remaining != 2:
		failures.append("fairy uses should restore from save data")