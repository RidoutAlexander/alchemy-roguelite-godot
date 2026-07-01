class_name RarityPalette
extends RefCounted


static func card_tint(rarity: int) -> Color:
	match rarity:
		IngredientData.Rarity.COMMON:
			return Color(1.0, 0.94, 0.78)
		IngredientData.Rarity.UNCOMMON:
			return Color(0.45, 1.0, 0.42)
		IngredientData.Rarity.RARE:
			return Color(0.4, 0.68, 1.0)
		IngredientData.Rarity.EPIC:
			return Color(0.82, 0.42, 1.0)
		IngredientData.Rarity.LEGENDARY:
			return Color(1.0, 0.72, 0.22)
		_:
			return Color.WHITE


static func card_tint_strength(rarity: int) -> float:
	match rarity:
		IngredientData.Rarity.COMMON:
			return 0.34
		IngredientData.Rarity.UNCOMMON:
			return 0.68
		IngredientData.Rarity.RARE:
			return 0.74
		IngredientData.Rarity.EPIC:
			return 0.8
		IngredientData.Rarity.LEGENDARY:
			return 0.86
		_:
			return 0.0