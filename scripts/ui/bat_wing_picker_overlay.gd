class_name BatWingPickerOverlay
extends CanvasLayer

signal completed(selected: IngredientData)

const _CARD_SCENE := preload("res://scenes/ui/ingredient_card.tscn")

@onready var _choices_row: HBoxContainer = $Layout/PanelOffset/Panel/Content/ChoicesRow

var _choice_cards: Array[IngredientCard] = []


func _ready() -> void:
	visible = false


func show_picker(ingredients: Array) -> void:
	_clear_cards()
	visible = true

	for ingredient in ingredients:
		if ingredient == null:
			continue
		var card := _CARD_SCENE.instantiate() as IngredientCard
		if card == null:
			continue
		card.bind_choice_card(ingredient)
		card.scale = Vector2(0.34, 0.34)
		if not card.choice_pressed.is_connected(_on_choice_pressed):
			card.choice_pressed.connect(_on_choice_pressed)
		if not card.mouse_entered.is_connected(_on_choice_hovered):
			card.mouse_entered.connect(_on_choice_hovered.bind(ingredient))
		_choices_row.add_child(card)
		_choice_cards.append(card)


func hide_picker() -> void:
	visible = false
	GameManager.clear_bat_wing_pick_preview()
	_clear_cards()


func _on_choice_hovered(ingredient: IngredientData) -> void:
	if ingredient == null:
		return
	GameManager.set_bat_wing_pick_preview(ingredient)


func _on_choice_pressed(card: IngredientCard) -> void:
	if card == null:
		return
	var ingredient := card.get_ingredient()
	if ingredient == null:
		return
	hide_picker()
	completed.emit(ingredient)


func _clear_cards() -> void:
	_choice_cards.clear()
	if _choices_row == null:
		return
	for child in _choices_row.get_children():
		child.queue_free()