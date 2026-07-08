extends SceneTree

## Run with:
## godot --headless --path "<project>" --script res://tools/verify_holy_grail.gd

const _IngredientEffects := preload("res://scripts/brewing/ingredient_effects.gd")
const _AuraData := preload("res://scripts/data/aura_data.gd")


func _init() -> void:
	var failures: Array[String] = []
	_test_limit_bonus_helper(failures)
	_test_holy_grail_increases_limit_before_explosion_check(failures)
	_test_hand_preview_simulates_limit_bonus(failures)

	if failures.is_empty():
		print("PASS: all holy grail verification checks passed")
		quit(0)
	else:
		for message in failures:
			print("FAIL: %s" % message)
		quit(1)


func _make_ingredient(id: String) -> IngredientData:
	return IngredientData.new(
		id,
		id,
		"test",
		4,
		0,
		1,
		IngredientData.Rarity.LEGENDARY
	)


func _make_boom_berry() -> IngredientData:
	return IngredientData.new(
		"boom_berry_red",
		"boom_berry_red",
		"test",
		5,
		2,
		1,
		IngredientData.Rarity.COMMON
	)


func _neutral_aura() -> AuraData:
	return AuraData.new("test", "Test", "", AuraData.Pool.NORMAL, 1, 0, 100, 100)


func _test_limit_bonus_helper(failures: Array[String]) -> void:
	var grail := _make_ingredient("holy_grail")
	var garlic := _make_ingredient("garlic")
	var cauldron: Array = [grail]

	if _IngredientEffects.explosion_limit_bonus_for_played_ingredient(grail, cauldron) != 1:
		failures.append("holy grail should always grant +1 limit")
	if _IngredientEffects.explosion_limit_bonus_for_played_ingredient(garlic, [garlic]) != 1:
		failures.append("first garlic should grant +1 limit")
	if _IngredientEffects.explosion_limit_bonus_for_played_ingredient(garlic, [garlic, garlic]) != 0:
		failures.append("second garlic should not grant another limit bonus")


func _test_holy_grail_increases_limit_before_explosion_check(failures: Array[String]) -> void:
	var context := BrewContext.new()
	context.explosiveness = 7
	context.explosion_limit = 8
	context.owned_trinket_ids = []

	var grail := _make_ingredient("holy_grail")
	var effect := _IngredientEffects.apply(grail, context)
	if effect.explosion_limit_bonus != 1:
		failures.append("holy grail apply() should return +1 explosion limit bonus")

	if effect.explosion_limit_bonus > 0:
		context.explosion_limit += effect.explosion_limit_bonus
	context.explosiveness += grail.explosive_value + effect.bonus_explosiveness

	if context.explosion_limit != 9:
		failures.append(
			"holy grail should raise limit to 9 (got %d)" % context.explosion_limit
		)
	if context.explosiveness != 7:
		failures.append("holy grail alone should not change explosiveness")
	if context.is_exploded():
		failures.append("holy grail should never explode on its own")

	# Same-card ordering: limit bonus must apply before explosiveness is added.
	context.explosiveness = 6
	context.explosion_limit = 8
	var limit_bonus := 1
	var explosive_add := 2
	context.explosion_limit += limit_bonus
	context.explosiveness += explosive_add
	if context.is_exploded():
		failures.append(
			"limit bonus before explosiveness should avoid false explosion at 8/9"
		)


func _test_hand_preview_simulates_limit_bonus(failures: Array[String]) -> void:
	var grail := _make_ingredient("holy_grail")
	var boom := _make_boom_berry()
	var hand_slots: Array = [grail, boom]
	var cauldron: Array = []

	var stats := _IngredientEffects.compute_hand_display_stats(
		hand_slots,
		cauldron,
		_neutral_aura(),
		2,
		0,
		{
			"explosiveness": 6,
			"explosion_limit": 8,
		}
	)

	var grail_stats: Dictionary = stats[0]
	var boom_stats: Dictionary = stats[1]
	if grail_stats == null or int(grail_stats.get("explosive_value", -1)) != 0:
		failures.append("holy grail preview should show 0 explosiveness")
	if boom_stats == null or int(boom_stats.get("explosive_value", -1)) != 2:
		failures.append(
			"after holy grail, boom berry preview should still add explosiveness at 8/9 (got %s)"
			% str(boom_stats)
		)