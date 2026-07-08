class_name DefaultContent
extends RefCounted

var ingredients: Dictionary = {}
var auras: Dictionary = {}
var trinkets: Dictionary = {}
var starter_bag: Array[Dictionary] = []


static func create() -> DefaultContent:
	var content := DefaultContent.new()
	content._build()
	return content


func _build() -> void:
	ingredients = SpreadsheetContentLoader.load_ingredients()
	auras = SpreadsheetContentLoader.load_auras()
	trinkets = SpreadsheetContentLoader.load_trinkets()
	starter_bag = SpreadsheetContentLoader.load_starter_bag(ingredients)


func find_ingredient(ingredient_id: String) -> IngredientData:
	return ingredients.get(ingredient_id)


func create_bag_chip_from_save(chip_data: Dictionary) -> IngredientData:
	var ingredient_id := str(chip_data.get("id", ""))
	var template := find_ingredient(ingredient_id)
	if template == null:
		return null
	var chip := template.duplicate_for_bag()
	if chip_data.has("jarUses"):
		chip.jar_of_dirt_uses_remaining = maxi(0, int(chip_data.get("jarUses", 0)))
	return chip


func all_ingredients() -> Array:
	return ingredients.values()


func find_aura(aura_id: String) -> AuraData:
	return auras.get(aura_id)


func find_trinket(trinket_id: String) -> TrinketData:
	return trinkets.get(trinket_id)


func all_trinkets() -> Array:
	return trinkets.values()


func auras_for_pool(pool: AuraData.Pool, level: int = 1) -> Array:
	var result: Array = []
	for aura in auras.values():
		if aura.pool == pool and level >= aura.pool_unlock_level:
			result.append(aura)
	return result


func flatten_starter_bag() -> Array[IngredientData]:
	var chips: Array[IngredientData] = []
	for stack in starter_bag:
		var ingredient := find_ingredient(stack["id"])
		if ingredient == null:
			continue
		for _i in stack["count"]:
			chips.append(ingredient.duplicate_for_bag())
	return chips