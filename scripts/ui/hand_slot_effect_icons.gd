class_name HandSlotEffectIcons
extends Control

const _EffectIconScene := preload("res://scenes/ui/brew_persistent_effect_icon.tscn")

const MAX_ICONS := 4
const ICON_SIZE := 22.0
const ICON_GAP := 2.0

@onready var _icon_row: HBoxContainer = $IconRow

var _icon_pool: Array[BrewPersistentEffectIcon] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = _strip_size()
	size = custom_minimum_size
	if _icon_row != null:
		_icon_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_icon_row.add_theme_constant_override("separation", int(ICON_GAP))


func bind_entries(entries: Array, ingredient_lookup: Callable) -> void:
	_ensure_icon_row()
	var icon_size := Vector2(ICON_SIZE, ICON_SIZE)
	var visible_count := mini(entries.size(), MAX_ICONS)
	for index in visible_count:
		var entry = entries[index]
		if not entry is Dictionary:
			continue
		var trinket_id := str(entry.get("trinket_id", ""))
		var ingredient_id := str(entry.get("ingredient_id", ""))
		var ingredient: IngredientData = null
		if trinket_id.is_empty():
			if ingredient_id.is_empty():
				continue
			ingredient = ingredient_lookup.call(ingredient_id)
			if ingredient == null:
				continue
		var icon := _get_or_create_icon(index)
		icon.bind(
			ingredient,
			str(entry.get("overlay_text", "")),
			icon_size,
			trinket_id
		)
		icon.visible = true

	for index in range(visible_count, _icon_pool.size()):
		_icon_pool[index].visible = false

	visible = visible_count > 0


func clear_icons() -> void:
	for icon in _icon_pool:
		icon.visible = false
	visible = false


func _strip_size() -> Vector2:
	var width := ICON_SIZE * float(MAX_ICONS) + ICON_GAP * float(MAX_ICONS - 1)
	return Vector2(width, ICON_SIZE)


func _get_or_create_icon(index: int) -> BrewPersistentEffectIcon:
	_ensure_icon_row()
	while index >= _icon_pool.size():
		var icon := _EffectIconScene.instantiate() as BrewPersistentEffectIcon
		if _icon_row != null:
			_icon_row.add_child(icon)
		_icon_pool.append(icon)
	return _icon_pool[index]


func _ensure_icon_row() -> void:
	if _icon_row != null:
		return
	_icon_row = get_node_or_null("IconRow") as HBoxContainer