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


func bind(trinket: TrinketData) -> void:
	_trinket = trinket
	_selectable = true
	modulate = Color.WHITE
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


func _load_art(trinket: TrinketData) -> Texture2D:
	var art_path := _ART_PATH_TEMPLATE % trinket.get_art_filename()
	if not ResourceLoader.exists(art_path):
		return null
	return load(art_path) as Texture2D