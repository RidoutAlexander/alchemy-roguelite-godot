class_name DefaultContent
extends RefCounted

var ingredients: Dictionary = {}
var auras: Dictionary = {}
var starter_bag: Array[Dictionary] = []


static func create() -> DefaultContent:
	var content := DefaultContent.new()
	content._build()
	return content


func _build() -> void:
	ingredients = SpreadsheetContentLoader.load_ingredients()
	auras = SpreadsheetContentLoader.load_auras()
	starter_bag = SpreadsheetContentLoader.load_starter_bag(ingredients)


func find_ingredient(ingredient_id: String) -> IngredientData:
	return ingredients.get(ingredient_id)


func all_ingredients() -> Array:
	return ingredients.values()


func find_aura(aura_id: String) -> AuraData:
	return auras.get(aura_id)


func auras_for_pool(pool: AuraData.Pool) -> Array:
	var result: Array = []
	for aura in auras.values():
		if aura.pool == pool:
			result.append(aura)
	return result


func flatten_starter_bag() -> Array[IngredientData]:
	var chips: Array[IngredientData] = []
	for stack in starter_bag:
		var ingredient := find_ingredient(stack["id"])
		if ingredient == null:
			continue
		for i in stack["count"]:
			chips.append(ingredient)
	return chips