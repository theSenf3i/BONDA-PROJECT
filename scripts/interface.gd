extends CanvasLayer

signal advance
signal selected(index: int)
signal start_game
signal continue_game
signal retry
signal resume_game
signal quit_to_menu
signal music_changed(value: float)
signal effects_changed(value: float)
signal mute_requested
signal fullscreen_requested

var home_achievement = false
var extras: Panel
var extras_title: Label
var extras_text: RichTextLabel
var extras_close: Button

var root: Control
var hud: Control
var chapter: Label
var objective: Label
var prompt: Label
var music_label: Label
var subtitle_panel: Panel
var speaker: Label
var subtitle: RichTextLabel
var help: Label
var options: VBoxContainer
var dialog_text = ""
var char_count = 0.0
var dialog_open = false
var option_texts: Array = []
var input_lock = 0.0
var menu: Panel
var pause_panel: Panel
var result_panel: Panel
var result_title: Label
var result_text: Label
var result_button: Button
var player_bar: ProgressBar
var enemy_bar: ProgressBar
var fight_labels: Label
var survival: Label
var danger: Label
var toast: Label
var toast_time = 0.0
var veil: ColorRect
var banner: Label
var credit_label: Label
var accent = Color("e8bc72")
var ink = Color("201d2b")
var paper = Color("f5e6ca")
var current_option = 0

func _ready() -> void:
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme = Theme.new()
	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Bahnschrift", "Segoe UI", "Arial"])
	theme.default_font = font
	theme.default_font_size = 22
	theme.set_color("font_color", "Label", paper)
	theme.set_color("font_color", "Button", paper)
	theme.set_color("font_hover_color", "Button", ink)
	theme.set_color("font_focus_color", "Button", ink)
	theme.set_stylebox("normal", "Button", style(Color("36313f"), Color("635362"), 1, 6))
	theme.set_stylebox("hover", "Button", style(accent, accent, 1, 6))
	theme.set_stylebox("focus", "Button", style(accent, paper, 2, 6))
	theme.set_stylebox("pressed", "Button", style(Color("c49b5f"), accent, 1, 6))
	theme.set_stylebox("disabled", "Button", style(Color("292532"), Color("40384b"), 1, 6))
	root.theme = theme
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	var objective_bg = panel(hud, Vector2(28, 24), Vector2(575, 100), Color(0.11, .10, .16, .9))
	chapter = label(objective_bg, "DIMENSÃO 01   /   DEDADÃO", Vector2(22, 13), Vector2(540, 24), 17, accent)
	objective = label(objective_bg, "", Vector2(22, 43), Vector2(540, 47), 23)
	label(hud, "BONDAONDA", Vector2(1020, 31), Vector2(230, 32), 28, paper).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label(hud, "DIMENSÃO 01", Vector2(1020, 66), Vector2(230, 20), 12, accent).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	prompt = label(hud, "", Vector2(270, 608), Vector2(740, 42), 24)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_color_override("font_shadow_color", ink)
	prompt.add_theme_constant_override("shadow_offset_x", 2)
	prompt.add_theme_constant_override("shadow_offset_y", 2)
	var footer = panel(hud, Vector2(0, 637), Vector2(1280, 83), Color(.09, .08, .13, .87))
	footer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label(footer, "WASD  andar    SHIFT  correr    ESPAÇO  pular    E  interagir    MOUSE / ← →  câmera    ESC  pausa", Vector2(28, 40), Vector2(1100, 24), 15, Color("d5c5b4"))
	music_label = label(hud, "", Vector2(28, 645), Vector2(1050, 22), 14, Color("c8b8ce"))
	player_bar = health_bar(hud, Vector2(32, 149), Color("9cceaf"))
	enemy_bar = health_bar(hud, Vector2(920, 149), Color("db8e8d"))
	fight_labels = label(hud, "VOCÊ                                     J SOCO  /  K DEFESA  /  Q ESQUIVA", Vector2(32, 126), Vector2(850, 28), 16)
	label(enemy_bar, "RIVAL", Vector2(0, -27), Vector2(328, 24), 16).horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	survival = label(hud, "", Vector2(460, 146), Vector2(360, 65), 34, accent)
	survival.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	survival.add_theme_color_override("font_shadow_color", ink)
	survival.add_theme_constant_override("outline_size", 6)
	survival.add_theme_color_override("font_outline_color", ink)
	danger = label(hud, "", Vector2(350, 220), Vector2(580, 42), 21, Color("f3b088"))
	danger.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	danger.add_theme_constant_override("outline_size", 5)
	danger.add_theme_color_override("font_outline_color", ink)
	toast = label(hud, "", Vector2(300, 275), Vector2(680, 45), 25)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_constant_override("outline_size", 5)
	toast.add_theme_color_override("font_outline_color", ink)
	subtitle_panel = panel(root, Vector2(76, 461), Vector2(1128, 202), Color(.10, .085, .14, .97))
	speaker = label(subtitle_panel, "", Vector2(28, 16), Vector2(1030, 26), 19, accent)
	subtitle = RichTextLabel.new()
	subtitle_panel.add_child(subtitle)
	subtitle.position = Vector2(28, 55)
	subtitle.size = Vector2(1060, 110)
	subtitle.add_theme_font_size_override("normal_font_size", 24)
	subtitle.add_theme_color_override("default_color", paper)
	subtitle.scroll_active = false
	subtitle.bbcode_enabled = false
	subtitle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help = label(subtitle_panel, "E / ENTER  completar · avançar", Vector2(28, 172), Vector2(1060, 23), 14, Color("b5a6bf"))
	options = VBoxContainer.new()
	subtitle_panel.add_child(options)
	options.position = Vector2(617, 45)
	options.size = Vector2(482, 142)
	options.add_theme_constant_override("separation", 8)
	subtitle_panel.hide()
	menu = panel(root, Vector2(56, 67), Vector2(540, 625), Color(.10, .09, .14, .95))
	label(menu, "UMA AVENTURA NO UNIVERSO DE BONDA", Vector2(32, 28), Vector2(478, 23), 15, accent)
	label(menu, "BONDA\nONDA", Vector2(27, 60), Vector2(490, 180), 83, paper)
	label(menu, "01  /  DIMENSÃO DEDADÃO", Vector2(32, 258), Vector2(480, 36), 25, accent)
	label(menu, "Uma consulta. Um romance.\nUma quantidade absurda de problemas.", Vector2(32, 309), Vector2(475, 68), 23)
	button(menu, "ENTRAR NA DIMENSÃO  →", Vector2(32, 402), Vector2(476, 52), func(): start_game.emit())
	var continue_button = button(menu, "CONTINUAR DO CHECKPOINT", Vector2(32, 464), Vector2(476, 44), func(): continue_game.emit())
	continue_button.name = "Continue"
	label(menu, "FAN GAME  •  LEGENDADO  •  TRILHA BONDA", Vector2(32, 590), Vector2(476, 22), 13, Color("b5a6bf"))
	button(menu, "CONQUISTAS", Vector2(32, 522), Vector2(230, 44), func(): show_extras(false))
	button(menu, "NOVIDADES / v0.4", Vector2(278, 522), Vector2(230, 44), func(): show_extras(true))
	pause_panel = panel(root, Vector2(390, 113), Vector2(500, 503), Color(.10, .09, .14, .98))
	label(pause_panel, "UM RESPIRO.", Vector2(32, 25), Vector2(440, 55), 39)
	button(pause_panel, "VOLTAR AO JOGO", Vector2(32, 99), Vector2(436, 45), func(): resume_game.emit())
	label(pause_panel, "Música", Vector2(32, 166), Vector2(200, 26), 20, accent)
	var mus = HSlider.new()
	pause_panel.add_child(mus)
	mus.position = Vector2(32, 205)
	mus.size = Vector2(436, 28)
	mus.max_value = 1
	mus.step = .01
	mus.value = .7
	mus.value_changed.connect(func(v): music_changed.emit(v))
	label(pause_panel, "Efeitos", Vector2(32, 248), Vector2(200, 26), 20, accent)
	var fx = HSlider.new()
	pause_panel.add_child(fx)
	fx.position = Vector2(32, 286)
	fx.size = Vector2(436, 28)
	fx.max_value = 1
	fx.step = .01
	fx.value = .65
	fx.value_changed.connect(func(v): effects_changed.emit(v))
	label(pause_panel, "M  silenciar tudo    •    F11  tela cheia", Vector2(32, 339), Vector2(436, 28), 17)
	button(pause_panel, "VOLTAR AO MENU", Vector2(32, 398), Vector2(436, 45), func(): quit_to_menu.emit())
	label(pause_panel, "Seu último checkpoint está salvo.", Vector2(32, 461), Vector2(436, 23), 15, Color("b5a6bf"))
	pause_panel.hide()
	result_panel = panel(root, Vector2(290, 170), Vector2(700, 380), Color(.12, .085, .15, .98))
	result_title = label(result_panel, "DEU RUIM.", Vector2(35, 28), Vector2(630, 65), 48, accent)
	result_text = label(result_panel, "", Vector2(35, 112), Vector2(630, 130), 24)
	result_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_button = button(result_panel, "TENTAR DE NOVO  ↻", Vector2(35, 276), Vector2(630, 56), func(): retry.emit())
	result_panel.hide()
	veil = ColorRect.new()
	root.add_child(veil)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.color = Color(0.055, .045, .075, 0)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner = label(veil, "", Vector2(90, 286), Vector2(1100, 160), 48, paper)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.modulate.a = 0
	credit_label = label(root, "", Vector2(650, 560), Vector2(570, 90), 14, Color("f1e2cc"))
	credit_label.add_theme_constant_override("outline_size", 4)
	credit_label.add_theme_color_override("font_outline_color", ink)
	credit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	credit_label.text = "MC VV / BONDA\nModelagem, cenários e código novos\nUm projeto de fã. Sem participação oficial dos artistas."
	extras = panel(root, Vector2(140, 70), Vector2(1000, 580), Color(.10, .09, .14, .99))
	extras_title = label(extras, "", Vector2(32, 24), Vector2(930, 46), 32, accent)
	extras_text = RichTextLabel.new()
	extras.add_child(extras_text)
	extras_text.position = Vector2(32, 90)
	extras_text.size = Vector2(936, 400)
	extras_text.add_theme_font_size_override("normal_font_size", 22)
	extras_text.bbcode_enabled = false
	extras_close = button(extras, "VOLTAR", Vector2(32, 514), Vector2(220, 44), close_extras)
	extras.hide()
	combat(false)

func style(color: Color, border: Color, width: int = 1, radius: int = 0) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(width)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 12
	s.content_margin_right = 12
	return s

func panel(parent: Node, pos: Vector2, size: Vector2, color: Color) -> Panel:
	var p = Panel.new()
	parent.add_child(p)
	p.position = pos
	p.size = size
	p.add_theme_stylebox_override("panel", style(color, Color("7a625b"), 1, 5))
	return p

func label(parent: Node, value: String, pos: Vector2, size: Vector2, font_size: int, tint: Color = Color("f5e6ca")) -> Label:
	var l = Label.new()
	parent.add_child(l)
	l.text = value
	l.position = pos
	l.size = size
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", tint)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func button(parent: Node, value: String, pos: Vector2, size: Vector2, callback: Callable) -> Button:
	var b = Button.new()
	parent.add_child(b)
	b.text = value
	b.position = pos
	b.custom_minimum_size = size
	b.size = size
	b.add_theme_font_size_override("font_size", 19)
	b.pressed.connect(callback)
	return b

func health_bar(parent: Node, pos: Vector2, tint: Color) -> ProgressBar:
	var b = ProgressBar.new()
	parent.add_child(b)
	b.position = pos
	b.size = Vector2(328, 16)
	b.show_percentage = false
	b.add_theme_stylebox_override("background", style(Color("2a2536"), Color("6d5a62")))
	b.add_theme_stylebox_override("fill", style(tint, tint))
	b.value = 100
	return b

func combat(on: bool) -> void:
	player_bar.visible = on
	enemy_bar.visible = on
	fight_labels.visible = on
	survival.hide()
	danger.text = ""

func line(who: String, value: String, choices: Array = []) -> void:
	dialog_open = true
	subtitle_panel.show()
	speaker.text = who.to_upper()
	dialog_text = value
	subtitle.text = value
	char_count = 0
	subtitle.visible_characters = 0
	input_lock = .18
	option_texts = choices
	current_option = 0
	for child in options.get_children():
		child.queue_free()
	subtitle.size.x = 554 if not choices.is_empty() else 1060
	for i in range(choices.size()):
		var b = button(options, str(i + 1) + "  " + str(choices[i]), Vector2.ZERO, Vector2(482, 42), func(): choose(i))
		b.add_theme_font_size_override("font_size", 17)
		b.disabled = true
	help.text = "E / ENTER  completar texto" if choices.is_empty() else "E / ENTER  completar  ·  1–3 ou mouse  responder"

func close_dialog() -> void:
	dialog_open = false
	subtitle_panel.hide()
	option_texts = []

func choose(index: int) -> void:
	if input_lock > 0 or char_count < dialog_text.length() or index >= option_texts.size():
		return
	input_lock = .2
	selected.emit(index)

func next() -> void:
	if input_lock > 0 or not dialog_open:
		return
	if char_count < dialog_text.length():
		char_count = dialog_text.length()
		subtitle.visible_characters = -1
		input_lock = .12
		return
	if option_texts.is_empty():
		advance.emit()
	else:
		choose(current_option)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_M:
			mute_requested.emit()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_F11:
			fullscreen_requested.emit()
			get_viewport().set_input_as_handled()
			return
	if pause_panel.visible and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		resume_game.emit()
		get_viewport().set_input_as_handled()
		return
	if not dialog_open or pause_panel.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode in [KEY_E, KEY_ENTER, KEY_SPACE]:
			next()
			get_viewport().set_input_as_handled()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_3:
			choose(event.keycode - KEY_1)
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_UP, KEY_DOWN] and not option_texts.is_empty():
			current_option = posmod(current_option + (1 if event.keycode == KEY_DOWN else -1), option_texts.size())
			if char_count >= dialog_text.length():
				options.get_child(current_option).grab_focus()
			get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	input_lock = maxf(0, input_lock - dt)
	if dialog_open:
		char_count += dt * 43
		subtitle.visible_characters = int(char_count)
		if char_count >= dialog_text.length():
			for b in options.get_children():
				b.disabled = false
			if option_texts.is_empty():
				help.text = "E / ENTER  avançar"
	toast_time -= dt
	toast.modulate.a = clampf(toast_time, 0, 1)

func notify(text: String) -> void:
	toast.text = text
	toast_time = 3.5

func failure(reason: String) -> void:
	close_dialog()
	result_title.text = "DEU RUIM."
	result_text.text = reason
	result_button.text = "TENTAR DE NOVO  ↻"
	result_panel.show()
	result_button.grab_focus()

func show_menu(on: bool) -> void:
	extras.hide()
	menu.visible = on
	hud.visible = not on
	credit_label.visible = on
	menu.get_node("Continue").visible = FileAccess.file_exists("res://save/checkpoint.json")

func transition(text: String, duration: float = 1.2) -> void:
	banner.text = text
	var t = create_tween()
	t.tween_property(veil, "color:a", 1.0, .35)
	t.parallel().tween_property(banner, "modulate:a", 1.0, .35)
	t.tween_interval(duration)
	t.tween_property(veil, "color:a", 0.0, .5)
	t.parallel().tween_property(banner, "modulate:a", 0.0, .5)
	await t.finished

func show_extras(changelog: bool) -> void:
	menu.hide()
	credit_label.hide()
	extras_title.text = "NOVIDADES / HISTÓRICO DE VERSÕES" if changelog else "CONQUISTAS"
	if changelog:
		extras_text.text = FileAccess.get_file_as_string("res://CHANGELOG.txt")
	elif home_achievement:
		extras_text.text = "1 / 1 desbloqueada\n\nCAJA SUSA, CHÃO SUJO...\n\nVocê arrumou e limpou tudo na casa.\n\nConquista permanente: novas partidas não apagam esta descoberta."
	else:
		extras_text.text = "0 / 1 desbloqueada\n\n???\n\nConquista secreta. Explore e descubra."
	extras_text.scroll_to_line(0)
	extras.show()
	extras_close.grab_focus()

func close_extras() -> void:
	extras.hide()
	menu.show()
	credit_label.show()
	menu.get_node("Continue").grab_focus()
