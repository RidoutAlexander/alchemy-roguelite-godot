class_name TrinketRewardOption
extends PanelContainer

signal selected(trinket: TrinketData)

const _ART_PATH_TEMPLATE := "res://assets/cards/trinkets/%s.png"

@onready var _icon: TextureRect = $MarginContainer/Column/IconFrame/Icon
@onready var _fallback: Panel = $MarginContainer/Column/IconFrame/Fallback
@onready var _name_label: Label = $MarginContainer/Column/NameLabel
@onready var _description_label: RichTextLabel = $MarginContainer/Column/Description

var _trinket: TrinketData
var _selectable := true
var _dev_selected := false
var _dev_owned := false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_pass_mouse_input_to_root(self)
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)


func _pass_mouse_input_to_root(node: Node) -> void:
	for child in node.get_children():
		if child is Control:
			var control := child as Control
			control.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_pass_mouse_input_to_root(control)


func get_trinket() -> TrinketData:
	return _trinket


func get_icon_global_center() -> Vector2:
	if _icon != null and _icon.visible:
		return _icon.get_global_rect().get_center()
	return get_global_rect().get_center()


func get_icon_texture() -> Texture2D:
	if _icon != null and _icon.texture != null:
		return _icon.texture
	return null


func hide_for_poof() -> void:
	if _icon != null:
		_icon.visible = false
	if _fallback != null:
		_fallback.visible = false
	if _name_label != null:
		_name_label.visible = false
	if _description_label != null:
		_description_label.visible = false


func bind(trinket: TrinketData) -> void:
	_trinket = trinket
	_selectable = true
	_dev_selected = false
	_dev_owned = false
	_apply_dev_visual_state()
	if trinket == null:
		_clear()
		return
	if _name_label != null:
		_name_label.text = trinket.display_name
	if _description_label != null:
		_description_label.text = trinket.description
	var texture := _load_art(trinket)
	if _icon != null:
		_icon.texture = texture
		_icon.visible = texture != null
	if _fallback != null:
		_fallback.visible = texture == null


func set_selectable(enabled: bool) -> void:
	_selectable = enabled


func set_dev_picker_state(selected: bool, owned: bool) -> void:
	_dev_selected = selected
	_dev_owned = owned
	_apply_dev_visual_state()


func _apply_dev_visual_state() -> void:
	if _dev_selected:
		modulate = Color(0.9, 1.05, 0.82, 1.0)
	elif _dev_owned:
		modulate = Color(0.72, 0.72, 0.72, 1.0)
	else:
		modulate = Color.WHITE


func _clear() -> void:
	if _name_label != null:
		_name_label.text = ""
	if _description_label != null:
		_description_label.text = ""
	if _icon != null:
		_icon.texture = null
		_icon.visible = false
	if _fallback != null:
		_fallback.visible = true


func _on_gui_input(event: InputEvent) -> void:
	if not _selectable or _trinket == null:
		return
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			selected.emit(_trinket)
			accept_event()


func _load_art(trinket: TrinketData) -> Texture2D:
	var art_path := _ART_PATH_TEMPLATE % trinket.get_art_filename()
	if not ResourceLoader.exists(art_path):
		return null
	return load(art_path) as Texture2D