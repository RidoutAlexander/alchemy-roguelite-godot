class_name IngredientCard
extends Button

## Optional overrides — leave empty to use whatever you placed in the scene.
@export_group("Art Slots")
@export var card_background_texture: Texture2D
@export var name_plate_texture: Texture2D
@export var description_plate_texture: Texture2D
@export var cost_plate_texture: Texture2D
@export var art_frame_texture: Texture2D
@export var points_icon_texture: Texture2D
@export var explosive_icon_texture: Texture2D
@export var cost_icon_texture: Texture2D

signal offer_pressed(slot_index: int)
signal puzzle_drag_began(card: IngredientCard)
signal choice_pressed(card: IngredientCard)
signal picker_card_pressed(card: IngredientCard)

const CARD_TINT_SHADER := preload("res://shaders/card_rarity_tint.gdshader")

const HOVER_SCALE := 1.08
const SCALE_SPEED := 12.0

@onready var _visual_root: Control = $VisualRoot
@onready var _card_background: TextureRect = $VisualRoot/CardBackground
@onready var _name_label: Label = $VisualRoot/NamePlate/NameLabel
@onready var _art_frame_bg: TextureRect = $VisualRoot/ArtArea/ArtFrameBackground
@onready var _art_texture: TextureRect = $VisualRoot/ArtArea/IngredientArt
@onready var _art_placeholder: Label = $VisualRoot/ArtArea/ArtPlaceholder
@onready var _points_icon: TextureRect = $VisualRoot/StatsRow/PointsStat/Icon
@onready var _points_value: Label = $VisualRoot/StatsRow/PointsStat/ValueLabel
@onready var _explosive_icon: TextureRect = $VisualRoot/StatsRow/ExplosiveStat/IconBackground
@onready var _explosive_value: Label = $VisualRoot/StatsRow/ExplosiveStat/ValueLabel
@onready var _description_label: Label = $VisualRoot/DescriptionPanel/DescriptionLabel
@onready var _cost_plate_bg: TextureRect = $VisualRoot/CostRow/CostPlateBackground
@onready var _cost_icon: TextureRect = $VisualRoot/CostRow/Icon
@onready var _cost_label: Label = $VisualRoot/CostRow/CostLabel

var _name_plate_bg: TextureRect
var _description_plate_bg: TextureRect
var _name_plate_fallback: ColorRect
var _description_plate_fallback: ColorRect
var _explosive_icon_fallback: ColorRect
var _scene_art_locked: bool = false

var _slot_index: int = -1
var _ingredient: IngredientData
var _price: int = 0
var _has_offer: bool = false
var _rarity_tint := Color.WHITE
var _hover_enabled: bool = false
var _is_hovered: bool = false
var _puzzle_drag_enabled: bool = false
var _choice_mode: bool = false
var _picker_mode: bool = false
var _picker_selected: bool = false
var _puzzle_press_position: Vector2 = Vector2.INF
var _is_animating: bool = false


func _ready() -> void:
	_cache_optional_nodes()
	_scene_art_locked = _art_texture != null and _art_texture.texture != null

	flat = true
	focus_mode = Control.FOCUS_NONE
	pressed.connect(_on_pressed)
	_make_button_transparent()
	_apply_optional_art_overrides()
	_sync_ingredient_art_visibility()
	_set_empty_state()
	resized.connect(_on_resized)
	gui_input.connect(_on_gui_input)
	_ignore_visual_mouse_input(_visual_root)
	_update_hover_pivot()
	set_process(false)


func _cache_optional_nodes() -> void:
	_name_plate_bg = get_node_or_null("VisualRoot/NamePlate/PlateBackground") as TextureRect
	_description_plate_bg = get_node_or_null("VisualRoot/DescriptionPanel/PlateBackground") as TextureRect
	_name_plate_fallback = get_node_or_null("VisualRoot/NamePlate/NamePlateFallback") as ColorRect
	_description_plate_fallback = get_node_or_null("VisualRoot/DescriptionPanel/DescriptionFallback") as ColorRect
	_explosive_icon_fallback = get_node_or_null("VisualRoot/StatsRow/ExplosiveStat/IconFallback") as ColorRect


func get_ingredient() -> IngredientData:
	return _ingredient


func bind_puzzle_card(ingredient: IngredientData) -> void:
	set_puzzle_drag_enabled(true)
	bind_preview(ingredient)
	apply_puzzle_layout()


func bind_choice_card(ingredient: IngredientData) -> void:
	_choice_mode = true
	_hover_enabled = true
	_has_offer = false
	bind_preview(ingredient)


func bind_picker_card(ingredient: IngredientData) -> void:
	_picker_mode = true
	_choice_mode = false
	_picker_selected = false
	_puzzle_drag_enabled = false
	bind_preview(ingredient)
	apply_puzzle_layout()
	sync_picker_input()


func is_picker_mode() -> bool:
	return _picker_mode


func set_picker_selected(selected: bool) -> void:
	if not _picker_mode:
		return
	_picker_selected = selected
	if selected:
		_is_hovered = true
		set_process(false)
		if _visual_root != null:
			_visual_root.scale = Vector2.ONE * HOVER_SCALE
	else:
		_is_hovered = false
		set_process(true)
		_reset_visual_scale()


func set_picker_drag_enabled(_enabled: bool) -> void:
	_puzzle_drag_enabled = false
	sync_picker_input()


func sync_picker_input() -> void:
	if not _picker_mode:
		return
	mouse_filter = Control.MOUSE_FILTER_STOP
	disabled = false
	focus_mode = Control.FOCUS_NONE
	action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	_hover_enabled = true
	if not _picker_selected:
		set_process(true)


func apply_puzzle_layout() -> void:
	EyeballPuzzleLayout.configure_card(self)


func set_puzzle_drag_enabled(enabled: bool) -> void:
	_puzzle_drag_enabled = enabled
	_hover_enabled = false
	_is_hovered = false
	set_process(false)
	_reset_visual_scale()
	if is_node_ready():
		_sync_puzzle_input()


func _sync_puzzle_input() -> void:
	if _puzzle_drag_enabled:
		_has_offer = _ingredient != null
		mouse_filter = Control.MOUSE_FILTER_STOP
		disabled = false
		focus_mode = Control.FOCUS_NONE
		action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		_puzzle_press_position = Vector2.INF
		apply_puzzle_layout()
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		disabled = true
		action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
		_puzzle_press_position = Vector2.INF


func bind_preview(ingredient: IngredientData) -> void:
	if not is_node_ready():
		call_deferred("bind_preview", ingredient)
		return
	if ingredient == null:
		_set_empty_state()
		return

	_slot_index = -1
	_is_animating = false
	_ingredient = ingredient
	_price = 0
	_has_offer = true
	_hover_enabled = false
	_is_hovered = false
	set_process(false)
	_reset_visual_scale()
	visible = true
	_visual_root.visible = true
	_ensure_card_background_visible()
	_name_label.text = ingredient.display_name
	_description_label.text = ingredient.description
	_points_value.text = "%d" % ingredient.point_value
	if ingredient.explosive_value > 0:
		_explosive_value.text = "%d" % ingredient.explosive_value
		$VisualRoot/StatsRow/ExplosiveStat.visible = true
	else:
		_explosive_value.text = ""
		$VisualRoot/StatsRow/ExplosiveStat.visible = false
	_set_cost_row_visible(false)
	_apply_rarity_tint(ingredient.rarity)
	_apply_ingredient_art(ingredient)
	if _puzzle_drag_enabled:
		_sync_puzzle_input()
	elif _picker_mode:
		sync_picker_input()
	elif _choice_mode:
		mouse_filter = Control.MOUSE_FILTER_STOP
		disabled = false
		_hover_enabled = true
		set_process(true)
	else:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		disabled = true


func set_offer_hover_enabled(enabled: bool) -> void:
	if not _has_offer or _is_animating:
		return
	_hover_enabled = enabled
	if not enabled:
		_is_hovered = false
		_reset_visual_scale()
	set_process(enabled)


func bind_offer(ingredient: IngredientData, price: int, slot_index: int) -> void:
	if not is_node_ready():
		call_deferred("bind_offer", ingredient, price, slot_index)
		return
	if _is_animating:
		return

	_slot_index = slot_index
	_is_animating = false
	_hover_enabled = false
	_is_hovered = false
	_reset_visual_scale()
	if ingredient == null:
		_set_empty_state()
		return
	_ingredient = ingredient
	_price = price
	_has_offer = true
	visible = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	_visual_root.visible = true
	disabled = false
	_hover_enabled = true
	set_process(true)
	_ensure_card_background_visible()
	_name_label.text = ingredient.display_name
	_description_label.text = ingredient.description
	_cost_label.text = "%d" % price
	_points_value.text = "%d" % ingredient.point_value
	if ingredient.explosive_value > 0:
		_explosive_value.text = "%d" % ingredient.explosive_value
		$VisualRoot/StatsRow/ExplosiveStat.visible = true
	else:
		_explosive_value.text = ""
		$VisualRoot/StatsRow/ExplosiveStat.visible = false
	_set_cost_row_visible(true)
	_apply_rarity_tint(ingredient.rarity)
	_apply_ingredient_art(ingredient)


func _set_cost_row_visible(visible_row: bool) -> void:
	var cost_row := $VisualRoot.get_node_or_null("CostRow")
	if cost_row != null:
		cost_row.visible = visible_row


func get_art_global_center() -> Vector2:
	if not is_node_ready():
		return get_global_rect().get_center()
	if _art_texture != null and _art_texture.visible:
		var art_rect := _art_texture.get_global_rect()
		if art_rect.size.x >= 2.0 and art_rect.size.y >= 2.0:
			return art_rect.get_center()
	return get_global_rect().get_center()


func capture_fly_data() -> Dictionary:
	if not is_node_ready() or not _has_offer:
		return {}

	var texture: Texture2D = null
	if _art_texture != null and _art_texture.texture != null:
		texture = _art_texture.texture
	elif _ingredient != null:
		var art_path := "res://assets/cards/ingredients/%s.png" % _ingredient.get_art_filename()
		if ResourceLoader.exists(art_path):
			texture = load(art_path)
	if texture == null:
		return {}

	var art_rect := _art_texture.get_global_rect() if _art_texture != null else get_global_rect()
	if art_rect.size.x < 2.0 or art_rect.size.y < 2.0:
		var center := get_global_rect().get_center()
		art_rect = Rect2(center - Vector2(48.0, 48.0), Vector2(96.0, 96.0))

	return {
		"texture": texture,
		"size": art_rect.size,
		"start_center": art_rect.get_center(),
	}


func hide_for_purchase() -> void:
	_is_animating = true
	_hover_enabled = false
	_is_hovered = false
	set_process(false)
	disabled = true
	_reset_visual_scale()
	_visual_root.visible = false
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func clear_purchased_slot() -> void:
	_is_animating = false
	_set_empty_state()


func _apply_optional_art_overrides() -> void:
	_set_texture_if_empty(_card_background, card_background_texture)
	_set_texture_if_empty(_name_plate_bg, name_plate_texture, _name_plate_fallback)
	_set_texture_if_empty(_description_plate_bg, description_plate_texture, _description_plate_fallback)
	_set_texture_if_empty(_cost_plate_bg, cost_plate_texture)
	_set_texture_if_empty(_art_frame_bg, art_frame_texture)
	_set_texture_if_empty(_points_icon, points_icon_texture)
	_set_texture_if_empty(_explosive_icon, explosive_icon_texture, _explosive_icon_fallback)
	_set_texture_if_empty(_cost_icon, cost_icon_texture)


func _apply_rarity_tint(rarity: int) -> void:
	if _card_background == null:
		return
	_rarity_tint = RarityPalette.card_tint(rarity)
	_card_background.modulate = Color.WHITE
	var tint_material := _card_background.material as ShaderMaterial
	if tint_material == null:
		tint_material = ShaderMaterial.new()
		tint_material.shader = CARD_TINT_SHADER
		_card_background.material = tint_material
	tint_material.set_shader_parameter("tint_color", _rarity_tint)
	tint_material.set_shader_parameter("tint_strength", RarityPalette.card_tint_strength(rarity))


func _ensure_card_background_visible() -> void:
	if _card_background == null:
		return
	_card_background.visible = true


func _reset_visual_scale() -> void:
	if _visual_root != null:
		_visual_root.scale = Vector2.ONE


func _ignore_visual_mouse_input(node: Node) -> void:
	if node is Control and node != self:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_visual_mouse_input(child)


func _apply_ingredient_art(ingredient: IngredientData) -> void:
	if _art_texture == null:
		return

	if _scene_art_locked:
		_sync_ingredient_art_visibility()
		return

	var art_path := "res://assets/cards/ingredients/%s.png" % ingredient.get_art_filename()
	if ResourceLoader.exists(art_path):
		_art_texture.texture = load(art_path)
		_art_texture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_art_texture.visible = true
		if _art_placeholder != null:
			_art_placeholder.visible = false
	else:
		_art_texture.texture = null
		_art_texture.visible = false
		if _art_placeholder != null:
			_art_placeholder.visible = true
			_art_placeholder.text = ingredient.display_name


func _sync_ingredient_art_visibility() -> void:
	if _art_texture == null:
		return
	var has_art := _art_texture.texture != null
	_art_texture.visible = has_art
	if _art_placeholder != null:
		_art_placeholder.visible = not has_art


func _set_empty_state() -> void:
	if not is_node_ready():
		return
	_has_offer = false
	_hover_enabled = false
	_is_hovered = false
	set_process(false)
	disabled = true
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reset_visual_scale()
	_visual_root.visible = false


func _make_button_transparent() -> void:
	var empty := StyleBoxEmpty.new()
	add_theme_stylebox_override("normal", empty)
	add_theme_stylebox_override("hover", empty)
	add_theme_stylebox_override("pressed", empty)
	add_theme_stylebox_override("disabled", empty)
	add_theme_stylebox_override("focus", empty)


func _set_texture_if_empty(
	target: TextureRect,
	texture: Texture2D,
	fallback: CanvasItem = null
) -> void:
	if target == null or texture == null or target.texture != null:
		return
	target.texture = texture
	target.visible = true
	if fallback != null:
		fallback.visible = false


func _on_resized() -> void:
	_update_hover_pivot()


func _update_hover_pivot() -> void:
	if _visual_root != null:
		_visual_root.pivot_offset = _visual_root.size * 0.5


func _is_cursor_over_card() -> bool:
	return get_global_rect().has_point(get_global_mouse_position())


func _process(delta: float) -> void:
	if _picker_selected or not _hover_enabled or _is_animating or _visual_root == null:
		return
	_is_hovered = _is_cursor_over_card()
	var target_scale := HOVER_SCALE if _is_hovered else 1.0
	var next_scale := lerpf(_visual_root.scale.x, target_scale, SCALE_SPEED * delta)
	_visual_root.scale = Vector2.ONE * next_scale


func _on_gui_input(event: InputEvent) -> void:
	if not _puzzle_drag_enabled or _ingredient == null:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_puzzle_press_position = event.global_position
		else:
			_puzzle_press_position = Vector2.INF
	elif event is InputEventMouseMotion and _puzzle_press_position != Vector2.INF:
		if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
			return
		if event.global_position.distance_to(_puzzle_press_position) < 8.0:
			return
		_puzzle_press_position = Vector2.INF
		puzzle_drag_began.emit(self)
		accept_event()


func _on_pressed() -> void:
	if _picker_mode and not _is_animating:
		picker_card_pressed.emit(self)
		return
	if _choice_mode and not _is_animating:
		choice_pressed.emit(self)
		return
	if _puzzle_drag_enabled:
		return
	if _has_offer and not _is_animating:
		_is_hovered = false
		_reset_visual_scale()
		offer_pressed.emit(_slot_index)
