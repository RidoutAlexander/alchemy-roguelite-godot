extends Control

@onready var _bag_button: TextureButton = $RunPrepPanel/BagColumn/BagButton
@onready var _ready_button: WoodenButton = $RunPrepPanel/BagColumn/ReadyButton
@onready var _bag_contents: BagContentsOverlay = $RunPrepPanel/BagContentsOverlay
@onready var _aura_banner: LevelAuraBanner = $RunPrepPanel/LevelAuraBanner


func _ready() -> void:
	print("RunPrep: prep scene loaded — press Ready to start brew")
	_wire_controls()
	_refresh_preview()


func _wire_controls() -> void:
	if _bag_button != null and not _bag_button.pressed.is_connected(_on_bag_pressed):
		_bag_button.pressed.connect(_on_bag_pressed)
	if _ready_button != null and not _ready_button.pressed.is_connected(_on_ready_pressed):
		_ready_button.pressed.connect(_on_ready_pressed)


func _on_bag_pressed() -> void:
	if _bag_contents != null and GameManager.run != null:
		_bag_contents.toggle(GameManager.run.bag)


func _on_ready_pressed() -> void:
	print("RunPrep: Ready pressed — starting first brew")
	if _ready_button != null:
		_ready_button.disabled = true
	if not GameManager.press_ready_to_start_first_brew():
		if _ready_button != null:
			_ready_button.disabled = false
		return
	await SceneTransition.go_to(GameManager.GAME_SCENE_PATH)


func _refresh_preview() -> void:
	if _aura_banner == null or GameManager.run == null:
		return
	var run := GameManager.run
	_aura_banner.bind_preview(
		run.get_upcoming_brew_level(),
		run.ensure_aura_locked_for_upcoming_brew()
	)