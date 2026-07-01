@tool
extends Control

@onready var _background: TextureRect = $Background
@onready var _intro_video: VideoStreamPlayer = $IntroVideo
@onready var _intro_audio: AudioStreamPlayer = $IntroAudio
@onready var _play_button: WoodenButton = $PlayButton
@onready var _continue_button: WoodenButton = $ContinueButton
@onready var _easy_button: WoodenButton = $EasyButton
@onready var _hard_button: WoodenButton = $HardButton

var _intro_playing: bool = false
var _difficulty_picker_open: bool = false
var _selected_difficulty: int = GameDifficulty.Mode.HARD


func _ready() -> void:
	if Engine.is_editor_hint():
		_sync_editor_presentation()
		return

	if _play_button == null:
		push_error("MainMenu: PlayButton not found")
	elif not _play_button.pressed.is_connected(_on_play_pressed):
		_play_button.pressed.connect(_on_play_pressed)

	if _continue_button != null and not _continue_button.pressed.is_connected(_on_continue_pressed):
		_continue_button.pressed.connect(_on_continue_pressed)

	if _easy_button != null and not _easy_button.pressed.is_connected(_on_easy_pressed):
		_easy_button.pressed.connect(_on_easy_pressed)
	if _hard_button != null and not _hard_button.pressed.is_connected(_on_hard_pressed):
		_hard_button.pressed.connect(_on_hard_pressed)

	visibility_changed.connect(_on_visibility_changed)
	_bind_intro_video_stream()
	_set_difficulty_picker_open(false)
	_refresh_continue()


func _bind_intro_video_stream() -> void:
	if _intro_video == null:
		return
	var intro_path := "res://assets/main_menu/intro.ogv"
	if not ResourceLoader.exists(intro_path):
		return
	var stream: Resource = ResourceLoader.load(intro_path)
	if stream is VideoStream:
		_intro_video.stream = stream


func _sync_editor_presentation() -> void:
	if _continue_button != null:
		_continue_button.visible = true
	if _play_button != null:
		_play_button.visible = true
	if _easy_button != null:
		_easy_button.visible = false
	if _hard_button != null:
		_hard_button.visible = false
	if _background != null:
		_background.visible = true
	if _intro_video != null:
		_intro_video.visible = false


func _on_visibility_changed() -> void:
	if Engine.is_editor_hint():
		return
	if visible:
		_reset_intro_state()
		_refresh_continue()


func _reset_intro_state() -> void:
	_intro_playing = false
	_set_difficulty_picker_open(false)
	if _background != null:
		_background.visible = true
	_stop_intro_media()
	if _play_button != null:
		_play_button.visible = true
	_refresh_continue()


func _stop_intro_media() -> void:
	if _intro_video != null:
		_intro_video.visible = false
		if _intro_video.finished.is_connected(_on_intro_clip_finished):
			_intro_video.finished.disconnect(_on_intro_clip_finished)
		_intro_video.stop()
	if _intro_audio != null:
		if _intro_audio.finished.is_connected(_on_intro_clip_finished):
			_intro_audio.finished.disconnect(_on_intro_clip_finished)
		_intro_audio.stop()


func _refresh_continue() -> void:
	if _continue_button == null or _intro_playing:
		return
	if Engine.is_editor_hint():
		_continue_button.visible = true
		return
	_continue_button.visible = GameManager.has_save()


func _set_difficulty_picker_open(open: bool) -> void:
	_difficulty_picker_open = open
	if _easy_button != null:
		_easy_button.visible = open
	if _hard_button != null:
		_hard_button.visible = open
	_refresh_continue()


func _on_play_pressed() -> void:
	if _intro_playing:
		return
	if _difficulty_picker_open:
		_set_difficulty_picker_open(false)
		return
	_set_difficulty_picker_open(true)


func _on_easy_pressed() -> void:
	_begin_new_run_with_difficulty(GameDifficulty.Mode.EASY)


func _on_hard_pressed() -> void:
	_begin_new_run_with_difficulty(GameDifficulty.Mode.HARD)


func _begin_new_run_with_difficulty(difficulty: int) -> void:
	_selected_difficulty = difficulty
	_set_difficulty_picker_open(false)
	_play_intro_then_start_new_run()


func _play_intro_then_start_new_run() -> void:
	var has_video := _intro_video != null and _intro_video.stream != null
	var has_audio := _intro_audio != null and _intro_audio.stream != null
	if not has_video and not has_audio:
		await _start_game_scene(true)
		return

	_intro_playing = true
	if _play_button != null:
		_play_button.visible = false
	if _continue_button != null:
		_continue_button.visible = false
	if _background != null:
		_background.visible = false

	if has_video:
		_intro_video.visible = true
		if not _intro_video.finished.is_connected(_on_intro_clip_finished):
			_intro_video.finished.connect(_on_intro_clip_finished, CONNECT_ONE_SHOT)
		_intro_video.play()
	elif has_audio and not _intro_audio.finished.is_connected(_on_intro_clip_finished):
		_intro_audio.finished.connect(_on_intro_clip_finished, CONNECT_ONE_SHOT)

	if has_audio:
		_intro_audio.play()


func _on_intro_clip_finished() -> void:
	if not _intro_playing:
		return
	_stop_intro_media()
	_intro_playing = false
	await _start_game_scene(true)


func _on_continue_pressed() -> void:
	await _start_game_scene(false)


func _start_game_scene(new_run: bool) -> void:
	if new_run:
		GameManager.start_new_run(_selected_difficulty)
	else:
		GameManager.continue_run()
	await SceneTransition.go_to("res://scenes/game.tscn")
