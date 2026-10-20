extends Control

var p1_label: Label
var p2_label: Label
var menu_panel: PanelContainer
var setup_panel: PanelContainer
var training_selected := false


func _ready() -> void:
	_build_ui()
	refresh()


func _build_ui() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var backdrop := ColorRect.new()
	backdrop.color = Color("11141d")
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	menu_panel = _panel(Vector2(-250, -185), Vector2(500, 370))
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 16)
	menu_panel.add_child(menu)
	var title := _label("刃  //  CLAN DUEL", 38)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(title)
	var sub := _label("SAMURAI PLATFORM FIGHTER", 15)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", Color("c59b68"))
	menu.add_child(sub)
	menu.add_child(_spacer(8))
	var versus := _button("VERSUS", 24)
	versus.pressed.connect(func(): _open_setup(false))
	menu.add_child(versus)
	var training := _button("TRAINING DOJO", 20)
	training.pressed.connect(func(): _open_setup(true))
	menu.add_child(training)
	var controls := _label("Local play: keyboard + keyboard or up to two gamepads", 13)
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu.add_child(controls)
	add_child(menu_panel)

	setup_panel = _panel(Vector2(-285, -260), Vector2(570, 520))
	var setup := VBoxContainer.new()
	setup.add_theme_constant_override("separation", 14)
	setup_panel.add_child(setup)
	var setup_title := _label("VERSUS SETUP", 30)
	setup_title.name = "SetupTitle"
	setup_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup.add_child(setup_title)
	var intro := _label("Choose both clan champions", 16)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup.add_child(intro)
	p1_label = _add_pick_row(setup, 0, "PLAYER 1")
	p2_label = _add_pick_row(setup, 1, "PLAYER 2")
	setup.add_child(_spacer(8))
	var pad_assignment := _button("", 13)
	pad_assignment.name = "PadAssignment"
	pad_assignment.pressed.connect(_toggle_single_pad)
	setup.add_child(pad_assignment)
	var fight := _button("START VERSUS MATCH", 20)
	fight.name = "StartButton"
	fight.pressed.connect(_begin_selected_mode)
	setup.add_child(fight)
	var back := _button("BACK", 16)
	back.name = "BackButton"
	back.pressed.connect(
		func():
			setup_panel.hide()
			menu_panel.show()
	)
	setup.add_child(back)
	var hints := _label(
		(
			"P1: WASD / J attack / U+J smash / K special (hold to charge) / SPACE jump / L tech\n"
			+ "P2: ARROWS / KP1 attack / KP4+KP1 smash / KP2 special / KP0 jump / KP3 tech"
		),
		12
	)
	hints.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	setup.add_child(hints)
	add_child(setup_panel)
	setup_panel.hide()


func _open_setup(training: bool) -> void:
	training_selected = training
	menu_panel.hide()
	setup_panel.show()
	setup_panel.get_node("VBoxContainer/SetupTitle").text = (
		"TRAINING SETUP" if training else "VERSUS SETUP"
	)
	setup_panel.get_node("VBoxContainer/StartButton").text = (
		"START TRAINING" if training else "START VERSUS MATCH"
	)
	_update_pad_label()


func _begin_selected_mode() -> void:
	if training_selected:
		MatchManager.start_training()
	else:
		MatchManager.start_versus()


func _toggle_single_pad() -> void:
	InputManager.single_gamepad_player = 1 - InputManager.single_gamepad_player
	_update_pad_label()


func _update_pad_label() -> void:
	var slot_name := "PLAYER 1" if InputManager.single_gamepad_player == 0 else "PLAYER 2"
	setup_panel.get_node("VBoxContainer/PadAssignment").text = "ONE GAMEPAD → %s" % slot_name


func _add_pick_row(parent: VBoxContainer, slot: int, caption: String) -> Label:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var left := _button("‹", 24)
	left.custom_minimum_size = Vector2(58, 52)
	left.pressed.connect(func(): _cycle(slot, -1))
	row.add_child(left)
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 285
	var header := _label(caption, 13)
	header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	header.add_theme_color_override("font_color", Color("c59b68"))
	col.add_child(header)
	var name := _label("", 22)
	name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name)
	row.add_child(col)
	var right := _button("›", 24)
	right.custom_minimum_size = Vector2(58, 52)
	right.pressed.connect(func(): _cycle(slot, 1))
	row.add_child(right)
	parent.add_child(row)
	return name


func _cycle(slot: int, direction: int) -> void:
	var roster_size := MatchManager.CHARACTERS.size()
	MatchManager.character_indices[slot] = posmod(
		MatchManager.character_indices[slot] + direction, roster_size
	)
	refresh()


func refresh() -> void:
	if not is_instance_valid(p1_label):
		return
	p1_label.text = MatchManager.CHARACTERS[MatchManager.character_indices[0]].display_name
	p2_label.text = MatchManager.CHARACTERS[MatchManager.character_indices[1]].display_name


func _panel(position: Vector2, size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = position
	panel.size = size
	panel.custom_minimum_size = size
	panel.add_theme_stylebox_override("panel", _panel_style(Color("201e26")))
	return panel


func _button(text: String, size: int) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(320, 48)
	button.add_theme_font_size_override("font_size", size)
	button.add_theme_color_override("font_color", Color("f4ead9"))
	button.add_theme_color_override("font_hover_color", Color("edc083"))
	button.add_theme_stylebox_override("normal", _panel_style(Color("292832")))
	button.add_theme_stylebox_override("hover", _panel_style(Color("554036")))
	button.add_theme_stylebox_override("pressed", _panel_style(Color("754638")))
	return button


func _panel_style(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = Color("aa784a")
	style.set_border_width_all(1)
	style.set_corner_radius_all(5)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	return style


func _label(text: String, size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", Color("f3e9d8"))
	return label


func _spacer(height: float) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size.y = height
	return spacer
