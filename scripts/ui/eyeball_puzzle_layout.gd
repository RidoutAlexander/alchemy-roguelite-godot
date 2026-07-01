class_name EyeballPuzzleLayout
extends RefCounted

const CARD_BASE_SIZE := Vector2(300.0, 420.0)
const CARD_SCALE := 0.52


static func card_display_size() -> Vector2:
	return (CARD_BASE_SIZE * CARD_SCALE).floor()


static func configure_card(card: IngredientCard) -> void:
	card.scale = Vector2.ONE * CARD_SCALE
	card.pivot_offset = Vector2.ZERO
	card.position = Vector2.ZERO
	card.custom_minimum_size = CARD_BASE_SIZE
	card.size = CARD_BASE_SIZE
	if card.has_method("_reset_visual_scale"):
		card._reset_visual_scale()