class_name ShopService
extends RefCounted

class ShopOffer:
	var ingredient: IngredientData
	var price: int

var _content: DefaultContent


func _init(content: DefaultContent) -> void:
	_content = content


func generate_offers(
	_level: int,
	gold: int,
	slot_count: int = GameConstants.SHOP_SLOT_COUNT
) -> Array:
	var offers: Array = []
	offers.resize(slot_count)
	for slot_index in slot_count:
		offers[slot_index] = null

	var affordable := _affordable_ingredients(gold)
	if affordable.is_empty():
		return offers

	var offered_ids: Dictionary = {}
	for slot_index in slot_count:
		var available := _excluding_offered(affordable, offered_ids)
		if available.is_empty():
			break
		var ingredient := _pick_weighted_ingredient(available)
		if ingredient == null:
			break
		offered_ids[ingredient.id] = true
		var offer := ShopOffer.new()
		offer.ingredient = ingredient
		offer.price = ingredient.shop_cost
		offers[slot_index] = offer
	return offers


func _excluding_offered(candidates: Array, offered_ids: Dictionary) -> Array:
	var available: Array = []
	for ingredient in candidates:
		if ingredient != null and not offered_ids.has(ingredient.id):
			available.append(ingredient)
	return available


func _affordable_ingredients(gold: int) -> Array:
	var affordable: Array = []
	for ingredient in _content.all_ingredients():
		if (
			ingredient != null
			and ingredient.shop_available
			and ingredient.shop_cost <= gold
		):
			affordable.append(ingredient)
	return affordable


func _rarity_weight(ingredient: IngredientData) -> int:
	var rarity_index := int(ingredient.rarity)
	if rarity_index < 0 or rarity_index >= GameConstants.SHOP_RARITY_WEIGHTS.size():
		return 1
	return int(GameConstants.SHOP_RARITY_WEIGHTS[rarity_index])


func _pick_weighted_ingredient(candidates: Array) -> IngredientData:
	if candidates.is_empty():
		return null
	if candidates.size() == 1:
		return candidates[0]

	var total := 0
	var weights: Array[int] = []
	for ingredient in candidates:
		var weight := _rarity_weight(ingredient)
		weights.append(weight)
		total += weight
	if total <= 0:
		return candidates[0]

	var roll := randi_range(0, total - 1)
	var cumulative := 0
	for i in candidates.size():
		cumulative += weights[i]
		if roll < cumulative:
			return candidates[i]
	return candidates[candidates.size() - 1]