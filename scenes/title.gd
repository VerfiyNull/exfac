extends Control
## Title — brand + Continue / New only. Soft accent pulse; no extra chrome.

@onready var accent: ColorRect = $Accent
@onready var save_hint: Label = %SaveHint
@onready var continue_button: Button = %ContinueButton
@onready var new_button: Button = %NewButton
@onready var version_label: Label = %VersionLabel

var _has_save := false
var _new_armed := false
var _pulse := 0.0


func _ready() -> void:
	version_label.text = "v%s" % GameSession.APP_VERSION
	_has_save = false
	_new_armed = false
	var meta_preview := {}
	if SaveGame.has_save():
		meta_preview = SaveGame.load_meta()
		if meta_preview.is_empty():
			# Damaged file still on disk — don't offer Continue; New run can wipe.
			save_hint.text = "Save damaged — choose New run to wipe, or fix the file."
			continue_button.visible = false
			new_button.text = "New run"
			UiStyle.style_button(new_button, true)
			continue_button.pressed.connect(_on_continue)
			new_button.pressed.connect(_on_new_pressed)
			return
		_has_save = true
	continue_button.visible = _has_save
	if _has_save:
		save_hint.text = SaveGame.summarize(meta_preview)
		continue_button.text = "Continue"
		new_button.text = "New run"
		UiStyle.style_button(continue_button, true)
		UiStyle.style_button(new_button, false)
	else:
		save_hint.text = ""
		continue_button.visible = false
		new_button.text = "Begin"
		UiStyle.style_button(new_button, true)
	continue_button.pressed.connect(_on_continue)
	new_button.pressed.connect(_on_new_pressed)


func _process(dt: float) -> void:
	_pulse += dt
	# Quiet brand cue — accent breathes without competing with Continue.
	var a := 0.55 + 0.45 * (0.5 + 0.5 * sin(_pulse * 1.6))
	accent.modulate = Color(1, 1, 1, a)
	if Input.is_action_just_pressed("start_raid") or Input.is_action_just_pressed("ui_accept"):
		# When wipe is armed, Enter confirms New run instead of Continue.
		if _new_armed:
			GameSession.start_new_run()
		elif _has_save:
			_on_continue()
		else:
			GameSession.start_new_run()
	elif Input.is_action_just_pressed("pause_game") and _new_armed:
		_disarm_new()


func _on_continue() -> void:
	_disarm_new()
	GameSession.continue_run()


func _on_new_pressed() -> void:
	if not _has_save:
		GameSession.start_new_run()
		return
	if not _new_armed:
		_new_armed = true
		new_button.text = "Confirm wipe"
		save_hint.text = "This erases the save. Press again to confirm — Esc cancels."
		return
	GameSession.start_new_run()


func _disarm_new() -> void:
	if not _new_armed:
		return
	_new_armed = false
	if _has_save:
		new_button.text = "New run"
		save_hint.text = SaveGame.summarize(SaveGame.load_meta())
