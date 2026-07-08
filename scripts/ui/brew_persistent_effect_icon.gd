class_name BrewPersistentEffectIcon
extends Control

const _INGREDIENT_ART_PATH_TEMPLATE := "res://assets/cards/ingredients/%s.png"
const _TRINKET_ART_PATH_TEMPLATE := "res://assets/cards/trinkets/%s.png"

@onready var _icon: TextureRect = $Icon
@onready var _overlay: Label = $Overlay


func bind(
	ingredient: IngredientData,
	overlay_text: String,
	icon_size: Vector2,
	trinket_id: String = ""
) -> void:
	custom_minimum_size = icon_size
	size = icon_size
	var icon := _icon if _icon != null else get_node_or_null("Icon") as TextureRect
	if icon != null:
		icon.custom_minimum_size = icon_size
		icon.size = icon_size
		icon.texture = _load_trinket_art(trinket_id) if trinket_id != "" else _load_ingredient_art(ingredient)
	var overlay := _overlay if _overlay != null else get_node_or_null("Overlay") as Label
	if overlay != null:
		overlay.text = overlay_text
		overlay.visible = overlay_text != ""
		var font_size := clampi(int(icon_size.y * 0.52), 14, 28)
		overlay.add_theme_font_size_override("font_size", font_size)


func _load_ingredient_art(ingredient: IngredientData) -> Texture2D:
	if ingredient == null:
		return null
	var art_path := _INGREDIENT_ART_PATH_TEMPLATE % ingredient.get_art_filename()
	if not ResourceLoader.exists(art_path):
		return null
	return load(art_path) as Texture2D


func _load_trinket_art(trinket_id: String) -> Texture2D:
	if trinket_id.is_empty():
		return null
	var art_path := _TRINKET_ART_PATH_TEMPLATE % trinket_id
	if not ResourceLoader.exists(art_path):
		return null
	return load(art_path) as Texture2D