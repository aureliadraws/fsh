extends Control
signal closed
enum ViewMode { INVENTORY, DECK, OPTIONS, PAUSE }

@onready var notebook: TextureRect = $Notebook
@onready var next_page: TextureButton = $NextPage
@onready var prev_page: TextureButton = $PrevPage
@onready var page1: VBoxContainer = $Page1
@onready var page2: VBoxContainer = $Page2
@onready var menu_title: Label = $MenuTitle
@onready var close_button: Button = $CloseButton
@onready var focused1: TextureRect = $Focused1
@onready var focused_icon: TextureRect = $FocusedIcon
@onready var focused2: TextureRect = $Focused2
@onready var focused_icon2: TextureRect = $FocusedIcon2
@onready var focused3: TextureRect = $Focused3
@onready var focused_icon3: TextureRect = $FocusedIcon3
@onready var focused4: TextureRect = $Focused4
@onready var focused_icon4: TextureRect = $FocusedIcon4
@onready var inventory_tab: Button = $InventoryTab
@onready var deck_tab: Button = $DeckTab
@onready var pause_layer: CanvasLayer = $Pause
@onready var settings_layer: CanvasLayer = $Settings

var toggle_on_texture: Texture2D
var toggle_off_texture: Texture2D

const CARD_LAYOUT_SCENE := preload("res://scenes/roguelike/card layout.tscn")

var current_mode: ViewMode = ViewMode.INVENTORY
var current_page: int = 0

const FISH_PER_PAGE: int = 15
const FISH_PER_SPREAD: int = 30
const CARDS_PER_PAGE: int = 9
const CARDS_PER_SPREAD: int = 18

var fish_inventory: Array = []
var deck_cards: Array = []

var _external_catch_hold: Array = []
var _external_deck: Array = []
var _use_external_data: bool = false

var settings: Dictionary = {}
var is_from_main_menu: bool = false

var dragging_slider: String = ""
const SLIDER_MIN_X: float = 391.0
const SLIDER_WIDTH: float = 213.0

var window_options: Array = ["Windowed", "Borderless", "Fullscreen"]
var resolution_options: Array = ["1280x720", "1600x900", "1720x750", "1920x1080", "2560x1440"]
var frame_cap_options: Array = ["30fps", "60fps", "120fps", "Unlimited"]
var colorblind_options: Array = ["None", "Protanopia", "Deuteranopia", "Tritanopia"]
var font_size_options: Array = ["80%", "100%", "120%", "150%"]
var cursor_size_options: Array = ["Small", "Medium", "Large"]
var battle_speed_options: Array = ["Slow 0.5x", "Normal 1x", "Fast 2x", "Very Fast 3x"]

var window_index: int = 0
var resolution_index: int = 2
var frame_cap_index: int = 1
var colorblind_index: int = 0
var font_size_index: int = 1
var cursor_size_index: int = 1
var battle_speed_index: int = 1

const SAVE_SLOT_PATHS: Array = ["user://save_slot_1.json", "user://save_slot_2.json", "user://save_slot_3.json"]

const SLIDE_DURATION: float = 0.3
var _is_animating: bool = false

# Track if settings have been modified for auto-save
var _settings_dirty: bool = false

# Store references to settings UI elements for interaction
var _slider_controls: Dictionary = {}
var _dropdown_controls: Dictionary = {}
var _toggle_controls: Dictionary = {}

func _ready() -> void:
	toggle_off_texture = load("res://assets/menu/Sprites/UI_NoteBook_Toggle05a.png")
	toggle_on_texture = load("res://assets/menu/Sprites/UI_NoteBook_Toggle05b.png")
	
	if next_page: next_page.pressed.connect(_on_next_page)
	if prev_page: prev_page.pressed.connect(_on_prev_page)
	if inventory_tab: inventory_tab.pressed.connect(_on_inventory_tab_pressed)
	if deck_tab: deck_tab.pressed.connect(_on_deck_tab_pressed)
	
	_setup_tab_click_areas()
	
	if close_button:
		close_button.pressed.connect(_close)
		var style_empty := StyleBoxEmpty.new()
		close_button.add_theme_stylebox_override("normal", style_empty)
		close_button.add_theme_stylebox_override("pressed", style_empty)
		close_button.add_theme_stylebox_override("hover", style_empty)
		close_button.add_theme_stylebox_override("focus", style_empty)
	
	_setup_pause_buttons()
	_setup_settings_controls()
	_load_settings()
	
	_set_layer_visible(pause_layer, false)
	_set_layer_visible(settings_layer, false)
	
	visible = false
	
	# Ensure proper mouse filter for input handling
	mouse_filter = Control.MOUSE_FILTER_STOP


func _set_layer_visible(layer: CanvasLayer, is_visible: bool) -> void:
	if layer == null: return
	if is_visible:
		layer.layer = 100  # High layer to ensure visibility above other UI
		for child in layer.get_children():
			if child is CanvasItem: 
				child.visible = true
				if child is Control:
					child.mouse_filter = Control.MOUSE_FILTER_STOP
	else:
		layer.layer = -100  # Hide by putting below everything
		for child in layer.get_children():
			if child is CanvasItem: child.visible = false


func _setup_tab_click_areas() -> void:
	var style_empty := StyleBoxEmpty.new()
	
	var options_tab := Button.new()
	options_tab.name = "OptionsTabBtn"
	options_tab.z_index = 22
	options_tab.flat = true
	options_tab.focus_mode = Control.FOCUS_NONE
	options_tab.position = Vector2(147, 410)
	options_tab.size = Vector2(150, 130)
	options_tab.mouse_filter = Control.MOUSE_FILTER_STOP
	options_tab.add_theme_stylebox_override("normal", style_empty)
	options_tab.pressed.connect(_on_options_tab_pressed)
	add_child(options_tab)
	
	var pause_tab := Button.new()
	pause_tab.name = "PauseTabBtn"
	pause_tab.z_index = 22
	pause_tab.flat = true
	pause_tab.focus_mode = Control.FOCUS_NONE
	pause_tab.position = Vector2(147, 550)
	pause_tab.size = Vector2(150, 130)
	pause_tab.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_tab.add_theme_stylebox_override("normal", style_empty)
	pause_tab.pressed.connect(_on_pause_tab_pressed)
	add_child(pause_tab)


func _setup_pause_buttons() -> void:
	var continue_btn = get_node_or_null("Pause/VBoxContainer/ContinueButton")
	var save_btn = get_node_or_null("Pause/VBoxContainer/SaveGameButton")
	var load_btn = get_node_or_null("Pause/VBoxContainer/LoadGameButton")
	var main_menu_btn = get_node_or_null("Pause/VBoxContainer/MainMenuButton")
	var quit_btn = get_node_or_null("Pause/VBoxContainer/QuitButton")
	
	if continue_btn: continue_btn.pressed.connect(_on_continue_pressed)
	if save_btn: save_btn.pressed.connect(_on_save_game_pressed)
	if load_btn: load_btn.pressed.connect(_on_load_game_pressed)
	if main_menu_btn: main_menu_btn.pressed.connect(_on_main_menu_pressed)
	if quit_btn: quit_btn.pressed.connect(_on_quit_pressed)


func _setup_settings_controls() -> void:
	_setup_slider("Settings/Audio/Master Volume", "master_volume")
	_setup_slider("Settings/Audio/Music Volume", "music_volume")
	_setup_slider("Settings/Audio/SFX Volume", "sfx_volume")
	
	_setup_dropdown("Settings/Window", "window", window_options)
	_setup_dropdown("Settings/Resolution", "resolution", resolution_options)
	_setup_dropdown("Settings/FrameCap", "frame_cap", frame_cap_options)
	
	_setup_toggle("Settings/Vsync", "vsync")
	
	_setup_dropdown("Settings/ColorblindMode", "colorblind_mode", colorblind_options)
	_setup_dropdown("Settings/FontSize", "font_size", font_size_options)
	_setup_dropdown("Settings/CursorSize2", "cursor_size", cursor_size_options)
	
	_setup_toggle("Settings/EasyHook", "easy_hook")
	
	_setup_dropdown("Settings/BattleSpeed", "battle_speed", battle_speed_options)
	
	_setup_toggle("Settings/Card Effects", "card_effects")
	_setup_toggle("Settings/Card Effects2", "card_effects2")


func _setup_slider(path: String, setting_key: String) -> void:
	var label_node = get_node_or_null(path)
	if not label_node:
		return
	
	var bar_handle = label_node.get_node_or_null("BarHandle")
	var bar_fill = label_node.get_node_or_null("BarFill")
	var slider_bg = label_node.get_node_or_null("Slider")
	
	if bar_handle and slider_bg:
		_slider_controls[setting_key] = {
			"handle": bar_handle,
			"fill": bar_fill,
			"bg": slider_bg,
			"label": label_node
		}
		
		var click_area := Button.new()
		click_area.flat = true
		click_area.focus_mode = Control.FOCUS_NONE
		click_area.mouse_filter = Control.MOUSE_FILTER_STOP
		click_area.position = Vector2(376, 0)
		click_area.size = Vector2(240, 50)
		
		var style_empty := StyleBoxEmpty.new()
		click_area.add_theme_stylebox_override("normal", style_empty)
		click_area.add_theme_stylebox_override("hover", style_empty)
		click_area.add_theme_stylebox_override("pressed", style_empty)
		click_area.add_theme_stylebox_override("focus", style_empty)
		
		click_area.button_down.connect(func(): _start_slider_drag(setting_key))
		click_area.button_up.connect(_stop_slider_drag)
		
		label_node.add_child(click_area)


func _setup_dropdown(path: String, setting_key: String, options: Array) -> void:
	var label_node = get_node_or_null(path)
	if not label_node:
		return
	
	var frame_name := setting_key.to_pascal_case() + "Frame"
	if setting_key == "window":
		frame_name = "WindowFrame"
	elif setting_key == "resolution":
		frame_name = "ResolutionFrame"
	elif setting_key == "frame_cap":
		frame_name = "FrameCapFrame"
	elif setting_key == "colorblind_mode":
		frame_name = "ColorblindModeFrame"
	elif setting_key == "font_size":
		frame_name = "FontSizeFrame"
	elif setting_key == "cursor_size":
		frame_name = "CursorSizeFrame"
	elif setting_key == "battle_speed":
		frame_name = "BattleSpeedFrame"
	
	var frame = label_node.get_node_or_null(frame_name)
	
	var text_node = null
	for possible_name in ["WindowText", "ResolutionText", "FrameCapText", "ColorblindModeText", "FontSizeText", "CursorSizeText", "BattleSpeedText"]:
		text_node = label_node.get_node_or_null(possible_name)
		if text_node:
			break
	
	if frame:
		_dropdown_controls[setting_key] = {
			"frame": frame,
			"text": text_node,
			"options": options,
			"current_index": 0
		}
		
		var click_area := Button.new()
		click_area.flat = true
		click_area.focus_mode = Control.FOCUS_NONE
		click_area.mouse_filter = Control.MOUSE_FILTER_STOP
		click_area.position = frame.position - Vector2(10, 10)
		click_area.size = Vector2(320, 70)
		
		var style_empty := StyleBoxEmpty.new()
		click_area.add_theme_stylebox_override("normal", style_empty)
		click_area.add_theme_stylebox_override("hover", style_empty)
		click_area.add_theme_stylebox_override("pressed", style_empty)
		click_area.add_theme_stylebox_override("focus", style_empty)
		
		click_area.pressed.connect(func(): _cycle_dropdown(setting_key))
		
		label_node.add_child(click_area)


func _setup_toggle(path: String, setting_key: String) -> void:
	var label_node = get_node_or_null(path)
	if not label_node:
		return
	
	var toggle_btn = label_node.get_node_or_null("On_OffButton")
	if toggle_btn:
		_toggle_controls[setting_key] = {
			"button": toggle_btn,
			"enabled": true
		}
		
		var click_area := Button.new()
		click_area.flat = true
		click_area.focus_mode = Control.FOCUS_NONE
		click_area.mouse_filter = Control.MOUSE_FILTER_STOP
		click_area.position = toggle_btn.position - Vector2(10, 10)
		click_area.size = Vector2(120, 80)
		
		var style_empty := StyleBoxEmpty.new()
		click_area.add_theme_stylebox_override("normal", style_empty)
		click_area.add_theme_stylebox_override("hover", style_empty)
		click_area.add_theme_stylebox_override("pressed", style_empty)
		click_area.add_theme_stylebox_override("focus", style_empty)
		
		click_area.pressed.connect(func(): _toggle_setting(setting_key))
		
		label_node.add_child(click_area)


func _start_slider_drag(setting_key: String) -> void:
	dragging_slider = setting_key
	if AudioManager and AudioManager.has_method("play_ui_select"):
		AudioManager.play_ui_select()


func _stop_slider_drag() -> void:
	if dragging_slider != "":
		dragging_slider = ""
		_auto_save_settings()


func _process(_delta: float) -> void:
	if dragging_slider != "" and _slider_controls.has(dragging_slider):
		var slider_data: Dictionary = _slider_controls[dragging_slider]
		var handle: TextureRect = slider_data["handle"]
		var fill: TextureRect = slider_data["fill"]
		var label_node = slider_data["label"]
		
		if handle and label_node and label_node is Control:
			var label_control: Control = label_node as Control
			var local_mouse: Vector2 = label_control.get_local_mouse_position()
			var slider_start: float = SLIDER_MIN_X
			var value: float = clampf((local_mouse.x - slider_start) / SLIDER_WIDTH, 0.0, 1.0)
			var handle_x: float = slider_start + (value * SLIDER_WIDTH)
			handle.position.x = handle_x
			if fill:
				fill.size.x = (value * SLIDER_WIDTH) / 5.0
			_apply_slider_value(dragging_slider, value)


func _apply_slider_value(setting_key: String, value: float) -> void:
	match setting_key:
		"master_volume":
			if SettingsManager:
				SettingsManager.audio_settings.master_volume = value
				SettingsManager.apply_audio_settings()
			_settings_dirty = true
		"music_volume":
			if SettingsManager:
				SettingsManager.audio_settings.music_volume = value
				SettingsManager.apply_audio_settings()
			_settings_dirty = true
		"sfx_volume":
			if SettingsManager:
				SettingsManager.audio_settings.sfx_volume = value
				SettingsManager.apply_audio_settings()
			_settings_dirty = true


func _cycle_dropdown(setting_key: String) -> void:
	if not _dropdown_controls.has(setting_key):
		return
	
	if AudioManager and AudioManager.has_method("play_ui_select"):
		AudioManager.play_ui_select()
	
	var dropdown_data: Dictionary = _dropdown_controls[setting_key]
	var options: Array = dropdown_data["options"]
	var current_idx: int = dropdown_data["current_index"]
	
	current_idx = (current_idx + 1) % options.size()
	dropdown_data["current_index"] = current_idx
	
	var text_node: Label = dropdown_data["text"]
	if text_node:
		text_node.text = options[current_idx]
	
	_apply_dropdown_value(setting_key, current_idx, options[current_idx])
	_auto_save_settings()


func _apply_dropdown_value(setting_key: String, index: int, value: String) -> void:
	match setting_key:
		"window":
			if SettingsManager:
				var modes := ["windowed", "borderless", "fullscreen"]
				if index < modes.size():
					SettingsManager.display_settings.window_mode = modes[index]
					SettingsManager.apply_display_settings()
			_settings_dirty = true
		"resolution":
			if SettingsManager:
				var res_parts := value.split("x")
				if res_parts.size() == 2:
					var res := Vector2i(int(res_parts[0]), int(res_parts[1]))
					SettingsManager.display_settings.resolution = res
					SettingsManager.apply_display_settings()
			_settings_dirty = true
		"frame_cap":
			if SettingsManager:
				var caps := [30, 60, 120, 0]
				if index < caps.size():
					SettingsManager.display_settings.framerate_cap = caps[index]
					SettingsManager.apply_display_settings()
			_settings_dirty = true
		"colorblind_mode":
			if SettingsManager:
				var modes := ["none", "protanopia", "deuteranopia", "tritanopia"]
				if index < modes.size():
					SettingsManager.accessibility_settings.colorblind_mode = modes[index]
					SettingsManager.apply_accessibility_settings()
			_settings_dirty = true
		"font_size":
			if SettingsManager:
				var sizes := [0.8, 1.0, 1.2, 1.5]
				if index < sizes.size():
					SettingsManager.accessibility_settings.text_size = sizes[index]
					SettingsManager.apply_accessibility_settings()
			_settings_dirty = true
		"cursor_size":
			if SettingsManager:
				# The 'value' argument already contains the string "Small", "Medium", or "Large"
				SettingsManager.accessibility_settings.cursor_size = value
				SettingsManager.apply_accessibility_settings()
			_settings_dirty = true
		"battle_speed":
			if SettingsManager:
				var speeds := [0.5, 1.0, 2.0, 3.0]
				if index < speeds.size():
					SettingsManager.gameplay_settings.battle_speed = speeds[index]
					SettingsManager.apply_gameplay_settings()
			_settings_dirty = true


func _toggle_setting(setting_key: String) -> void:
	if not _toggle_controls.has(setting_key):
		return
	
	if AudioManager and AudioManager.has_method("play_ui_confirm"):
		AudioManager.play_ui_confirm()
	
	var toggle_data: Dictionary = _toggle_controls[setting_key]
	var is_enabled: bool = toggle_data["enabled"]
	var toggle_btn: TextureRect = toggle_data["button"]
	
	is_enabled = not is_enabled
	toggle_data["enabled"] = is_enabled
	
	if toggle_btn:
		if is_enabled and toggle_on_texture:
			toggle_btn.texture = toggle_on_texture
		elif toggle_off_texture:
			toggle_btn.texture = toggle_off_texture
	
	_apply_toggle_value(setting_key, is_enabled)
	_auto_save_settings()


func _apply_toggle_value(setting_key: String, enabled: bool) -> void:
	match setting_key:
		"vsync":
			if SettingsManager:
				SettingsManager.display_settings.vsync = enabled
				SettingsManager.apply_display_settings()
			_settings_dirty = true
		"easy_hook":
			if SettingsManager:
				SettingsManager.accessibility_settings.easy_hook_mode = enabled
				SettingsManager.apply_accessibility_settings()
			_settings_dirty = true
		"card_effects", "card_effects2":
			if SettingsManager:
				SettingsManager.gameplay_settings.card_float_animation = enabled
				SettingsManager.gameplay_settings.card_dissolve = enabled
				SettingsManager.apply_gameplay_settings()
			_settings_dirty = true


func _auto_save_settings() -> void:
	if SettingsManager and SettingsManager.has_method("save_all_settings"):
		SettingsManager.save_all_settings()
	_settings_dirty = false


func _load_settings() -> void:
	if not SettingsManager:
		return
	
	_update_slider_ui("master_volume", SettingsManager.audio_settings.get("master_volume", 1.0))
	_update_slider_ui("music_volume", SettingsManager.audio_settings.get("music_volume", 0.8))
	_update_slider_ui("sfx_volume", SettingsManager.audio_settings.get("sfx_volume", 1.0))
	
	var window_mode: String = SettingsManager.display_settings.get("window_mode", "windowed")
	var window_idx := 0
	match window_mode:
		"windowed": window_idx = 0
		"borderless": window_idx = 1
		"fullscreen": window_idx = 2
	_update_dropdown_ui("window", window_idx)
	
	var res: Vector2i = SettingsManager.display_settings.get("resolution", Vector2i(1920, 1080))
	var res_str := "%dx%d" % [res.x, res.y]
	var res_idx := resolution_options.find(res_str)
	if res_idx == -1: res_idx = 3
	_update_dropdown_ui("resolution", res_idx)
	
	var frame_cap: int = SettingsManager.display_settings.get("framerate_cap", 60)
	var frame_idx := 1
	match frame_cap:
		30: frame_idx = 0
		60: frame_idx = 1
		120: frame_idx = 2
		0: frame_idx = 3
	_update_dropdown_ui("frame_cap", frame_idx)
	
	var cb_mode: String = SettingsManager.accessibility_settings.get("colorblind_mode", "none")
	var cb_idx := 0
	match cb_mode:
		"none": cb_idx = 0
		"protanopia": cb_idx = 1
		"deuteranopia": cb_idx = 2
		"tritanopia": cb_idx = 3
	_update_dropdown_ui("colorblind_mode", cb_idx)
	
	var font_size: float = SettingsManager.accessibility_settings.get("text_size", 1.0)
	var font_idx := 1
	if font_size <= 0.8: font_idx = 0
	elif font_size <= 1.0: font_idx = 1
	elif font_size <= 1.2: font_idx = 2
	else: font_idx = 3
	_update_dropdown_ui("font_size", font_idx)
	
	# Load cursor size (handles both String and legacy float saves)
	var cursor_val = SettingsManager.accessibility_settings.get("cursor_size", "Medium")
	var cursor_idx := 1 # Default to Medium (index 1)
	
	if cursor_val is String:
		# Find the index of the string in the options array
		var found_idx = cursor_size_options.find(cursor_val)
		if found_idx != -1:
			cursor_idx = found_idx
	elif cursor_val is float:
		# Legacy support for old save files
		if cursor_val <= 1.0: cursor_idx = 0 # Small
		elif cursor_val <= 1.5: cursor_idx = 1 # Medium
		else: cursor_idx = 2 # Large
		
	_update_dropdown_ui("cursor_size", cursor_idx)
	
	var battle_speed: float = SettingsManager.gameplay_settings.get("battle_speed", 1.0)
	var speed_idx := 1
	if battle_speed <= 0.5: speed_idx = 0
	elif battle_speed <= 1.0: speed_idx = 1
	elif battle_speed <= 2.0: speed_idx = 2
	else: speed_idx = 3
	_update_dropdown_ui("battle_speed", speed_idx)
	
	_update_toggle_ui("vsync", SettingsManager.display_settings.get("vsync", true))
	_update_toggle_ui("easy_hook", SettingsManager.accessibility_settings.get("easy_hook_mode", false))
	_update_toggle_ui("card_effects", SettingsManager.gameplay_settings.get("card_float_animation", true))
	_update_toggle_ui("card_effects2", SettingsManager.gameplay_settings.get("card_dissolve", true))


func _update_slider_ui(setting_key: String, value: float) -> void:
	if not _slider_controls.has(setting_key):
		return
	
	var slider_data: Dictionary = _slider_controls[setting_key]
	var handle: TextureRect = slider_data.get("handle")
	var fill: TextureRect = slider_data.get("fill")
	
	if handle:
		var handle_x := SLIDER_MIN_X + (value * SLIDER_WIDTH)
		handle.position.x = handle_x
	
	if fill:
		fill.size.x = (value * SLIDER_WIDTH) / 5.0


func _update_dropdown_ui(setting_key: String, index: int) -> void:
	if not _dropdown_controls.has(setting_key):
		return
	
	var dropdown_data: Dictionary = _dropdown_controls[setting_key]
	dropdown_data["current_index"] = index
	
	var options: Array = dropdown_data.get("options", [])
	var text_node: Label = dropdown_data.get("text")
	
	if text_node and index < options.size():
		text_node.text = options[index]


func _update_toggle_ui(setting_key: String, enabled: bool) -> void:
	if not _toggle_controls.has(setting_key):
		return
	
	var toggle_data: Dictionary = _toggle_controls[setting_key]
	toggle_data["enabled"] = enabled
	
	var toggle_btn: TextureRect = toggle_data.get("button")
	if toggle_btn:
		if enabled and toggle_on_texture:
			toggle_btn.texture = toggle_on_texture
		elif toggle_off_texture:
			toggle_btn.texture = toggle_off_texture


func _set_view_mode(mode: ViewMode) -> void:
	current_mode = mode
	current_page = 0
	
	_set_layer_visible(pause_layer, false)
	_set_layer_visible(settings_layer, false)
	
	# IMPORTANT: Load data before updating display
	_load_data()
	
	var show_inventory_tabs := mode == ViewMode.INVENTORY or mode == ViewMode.DECK
	
	if is_from_main_menu:
		show_inventory_tabs = false
	
	if focused1: focused1.visible = not is_from_main_menu
	if focused_icon: focused_icon.visible = not is_from_main_menu
	if inventory_tab: inventory_tab.visible = not is_from_main_menu
	
	if focused2: focused2.visible = not is_from_main_menu
	if focused_icon2: focused_icon2.visible = not is_from_main_menu
	if deck_tab: deck_tab.visible = not is_from_main_menu
	
	if focused3: focused3.visible = true
	if focused_icon3: focused_icon3.visible = true
	var options_tab_btn = get_node_or_null("OptionsTabBtn")
	if options_tab_btn: options_tab_btn.visible = not is_from_main_menu
	
	var pause_tab_btn = get_node_or_null("PauseTabBtn")
	if pause_tab_btn: pause_tab_btn.visible = not is_from_main_menu
	if focused4: focused4.visible = not is_from_main_menu
	if focused_icon4: focused_icon4.visible = not is_from_main_menu
	
	if page1: page1.visible = show_inventory_tabs
	if page2: page2.visible = show_inventory_tabs
	if next_page: next_page.visible = show_inventory_tabs
	if prev_page: prev_page.visible = show_inventory_tabs
	
	match mode:
		ViewMode.INVENTORY: _highlight_tab(1)
		ViewMode.DECK: _highlight_tab(2)
		ViewMode.OPTIONS:
			_highlight_tab(3)
			_set_layer_visible(settings_layer, true)
		ViewMode.PAUSE:
			_highlight_tab(4)
			_set_layer_visible(pause_layer, true)
	
	_update_display()


func _highlight_tab(tab_num: int) -> void:
	var tabs := [focused1, focused2, focused3, focused4]
	var icons := [focused_icon, focused_icon2, focused_icon3, focused_icon4]
	
	for i in 4:
		var is_selected := (i + 1) == tab_num
		# Selected tab is fully visible, non-selected tabs are invisible
		if tabs[i]: tabs[i].modulate.a = 1.0 if is_selected else 0.0
		if icons[i]: icons[i].modulate.a = 1.0 if is_selected else 0.0


func _load_data() -> void:
	if _use_external_data:
		fish_inventory = _external_catch_hold.duplicate()
		deck_cards = _external_deck.duplicate()
	elif GameState:
		# Fish inventory: convert FishData to Dictionary if needed
		var catch_hold_raw = GameState.get_catch_hold() if GameState.has_method("get_catch_hold") else []
		fish_inventory.clear()
		for fish in catch_hold_raw:
			if fish is FishData:
				# Convert FishData to Dictionary for display
				var fish_dict := {
					"name": fish.fish_name,
					"rarity": fish.rarity,
					"base_cowries": fish.base_cowries,
					"hook": fish.hook,
					"line": fish.line,
					"sinker": fish.sinker
				}
				fish_inventory.append(fish_dict)
			elif fish is Dictionary:
				fish_inventory.append(fish)
		
		# Deck cards: already CardData objects
		deck_cards = GameState.get_full_deck().duplicate() if GameState.has_method("get_full_deck") else []


func _update_display() -> void:
	if page1 == null or page2 == null: return
	
	for child in page1.get_children(): child.queue_free()
	for child in page2.get_children(): child.queue_free()
	
	match current_mode:
		ViewMode.INVENTORY: _display_fish_inventory()
		ViewMode.DECK: _display_deck()


const FISH_ROWS: int = 5
const FISH_COLS: int = 3
const CARD_ROWS: int = 3
const CARD_COLS: int = 3

func _display_fish_inventory() -> void:
	# Group fish by name and count duplicates
	var fish_groups: Dictionary = {}
	for fish_entry in fish_inventory:
		var fish_data = fish_entry.get("fish")
		if fish_data == null: continue
		
		var fish_name: String = ""
		if fish_data is FishData:
			fish_name = fish_data.fish_name
		elif fish_data is Dictionary:
			fish_name = fish_data.get("name", "Unknown")
		else: 
			continue
		
		if fish_name.is_empty(): continue
		
		if fish_groups.has(fish_name):
			fish_groups[fish_name]["count"] += 1
		else:
			fish_groups[fish_name] = {"fish_data": fish_data, "count": 1}
	
	var grouped_fish: Array = fish_groups.values()
	var page1_start: int = current_page * FISH_PER_SPREAD
	var page1_end: int = mini(page1_start + FISH_PER_PAGE, grouped_fish.size())
	_populate_fish_page(page1, grouped_fish, page1_start, page1_end)
	
	var page2_start: int = page1_start + FISH_PER_PAGE
	var page2_end: int = mini(page2_start + FISH_PER_PAGE, grouped_fish.size())
	_populate_fish_page(page2, grouped_fish, page2_start, page2_end)


func _populate_fish_page(page: VBoxContainer, fish_list: Array, start_idx: int, end_idx: int) -> void:
	if page == null: return
	
	for row in FISH_ROWS:
		var row_container := HBoxContainer.new()
		row_container.custom_minimum_size = Vector2(118, 155)
		row_container.add_theme_constant_override("separation", 10)
		page.add_child(row_container)
		
		for col in FISH_COLS:
			var fish_index: int = start_idx + (row * FISH_COLS) + col
			if fish_index < end_idx and fish_index < fish_list.size():
				var fish_entry: Dictionary = fish_list[fish_index]
				var fish_item := _create_fish_item(fish_entry["fish_data"], fish_entry["count"])
				row_container.add_child(fish_item)
			else:
				var placeholder := Control.new()
				placeholder.custom_minimum_size = Vector2(155, 0)
				row_container.add_child(placeholder)


func _create_fish_item(fish_data, count: int) -> VBoxContainer:
	var container := VBoxContainer.new()
	container.custom_minimum_size = Vector2(155, 0)
	
	var fish_name: String = ""
	if fish_data is FishData:
		fish_name = fish_data.fish_name if fish_data.fish_name else "Unknown Fish"
	elif fish_data is Dictionary:
		fish_name = fish_data.get("name", fish_data.get("fish_name", "Unknown Fish"))
	
	if fish_name.is_empty(): 
		fish_name = "Unknown Fish"
	
	# Fish image
	var fish_image := TextureRect.new()
	fish_image.z_index = 20
	fish_image.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	fish_image.custom_minimum_size = Vector2(120, 80)
	fish_image.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fish_image.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fish_image.pivot_offset = Vector2(60, 40)
	
	# Load fish texture from FishDatabase
	if FishDatabase:
		var image_path: String = FishDatabase.get_fish_image_path(fish_name)
		if image_path != "" and ResourceLoader.exists(image_path):
			fish_image.texture = load(image_path)
	elif fish_data is FishData and fish_data.texture:
		fish_image.texture = fish_data.texture
	
	fish_image.mouse_filter = Control.MOUSE_FILTER_STOP
	container.add_child(fish_image)
	
	# Fish name label
	var font_path := "res://menu/font/BoldPixels.otf"
	var name_label := Label.new()
	name_label.z_index = 20
	name_label.add_theme_color_override("font_color", Color(0.035, 0.137, 0.271, 1))
	if ResourceLoader.exists(font_path): 
		name_label.add_theme_font_override("font", load(font_path))
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.text = fish_name
	container.add_child(name_label)
	
	# Count label
	var count_label := Label.new()
	count_label.z_index = 20
	count_label.add_theme_color_override("font_color", Color(0.035, 0.137, 0.271, 1))
	if ResourceLoader.exists(font_path): 
		count_label.add_theme_font_override("font", load(font_path))
	count_label.add_theme_font_size_override("font_size", 20)
	count_label.text = "x%d" % count
	container.add_child(count_label)
	
	return container


func _display_deck() -> void:
	var start_index: int = current_page * CARDS_PER_SPREAD
	var page1_start: int = start_index
	var page1_end: int = mini(page1_start + CARDS_PER_PAGE, deck_cards.size())
	_populate_card_page(page1, page1_start, page1_end)
	
	var page2_start: int = start_index + CARDS_PER_PAGE
	var page2_end: int = mini(page2_start + CARDS_PER_PAGE, deck_cards.size())
	_populate_card_page(page2, page2_start, page2_end)


func _populate_card_page(page: VBoxContainer, start_idx: int, end_idx: int) -> void:
	if page == null: return
	
	for row in CARD_ROWS:
		var row_container := HBoxContainer.new()
		row_container.custom_minimum_size = Vector2(118, 250)
		row_container.add_theme_constant_override("separation", 15)
		row_container.alignment = BoxContainer.ALIGNMENT_CENTER
		page.add_child(row_container)
		
		for col in CARD_COLS:
			var card_index: int = start_idx + (row * CARD_COLS) + col
			if card_index < end_idx and card_index < deck_cards.size():
				var card: CardData = deck_cards[card_index]
				var card_item := _create_card_item(card)
				row_container.add_child(card_item)
			else:
				var placeholder := Control.new()
				placeholder.custom_minimum_size = Vector2(180, 260)
				row_container.add_child(placeholder)


func _create_card_item(card: CardData) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(180, 260)
	
	# Use SubViewport to render the card layout scene
	var viewport := SubViewport.new()
	viewport.size = Vector2i(180, 260)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	
	# Instance the card layout
	var card_display: Node2D = CARD_LAYOUT_SCENE.instantiate()
	card_display.position = Vector2(90, 130)
	card_display.scale = Vector2(0.65, 0.65)
	viewport.add_child(card_display)
	
	# Create viewport container to display it
	var viewport_container := SubViewportContainer.new()
	viewport_container.custom_minimum_size = Vector2(180, 260)
	viewport_container.stretch = true
	viewport_container.add_child(viewport)
	
	container.add_child(viewport_container)
	
	# Setup the card with data
	if card_display.has_method("setup"):
		card_display.setup(card)
	
	return container


func _on_continue_pressed() -> void:
	if AudioManager and AudioManager.has_method("play_ui_confirm"): 
		AudioManager.play_ui_confirm()
	_close()


func _on_save_game_pressed() -> void:
	if AudioManager and AudioManager.has_method("play_ui_confirm"): 
		AudioManager.play_ui_confirm()


func _on_load_game_pressed() -> void:
	if AudioManager and AudioManager.has_method("play_ui_confirm"): 
		AudioManager.play_ui_confirm()


func _on_main_menu_pressed() -> void:
	if AudioManager and AudioManager.has_method("play_ui_confirm"): 
		AudioManager.play_ui_confirm()
	if SaveManager and SaveManager.has_method("delete_run_save"):
		SaveManager.delete_run_save()
	if GameState and GameState.has_method("reset_run"):
		GameState.reset_run()
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")


func _on_quit_pressed() -> void:
	if AudioManager and AudioManager.has_method("play_ui_confirm"): 
		AudioManager.play_ui_confirm()
	get_tree().quit()


func _on_inventory_tab_pressed() -> void:
	if current_mode != ViewMode.INVENTORY and not is_from_main_menu:
		if AudioManager and AudioManager.has_method("play_ui_confirm"): 
			AudioManager.play_ui_confirm()
		_set_view_mode(ViewMode.INVENTORY)


func _on_deck_tab_pressed() -> void:
	if current_mode != ViewMode.DECK and not is_from_main_menu:
		if AudioManager and AudioManager.has_method("play_ui_confirm"): 
			AudioManager.play_ui_confirm()
		_set_view_mode(ViewMode.DECK)


func _on_options_tab_pressed() -> void:
	if current_mode != ViewMode.OPTIONS:
		if AudioManager and AudioManager.has_method("play_ui_confirm"): 
			AudioManager.play_ui_confirm()
		_set_view_mode(ViewMode.OPTIONS)


func _on_pause_tab_pressed() -> void:
	if current_mode != ViewMode.PAUSE and not is_from_main_menu:
		if AudioManager and AudioManager.has_method("play_ui_confirm"): 
			AudioManager.play_ui_confirm()
		_set_view_mode(ViewMode.PAUSE)


func _on_next_page() -> void:
	if AudioManager and AudioManager.has_method("play_ui_confirm"): 
		AudioManager.play_ui_confirm()
	current_page += 1
	_update_display()


func _on_prev_page() -> void:
	if AudioManager and AudioManager.has_method("play_ui_confirm"): 
		AudioManager.play_ui_confirm()
	current_page = maxi(0, current_page - 1)
	_update_display()


func _animate_show() -> void:
	if _is_animating: return
	_is_animating = true
	
	modulate.a = 0
	visible = true
	
	mouse_filter = Control.MOUSE_FILTER_STOP
	
	_load_settings()
	
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, SLIDE_DURATION)
	tween.tween_callback(func(): _is_animating = false)


func _animate_hide() -> void:
	if _is_animating: return
	_is_animating = true
	
	_set_layer_visible(pause_layer, false)
	_set_layer_visible(settings_layer, false)
	
	if _settings_dirty:
		_auto_save_settings()
	
	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 0.0, SLIDE_DURATION)
	tween.tween_callback(func():
		visible = false
		modulate.a = 1.0
		_is_animating = false
		closed.emit()
	)


func _close() -> void:
	if AudioManager and AudioManager.has_method("play_ui_confirm"): 
		AudioManager.play_ui_confirm()
	_animate_hide()


func show_inventory(catch_hold: Array = [], deck: Array = []) -> void:
	is_from_main_menu = false
	_external_catch_hold = catch_hold
	_external_deck = deck
	_use_external_data = not catch_hold.is_empty() or not deck.is_empty()
	_load_data()
	_set_view_mode(ViewMode.INVENTORY)
	_animate_show()


func show_deck(catch_hold: Array = [], deck: Array = []) -> void:
	is_from_main_menu = false
	_external_catch_hold = catch_hold
	_external_deck = deck
	_use_external_data = not catch_hold.is_empty() or not deck.is_empty()
	_load_data()
	_set_view_mode(ViewMode.DECK)
	_animate_show()


func show_options(catch_hold: Array = [], deck: Array = []) -> void:
	is_from_main_menu = false
	_external_catch_hold = catch_hold
	_external_deck = deck
	_use_external_data = true
	_load_data()
	_set_view_mode(ViewMode.INVENTORY)
	_animate_show()


func show_options_only() -> void:
	is_from_main_menu = true
	_use_external_data = false
	_set_view_mode(ViewMode.OPTIONS)
	_animate_show()


func show_pause() -> void:
	is_from_main_menu = false
	_use_external_data = false
	_load_data()
	_set_view_mode(ViewMode.PAUSE)
	_animate_show()
