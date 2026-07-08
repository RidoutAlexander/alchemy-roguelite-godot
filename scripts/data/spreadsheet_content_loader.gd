class_name SpreadsheetContentLoader
extends RefCounted

const INGREDIENTS_PATH := "res://data/ingredients.json"
const STARTER_BAG_PATH := "res://data/starter_bag.json"
const AURAS_PATH := "res://data/auras.json"
const TRINKETS_PATH := "res://data/trinkets.json"

const RARITY_MAP := {
	"common": IngredientData.Rarity.COMMON,
	"uncommon": IngredientData.Rarity.UNCOMMON,
	"rare": IngredientData.Rarity.RARE,
	"epic": IngredientData.Rarity.EPIC,
	"legendary": IngredientData.Rarity.LEGENDARY,
}

const POOL_MAP := {
	"normal": AuraData.Pool.NORMAL,
	"boss": AuraData.Pool.BOSS,
}


static func load_ingredients() -> Dictionary:
	var ingredients: Dictionary = {}
	var rows := _read_json_array(INGREDIENTS_PATH, "ingredients")
	for row in rows:
		var ingredient := _parse_ingredient(row)
		ingredients[ingredient.id] = ingredient
	return ingredients


static func load_auras() -> Dictionary:
	var auras: Dictionary = {}
	var rows := _read_json_array(AURAS_PATH, "auras")
	for row in rows:
		var aura := _parse_aura(row)
		auras[aura.id] = aura
	return auras


static func load_trinkets() -> Dictionary:
	var trinkets: Dictionary = {}
	var rows := _read_json_array(TRINKETS_PATH, "trinkets")
	for row in rows:
		var trinket := _parse_trinket(row)
		trinkets[trinket.id] = trinket
	return trinkets


static func load_starter_bag(ingredients: Dictionary) -> Array[Dictionary]:
	var starter_bag: Array[Dictionary] = []
	var rows := _read_json_array(STARTER_BAG_PATH, "starter bag")
	for row in rows:
		var ingredient_id := str(row.get("id", "")).strip_edges()
		if ingredient_id == "":
			continue
		if not ingredients.has(ingredient_id):
			push_warning("Starter bag references unknown ingredient '%s'." % ingredient_id)
			continue
		var count := int(row.get("count", 0))
		if count <= 0:
			push_warning("Starter bag count for '%s' must be > 0." % ingredient_id)
			continue
		starter_bag.append({"id": ingredient_id, "count": count})
	return starter_bag


static func _read_json_array(path: String, label: String) -> Array:
	if not FileAccess.file_exists(path):
		push_error("Missing %s file: %s. Run tools/export_ingredients.py first." % [label, path])
		return []
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Could not open %s: %s" % [label, path])
		return []
	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_ARRAY:
		push_error("%s file must contain a JSON array: %s" % [label, path])
		return []
	return parsed


static func _parse_aura(row: Dictionary) -> AuraData:
	var aura_id := str(row.get("id", "")).strip_edges()
	var pool_key := str(row.get("pool", "normal")).strip_edges().to_lower()
	if not POOL_MAP.has(pool_key):
		push_warning("Unknown aura pool '%s' for '%s'. Using normal." % [pool_key, aura_id])
		pool_key = "normal"
	return AuraData.new(
		aura_id,
		str(row.get("display_name", aura_id)),
		str(row.get("description", "")),
		POOL_MAP[pool_key],
		int(row.get("pool_unlock_level", 1)),
		int(row.get("explosion_limit_modifier", 0)),
		int(row.get("score_multiplier_percent", 100)),
		int(row.get("gold_multiplier_percent", 100))
	)


static func _parse_trinket(row: Dictionary) -> TrinketData:
	var trinket_id := str(row.get("id", "")).strip_edges()
	var display_name := str(row.get("display_name", row.get("name", trinket_id))).strip_edges()
	return TrinketData.new(
		trinket_id,
		display_name,
		str(row.get("description", "")),
		str(row.get("art", "")).strip_edges(),
		bool(row.get("reward_offerable", true))
	)


static func _parse_ingredient(row: Dictionary) -> IngredientData:
	var ingredient_id := str(row.get("id", "")).strip_edges()
	var rarity_key := str(row.get("rarity", "common")).strip_edges().to_lower()
	if not RARITY_MAP.has(rarity_key):
		push_warning("Unknown rarity '%s' for '%s'. Using common." % [rarity_key, ingredient_id])
		rarity_key = "common"
	return IngredientData.new(
		ingredient_id,
		str(row.get("display_name", ingredient_id)),
		str(row.get("description", "")),
		int(row.get("point_value", 0)),
		int(row.get("explosive_value", 0)),
		int(row.get("shop_cost", 0)),
		RARITY_MAP[rarity_key],
		bool(row.get("shop_available", true)),
		str(row.get("art", "")).strip_edges()
	)