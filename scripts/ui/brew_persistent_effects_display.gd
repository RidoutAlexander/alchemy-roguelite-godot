class_name BrewPersistentEffectsDisplay
extends Control

const _EffectIconScene := preload("res://scenes/ui/brew_persistent_effect_icon.tscn")

const MAX_COLUMNS := 5
const BASE_ICON_SIZE := 44.0
const MIN_ICON_SIZE := 24.0
const GRID_GAP := 4.0

@onready var _grid: GridContainer = $IconGrid

var _icon_pool: Array[BrewPersistentEffectIcon] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _grid != null:
		_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid.add_theme_constant_override("h_separation", int(GRID_GAP))
		_grid.add_theme_constant_override("v_separation", int(GRID_GAP))
	if not GameManager.brew_updated.is_connected(_on_brew_updated):
		GameManager.brew_updated.connect(_on_brew_updated)
	_refresh()


func _on_brew_updated(_ctx: BrewContext) -> void:
	_refresh()


func _refresh() -> void:
	if _grid == null:
		return
	if GameManager.run == null:
		_hide_all_icons()
		visible = false
		return

	var session := GameManager.run.brew_session
	if session.context.outcome != BrewOutcome.Outcome.IN_PROGRESS:
		_hide_all_icons()
		visible = false
		return

	var entries := session.get_persistent_effect_entries()
	if entries.is_empty():
		_hide_all_icons()
		visible = false
		return

	visible = true
	_grid.columns = MAX_COLUMNS
	var icon_size := _resolve_icon_size(entries.size())
	for index in entries.size():
		var icon := _get_or_create_icon(index)
		var ingredient := GameManager.run.find_ingredient(entries[index].ingredient_id)
		icon.bind(ingredient, entries[index].overlay_text, icon_size)
		icon.visible = true

	for index in range(entries.size(), _icon_pool.size()):
		_icon_pool[index].visible = false


func _resolve_icon_size(entry_count: int) -> Vector2:
	var rows := ceili(float(entry_count) / float(MAX_COLUMNS))
	rows = maxi(rows, 1)
	var width_budget := size.x - GRID_GAP * float(MAX_COLUMNS - 1)
	var height_budget := size.y - GRID_GAP * float(rows - 1)
	var icon_w := width_budget / float(MAX_COLUMNS)
	var icon_h := height_budget / float(rows)
	var icon_dim := clampf(minf(icon_w, icon_h), MIN_ICON_SIZE, BASE_ICON_SIZE)
	return Vector2(icon_dim, icon_dim)


func _get_or_create_icon(index: int) -> BrewPersistentEffectIcon:
	while index >= _icon_pool.size():
		var icon := _EffectIconScene.instantiate() as BrewPersistentEffectIcon
		_grid.add_child(icon)
		_icon_pool.append(icon)
	return _icon_pool[index]


func _hide_all_icons() -> void:
	for icon in _icon_pool:
		icon.visible = false