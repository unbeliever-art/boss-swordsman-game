extends Control

const BACKGROUND: Texture2D = preload("res://assets/scene1_background_new.jpg")
const CHICKEN_TEXTURE: Texture2D = preload("res://assets/chicken.png")
const INTRO_VIDEO: VideoStream = preload("res://assets/episode1_intro.ogv")
const ART_SOURCE_SIZE := Vector2(1536.0, 864.0)
const ART_RECT := Rect2(32.0, 140.0, 768.0, 432.0)
const GOLD := Color("#d4ad70")
const IVORY := Color("#f4ead8")
const MUTED := Color("#c9bca7")
const PANEL := Color("#211d1b")
const PANEL_LIGHT := Color("#302823")
const BORDER := Color("#765b3d")

var thai_font: Font
var art_view: TextureRect
var chicken: TextureRect
var story_label: Label
var count_label: Label
var case_button: Button
var clue_slots: Array[Label] = []
var gameplay_nodes: Array[CanvasItem] = []
var intro_layer: Control
var intro_player: VideoStreamPlayer
var intro_active := false
var discovered: Dictionary = {}
var chicken_mode := "idle"
var chicken_timer := 1.4
var chicken_direction := -1.0
var chicken_home := Vector2.ZERO
var chicken_bounds := Vector2.ZERO
var story_default := "ฝนเพิ่งหยุดตก บ้านเลขที่ 27 เปิดไฟอยู่ ทั้งที่ตระกูลเจ้าของบ้านหายไปนานแล้ว\nแตะสิ่งที่สะดุดตาเพื่อสำรวจบริเวณหน้าบ้าน"

const CLUES := {
	"mailbox": {"title": "จดหมายเปียกฝน", "text": "ใต้ฝากล่องมีซองจดหมายชื้นอยู่ ผู้ส่งไม่ได้เขียนชื่อ แต่หมึกด้านหลังยังอ่านได้ว่า “กลับมาก่อนเที่ยงคืน”"},
	"door": {"title": "กลอนประตู", "text": "กลอนถูกเลื่อนจากด้านใน มีรอยนิ้วมือใหม่บนไม้ แสดงว่ามีใครเพิ่งเข้าไปในบ้าน"},
	"window": {"title": "ม่านชั้นใน", "text": "หน้าต่างปิดสนิท แต่ม่านด้านในยังไหวเบา ๆ เหมือนมีคนเพิ่งเดินผ่าน"},
	"sign": {"title": "ป้ายบ้านเลขที่ 27", "text": "ฝุ่นบนป้ายถูกเช็ดออกเป็นวง มีรอยคราบนิ้วมือสดอยู่ตรงเลข 7"},
	"chicken": {"title": "เหรียญใต้ดิน", "text": "ไก่เขี่ยดินตรงลานหน้าบ้านจนเห็นเหรียญเก่าหนึ่งเหรียญ ด้านหลังมีตราร้านข้าวของตระกูลเจ้าของบ้าน"}
}

func _ready() -> void:
	randomize()
	mouse_filter = Control.MOUSE_FILTER_PASS
	_build_interface()
	for node in get_children():
		if node is CanvasItem:
			gameplay_nodes.append(node)
			node.visible = false
	_start_intro()

func _process(delta: float) -> void:
	if intro_active or not is_instance_valid(chicken):
		return
	chicken_timer -= delta
	if chicken_mode == "walk":
		chicken.position.x += chicken_direction * 22.0 * delta
		if chicken.position.x < chicken_bounds.x or chicken.position.x > chicken_bounds.y:
			chicken_direction *= -1.0
			chicken.flip_h = chicken_direction > 0.0
			chicken.position.x = clampf(chicken.position.x, chicken_bounds.x, chicken_bounds.y)
		chicken.position.y = chicken_home.y + sin(Time.get_ticks_msec() / 75.0) * 2.0
	elif chicken_mode == "idle":
		chicken.position.y = chicken_home.y + sin(Time.get_ticks_msec() / 390.0) * 1.0
	elif chicken_mode == "peck":
		chicken.rotation_degrees = sin(Time.get_ticks_msec() / 45.0) * 7.0
	if chicken_timer <= 0.0:
		if chicken_mode == "walk":
			chicken_mode = "idle"
			chicken_timer = randf_range(1.0, 2.4)
			chicken.position.x = clampf(chicken.position.x, chicken_bounds.x, chicken_bounds.y)
			chicken_home.x = chicken.position.x
		elif chicken_mode == "peck":
			chicken.rotation_degrees = 0.0
			chicken_mode = "idle"
			chicken_timer = randf_range(1.2, 2.7)
		elif randf() < 0.38:
			chicken_mode = "peck"
			chicken_timer = 0.55
		else:
			chicken_mode = "walk"
			chicken_direction = -1.0 if randf() < 0.5 else 1.0
			chicken.flip_h = chicken_direction > 0.0
			chicken_timer = randf_range(0.8, 1.7)

func _build_interface() -> void:
	thai_font = SystemFont.new()
	thai_font.font_names = PackedStringArray(["Noto Sans Thai", "Tahoma", "Arial", "sans-serif"])

	var full_bg := ColorRect.new()
	full_bg.color = Color("#120f0e")
	full_bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	full_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(full_bg)

	_add_panel("Header", Vector2(24, 12), Vector2(1232, 116), Color("#231d19"), GOLD)
	_add_label("คฤหาสน์ที่ไม่มีเจ้าของ", Vector2(42, 20), Vector2(760, 50), 36, GOLD, true)
	_add_label("คดีที่ 1  •  บ้านเลขที่ 27", Vector2(44, 68), Vector2(600, 36), 22, MUTED, false)
	count_label = _add_label("เบาะแสที่พบ  0 / 5", Vector2(824, 39), Vector2(400, 42), 24, IVORY, true, HORIZONTAL_ALIGNMENT_RIGHT)

	art_view = TextureRect.new()
	art_view.texture = BACKGROUND
	art_view.position = ART_RECT.position
	art_view.size = ART_RECT.size
	art_view.stretch_mode = TextureRect.STRETCH_SCALE
	art_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art_view)

	var art_frame := _add_panel("ArtFrame", ART_RECT.position - Vector2(4, 4), ART_RECT.size + Vector2(8, 8), Color(0, 0, 0, 0), GOLD)
	move_child(art_frame, get_child_count() - 1)
	move_child(art_view, get_child_count() - 1)

	_add_hotspot("mailbox", _map_scene_rect(Rect2(112, 480, 148, 118)))
	_add_hotspot("door", _map_scene_rect(Rect2(670, 300, 146, 134)))
	_add_hotspot("window", _map_scene_rect(Rect2(361, 285, 110, 117)))
	_add_hotspot("sign", _map_scene_rect(Rect2(1276, 512, 138, 112)))
	_add_hotspot("chicken", _map_scene_rect(Rect2(1040, 552, 152, 128)))

	chicken = TextureRect.new()
	chicken.texture = CHICKEN_TEXTURE
	chicken.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chicken.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chicken.size = Vector2(46, 39)
	chicken_home = ART_RECT.position + Vector2(1106.0 / ART_SOURCE_SIZE.x * ART_RECT.size.x, 608.0 / ART_SOURCE_SIZE.y * ART_RECT.size.y) - chicken.size * 0.5
	chicken.position = chicken_home
	chicken_bounds = Vector2(ART_RECT.position.x + 1030.0 / ART_SOURCE_SIZE.x * ART_RECT.size.x, ART_RECT.position.x + 1200.0 / ART_SOURCE_SIZE.x * ART_RECT.size.x)
	add_child(chicken)

	_add_panel("StoryPanel", Vector2(32, 588), Vector2(768, 104), PANEL, BORDER)
	_add_label("บันทึกจากหน้าบ้าน", Vector2(48, 593), Vector2(730, 30), 21, GOLD, true)
	story_label = _add_label(story_default, Vector2(48, 621), Vector2(730, 62), 17, IVORY, false)
	story_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	story_label.vertical_alignment = VERTICAL_ALIGNMENT_TOP

	_add_panel("EvidencePanel", Vector2(824, 140), Vector2(424, 452), Color("#191614"), BORDER)
	_add_label("ของที่พบในบริเวณบ้าน", Vector2(844, 156), Vector2(384, 42), 24, GOLD, true)
	_add_label("แตะจุดในภาพเพื่อค้นหาเบาะแส", Vector2(844, 196), Vector2(384, 34), 17, MUTED, false)
	for i in range(5):
		var y := 244.0 + float(i) * 59.0
		var slot := _add_label("□  ยังไม่พบเบาะแส", Vector2(844, y), Vector2(384, 48), 19, Color("#9d907e"), false)
		slot.add_theme_color_override("font_color", Color("#9d907e"))
		clue_slots.append(slot)

	case_button = _make_button("เปิดสรุปคดี  •  พบแล้ว 0 / 5")
	case_button.position = Vector2(824, 608)
	case_button.size = Vector2(424, 78)
	case_button.pressed.connect(_on_case_button_pressed)
	add_child(case_button)

func _start_intro() -> void:
	intro_active = true
	intro_layer = Control.new()
	intro_layer.name = "Episode1Intro"
	intro_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(intro_layer)

	intro_player = VideoStreamPlayer.new()
	intro_player.name = "IntroVideo"
	intro_player.stream = INTRO_VIDEO
	intro_player.expand = true
	intro_player.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	intro_player.finished.connect(_finish_intro)
	intro_layer.add_child(intro_player)

	var title_panel := Panel.new()
	title_panel.position = Vector2(32, 28)
	title_panel.size = Vector2(520, 104)
	title_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var title_style := StyleBoxFlat.new()
	title_style.bg_color = Color(0.08, 0.06, 0.05, 0.76)
	title_style.border_color = GOLD
	title_style.set_border_width_all(2)
	title_style.set_corner_radius_all(14)
	title_panel.add_theme_stylebox_override("panel", title_style)
	intro_layer.add_child(title_panel)

	var title := Label.new()
	title.text = "คฤหาสน์ที่ไม่มีเจ้าของ\nบทที่ 1  •  บ้านเลขที่ 27"
	title.position = Vector2(52, 38)
	title.size = Vector2(484, 82)
	title.add_theme_font_override("font", thai_font)
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", IVORY)
	title.add_theme_color_override("font_outline_color", Color("#24180f"))
	title.add_theme_constant_override("outline_size", 3)
	title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	title_panel.add_child(title)

	var skip := _make_button("ข้าม  ›")
	skip.name = "SkipIntro"
	skip.position = Vector2(1090, 638)
	skip.size = Vector2(158, 58)
	skip.add_theme_font_size_override("font_size", 20)
	skip.pressed.connect(_finish_intro)
	intro_layer.add_child(skip)
	intro_player.play()

func _finish_intro() -> void:
	if not intro_active:
		return
	intro_active = false
	if is_instance_valid(intro_player):
		intro_player.stop()
	intro_layer.queue_free()
	for node in gameplay_nodes:
		if is_instance_valid(node):
			node.visible = true
	_start_chicken_cycle()

func _map_scene_rect(rect: Rect2) -> Rect2:
	var relative_position := rect.position / ART_SOURCE_SIZE
	var relative_size := rect.size / ART_SOURCE_SIZE
	return Rect2(ART_RECT.position + relative_position * ART_RECT.size, relative_size * ART_RECT.size)

func _add_panel(node_name: String, pos: Vector2, panel_size: Vector2, fill: Color, border_color: Color) -> Panel:
	var panel := Panel.new()
	panel.name = node_name
	panel.position = pos
	panel.size = panel_size
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border_color
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0, 0, 0, 0.38)
	style.shadow_size = 5
	style.shadow_offset = Vector2(0, 3)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	return panel

func _add_label(text_value: String, pos: Vector2, label_size: Vector2, font_size: int, font_color: Color, bold: bool, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text_value
	label.position = pos
	label.size = label_size
	label.horizontal_alignment = align
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_override("font", thai_font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.72))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 2)
	if bold:
		label.add_theme_color_override("font_outline_color", Color("#4b3826"))
		label.add_theme_constant_override("outline_size", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(label)
	return label

func _add_hotspot(clue_id: String, rect: Rect2) -> void:
	var hotspot := Button.new()
	hotspot.position = rect.position
	hotspot.size = rect.size
	hotspot.text = ""
	hotspot.flat = true
	hotspot.focus_mode = Control.FOCUS_NONE
	hotspot.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	hotspot.modulate = Color(1, 1, 1, 0.01)
	hotspot.pressed.connect(_on_hotspot_pressed.bind(clue_id))
	add_child(hotspot)

func _make_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	button.add_theme_font_override("font", thai_font)
	button.add_theme_font_size_override("font_size", 23)
	button.add_theme_color_override("font_color", Color("#20170f"))
	button.add_theme_color_override("font_hover_color", Color("#20170f"))
	button.add_theme_color_override("font_pressed_color", Color("#20170f"))
	var normal := StyleBoxFlat.new()
	normal.bg_color = GOLD
	normal.border_color = Color("#f1d6a2")
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(16)
	normal.shadow_color = Color(0, 0, 0, 0.5)
	normal.shadow_size = 5
	normal.shadow_offset = Vector2(0, 3)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#b98d51")
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", normal)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return button

func _start_chicken_cycle() -> void:
	chicken_mode = "idle"
	chicken_timer = randf_range(1.1, 2.1)

func _on_hotspot_pressed(clue_id: String) -> void:
	if not CLUES.has(clue_id):
		return
	var clue: Dictionary = CLUES[clue_id]
	story_label.text = clue["text"]
	if not discovered.has(clue_id):
		discovered[clue_id] = true
		_update_evidence()
	else:
		story_label.text = clue["text"] + "\nจดเบาะแสนี้ไว้แล้ว"
	if clue_id == "chicken":
		chicken_mode = "peck"
		chicken_timer = 0.55
	if discovered.size() == CLUES.size():
		story_label.text += "\nเบาะแสครบแล้ว ลองเปิดสรุปคดีดู"

func _update_evidence() -> void:
	var ids := ["mailbox", "door", "window", "sign", "chicken"]
	for i in range(ids.size()):
		var clue_id: String = ids[i]
		if discovered.has(clue_id):
			clue_slots[i].text = "✓  " + CLUES[clue_id]["title"]
			clue_slots[i].add_theme_color_override("font_color", IVORY)
		else:
			clue_slots[i].text = "□  ยังไม่พบเบาะแส"
			clue_slots[i].add_theme_color_override("font_color", Color("#9d907e"))
	count_label.text = "เบาะแสที่พบ  %d / %d" % [discovered.size(), CLUES.size()]
	case_button.text = "เปิดสรุปคดี  •  พบแล้ว %d / %d" % [discovered.size(), CLUES.size()]

func _on_case_button_pressed() -> void:
	if discovered.size() < CLUES.size():
		story_label.text = "ยังมีบางอย่างซ่อนอยู่รอบบ้าน ลองแตะตรวจกล่องจดหมาย ประตู หน้าต่าง ป้ายบ้าน และไก่ที่ลาน"
	else:
		story_label.text = "สรุปเบาะแส: มีคนอยู่ในบ้านเลขที่ 27 และเพิ่งกลับเข้ามาในช่วงฝนตก\nจดหมายบอกให้กลับก่อนเที่ยงคืน—แต่ใครเป็นคนเขียน?"
