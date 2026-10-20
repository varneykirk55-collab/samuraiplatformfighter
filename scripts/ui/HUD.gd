extends CanvasLayer

var status: Label
var p1_readout: Label
var p2_readout: Label
var pause_panel: PanelContainer
var results_panel: PanelContainer
var training_panel: PanelContainer
var p1_damage: SpinBox
var dummy_damage: SpinBox
var debug_toggle: CheckBox


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	MatchManager.match_state_changed.connect(_refresh)
	MatchManager.match_ended.connect(_show_result)
	_refresh()


func _process(_delta: float) -> void:
	_refresh()


func _build() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var top := PanelContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 22
	top.offset_right = -22
	top.offset_top = 18
	top.offset_bottom = 88
	root.add_child(top)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 36)
	top.add_child(line)
	p1_readout = _label("P1    0%   •••", 19)
	p1_readout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(p1_readout)
	status = _label("03:00   •   ROUND 1", 22)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(status)
	var pause := Button.new()
	pause.text = "Ⅱ  PAUSE"
	pause.pressed.connect(func(): MatchManager.toggle_pause())
	line.add_child(pause)
	p2_readout = _label("•••   0%    P2", 19)
	p2_readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	p2_readout.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	line.add_child(p2_readout)

	pause_panel = _center_panel(root, "PAUSED", ["RESUME", "RETURN TO MENU"])
	var pause_buttons: VBoxContainer = pause_panel.get_node("Margin/VBox")
	pause_buttons.get_child(1).pressed.connect(
		func():
			MatchManager.toggle_pause()
			pause_panel.hide()
	)
	pause_buttons.get_child(2).pressed.connect(_return_to_menu)
	pause_panel.hide()

	results_panel = _center_panel(root, "MATCH OVER", ["REMATCH", "MAIN MENU"])
	var result_buttons: VBoxContainer = results_panel.get_node("Margin/VBox")
	result_buttons.get_child(1).pressed.connect(_rematch)
	result_buttons.get_child(2).pressed.connect(_return_to_menu)
	results_panel.hide()

	if MatchManager.training_mode:
		_build_training(root)
	MatchManager.match_state_changed.connect(_sync_panels)


func _center_panel(parent: Control, heading: String, buttons: Array) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-185, -145)
	panel.size = Vector2(370, 290)
	panel.custom_minimum_size = Vector2(370, 290)
	var margin := MarginContainer.new()
	margin.name = "Margin"
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	var vbox := VBoxContainer.new()
	vbox.name = "VBox"
	vbox.add_theme_constant_override("separation", 14)
	margin.add_child(vbox)
	var title := _label(heading, 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)
	for text in buttons:
		var button := Button.new()
		button.text = text
		button.custom_minimum_size.y = 42
		vbox.add_child(button)
	parent.add_child(panel)
	return panel


func _build_training(parent: Control) -> void:
	training_panel = PanelContainer.new()
	training_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	training_panel.offset_left = 18
	training_panel.offset_bottom = -18
	training_panel.position.y = -10
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	training_panel.add_child(v)
	v.add_child(_label("TRAINING  •  T toggles hitboxes", 16))
	p1_damage = _spinbox(0)
	dummy_damage = _spinbox(0)
	v.add_child(_label("Player percent", 13))
	v.add_child(p1_damage)
	v.add_child(_label("Dummy percent", 13))
	v.add_child(dummy_damage)
	p1_damage.value_changed.connect(
		func(value: float):
			if is_instance_valid(MatchManager.fighter1):
				MatchManager.fighter1.percent = value
	)
	dummy_damage.value_changed.connect(
		func(value: float):
			if is_instance_valid(MatchManager.fighter2):
				MatchManager.fighter2.percent = value
	)
	debug_toggle = CheckBox.new()
	debug_toggle.text = "Hitbox / hurtbox view"
	debug_toggle.toggled.connect(_toggle_debug)
	v.add_child(debug_toggle)
	var reset := Button.new()
	reset.text = "RESET POSITIONS / DAMAGE"
	reset.pressed.connect(
		func():
			MatchManager.reset_training()
			p1_damage.value = 0
			dummy_damage.value = 0
	)
	v.add_child(reset)
	var ai := OptionButton.new()
	ai.add_item("Dummy: Stand", 0)
	ai.add_item("Dummy: Walk", 1)
	ai.add_item("Dummy: Jump", 2)
	ai.item_selected.connect(
		func(index: int):
			if is_instance_valid(MatchManager.fighter2):
				MatchManager.fighter2.dummy_behavior = index
	)
	v.add_child(ai)
	parent.add_child(training_panel)


func _spinbox(value: float) -> SpinBox:
	var spin := SpinBox.new()
	spin.min_value = 0
	spin.max_value = 999
	spin.step = 1
	spin.value = value
	return spin


func _toggle_debug(enabled: bool) -> void:
	for fighter in get_tree().get_nodes_in_group("fighters"):
		fighter.show_debug = enabled


func _refresh() -> void:
	if not is_instance_valid(status):
		return
	var seconds := int(maxf(0, MatchManager.timer))
	var clock := "%02d:%02d" % [seconds / 60, seconds % 60]
	status.text = (
		"SUDDEN DEATH"
		if MatchManager.sudden_death
		else "%s   •   ROUND %d / 3" % [clock, MatchManager.round_number]
	)
	if is_instance_valid(MatchManager.fighter1):
		var f := MatchManager.fighter1
		p1_readout.text = (
			"%s    %d%%    x%d" % [f.character.display_name, roundi(f.percent), f.stocks]
		)
	if is_instance_valid(MatchManager.fighter2):
		var f := MatchManager.fighter2
		p2_readout.text = (
			"%s    %d%%    x%d" % [f.character.display_name, roundi(f.percent), f.stocks]
		)
	if (
		is_instance_valid(p1_damage)
		and MatchManager.training_mode
		and is_instance_valid(MatchManager.fighter1)
	):
		if not p1_damage.has_focus():
			p1_damage.set_value_no_signal(MatchManager.fighter1.percent)
		if not dummy_damage.has_focus() and is_instance_valid(MatchManager.fighter2):
			dummy_damage.set_value_no_signal(MatchManager.fighter2.percent)


func _sync_panels() -> void:
	if is_instance_valid(pause_panel):
		pause_panel.visible = MatchManager.paused


func _show_result(winner: int) -> void:
	results_panel.show()
	results_panel.get_node("Margin/VBox").get_child(0).text = "PLAYER %d WINS" % winner


func _rematch() -> void:
	MatchManager.p1_round_wins = 0
	MatchManager.p2_round_wins = 0
	MatchManager.round_number = 1
	MatchManager.match_over = false
	MatchManager.round_reset_pending = false
	results_panel.hide()
	MatchManager.begin_round()


func _return_to_menu() -> void:
	get_tree().paused = false
	MatchManager.paused = false
	MatchManager.match_over = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("f3e9d8"))
	return label
