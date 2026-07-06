class_name BrewPersistentEffectIcon
extends Control

const _ART_PATH_TEMPLATE := "res://assets/cards/ingredients/%s.png"

@onready var _icon: TextureRect = $Icon
@onready var _overlay: Label = $Overlay


func bind(ingredient: IngredientData, overlay_text: String, icon_size: Vector2) -> void:
	custom_minimum_size = icon_size
	size = icon_size
	if _icon != null:
		_icon.custom_minimum_size = icon_size
		_icon.size = icon_size
		_icon.texture = _load_art(ingredient)
	if _overlay != null:
		_overlay.text = overlay_text
		_overlay.visible = overlay_text != ""
		var font_size := clampi(int(icon_size.y * 0.52), 14, 28)
		_overlay.add_theme_font_size_override("font_size", font_size)


func _load_art(ingredient: IngredientData) -> Texture2D:
	if ingredient == null:
		return null
	var art_path := _ART_PATH_TEMPLATE % ingredient.get_art_filename()
	if not ResourceLoader.exists(art_path):
		return null
	return load(art_path) as Texture2D