class_name TrinketsDisplay
extends Control

const _TrinketIconScene := preload("res://scenes/ui/trinket_icon.tscn")

const MAX_COLUMNS := 6
const BASE_ICON_SIZE := 40.0
const MIN_ICON_SIZE := 24.0
const GRID_GAP := 4.0

@onready var _grid: GridContainer = $IconGrid
@onready var _tooltip_layer: CanvasLayer = $TooltipLayer
@onready var _tooltip: TrinketTooltip = $TooltipLayer/TrinketTooltip

var _icon_pool: Array[TrinketIcon] = []
var _hovered_icon: TrinketIcon


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	if _grid != null:
		_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_grid.add_theme_constant_override("h_separation", int(GRID_GAP))
		_grid.add_theme_constant_override("v_separation", int(GRID_GAP))
	if _tooltip != null:
		_tooltip.hide_tooltip()
	if not GameManager.run_changed.is_connected(_on_run_changed):
		GameManager.run_changed.connect(_on_run_changed)
	if not GameManager.brew_updated.is_connected(_on_brew_updated):
		GameManager.brew_updated.connect(_on_brew_updated)
	_refresh()


func _process(_delta: float) -> void:
	if _hovered_icon == null or not is_instance_valid(_hovered_icon):
		return
	if not _hovered_icon.get_global_rect().has_point(get_global_mouse_position()):
		_clear_hover()


func _on_run_changed() -> void:
	_refresh()


func _on_brew_updated(_ctx: BrewContext) -> void:
	_refresh()


func _refresh() -> void:
	_clear_hover()
	if _grid == null:
		return
	if GameManager.run == null:
		_hide_all_icons()
		visible = false
		return

	var trinkets := GameManager.run.get_owned_trinkets()
	if trinkets.is_empty():
		_hide_all_icons()
		visible = false
		return

	visible = true
	_grid.columns = MAX_COLUMNS
	var icon_size := _resolve_icon_size(trinkets.size())
	for index in trinkets.size():
		var icon := _get_or_create_icon(index)
		icon.bind(
			trinkets[index],
			icon_size,
			_countdown_text_for(trinkets[index]),
			_is_clickable_trinket(trinkets[index])
		)
		icon.visible = true

	for index in range(trinkets.size(), _icon_pool.size()):
		_icon_pool[index].visible = false


func _on_icon_hover_started(trinket: TrinketData) -> void:
	var icon := _find_icon_for_trinket(trinket)
	if icon == null:
		return
	_hovered_icon = icon
	if _tooltip != null:
		_tooltip.bind(trinket)
		_tooltip.show_below_icon(icon.get_global_rect())


func _on_icon_hover_ended() -> void:
	_clear_hover()


func _clear_hover() -> void:
	_hovered_icon = null
	if _tooltip != null:
		_tooltip.hide_tooltip()


func _find_icon_for_trinket(trinket: TrinketData) -> TrinketIcon:
	if trinket == null:
		return null
	for icon in _icon_pool:
		if not icon.visible:
			continue
		var bound := icon.get_trinket()
		if bound != null and bound.id == trinket.id:
			return icon
	return null


func _resolve_icon_size(entry_count: int) -> Vector2:
	var rows := ceili(float(entry_count) / float(MAX_COLUMNS))
	rows = maxi(rows, 1)
	var width_budget := size.x - GRID_GAP * float(MAX_COLUMNS - 1)
	var height_budget := size.y - GRID_GAP * float(rows - 1)
	var icon_w := width_budget / float(MAX_COLUMNS)
	var icon_h := height_budget / float(rows)
	var icon_dim := clampf(minf(icon_w, icon_h), MIN_ICON_SIZE, BASE_ICON_SIZE)
	return Vector2(icon_dim, icon_dim)


func _get_or_create_icon(index: int) -> TrinketIcon:
	while index >= _icon_pool.size():
		var icon := _TrinketIconScene.instantiate() as TrinketIcon
		_grid.add_child(icon)
		if not icon.hover_started.is_connected(_on_icon_hover_started):
			icon.hover_started.connect(_on_icon_hover_started)
		if not icon.hover_ended.is_connected(_on_icon_hover_ended):
			icon.hover_ended.connect(_on_icon_hover_ended)
		if not icon.activated.is_connected(_on_icon_activated):
			icon.activated.connect(_on_icon_activated)
		_icon_pool.append(icon)
	return _icon_pool[index]


func _hide_all_icons() -> void:
	for icon in _icon_pool:
		icon.visible = false


func _is_clickable_trinket(trinket: TrinketData) -> bool:
	if trinket == null or trinket.id != TrinketEffects.TIME_TURNER_ID:
		return false
	return GameManager.can_use_time_turner()


func _on_icon_activated(
	trinket: TrinketData,
	icon_center: Vector2,
	texture: Texture2D
) -> void:
	if trinket == null or trinket.id != TrinketEffects.TIME_TURNER_ID:
		return
	GameManager.try_use_time_turner(icon_center, texture)


func _countdown_text_for(trinket: TrinketData) -> String:
	if trinket == null:
		return ""
	if GameManager.run == null:
		return ""
	if GameManager.current_phase != GamePhase.Phase.BREWING:
		return ""
	var session := GameManager.run.brew_session
	if session.context.outcome != BrewOutcome.Outcome.IN_PROGRESS:
		return ""
	var countdown := 0
	if trinket.id == TrinketEffects.POCKET_WATCH_ID:
		countdown = session.get_pocket_watch_countdown()
	elif trinket.id == TrinketEffects.GECKO_ASSISTANT_ID:
		countdown = session.get_gecko_assistant_countdown()
	elif trinket.id == TrinketEffects.HEADLESS_CHICKEN_ID:
		countdown = session.get_headless_chicken_turns_remaining()
	else:
		return ""
	if countdown <= 0:
		return ""
	return str(countdown)