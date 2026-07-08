extends SceneTree

## Run with:
## godot --headless --path "<project>" --script res://tools/verify_cobbler_bat_wing.gd

const _IngredientEffects := preload("res://scripts/brewing/ingredient_effects.gd")
const _AuraData := preload("res://scripts/data/aura_data.gd")
const _BrewSession := preload("res://scripts/brewing/brew_session.gd")

const COBBLER_SCORE := 10
const COBBLER_EXPLOSIVE := 2


func _init() -> void:
	var failures: Array[String] = []
	_test_resolve_played_left_neighbor(failures)
	_test_apply_hand_play_after_bat_wing(failures)
	_test_brew_session_bat_wing_pick_preview(failures)
	_test_brew_session_bat_wing_pick_apply(failures)

	if failures.is_empty():
		print("PASS: all cobbler + bat wing verification checks passed")
		quit(0)
	else:
		for message in failures:
			print("FAIL: %s" % message)
		quit(1)


func _make_ingredient(
	template_id: String,
	_copy: int = 1,
	point_value: int = 1,
	explosive_value: int = 0
) -> IngredientData:
	return IngredientData.new(
		template_id,
		template_id,
		"test",
		point_value,
		explosive_value,
		1,
		IngredientData.Rarity.COMMON
	)


func _neutral_aura() -> AuraData:
	return AuraData.new("test", "Test", "", AuraData.Pool.NORMAL, 1, 0, 100, 100)


func _test_resolve_played_left_neighbor(failures: Array[String]) -> void:
	var cobbler: IngredientData = _make_ingredient("cobbler", 1, 2, 0)
	var bat_wing: IngredientData = _make_ingredient("bat_wing", 1, 0, 0)
	var boom: IngredientData = _make_ingredient("boom_berry_2", 1, 2, 2)
	var hand_slots: Array = [cobbler, bat_wing, null, null, null]
	var cauldron: Array = [cobbler, bat_wing]

	var resolved: Dictionary = _IngredientEffects.resolve_hand_play_cobbler(
		boom,
		cauldron,
		1,
		1,
		hand_slots,
		bat_wing,
		{},
		2
	)
	if not bool(resolved.get("apply_to_current", false)):
		failures.append("resolve should apply cobbler bonus to picked boom berry")
	if int(resolved.get("bonus", {}).get("score", 0)) != COBBLER_SCORE:
		failures.append(
			"resolve bonus score expected %d got %s"
			% [COBBLER_SCORE, str(resolved.get("bonus", {}))]
		)

	resolved = _IngredientEffects.resolve_hand_play_cobbler(
		boom,
		cauldron,
		1,
		1,
		hand_slots,
		bat_wing,
		{},
		-1
	)
	if not bool(resolved.get("apply_to_current", false)):
		failures.append("resolve should pair with played cobbler even when play_cursor is -1")


func _test_apply_hand_play_after_bat_wing(failures: Array[String]) -> void:
	var context: BrewContext = BrewContext.new()
	var cobbler: IngredientData = _make_ingredient("cobbler", 1, 2, 0)
	var bat_wing: IngredientData = _make_ingredient("bat_wing", 1, 0, 0)
	var boom: IngredientData = _make_ingredient("boom_berry_2", 1, 2, 2)
	context.cauldron_contents = [cobbler, bat_wing]
	context.ingredients_added_to_cauldron = 2

	var hand_play: Dictionary = {
		"play_slot": 1,
		"last_hand_slot": 1,
		"last_hand_ingredient": bat_wing,
		"hand_slots": [cobbler, bat_wing, null, null, null],
		"locked_slots": {},
		"play_cursor": 2,
	}
	var effect = _IngredientEffects.apply(boom, context, hand_play)
	if effect.bonus_score != COBBLER_SCORE:
		failures.append(
			"apply effect bonus_score expected %d got %d"
			% [COBBLER_SCORE, effect.bonus_score]
		)
	if effect.bonus_explosiveness != COBBLER_EXPLOSIVE:
		failures.append(
			"apply effect bonus_explosiveness expected %d got %d"
			% [COBBLER_EXPLOSIVE, effect.bonus_explosiveness]
		)


func _test_brew_session_bat_wing_pick_preview(failures: Array[String]) -> void:
	var session: BrewSession = _make_session_with_cobbler_bat_wing_hand()
	_simulate_bat_wing_played(session)
	session.begin_bat_wing_picker()
	if not session._bat_wing_picker_active:
		failures.append("bat wing picker should be active before preview")
	if session._bat_wing_source_slot_index < 0:
		failures.append("bat wing source slot should be set before preview")

	var boom: IngredientData = _make_ingredient("boom_berry_2", 99, 2, 2)
	var preview: Dictionary = session.get_bat_wing_choice_preview(boom)
	var point_value: int = int(preview.get("point_value", 0))
	var explosive_value: int = int(preview.get("explosive_value", 0))
	if point_value != boom.point_value + COBBLER_SCORE:
		failures.append(
			"picker preview points expected %d got %d preview=%s"
			% [boom.point_value + COBBLER_SCORE, point_value, str(preview)]
		)
	if explosive_value != boom.explosive_value + COBBLER_EXPLOSIVE:
		failures.append(
			"picker preview explosive expected %d got %d"
			% [boom.explosive_value + COBBLER_EXPLOSIVE, explosive_value]
		)

	var effect_entries: Array = preview.get("effect_entries", [])
	var has_cobbler_icon := false
	for entry in effect_entries:
		if str(entry.get("ingredient_id", "")) == "cobbler":
			has_cobbler_icon = true
			break
	if not has_cobbler_icon:
		failures.append("picker preview effect_entries should include cobbler icon")


func _test_brew_session_bat_wing_pick_apply(failures: Array[String]) -> void:
	var session: BrewSession = _make_session_with_cobbler_bat_wing_hand()
	_simulate_bat_wing_played(session)
	session.begin_bat_wing_picker()

	var boom: IngredientData = _make_ingredient("boom_berry_2", 99, 2, 2)
	session._bat_wing_choices = [boom]

	var score_before: int = session.context.score
	var explosive_before: int = session.context.explosiveness
	session.complete_bat_wing_picker(boom)

	var expected_score_delta: int = boom.point_value + COBBLER_SCORE
	var expected_explosive_delta: int = boom.explosive_value + COBBLER_EXPLOSIVE
	if session.context.score - score_before != expected_score_delta:
		failures.append(
			"complete picker score delta expected %d got %d"
			% [expected_score_delta, session.context.score - score_before]
		)
	if session.context.explosiveness - explosive_before != expected_explosive_delta:
		failures.append(
			"complete picker explosive delta expected %d got %d"
			% [expected_explosive_delta, session.context.explosiveness - explosive_before]
		)


func _make_session_with_cobbler_bat_wing_hand() -> BrewSession:
	var cobbler: IngredientData = _make_ingredient("cobbler", 1, 2, 0)
	var bat_wing: IngredientData = _make_ingredient("bat_wing", 2, 0, 0)
	var filler: IngredientData = _make_ingredient("rat", 3, 1, 0)
	var bag: BagModel = BagModel.new()
	bag.set_master_bag([filler, _filler_copy(4), _filler_copy(5), _filler_copy(6)])

	var session: BrewSession = _BrewSession.new()
	session.start_brew(1, _neutral_aura(), bag)
	session._hand_phase = _BrewSession.HandPhase.PLAYING
	session._hand_slots = [cobbler, bat_wing, null, null, null]
	session._hand_start_slots = session._hand_slots.duplicate()
	session._play_slot_cursor = 0
	session._hand_locked_slots = {}
	session._last_hand_play_slot = -1
	session._last_hand_play_ingredient = null
	return session


func _filler_copy(copy: int) -> IngredientData:
	return _make_ingredient("rat", copy, 1, 0)


func _simulate_bat_wing_played(session: BrewSession) -> void:
	var cobbler: IngredientData = session._hand_start_slots[0]
	var bat_wing: IngredientData = session._hand_start_slots[1]

	session._apply_ingredient(cobbler, true, true, 0)
	session._hand_slots[0] = null
	session._play_slot_cursor = 1

	session._apply_ingredient(bat_wing, true, true, 1)
	session._hand_slots[1] = null
	session._play_slot_cursor = 2
	session._bat_wing_source_slot_index = 1