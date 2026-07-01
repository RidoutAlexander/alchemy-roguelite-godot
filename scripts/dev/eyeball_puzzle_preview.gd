extends Control

## Standalone scene for tuning the eyeball puzzle overlay.
## Run this scene directly in the Godot editor (F6).

const _SAMPLE_IDS := ["pumpkin", "red_mushroom", "chili_pepper"]

@onready var _overlay: EyeballPuzzleOverlay = $EyeballPuzzleOverlay
@onready var _status_label: Label = $DevChrome/StatusLabel


func _ready() -> void:
	var ingredients: Array[IngredientData] = []
	var catalog := SpreadsheetContentLoader.load_ingredients()
	for ingredient_id in _SAMPLE_IDS:
		if catalog.has(ingredient_id):
			ingredients.append(catalog[ingredient_id])

	if ingredients.is_empty():
		if _status_label != null:
			_status_label.text = "No sample ingredients found."
		return

	_overlay.completed.connect(_on_puzzle_completed)
	_overlay.show_puzzle(ingredients)
	if _status_label != null:
		_status_label.text = "Drag cards between slots 1-3 to reorder, then press Done."


func _on_puzzle_completed(ordered: Array) -> void:
	var names: PackedStringArray = []
	for ingredient in ordered:
		if ingredient is IngredientData:
			names.append(ingredient.display_name)
	if _status_label != null:
		_status_label.text = "Confirmed order: %s" % ", ".join(names)
	call_deferred("_reopen_preview", ordered)


func _reopen_preview(_ordered: Array) -> void:
	var ingredients: Array[IngredientData] = []
	var catalog := SpreadsheetContentLoader.load_ingredients()
	for ingredient_id in _SAMPLE_IDS:
		if catalog.has(ingredient_id):
			ingredients.append(catalog[ingredient_id])
	_overlay.show_puzzle(ingredients)
	if _status_label != null:
		_status_label.text = "Preview reopened — drag between slots 1-3, then Done."