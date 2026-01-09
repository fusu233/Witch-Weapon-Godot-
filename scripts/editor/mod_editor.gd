# =============================================================================
# Mod可视化编辑器 (Mod Visual Editor) - 重构版
# =============================================================================
# 功能概述：
# 1. 三列布局：左侧Inspector+资源，中间预览+工具箱，右侧脚本序列
# 2. 点击脚本块在Inspector显示详细参数
# 3. 工具箱Tab分类
# 4. 资源列表智能筛选
# =============================================================================

extends Control

const CHARACTER_ICON_SIZE: Vector2i = Vector2i(96, 144)
const BACKGROUND_ICON_SIZE: Vector2i = Vector2i(160, 90)
const MOD_EDITOR_RESOURCE_INDEX_PATH: String = "res://assets/mod_editor_resource_index.json"
const PALETTE_ROW_SIDE_PADDING_X: float = 10.0
const EDITOR_PINS_FILENAME: String = "editor_pins.json"
const BACKGROUND_STAR_TAB_KEY: String = "__starred__"

const RESOURCE_ROW_BG: Color = Color(0.12, 0.12, 0.15, 1.0)
const RESOURCE_ROW_BG_HOVER: Color = Color(0.16, 0.16, 0.20, 1.0)
const RESOURCE_ROW_BG_PRESSED: Color = Color(0.10, 0.10, 0.14, 1.0)
const RESOURCE_ROW_BG_SELECTED: Color = Color(0.14, 0.14, 0.20, 1.0)
const RESOURCE_ROW_BORDER: Color = Color(0.35, 0.35, 0.45, 0.55)
const RESOURCE_ROW_BORDER_HOVER: Color = Color(0.55, 0.55, 0.75, 0.85)
const RESOURCE_ROW_BORDER_SELECTED: Color = Color(0.42, 0.39, 1.0, 0.9)

# 脚本块类型枚举
enum BlockType {
	TEXT_ONLY,          # 纯文本（旁白）
	DIALOG,             # 对话（带说话人）
	SHOW_CHARACTER_1,   # 显示第一个角色
	HIDE_CHARACTER_1,   # 隐藏第一个角色
	SHOW_CHARACTER_2,   # 显示第二个角色
	HIDE_CHARACTER_2,   # 隐藏第二个角色
	SHOW_CHARACTER_3,   # 显示第三个角色
	HIDE_CHARACTER_3,   # 隐藏第三个角色
	HIDE_ALL_CHARACTERS,# 隐藏所有角色
	BACKGROUND,         # 更改背景
	MUSIC,              # 播放音乐
	EXPRESSION,         # 更改表情
	SHOW_BACKGROUND,    # 显示背景（可渐变）
	CHANGE_MUSIC,       # 切换音乐
	STOP_MUSIC,         # 停止音乐
	MOVE_CHARACTER_1_LEFT, # 角色1左移
	MOVE_CHARACTER_2_LEFT, # 角色2左移
	MOVE_CHARACTER_3_LEFT, # 角色3左移
	CHANGE_EXPRESSION_1, # 更改表情(角色1)
	CHANGE_EXPRESSION_2, # 更改表情(角色2)
	CHANGE_EXPRESSION_3, # 更改表情(角色3)
	HIDE_BACKGROUND, # 隐藏背景
	HIDE_BACKGROUND_FADE, # 渐变隐藏背景
	CHARACTER_LIGHT_1, # 角色1变亮
	CHARACTER_LIGHT_2, # 角色2变亮
	CHARACTER_LIGHT_3, # 角色3变亮
	CHARACTER_DARK_1, # 角色1变暗
	CHARACTER_DARK_2, # 角色2变暗
	CHARACTER_DARK_3, # 角色3变暗
}

# 脚本块分类
const BLOCK_CATEGORIES = {
	"对话": [BlockType.TEXT_ONLY, BlockType.DIALOG],
	"角色": [BlockType.SHOW_CHARACTER_1, BlockType.HIDE_CHARACTER_1,
			 BlockType.SHOW_CHARACTER_2, BlockType.HIDE_CHARACTER_2,
			 BlockType.SHOW_CHARACTER_3, BlockType.HIDE_CHARACTER_3,
			 BlockType.MOVE_CHARACTER_1_LEFT, BlockType.MOVE_CHARACTER_2_LEFT, BlockType.MOVE_CHARACTER_3_LEFT,
			 BlockType.EXPRESSION, BlockType.CHANGE_EXPRESSION_1, BlockType.CHANGE_EXPRESSION_2, BlockType.CHANGE_EXPRESSION_3,
			 BlockType.CHARACTER_LIGHT_1, BlockType.CHARACTER_LIGHT_2, BlockType.CHARACTER_LIGHT_3,
			 BlockType.CHARACTER_DARK_1, BlockType.CHARACTER_DARK_2, BlockType.CHARACTER_DARK_3,
			 BlockType.HIDE_ALL_CHARACTERS],
	"场景": [BlockType.BACKGROUND, BlockType.SHOW_BACKGROUND, BlockType.HIDE_BACKGROUND, BlockType.HIDE_BACKGROUND_FADE],
	"音乐": [BlockType.MUSIC, BlockType.CHANGE_MUSIC, BlockType.STOP_MUSIC],
}

# 脚本块数据类
class ScriptBlock:
	const SPEAKER_MAX_LENGTH: int = 10

	var block_type: BlockType
	var params: Dictionary = {}
	var ui_node: Control = null  # 右侧列表中的简化UI
	var has_error: bool = false  # 是否有验证错误
	var error_message: String = ""  # 错误信息

	func _init(type: BlockType):
		block_type = type

	func validate() -> bool:
		"""验证脚本块参数，返回true表示无错误"""
		has_error = false
		error_message = ""

		match block_type:
			BlockType.SHOW_CHARACTER_1, BlockType.SHOW_CHARACTER_2, BlockType.SHOW_CHARACTER_3:
				# 验证角色名称
				var char_name = params.get("character_name", "")
				if char_name.is_empty():
					has_error = true
					error_message = "角色名称不能为空"
					return false

				# 验证X位置 (0-1范围)
				var x_pos = params.get("x_position", 0.0)
				if typeof(x_pos) == TYPE_STRING:
					x_pos = x_pos.to_float()
				if x_pos < 0.0 or x_pos > 1.0:
					has_error = true
					error_message = "X位置必须在0-1之间"
					return false
			BlockType.MOVE_CHARACTER_1_LEFT, BlockType.MOVE_CHARACTER_2_LEFT, BlockType.MOVE_CHARACTER_3_LEFT:
				var to_xalign = params.get("to_xalign", -0.25)
				if typeof(to_xalign) == TYPE_STRING:
					to_xalign = to_xalign.to_float()
				if is_nan(to_xalign) or is_inf(to_xalign):
					has_error = true
					error_message = "目标X位置必须是有效数字"
					return false

				var duration = params.get("duration", 0.3)
				if typeof(duration) == TYPE_STRING:
					duration = duration.to_float()
				if is_nan(duration) or is_inf(duration) or duration < 0.0:
					has_error = true
					error_message = "时长必须是>=0的有效数字"
					return false
			BlockType.CHARACTER_LIGHT_1, BlockType.CHARACTER_LIGHT_2, BlockType.CHARACTER_LIGHT_3:
				var duration = params.get("duration", 0.35)
				if typeof(duration) == TYPE_STRING:
					duration = duration.to_float()
				if is_nan(duration) or is_inf(duration) or duration < 0.0:
					has_error = true
					error_message = "时长必须是>=0的有效数字"
					return false
			BlockType.TEXT_ONLY:
				var text = params.get("text", "")
				if text.is_empty():
					has_error = true
					error_message = "文本内容不能为空"
					return false

			BlockType.DIALOG:
				var text = params.get("text", "")
				var speaker = params.get("speaker", "")
				if text.is_empty():
					has_error = true
					error_message = "对话内容不能为空"
					return false
				if speaker.is_empty():
					has_error = true
					error_message = "说话人不能为空"
					return false
				if str(speaker).length() > SPEAKER_MAX_LENGTH:
					has_error = true
					error_message = "说话人名称不能超过%d个字符" % SPEAKER_MAX_LENGTH
					return false

			BlockType.BACKGROUND:
				var bg_path = params.get("background_path", "")
				if bg_path.is_empty():
					has_error = true
					error_message = "背景路径不能为空"
					return false

			BlockType.SHOW_BACKGROUND:
				var bg_path = params.get("background_path", "")
				if bg_path.is_empty():
					has_error = true
					error_message = "背景路径不能为空"
					return false
				var fade_time = params.get("fade_time", 0.0)
				if typeof(fade_time) == TYPE_STRING:
					fade_time = fade_time.to_float()
				if fade_time < 0.0:
					has_error = true
					error_message = "渐变时间不能小于0"
					return false

			BlockType.MUSIC:
				var music_path = params.get("music_path", "")
				if music_path.is_empty():
					has_error = true
					error_message = "音乐路径不能为空"
					return false

			BlockType.CHANGE_MUSIC:
				var music_path = params.get("music_path", "")
				if music_path.is_empty():
					has_error = true
					error_message = "音乐路径不能为空"
					return false

		return true

	func get_summary() -> String:
		"""获取脚本块的简要描述"""
		match block_type:
			BlockType.TEXT_ONLY:
				var text = params.get("text", "")
				return "旁白: " + text.substr(0, 20) + ("..." if text.length() > 20 else "")
			BlockType.DIALOG:
				var speaker = str(params.get("speaker", "未设置")).strip_edges().replace("\n", " ").replace("\r", " ")
				if speaker.length() > SPEAKER_MAX_LENGTH:
					speaker = speaker.substr(0, SPEAKER_MAX_LENGTH) + "…"
				var text = params.get("text", "")
				return speaker + ": " + text.substr(0, 15) + ("..." if text.length() > 15 else "")
			BlockType.SHOW_CHARACTER_1, BlockType.SHOW_CHARACTER_2, BlockType.SHOW_CHARACTER_3:
				var char_name = params.get("character_name", "未设置")
				return "显示角色: " + char_name
			BlockType.MOVE_CHARACTER_1_LEFT:
				var to_xalign = params.get("to_xalign", -0.25)
				return "角色1左移到: " + str(to_xalign)
			BlockType.MOVE_CHARACTER_2_LEFT:
				var to_xalign = params.get("to_xalign", -0.25)
				return "角色2左移到: " + str(to_xalign)
			BlockType.MOVE_CHARACTER_3_LEFT:
				var to_xalign = params.get("to_xalign", -0.25)
				return "角色3左移到: " + str(to_xalign)
			BlockType.EXPRESSION, BlockType.CHANGE_EXPRESSION_1:
				var expression = params.get("expression", "未设置")
				return "角色1表情切换: " + expression
			BlockType.CHANGE_EXPRESSION_2:
				var expression = params.get("expression", "未设置")
				return "角色2表情切换: " + expression
			BlockType.CHANGE_EXPRESSION_3:
				var expression = params.get("expression", "未设置")
				return "角色3表情切换: " + expression
			BlockType.CHARACTER_LIGHT_1:
				var expression = str(params.get("expression", ""))
				return "角色1变亮" + (" +表情" if not expression.is_empty() else "")
			BlockType.CHARACTER_LIGHT_2:
				var expression = str(params.get("expression", ""))
				return "角色2变亮" + (" +表情" if not expression.is_empty() else "")
			BlockType.CHARACTER_LIGHT_3:
				var expression = str(params.get("expression", ""))
				return "角色3变亮" + (" +表情" if not expression.is_empty() else "")
			BlockType.CHARACTER_DARK_1:
				return "角色1变暗"
			BlockType.CHARACTER_DARK_2:
				return "角色2变暗"
			BlockType.CHARACTER_DARK_3:
				return "角色3变暗"
			BlockType.HIDE_CHARACTER_1:
				return "隐藏角色1"
			BlockType.HIDE_CHARACTER_2:
				return "隐藏角色2"
			BlockType.HIDE_CHARACTER_3:
				return "隐藏角色3"
			BlockType.HIDE_ALL_CHARACTERS:
				return "隐藏所有角色"
			BlockType.BACKGROUND:
				return "切换背景(渐变)"
			BlockType.MUSIC:
				return "播放音乐"
			BlockType.SHOW_BACKGROUND:
				var bg_path = params.get("background_path", "")
				return "显示背景: " + bg_path.get_file()
			BlockType.HIDE_BACKGROUND:
				return "隐藏背景"
			BlockType.HIDE_BACKGROUND_FADE:
				return "渐变隐藏背景"
			BlockType.CHANGE_MUSIC:
				var music_path = params.get("music_path", "")
				return "切换音乐: " + music_path.get_file()
			BlockType.STOP_MUSIC:
				return "停止音乐"
			_:
				return "未知类型"

# === 节点引用 ===
# TopBar
@onready var back_button: Button = $TopBar/BackButton
@onready var run_button: Button = $TopBar/RunButton
@onready var export_button: Button = $TopBar/ExportButton
@onready var project_name_label: Label = $TopBar/ProjectNameLabel

# 左侧面板
@onready var inspector_content: VBoxContainer = $MainContainer/LeftPanel/InspectorPanel/InspectorContainer/InspectorScroll/InspectorContent
@onready var characters_list: ItemList = $MainContainer/LeftPanel/ResourcePanel/ResourceContainer/CharactersList
@onready var backgrounds_list: ItemList = $MainContainer/LeftPanel/ResourcePanel/ResourceContainer/BackgroundsList
@onready var background_tabs: TabContainer = $MainContainer/LeftPanel/ResourcePanel/ResourceContainer/BackgroundTabs
@onready var music_rows_scroll: ScrollContainer = $MainContainer/LeftPanel/ResourcePanel/ResourceContainer/MusicRowsScroll
@onready var music_rows: VBoxContainer = $MainContainer/LeftPanel/ResourcePanel/ResourceContainer/MusicRowsScroll/MusicRows
@onready var music_list: ItemList = $MainContainer/LeftPanel/ResourcePanel/ResourceContainer/MusicList

# 中间面板
@onready var preview_viewport: SubViewport = $MainContainer/CenterPanel/PreviewPanel/PreviewContainer/PreviewAspect/PreviewArea/SubViewport
@onready var dialog_blocks_container: VBoxContainer = $MainContainer/CenterPanel/ToolboxPanel/ToolboxContainer/ToolboxTabs/对话/DialogBlocksContainer
@onready var character_blocks_container: VBoxContainer = $MainContainer/CenterPanel/ToolboxPanel/ToolboxContainer/ToolboxTabs/角色/CharacterBlocksContainer
@onready var scene_blocks_container: VBoxContainer = $MainContainer/CenterPanel/ToolboxPanel/ToolboxContainer/ToolboxTabs/场景/SceneBlocksContainer
@onready var music_blocks_container: VBoxContainer = $MainContainer/CenterPanel/ToolboxPanel/ToolboxContainer/ToolboxTabs/音乐/MusicBlocksContainer
@onready var control_blocks_container: VBoxContainer = $MainContainer/CenterPanel/ToolboxPanel/ToolboxContainer/ToolboxTabs/控制/ControlBlocksContainer

# 右侧面板
@onready var script_sequence: VBoxContainer = $MainContainer/RightPanel/RightPanelContainer/ScriptSequenceScroll/ScriptSequence
@onready var script_sequence_scroll: ScrollContainer = $MainContainer/RightPanel/RightPanelContainer/ScriptSequenceScroll

# === 变量 ===
var project_path: String = ""
var project_config: Dictionary = {}
var script_blocks: Array[ScriptBlock] = []
var selected_block: ScriptBlock = null
var _project_root: String = ""
var _editor_pins_path: String = ""
var _editor_pins_loaded: bool = false
var _editor_pins: Dictionary = {}

# 预览相关
var novel_interface: Node = null
var is_previewing: bool = false
var preview_coroutine = null

# 资源列表相关
var current_editing_field: LineEdit = null  # 当前正在编辑的参数字段
var current_editing_param: String = ""  # 当前参数名（character_name, expression等）
var _resource_mode: String = "none"  # none|character|expression|background|music

var _character_scene_cache: Dictionary = {} # character_name -> PackedScene
var _character_base_dir_cache: Dictionary = {} # character_name -> String
var _character_thumbnail_cache: Dictionary = {} # character_name -> Texture2D
var _expression_thumbnail_cache: Dictionary = {} # "character|expression" -> Texture2D
var _character_expressions_cache: Dictionary = {} # character_name -> Array[String]
var _background_thumbnail_cache: Dictionary = {} # full_path -> Texture2D

var _background_base_dir: String = ""
var _background_tab_loaded: Array[bool] = []
var _background_tab_dirs: Array[String] = []

var _resource_index_loaded: bool = false
var _resource_index: Dictionary = {}

var _music_preview_player: AudioStreamPlayer = null
var _music_preview_current_path: String = ""
var _music_preview_buttons_by_path: Dictionary = {}

var _character_rows_scroll: ScrollContainer = null
var _character_rows: VBoxContainer = null
var _resource_selected_keys: Dictionary = {} # mode -> key
var _expression_list_character_name: String = ""

var _main_bgm_player: AudioStreamPlayer = null
var _main_bgm_suspended: bool = false
var _main_bgm_was_playing: bool = false
var _main_bgm_was_paused: bool = false
var _main_bgm_volume_db: float = 0.0
var _main_bgm_playback_pos: float = 0.0
var _main_bgm_stream: AudioStream = null

# 错误追踪
var has_validation_errors: bool = false

# 拖拽排序辅助UI
var drop_placeholder: PanelContainer = null

func _ready():
	set_process_input(true)
	_create_block_palette()
	_setup_preview()

	_setup_resource_panel()
	_suspend_main_menu_bgm()
	_ensure_music_preview_player()

	# 连接资源列表的点击事件
	characters_list.item_selected.connect(_on_character_selected)
	backgrounds_list.item_selected.connect(_on_background_selected)
	music_list.item_selected.connect(_on_music_selected)

	# 连接按钮事件
	run_button.pressed.connect(_on_run_button_pressed)
	export_button.pressed.connect(_on_export_button_pressed)
	back_button.pressed.connect(_on_back_button_pressed)

	# 允许拖拽时把块丢到“空隙/空白区域/列表末尾”
	script_sequence.set_drag_forwarding(
		Callable(self, "_get_drag_data_noop_simple"),
		Callable(self, "_can_drop_data_for_sequence").bind(script_sequence),
		Callable(self, "_drop_data_for_sequence").bind(script_sequence)
	)
	script_sequence_scroll.set_drag_forwarding(
		Callable(self, "_get_drag_data_noop_simple"),
		Callable(self, "_can_drop_data_for_sequence").bind(script_sequence_scroll),
		Callable(self, "_drop_data_for_sequence").bind(script_sequence_scroll)
	)
	_validate_all_blocks()

func _setup_resource_panel() -> void:
	_set_resource_panel_mode("none")

	# 更适合显示缩略图
	characters_list.fixed_icon_size = CHARACTER_ICON_SIZE
	characters_list.max_columns = 1
	_ensure_character_rows_ui()

func _ensure_character_rows_ui() -> void:
	if _character_rows_scroll != null and is_instance_valid(_character_rows_scroll):
		return
	if characters_list == null:
		return
	var parent := characters_list.get_parent() as Control
	if parent == null:
		return

	var scroll := ScrollContainer.new()
	scroll.name = "CharactersRowsScroll"
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	scroll.visible = false

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)
	scroll.add_child(rows)

	parent.add_child(scroll)
	_character_rows_scroll = scroll
	_character_rows = rows

func _create_resource_row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = RESOURCE_ROW_BG
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = RESOURCE_ROW_BORDER
	style.content_margin_left = 8
	style.content_margin_top = 6
	style.content_margin_right = 8
	style.content_margin_bottom = 6
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	return style

func _get_selected_resource_key(mode: String) -> String:
	if not _resource_selected_keys.has(mode):
		return ""
	return str(_resource_selected_keys.get(mode, ""))

func _apply_resource_row_visual(panel: PanelContainer) -> void:
	if panel == null:
		return
	var style_any: Variant = panel.get_meta("resource_style")
	var style := style_any as StyleBoxFlat
	if style == null:
		return

	var mode := str(panel.get_meta("resource_mode"))
	var key := str(panel.get_meta("resource_key"))
	var hovered := bool(panel.get_meta("resource_hovered"))
	var pressed := bool(panel.get_meta("resource_pressed"))
	var selected := (not key.is_empty()) and (key == _get_selected_resource_key(mode))

	if pressed:
		style.bg_color = RESOURCE_ROW_BG_PRESSED
	elif selected:
		style.bg_color = RESOURCE_ROW_BG_SELECTED
	elif hovered:
		style.bg_color = RESOURCE_ROW_BG_HOVER
	else:
		style.bg_color = RESOURCE_ROW_BG

	if selected:
		style.border_color = RESOURCE_ROW_BORDER_SELECTED
	elif hovered:
		style.border_color = RESOURCE_ROW_BORDER_HOVER
	else:
		style.border_color = RESOURCE_ROW_BORDER

func _refresh_visible_resource_row_styles() -> void:
	if _resource_mode == "music" and music_rows != null:
		for child in music_rows.get_children():
			var panel := child as PanelContainer
			if panel != null:
				_apply_resource_row_visual(panel)
	elif _resource_mode in ["character", "expression"] and _character_rows != null:
		for child in _character_rows.get_children():
			var panel := child as PanelContainer
			if panel != null:
				_apply_resource_row_visual(panel)
	elif _resource_mode == "background" and background_tabs != null:
		var rows := _get_background_tab_rows(background_tabs.current_tab)
		if rows != null:
			for child in rows.get_children():
				var panel := child as PanelContainer
				if panel != null:
					_apply_resource_row_visual(panel)

func _set_resource_selected_key(mode: String, key: String) -> void:
	if mode.is_empty():
		return
	_resource_selected_keys[mode] = key
	_refresh_visible_resource_row_styles()

func _make_interactive_resource_row(mode: String, key: String, on_activate: Callable) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := _create_resource_row_style()
	panel.add_theme_stylebox_override("panel", style)

	panel.set_meta("resource_mode", mode)
	panel.set_meta("resource_key", key)
	panel.set_meta("resource_style", style)
	panel.set_meta("resource_hovered", false)
	panel.set_meta("resource_pressed", false)

	panel.mouse_entered.connect(func():
		panel.set_meta("resource_hovered", true)
		_apply_resource_row_visual(panel)
	)
	panel.mouse_exited.connect(func():
		panel.set_meta("resource_hovered", false)
		panel.set_meta("resource_pressed", false)
		_apply_resource_row_visual(panel)
	)
	panel.gui_input.connect(func(ev: InputEvent):
		if ev is InputEventMouseButton and (ev as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
			if (ev as InputEventMouseButton).pressed:
				panel.set_meta("resource_pressed", true)
				_apply_resource_row_visual(panel)
			else:
				panel.set_meta("resource_pressed", false)
				_apply_resource_row_visual(panel)
				if on_activate.is_valid():
					on_activate.call()
	)

	_apply_resource_row_visual(panel)
	return panel

func _input(event: InputEvent) -> void:
	# 结束拖拽（或取消拖拽）时隐藏插入指示线
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_hide_drop_placeholder()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_hide_drop_placeholder()

func _exit_tree() -> void:
	_stop_music_preview()
	_resume_main_menu_bgm()

func _suspend_main_menu_bgm() -> void:
	if _main_bgm_suspended:
		return

	var player := _find_main_menu_bgm_player()
	if player == null:
		return

	_main_bgm_player = player
	_main_bgm_stream = player.stream
	_main_bgm_volume_db = player.volume_db
	_main_bgm_was_playing = player.playing
	_main_bgm_was_paused = player.stream_paused
	_main_bgm_playback_pos = player.get_playback_position()

	if player.playing or player.stream_paused:
		player.stream_paused = false
		player.stop()

	_main_bgm_suspended = true

func _resume_main_menu_bgm() -> void:
	if not _main_bgm_suspended:
		return

	_main_bgm_suspended = false

	if _main_bgm_player == null or not is_instance_valid(_main_bgm_player):
		return

	if not _main_bgm_was_playing:
		return

	if _main_bgm_stream != null:
		_main_bgm_player.stream = _main_bgm_stream
	_main_bgm_player.volume_db = _main_bgm_volume_db
	_main_bgm_player.play(_main_bgm_playback_pos)
	_main_bgm_player.stream_paused = _main_bgm_was_paused

func _find_main_menu_bgm_player() -> AudioStreamPlayer:
	var scene := get_tree().current_scene
	if scene == null:
		return null

	var direct := scene.get_node_or_null("BGMPlayer")
	if direct is AudioStreamPlayer:
		return direct as AudioStreamPlayer

	var found := scene.find_child("BGMPlayer", true, false)
	return found as AudioStreamPlayer

func _setup_preview():
	"""初始化预览区域的NovelInterface"""
	# 加载NovelInterface场景
	var novel_interface_scene = load("res://scenes/dialog/NovelInterface.tscn")
	if novel_interface_scene:
		novel_interface = novel_interface_scene.instantiate()
		preview_viewport.add_child(novel_interface)

		# 使用size_2d_override设置虚拟分辨率，匹配NovelInterface的设计尺寸
		preview_viewport.size_2d_override = Vector2i(1280, 720)
		preview_viewport.size_2d_override_stretch = true

		print("预览区域初始化完成")

# ==================== 资源列表管理 ====================

func _set_resource_panel_mode(mode: String) -> void:
	var previous_mode: String = _resource_mode
	_resource_mode = mode

	var resource_panel := get_node_or_null("MainContainer/LeftPanel/ResourcePanel") as Control
	var characters_label := get_node_or_null("MainContainer/LeftPanel/ResourcePanel/ResourceContainer/CharactersLabel") as Label
	var backgrounds_label := get_node_or_null("MainContainer/LeftPanel/ResourcePanel/ResourceContainer/BackgroundsLabel") as Control
	var music_label := get_node_or_null("MainContainer/LeftPanel/ResourcePanel/ResourceContainer/MusicLabel") as Control

	# 资源面板始终可见
	if resource_panel:
		resource_panel.visible = true

	# 根据模式显示对应的列表
	if characters_label:
		characters_label.visible = mode in ["character", "expression"]
		characters_label.text = "表情:" if mode == "expression" else "角色:"
	if characters_list:
		characters_list.visible = false
	_ensure_character_rows_ui()
	if _character_rows_scroll:
		_character_rows_scroll.visible = mode in ["character", "expression"]

	if backgrounds_label:
		backgrounds_label.visible = mode == "background"
	if backgrounds_list:
		backgrounds_list.visible = false
	if background_tabs:
		background_tabs.visible = mode == "background"

	if music_label:
		music_label.visible = mode == "music"
	if music_list:
		music_list.visible = false
	if music_rows_scroll:
		music_rows_scroll.visible = mode == "music"

	# 切换离开音乐模式时，先停止预览并清理引用，避免引用到已释放的按钮
	if previous_mode == "music" and mode != "music":
		_stop_music_preview()
		_music_preview_buttons_by_path.clear()

	# 当模式为"none"时，清空所有列表（但不隐藏面板）
	if mode == "none":
		if characters_list:
			characters_list.clear()
		if _character_rows:
			_clear_children(_character_rows)
		if backgrounds_list:
			backgrounds_list.clear()
		if background_tabs:
			for child in background_tabs.get_children():
				child.queue_free()
		if music_list:
			music_list.clear()
		if music_rows:
			for child in music_rows.get_children():
				child.queue_free()
		_music_preview_buttons_by_path.clear()
		# 隐藏所有标签
		if characters_label:
			characters_label.visible = false
		if backgrounds_label:
			backgrounds_label.visible = false
		if music_label:
			music_label.visible = false

func _load_characters_list():
	"""扫描并加载角色列表"""
	# Exported builds may store resources as `<name>.tscn.remap`, so avoid relying on raw `.tscn` listing.
	var dir_path := "res://scenes/character"
	var character_names: Array[String] = []
	var unique: Dictionary = {}
	for entry_name: String in DirAccess.get_files_at(dir_path):
		var normalized := _normalize_listed_file_name(entry_name)
		if normalized.to_lower().ends_with(".tscn"):
			var character_name := normalized.trim_suffix(".tscn")
			if not unique.has(character_name):
				unique[character_name] = true
				character_names.append(character_name)
	_set_resource_panel_mode("character")
	_ensure_character_rows_ui()
	if _character_rows == null:
		return
	_clear_children(_character_rows)

	character_names.sort()
	var pinned := _get_pinned_character_names()
	var pinned_set: Dictionary = {}
	for entry in pinned:
		pinned_set[str(entry)] = true

	# 先按置顶顺序添加（仅添加存在的角色）
	var count_added := 0
	for pinned_name_any in pinned:
		var pinned_name := str(pinned_name_any)
		if unique.has(pinned_name):
			_add_character_row(_character_rows, pinned_name, true)
			count_added += 1

	# 再添加未置顶角色（按字母序）
	for character_name in character_names:
		if pinned_set.has(character_name):
			continue
		_add_character_row(_character_rows, character_name, false)
		count_added += 1

	print("Loaded %d characters" % count_added)
	_refresh_visible_resource_row_styles()

func _add_character_row(parent: VBoxContainer, character_name: String, is_pinned: bool) -> void:
	if parent == null:
		return

	var panel := _make_interactive_resource_row("character", character_name, Callable(self, "_select_character_name").bind(character_name))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var thumb_holder := Control.new()
	thumb_holder.custom_minimum_size = Vector2(float(CHARACTER_ICON_SIZE.x), float(CHARACTER_ICON_SIZE.y))
	thumb_holder.size_flags_horizontal = 0
	thumb_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var texture_rect := TextureRect.new()
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.texture = _get_character_thumbnail(character_name)
	thumb_holder.add_child(texture_rect)

	var star_button := Button.new()
	star_button.text = "★" if is_pinned else "☆"
	star_button.tooltip_text = "取消置顶" if is_pinned else "置顶到顶部"
	star_button.custom_minimum_size = Vector2(22, 22)
	star_button.focus_mode = Control.FOCUS_NONE
	star_button.mouse_filter = Control.MOUSE_FILTER_STOP
	star_button.position = Vector2(4, 4)
	star_button.pressed.connect(Callable(self, "_on_character_pin_pressed").bind(character_name))
	if is_pinned:
		star_button.modulate = Color(1.0, 0.9, 0.25)
	thumb_holder.add_child(star_button)

	var label := Label.new()
	label.text = character_name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	row.add_child(thumb_holder)
	row.add_child(label)
	panel.add_child(row)
	parent.add_child(panel)

func _expression_key(character_name: String, expression_name: String) -> String:
	var c := character_name.strip_edges()
	var e := expression_name.strip_edges()
	return "%s|%s" % [c, e]

func _add_expression_row(parent: VBoxContainer, character_name: String, expression_name: String, is_pinned: bool = false) -> void:
	if parent == null:
		return

	var key := _expression_key(character_name, expression_name)
	var panel := _make_interactive_resource_row("expression", key, Callable(self, "_select_expression_name").bind(expression_name))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var thumb_holder := Control.new()
	thumb_holder.custom_minimum_size = Vector2(float(CHARACTER_ICON_SIZE.x), float(CHARACTER_ICON_SIZE.y))
	thumb_holder.size_flags_horizontal = 0
	thumb_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var texture_rect := TextureRect.new()
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.texture = _get_expression_thumbnail(character_name, expression_name)
	thumb_holder.add_child(texture_rect)

	var star_button := Button.new()
	star_button.text = "★" if is_pinned else "☆"
	star_button.tooltip_text = "取消置顶" if is_pinned else "置顶到顶部"
	star_button.custom_minimum_size = Vector2(22, 22)
	star_button.focus_mode = Control.FOCUS_NONE
	star_button.mouse_filter = Control.MOUSE_FILTER_STOP
	star_button.position = Vector2(4, 4)
	star_button.pressed.connect(Callable(self, "_on_expression_pin_pressed").bind(character_name, expression_name))
	if is_pinned:
		star_button.modulate = Color(1.0, 0.9, 0.25)
	thumb_holder.add_child(star_button)

	var label := Label.new()
	label.text = expression_name
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	row.add_child(thumb_holder)
	row.add_child(label)
	panel.add_child(row)
	parent.add_child(panel)

func _load_backgrounds_list():
	"""扫描并加载背景列表"""
	_set_resource_panel_mode("background")
	backgrounds_list.clear()

	_background_base_dir = ""
	var bg_dir_new := "res://assets/images/bg"
	var bg_dir_old := "res://assets/background"
	if _dir_has_any_entry(bg_dir_new):
		_background_base_dir = bg_dir_new + "/"
	elif _dir_has_any_entry(bg_dir_old):
		_background_base_dir = bg_dir_old + "/"

	if _background_base_dir.is_empty():
		push_warning("无法找到背景文件夹: res://assets/images/bg/ 或 res://assets/background/")
		return

	_refresh_background_tabs()

func _refresh_background_tabs() -> void:
	if not background_tabs:
		push_warning("BackgroundTabs 节点不存在，无法按文件夹显示背景资源")
		return

	for child in background_tabs.get_children():
		child.queue_free()

	_background_tab_dirs.clear()
	_background_tab_loaded.clear()

	var allowed_exts: Array[String] = [".png", ".jpg", ".jpeg", ".webp"]

	# 固定星标Tab：用于收纳玩家收藏的背景（不置顶其他Tab）
	_add_background_tab("★", BACKGROUND_STAR_TAB_KEY)

	var root_files: Array[String] = _collect_files_flat(_background_base_dir, allowed_exts)
	if root_files.is_empty():
		root_files = _get_index_background_root_files()
	if not root_files.is_empty():
		_add_background_tab("根目录", "")

	var folder_names: Array[String] = []
	for dir_name: String in DirAccess.get_directories_at(_background_base_dir.trim_suffix("/")):
		if not dir_name.begins_with("."):
			folder_names.append(dir_name)

	if folder_names.is_empty():
		var index := _get_resource_index()
		var bg: Variant = index.get("backgrounds", {})
		if typeof(bg) == TYPE_DICTIONARY:
			var folders: Variant = (bg as Dictionary).get("folders", {})
			if typeof(folders) == TYPE_DICTIONARY:
				for key in (folders as Dictionary).keys():
					if typeof(key) == TYPE_STRING and not (key as String).begins_with("."):
						folder_names.append(key as String)

	folder_names.sort()
	for folder_name: String in folder_names:
		_add_background_tab(folder_name, folder_name + "/")

	if background_tabs.tab_changed.is_connected(_on_background_tab_changed):
		background_tabs.tab_changed.disconnect(_on_background_tab_changed)
	background_tabs.tab_changed.connect(_on_background_tab_changed)

	if background_tabs.get_child_count() > 0:
		# 默认显示第一个“非星标”tab（更符合挑选资源的直觉）；如果没有则显示星标tab。
		var default_tab := 1 if background_tabs.get_child_count() > 1 else 0
		background_tabs.current_tab = default_tab
		_on_background_tab_changed(default_tab)

func _add_background_tab(title: String, rel_dir: String) -> void:
	var scroll := ScrollContainer.new()
	scroll.name = title
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	var rows := VBoxContainer.new()
	rows.name = "Rows"
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 10)
	scroll.add_child(rows)

	background_tabs.add_child(scroll)
	_background_tab_dirs.append(rel_dir)
	_background_tab_loaded.append(false)

func _get_background_tab_rows(tab_index: int) -> VBoxContainer:
	if background_tabs == null:
		return null
	var scroll := background_tabs.get_child(tab_index) as ScrollContainer
	if scroll == null:
		return null
	var rows := scroll.get_node_or_null("Rows") as VBoxContainer
	return rows

func _clear_children(node: Node) -> void:
	if node == null:
		return
	for child in node.get_children():
		child.queue_free()

func _add_background_thumb_row(parent: VBoxContainer, display_text: String, full_path: String, is_starred: bool) -> void:
	if parent == null:
		return

	var panel := _make_interactive_resource_row("background", full_path, Callable(self, "_select_background_path").bind(full_path))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var thumb_holder := Control.new()
	thumb_holder.custom_minimum_size = Vector2(float(BACKGROUND_ICON_SIZE.x), float(BACKGROUND_ICON_SIZE.y))
	thumb_holder.size_flags_horizontal = 0
	thumb_holder.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var texture_rect := TextureRect.new()
	texture_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.texture = _get_background_thumbnail(full_path)
	thumb_holder.add_child(texture_rect)

	var star_button := Button.new()
	star_button.text = "★" if is_starred else "☆"
	star_button.tooltip_text = "从星标移除" if is_starred else "加入星标"
	star_button.custom_minimum_size = Vector2(22, 22)
	star_button.focus_mode = Control.FOCUS_NONE
	star_button.mouse_filter = Control.MOUSE_FILTER_STOP
	star_button.position = Vector2(4, 4)
	star_button.pressed.connect(Callable(self, "_on_background_star_pressed").bind(full_path))
	if is_starred:
		star_button.modulate = Color(1.0, 0.9, 0.25)
	thumb_holder.add_child(star_button)

	var label := Label.new()
	label.text = display_text
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	row.add_child(thumb_holder)
	row.add_child(label)
	panel.add_child(row)
	parent.add_child(panel)

func _on_background_tab_changed(tab_index: int) -> void:
	if tab_index < 0 or tab_index >= background_tabs.get_child_count():
		return
	if tab_index < 0 or tab_index >= _background_tab_loaded.size():
		return
	if _background_tab_loaded[tab_index]:
		return

	var rows := _get_background_tab_rows(tab_index)
	if rows == null:
		return

	var rel_dir: String = _background_tab_dirs[tab_index]
	_clear_children(rows)

	# 星标Tab：直接从项目级收藏列表生成
	if rel_dir == BACKGROUND_STAR_TAB_KEY:
		var starred := _get_starred_background_paths()
		var count_added := 0
		for p_any in starred:
			var full_path := str(p_any)
			if not _resource_exists_with_remap(full_path):
				continue
			var display := full_path
			if not _background_base_dir.is_empty() and full_path.begins_with(_background_base_dir):
				display = full_path.substr(_background_base_dir.length())
			_add_background_thumb_row(rows, display, full_path, true)
			count_added += 1
		_background_tab_loaded[tab_index] = true
		print("已加载背景分类[%s] %d 个" % ["★", count_added])
		_refresh_visible_resource_row_styles()
		return

	var allowed_exts: Array[String] = [".png", ".jpg", ".jpeg", ".webp"]
	var rel_files: Array[String] = []
	if rel_dir.is_empty():
		rel_files = _collect_files_flat(_background_base_dir, allowed_exts)
	else:
		rel_files = _collect_files_recursive(_background_base_dir + rel_dir, allowed_exts)

	if rel_files.is_empty():
		if rel_dir.is_empty():
			rel_files = _get_index_background_root_files()
		else:
			rel_files = _get_index_background_folder_files(rel_dir.trim_suffix("/"))

	rel_files.sort()
	for rel_path: String in rel_files:
		var full_path: String = (_background_base_dir + rel_dir + rel_path) if not rel_dir.is_empty() else (_background_base_dir + rel_path)
		_add_background_thumb_row(rows, rel_path, full_path, _is_background_starred(full_path))

	_background_tab_loaded[tab_index] = true
	var tab_title := background_tabs.get_child(tab_index).name
	print("已加载背景分类[%s] %d 个" % [tab_title, rel_files.size()])
	_refresh_visible_resource_row_styles()

func _dir_has_any_entry(dir_path: String) -> bool:
	var normalized := dir_path.trim_suffix("/")
	var dir := DirAccess.open(normalized)
	if dir == null:
		return false

	dir.list_dir_begin()
	var entry := dir.get_next()
	while not entry.is_empty():
		if entry != "." and entry != "..":
			dir.list_dir_end()
			return true
		entry = dir.get_next()
	dir.list_dir_end()
	return false

func _normalize_listed_file_name(entry_name: String) -> String:
	# 导出后常见：`xxx.ext.remap`；少数情况下也可能出现 `xxx.ext.import.remap`。
	var normalized := entry_name
	var had_remap := normalized.ends_with(".remap")
	normalized = normalized.trim_suffix(".remap")
	if had_remap and normalized.ends_with(".import"):
		normalized = normalized.trim_suffix(".import")
	return normalized

func _get_resource_index() -> Dictionary:
	if _resource_index_loaded:
		return _resource_index
	_resource_index_loaded = true

	var file := FileAccess.open(MOD_EDITOR_RESOURCE_INDEX_PATH, FileAccess.READ)
	if file == null:
		push_warning("Mod editor resource index not found: " + MOD_EDITOR_RESOURCE_INDEX_PATH)
		return {}

	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	if err != OK:
		push_warning("Failed to parse mod editor resource index: " + MOD_EDITOR_RESOURCE_INDEX_PATH)
		return {}
	if typeof(json.data) == TYPE_DICTIONARY:
		_resource_index = json.data as Dictionary
	return _resource_index

func _get_index_background_root_files() -> Array[String]:
	var index := _get_resource_index()
	var bg: Variant = index.get("backgrounds", {})
	if typeof(bg) != TYPE_DICTIONARY:
		var empty: Array[String] = []
		return empty
	var root: Variant = (bg as Dictionary).get("root", [])
	if typeof(root) != TYPE_ARRAY:
		var empty: Array[String] = []
		return empty
	var results: Array[String] = []
	for entry in (root as Array):
		results.append(str(entry))
	return results

func _get_index_background_folder_files(folder_name: String) -> Array[String]:
	var index := _get_resource_index()
	var bg: Variant = index.get("backgrounds", {})
	if typeof(bg) != TYPE_DICTIONARY:
		var empty: Array[String] = []
		return empty
	var folders: Variant = (bg as Dictionary).get("folders", {})
	if typeof(folders) != TYPE_DICTIONARY:
		var empty: Array[String] = []
		return empty
	var list: Variant = (folders as Dictionary).get(folder_name, [])
	if typeof(list) != TYPE_ARRAY:
		var empty: Array[String] = []
		return empty
	var results: Array[String] = []
	for entry in (list as Array):
		results.append(str(entry))
	return results

func _get_index_music_files() -> Array[String]:
	var index := _get_resource_index()
	var music: Variant = index.get("music", {})
	if typeof(music) != TYPE_DICTIONARY:
		var empty: Array[String] = []
		return empty
	var files: Variant = (music as Dictionary).get("files", [])
	if typeof(files) != TYPE_ARRAY:
		var empty: Array[String] = []
		return empty
	var results: Array[String] = []
	for entry in (files as Array):
		results.append(str(entry))
	return results

func _collect_files_flat(dir_path: String, allowed_exts: Array[String]) -> Array[String]:
	# In exported builds, files can appear as `<name>.<ext>.remap`, so we enumerate with `get_files_at` and strip the suffix.
	var results: Array[String] = []
	var unique: Dictionary = {}
	for entry_name: String in DirAccess.get_files_at(dir_path.trim_suffix("/")):
		if entry_name.begins_with("."):
			continue
		var normalized := _normalize_listed_file_name(entry_name)
		var lower := normalized.to_lower()
		for ext in allowed_exts:
			if lower.ends_with(ext):
				if not unique.has(normalized):
					unique[normalized] = true
					results.append(normalized)
				break
	return results

func _collect_files_recursive(base_dir: String, allowed_exts: Array[String]) -> Array[String]:
	var results: Array[String] = []
	_collect_files_recursive_impl(base_dir, "", allowed_exts, results)
	return results

func _collect_files_recursive_impl(base_dir: String, sub_dir: String, allowed_exts: Array[String], results: Array[String]) -> void:
	var dir_path := (base_dir + sub_dir).trim_suffix("/")
	for dir_name: String in DirAccess.get_directories_at(dir_path):
		if dir_name.begins_with("."):
			continue
		_collect_files_recursive_impl(base_dir, sub_dir + dir_name + "/", allowed_exts, results)

	for entry_name: String in DirAccess.get_files_at(dir_path):
		if entry_name.begins_with("."):
			continue
		var normalized := _normalize_listed_file_name(entry_name)
		var lower := normalized.to_lower()
		for ext in allowed_exts:
			if lower.ends_with(ext):
				results.append(sub_dir + normalized)
				break
	return

func _load_music_list():
	"""扫描并加载音乐列表"""
	_set_resource_panel_mode("music")
	if music_rows:
		for child in music_rows.get_children():
			child.queue_free()
	_music_preview_buttons_by_path.clear()

	var base_dir: String = "res://assets/audio/music/"
	var allowed_exts: Array[String] = [".ogg", ".mp3", ".wav"]

	var rel_files: Array[String] = _collect_files_recursive(base_dir, allowed_exts)
	if rel_files.is_empty():
		rel_files = _get_index_music_files()
	rel_files.sort()

	var pinned_paths := _get_pinned_music_paths()
	var pinned_set: Dictionary = {}
	var full_to_rel: Dictionary = {}
	for rel_path: String in rel_files:
		full_to_rel[base_dir + rel_path] = rel_path
	for p_any in pinned_paths:
		pinned_set[str(p_any)] = true

	# 先按用户置顶顺序添加
	for p_any in pinned_paths:
		var p := str(p_any)
		if full_to_rel.has(p):
			_add_music_row(str(full_to_rel.get(p)), p, true)

	# 再添加其余
	for rel_path: String in rel_files:
		var full_path: String = base_dir + rel_path
		if pinned_set.has(full_path):
			continue
		_add_music_row(rel_path, full_path, false)

	print("已加载 %d 首音乐" % rel_files.size())
	_refresh_visible_resource_row_styles()

func _add_music_row(display_name: String, full_path: String, is_pinned: bool = false) -> void:
	if music_rows == null:
		return

	_ensure_music_preview_player()

	var panel := _make_interactive_resource_row("music", full_path, Callable(self, "_select_music_path").bind(full_path))

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var pin_button: Button = Button.new()
	pin_button.text = "★" if is_pinned else "☆"
	pin_button.tooltip_text = "取消置顶" if is_pinned else "置顶到顶部"
	pin_button.custom_minimum_size = Vector2(26, 0)
	pin_button.focus_mode = Control.FOCUS_NONE
	pin_button.pressed.connect(Callable(self, "_on_music_pin_pressed").bind(full_path))
	if is_pinned:
		pin_button.modulate = Color(1.0, 0.9, 0.25)

	var name_label: Label = Label.new()
	name_label.text = display_name.get_file()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var preview_button: Button = Button.new()
	preview_button.text = "▶"
	preview_button.tooltip_text = "播放/暂停"
	preview_button.custom_minimum_size = Vector2(36, 0)
	preview_button.focus_mode = Control.FOCUS_NONE
	preview_button.pressed.connect(Callable(self, "_toggle_music_preview").bind(full_path))

	row.add_child(pin_button)
	row.add_child(name_label)
	row.add_child(preview_button)
	panel.add_child(row)
	music_rows.add_child(panel)

	_music_preview_buttons_by_path[full_path] = preview_button
	_update_music_preview_buttons()

func _select_music_path(full_path: String) -> void:
	if current_editing_field == null or current_editing_param != "music_path":
		return

	current_editing_field.text = full_path
	current_editing_field.text_changed.emit(full_path)
	_set_resource_selected_key("music", full_path)

func _ensure_music_preview_player() -> void:
	if _music_preview_player != null:
		return

	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = "MusicPreviewPlayer"
	add_child(player)
	player.finished.connect(_on_music_preview_finished)
	_music_preview_player = player

func _on_music_preview_finished() -> void:
	_music_preview_current_path = ""
	if _music_preview_player:
		_music_preview_player.stream_paused = false
	_update_music_preview_buttons()

func _stop_music_preview() -> void:
	if _music_preview_player == null:
		_music_preview_current_path = ""
		return

	_music_preview_player.stop()
	_music_preview_player.stream_paused = false
	_music_preview_current_path = ""
	_update_music_preview_buttons()

func _toggle_music_preview(full_path: String) -> void:
	_ensure_music_preview_player()
	if _music_preview_player == null:
		return
	_select_music_path(full_path)

	if _music_preview_current_path != full_path:
		_music_preview_player.stop()
		_music_preview_player.stream_paused = false
		var stream: AudioStream = load(full_path) as AudioStream
		if stream == null and not full_path.ends_with(".remap"):
			stream = load(full_path + ".remap") as AudioStream
		if stream == null:
			push_warning("无法加载音乐资源: " + full_path)
			return
		_music_preview_player.stream = stream
		_music_preview_player.play()
		_music_preview_current_path = full_path
	else:
		if _music_preview_player.playing:
			_music_preview_player.stream_paused = not _music_preview_player.stream_paused
		else:
			_music_preview_player.stream_paused = false
			_music_preview_player.play()

	_update_music_preview_buttons()

func _update_music_preview_buttons() -> void:
	for key in _music_preview_buttons_by_path.keys():
		var path: String = str(key)
		var raw_button: Variant = _music_preview_buttons_by_path.get(path)
		if raw_button == null or not is_instance_valid(raw_button):
			_music_preview_buttons_by_path.erase(path)
			continue
		var button := raw_button as Button
		if button == null:
			_music_preview_buttons_by_path.erase(path)
			continue

		var is_current: bool = path == _music_preview_current_path
		var is_playing: bool = false
		var is_paused: bool = false
		if _music_preview_player != null and is_current:
			is_playing = _music_preview_player.playing
			is_paused = _music_preview_player.stream_paused

		button.text = "⏸" if (is_current and is_playing and not is_paused) else "▶"

func _get_character_base_dir(character_name: String) -> String:
	if _character_base_dir_cache.has(character_name):
		return _character_base_dir_cache[character_name]

	var base_dir := "res://assets/images/role/"
	if "_" in character_name:
		for part in character_name.split("_"):
			base_dir += part + "/"
	else:
		base_dir += character_name + "/"

	if DirAccess.open(base_dir) == null:
		return ""

	_character_base_dir_cache[character_name] = base_dir
	return base_dir

func _get_texture_thumbnail(texture: Texture2D) -> Texture2D:
	return _get_texture_thumbnail_fit(texture, CHARACTER_ICON_SIZE)

func _get_texture_thumbnail_fit(texture: Texture2D, target_size: Vector2i) -> Texture2D:
	if not texture:
		return null
	var source_image: Image = texture.get_image()
	if source_image == null:
		return texture

	var src_w: int = source_image.get_width()
	var src_h: int = source_image.get_height()
	if src_w <= 0 or src_h <= 0:
		return texture

	var target_w: int = maxi(1, target_size.x)
	var target_h: int = maxi(1, target_size.y)

	var scale_w: float = float(target_w) / float(src_w)
	var scale_h: float = float(target_h) / float(src_h)
	var scale_factor: float = min(scale_w, scale_h)

	var new_w: int = maxi(1, int(round(float(src_w) * scale_factor)))
	var new_h: int = maxi(1, int(round(float(src_h) * scale_factor)))

	var scaled: Image = source_image.duplicate()
	if scaled.get_format() != Image.FORMAT_RGBA8:
		scaled.convert(Image.FORMAT_RGBA8)
	scaled.resize(new_w, new_h, Image.INTERPOLATE_BILINEAR)

	var canvas: Image = Image.create(target_w, target_h, false, Image.FORMAT_RGBA8)
	canvas.fill(Color(0, 0, 0, 0))
	var offset_x: int = int((target_w - new_w) / 2.0)
	var offset_y: int = int((target_h - new_h) / 2.0)
	canvas.blit_rect(scaled, Rect2i(0, 0, new_w, new_h), Vector2i(offset_x, offset_y))
	return ImageTexture.create_from_image(canvas)

func _get_character_thumbnail(character_name: String) -> Texture2D:
	if _character_thumbnail_cache.has(character_name):
		return _character_thumbnail_cache[character_name]

	var base_dir := _get_character_base_dir(character_name)
	if base_dir.is_empty():
		return null

	var base_path := base_dir + "base.png"
	if not ResourceLoader.exists(base_path):
		return null

	var texture := load(base_path) as Texture2D
	var thumbnail := _get_texture_thumbnail_fit(texture, CHARACTER_ICON_SIZE)
	_character_thumbnail_cache[character_name] = thumbnail
	return thumbnail

func _get_expression_thumbnail(character_name: String, expression_name: String) -> Texture2D:
	var key := character_name + "|" + expression_name
	if _expression_thumbnail_cache.has(key):
		return _expression_thumbnail_cache[key]

	var base_dir := _get_character_base_dir(character_name)
	if base_dir.is_empty():
		return null

	var texture_path := base_dir + expression_name + ".png"
	if not ResourceLoader.exists(texture_path):
		return null

	var texture := load(texture_path) as Texture2D
	var thumbnail := _get_texture_thumbnail_fit(texture, CHARACTER_ICON_SIZE)
	_expression_thumbnail_cache[key] = thumbnail
	return thumbnail

func _get_background_thumbnail(full_path: String) -> Texture2D:
	if _background_thumbnail_cache.has(full_path):
		return _background_thumbnail_cache[full_path] as Texture2D

	var texture := load(full_path) as Texture2D
	if texture == null and not full_path.ends_with(".remap"):
		texture = load(full_path + ".remap") as Texture2D
	if texture == null:
		return null
	var thumbnail := _get_texture_thumbnail_fit(texture, BACKGROUND_ICON_SIZE)
	_background_thumbnail_cache[full_path] = thumbnail
	return thumbnail

func _get_character_scene(character_name: String) -> PackedScene:
	if _character_scene_cache.has(character_name):
		return _character_scene_cache[character_name]

	var scene_path := "res://scenes/character/" + character_name + ".tscn"
	if not ResourceLoader.exists(scene_path):
		return null

	var scene := load(scene_path) as PackedScene
	if scene:
		_character_scene_cache[character_name] = scene
	return scene

func _get_character_expressions(character_name: String) -> Array[String]:
	if _character_expressions_cache.has(character_name):
		var cached: Variant = _character_expressions_cache[character_name]
		if typeof(cached) == TYPE_ARRAY:
			return cached as Array[String]
		return []

	var scene := _get_character_scene(character_name)
	if not scene:
		_character_expressions_cache[character_name] = []
		return []

	var instance := scene.instantiate()
	if not instance:
		_character_expressions_cache[character_name] = []
		return []

	var unique: Dictionary = {}
	var expressions: Array[String] = []
	var raw: Variant = instance.get("expression_list")
	if typeof(raw) == TYPE_ARRAY:
		for entry in raw:
			if typeof(entry) == TYPE_STRING:
				var expression_name := (entry as String).strip_edges()
				if not expression_name.is_empty() and not unique.has(expression_name):
					unique[expression_name] = true
					expressions.append(expression_name)

	instance.free()
	_character_expressions_cache[character_name] = expressions
	return expressions

func _load_expressions_list(character_name: String) -> void:
	if character_name.strip_edges().is_empty():
		_set_resource_panel_mode("none")
		return

	_set_resource_panel_mode("expression")
	_expression_list_character_name = character_name.strip_edges()
	_ensure_character_rows_ui()
	if characters_list:
		characters_list.clear()
	if _character_rows == null:
		return
	_clear_children(_character_rows)

	var expressions := _get_character_expressions(character_name)
	expressions.sort()
	var pinned := _get_pinned_expression_names_for_character(_expression_list_character_name)
	var pinned_set: Dictionary = {}
	for entry in pinned:
		pinned_set[str(entry)] = true

	for pinned_expr_any in pinned:
		var pinned_expr := str(pinned_expr_any)
		if expressions.has(pinned_expr):
			_add_expression_row(_character_rows, _expression_list_character_name, pinned_expr, true)

	for expression_name in expressions:
		if pinned_set.has(expression_name):
			continue
		_add_expression_row(_character_rows, _expression_list_character_name, expression_name, false)

	_refresh_visible_resource_row_styles()

func _on_character_selected(index: int):
	"""角色列表项被选中"""
	if not current_editing_field:
		return
	if current_editing_param == "character_name":
		var character_name = characters_list.get_item_text(index)
		current_editing_field.text = character_name
		# 触发text_changed信号以保存数据
		current_editing_field.text_changed.emit(character_name)

	elif current_editing_param == "expression":
		var expression_name = characters_list.get_item_text(index)
		current_editing_field.text = expression_name
		current_editing_field.text_changed.emit(expression_name)

func _on_background_selected(index: int, source_list: ItemList = null):
	"""背景列表项被选中"""
	if current_editing_field and current_editing_param == "background_path":
		var full_path: String = ""
		var list: ItemList = source_list if source_list != null else backgrounds_list
		var metadata: Variant = list.get_item_metadata(index)
		if typeof(metadata) == TYPE_STRING:
			full_path = metadata as String

		if full_path.is_empty():
			var bg_name = list.get_item_text(index)
			# 兼容旧数据：优先尝试 res://assets/images/bg/ 路径
			full_path = "res://assets/images/bg/" + bg_name
			if not ResourceLoader.exists(full_path):
				# 如果不存在，尝试 res://assets/background/ 路径
				full_path = "res://assets/background/" + bg_name

		_select_background_path(full_path)

func _select_background_path(full_path: String) -> void:
	if current_editing_field == null or current_editing_param != "background_path":
		return
	if full_path.is_empty():
		return
	current_editing_field.text = full_path
	current_editing_field.text_changed.emit(full_path)
	_set_resource_selected_key("background", full_path)

func _select_character_name(character_name: String) -> void:
	if current_editing_field == null or current_editing_param != "character_name":
		return
	var selected_character_name := character_name.strip_edges()
	if selected_character_name.is_empty():
		return
	current_editing_field.text = selected_character_name
	current_editing_field.text_changed.emit(selected_character_name)
	_set_resource_selected_key("character", selected_character_name)

func _select_expression_name(expression_name: String) -> void:
	if current_editing_field == null or current_editing_param != "expression":
		return
	var expr := expression_name.strip_edges()
	if expr.is_empty():
		return
	current_editing_field.text = expr
	current_editing_field.text_changed.emit(expr)
	_set_resource_selected_key("expression", _expression_key(_expression_list_character_name, expr))

func _on_music_selected(index: int):
	"""音乐列表项被选中"""
	if current_editing_field and current_editing_param == "music_path":
		var music_name = music_list.get_item_text(index)
		var full_path = "res://assets/audio/music/" + music_name
		current_editing_field.text = full_path
		# 触发text_changed信号以保存数据
		current_editing_field.text_changed.emit(full_path)

# ==================== 参数验证 ====================

func _validate_all_blocks() -> bool:
	"""验证所有脚本块，返回true表示无错误"""
	has_validation_errors = false

	for block in script_blocks:
		if not block.validate():
			has_validation_errors = true
		elif not _validate_block_context(block):
			has_validation_errors = true

	_update_buttons_state()
	_update_all_block_ui()
	return not has_validation_errors

func _validate_block_context(block: ScriptBlock) -> bool:
	# ========== 资源字段校验 ==========
	# 这些字段允许用户手动输入，但必须属于资源列表范围，否则运行/导出会出错。
	if block.block_type in [BlockType.SHOW_CHARACTER_1, BlockType.SHOW_CHARACTER_2, BlockType.SHOW_CHARACTER_3]:
		var character_name: String = str(block.params.get("character_name", "")).strip_edges()
		if character_name.is_empty():
			block.has_error = true
			block.error_message = "角色名称不能为空（请从资源列表选择）"
			return false
		if _get_character_scene(character_name) == null:
			block.has_error = true
			block.error_message = "角色资源不存在: %s（请从资源列表选择）" % character_name
			return false

		# 显示角色支持可选表情：若填写也必须在该角色的表情列表内
		var expression_text: String = str(block.params.get("expression", "")).strip_edges()
		if not expression_text.is_empty():
			var expressions: Array[String] = _get_character_expressions(character_name)
			if not expressions.has(expression_text):
				block.has_error = true
				block.error_message = "表情不存在: %s（角色: %s）" % [expression_text, character_name]
				return false

	elif block.block_type in [BlockType.BACKGROUND, BlockType.SHOW_BACKGROUND]:
		var bg_path: String = str(block.params.get("background_path", "")).strip_edges()
		if bg_path.is_empty():
			block.has_error = true
			block.error_message = "背景路径不能为空（请从资源列表选择）"
			return false
		if _resolve_background_path_for_validation(bg_path).is_empty():
			block.has_error = true
			block.error_message = "背景资源不合法/不存在: %s（请从资源列表选择）" % bg_path
			return false

	elif block.block_type in [BlockType.MUSIC, BlockType.CHANGE_MUSIC]:
		var music_path: String = str(block.params.get("music_path", "")).strip_edges()
		if music_path.is_empty():
			block.has_error = true
			block.error_message = "音乐路径不能为空（请从资源列表选择）"
			return false
		if _resolve_music_path_for_validation(music_path).is_empty():
			block.has_error = true
			block.error_message = "音乐资源不合法/不存在: %s（请从资源列表选择）" % music_path
			return false

	elif block.block_type in [BlockType.HIDE_CHARACTER_1, BlockType.HIDE_CHARACTER_2, BlockType.HIDE_CHARACTER_3]:
		var slot := 1
		match block.block_type:
			BlockType.HIDE_CHARACTER_2:
				slot = 2
			BlockType.HIDE_CHARACTER_3:
				slot = 3
			_:
				slot = 1

		var state := _infer_character_state_for_slot_before(block, slot)
		var slot_is_visible: bool = bool(state.get("visible", false))
		var character_name: String = str(state.get("character_name", ""))
		if not slot_is_visible or character_name.is_empty():
			block.has_error = true
			block.error_message = "必须先显示%s（且未隐藏）才能隐藏" % ("角色%d" % slot)
			return false

	elif block.block_type == BlockType.HIDE_ALL_CHARACTERS:
		var any_visible := false
		for slot in [1, 2, 3]:
			var state := _infer_character_state_for_slot_before(block, slot)
			if bool(state.get("visible", false)):
				any_visible = true
				break
		if not any_visible:
			block.has_error = true
			block.error_message = "至少显示一个角色才能隐藏所有角色"
			return false

	elif block.block_type in [BlockType.HIDE_BACKGROUND, BlockType.HIDE_BACKGROUND_FADE]:
		var state := _infer_background_state_before(block)
		var visible_bg: bool = bool(state.get("visible", false))
		if not visible_bg:
			block.has_error = true
			block.error_message = "必须先显示背景才能隐藏背景"
			return false

	elif block.block_type == BlockType.STOP_MUSIC:
		var state := _infer_music_state_before(block)
		var is_playing: bool = bool(state.get("playing", false))
		if not is_playing:
			block.has_error = true
			block.error_message = "必须先播放/切换音乐才能停止音乐"
			return false

	if block.block_type in [BlockType.EXPRESSION, BlockType.CHANGE_EXPRESSION_1, BlockType.CHANGE_EXPRESSION_2, BlockType.CHANGE_EXPRESSION_3]:
		var slot := 1
		match block.block_type:
			BlockType.CHANGE_EXPRESSION_2:
				slot = 2
			BlockType.CHANGE_EXPRESSION_3:
				slot = 3
			_:
				slot = 1

		var state: Dictionary = _infer_character_state_for_slot(block, slot)
		var slot_is_visible: bool = bool(state.get("visible", false))
		var character_name: String = str(state.get("character_name", ""))
		if not slot_is_visible or character_name.is_empty():
			block.has_error = true
			block.error_message = "必须先显示%s（且未隐藏）才能切换表情" % ("角色%d" % slot)
			return false
		var expression_text: String = str(block.params.get("expression", "")).strip_edges()
		if expression_text.is_empty():
			block.has_error = true
			block.error_message = "表情不能为空"
			return false
		var expressions: Array[String] = _get_character_expressions(character_name)
		if not expressions.has(expression_text):
			block.has_error = true
			block.error_message = "表情不存在: " + expression_text
			return false
	elif block.block_type in [BlockType.CHARACTER_LIGHT_1, BlockType.CHARACTER_LIGHT_2, BlockType.CHARACTER_LIGHT_3,
		BlockType.CHARACTER_DARK_1, BlockType.CHARACTER_DARK_2, BlockType.CHARACTER_DARK_3]:
		var slot := 1
		match block.block_type:
			BlockType.CHARACTER_LIGHT_2, BlockType.CHARACTER_DARK_2:
				slot = 2
			BlockType.CHARACTER_LIGHT_3, BlockType.CHARACTER_DARK_3:
				slot = 3
			_:
				slot = 1

		var state: Dictionary = _infer_character_state_for_slot(block, slot)
		var slot_is_visible: bool = bool(state.get("visible", false))
		var character_name: String = str(state.get("character_name", ""))
		if not slot_is_visible or character_name.is_empty():
			block.has_error = true
			block.error_message = "必须先显示%s（且未隐藏）才能变更明暗" % ("角色%d" % slot)
			return false

		if block.block_type in [BlockType.CHARACTER_LIGHT_1, BlockType.CHARACTER_LIGHT_2, BlockType.CHARACTER_LIGHT_3]:
			var expression_text: String = str(block.params.get("expression", "")).strip_edges()
			if not expression_text.is_empty():
				var expressions: Array[String] = _get_character_expressions(character_name)
				if not expressions.has(expression_text):
					block.has_error = true
					block.error_message = "表情不存在: " + expression_text
					return false
	elif block.block_type in [BlockType.MOVE_CHARACTER_1_LEFT, BlockType.MOVE_CHARACTER_2_LEFT, BlockType.MOVE_CHARACTER_3_LEFT]:
		var slot := 1
		match block.block_type:
			BlockType.MOVE_CHARACTER_2_LEFT:
				slot = 2
			BlockType.MOVE_CHARACTER_3_LEFT:
				slot = 3
			_:
				slot = 1

		var state: Dictionary = _infer_character_state_for_slot(block, slot)
		var slot_is_visible: bool = bool(state.get("visible", false))
		var character_name: String = str(state.get("character_name", ""))
		if not slot_is_visible or character_name.is_empty():
			block.has_error = true
			block.error_message = "必须先显示%s（且未隐藏）才能移动位置" % ("角色%d" % slot)
			return false
	return true

func _infer_character_state_for_slot_before(block: ScriptBlock, slot: int) -> Dictionary:
	var index := script_blocks.find(block) - 1
	return _infer_character_state_for_slot_at_index(index, slot)

func _infer_character_state_for_slot_at_index(start_index: int, slot: int) -> Dictionary:
	if start_index < 0:
		return {"visible": false, "character_name": ""}

	var show_type := BlockType.SHOW_CHARACTER_1
	var hide_type := BlockType.HIDE_CHARACTER_1
	match slot:
		1:
			show_type = BlockType.SHOW_CHARACTER_1
			hide_type = BlockType.HIDE_CHARACTER_1
		2:
			show_type = BlockType.SHOW_CHARACTER_2
			hide_type = BlockType.HIDE_CHARACTER_2
		3:
			show_type = BlockType.SHOW_CHARACTER_3
			hide_type = BlockType.HIDE_CHARACTER_3

	for i in range(start_index, -1, -1):
		var prev: ScriptBlock = script_blocks[i]
		if prev.block_type == BlockType.HIDE_ALL_CHARACTERS:
			return {"visible": false, "character_name": ""}
		if prev.block_type == hide_type:
			return {"visible": false, "character_name": ""}
		if prev.block_type == show_type:
			var found_character_name := str(prev.params.get("character_name", "")).strip_edges()
			return {"visible": not found_character_name.is_empty(), "character_name": found_character_name}

	return {"visible": false, "character_name": ""}

func _infer_background_state_before(block: ScriptBlock) -> Dictionary:
	var index := script_blocks.find(block) - 1
	return _infer_background_state_at_index(index)

func _infer_background_state_at_index(start_index: int) -> Dictionary:
	if start_index < 0:
		return {"visible": false, "background_path": ""}

	for i in range(start_index, -1, -1):
		var prev: ScriptBlock = script_blocks[i]
		if prev.block_type in [BlockType.HIDE_BACKGROUND, BlockType.HIDE_BACKGROUND_FADE]:
			return {"visible": false, "background_path": ""}
		if prev.block_type in [BlockType.BACKGROUND, BlockType.SHOW_BACKGROUND]:
			var bg_path := str(prev.params.get("background_path", "")).strip_edges()
			if bg_path.is_empty():
				return {"visible": false, "background_path": ""}
			# 这里不强制判断资源存在（由对应块自身的资源校验负责）
			return {"visible": true, "background_path": bg_path}

	return {"visible": false, "background_path": ""}

func _infer_music_state_before(block: ScriptBlock) -> Dictionary:
	var index := script_blocks.find(block) - 1
	return _infer_music_state_at_index(index)

func _infer_music_state_at_index(start_index: int) -> Dictionary:
	if start_index < 0:
		return {"playing": false, "music_path": ""}

	for i in range(start_index, -1, -1):
		var prev: ScriptBlock = script_blocks[i]
		if prev.block_type == BlockType.STOP_MUSIC:
			return {"playing": false, "music_path": ""}
		if prev.block_type in [BlockType.MUSIC, BlockType.CHANGE_MUSIC]:
			var music_path := str(prev.params.get("music_path", "")).strip_edges()
			if music_path.is_empty():
				return {"playing": false, "music_path": ""}
			return {"playing": true, "music_path": music_path}

	return {"playing": false, "music_path": ""}

func _resource_exists_with_remap(path: String) -> bool:
	if path.is_empty():
		return false
	if ResourceLoader.exists(path):
		return true
	if path.ends_with(".remap"):
		return ResourceLoader.exists(path.trim_suffix(".remap"))
	return ResourceLoader.exists(path + ".remap")

func _get_background_base_dirs_for_validation() -> Array[String]:
	var dirs: Array[String] = []

	var bg_dir_new := "res://assets/images/bg"
	var bg_dir_old := "res://assets/background"
	if _dir_has_any_entry(bg_dir_new):
		dirs.append(bg_dir_new + "/")
	if _dir_has_any_entry(bg_dir_old):
		dirs.append(bg_dir_old + "/")

	if dirs.is_empty():
		var index := _get_resource_index()
		var bg: Variant = index.get("backgrounds", {})
		if typeof(bg) == TYPE_DICTIONARY:
			var base_dir := str((bg as Dictionary).get("base_dir", "")).strip_edges()
			if not base_dir.is_empty():
				dirs.append(base_dir.trim_suffix("/") + "/")

	return dirs

func _resolve_background_path_for_validation(input_path: String) -> String:
	var raw := input_path.strip_edges()
	if raw.is_empty():
		return ""

	var base_dirs := _get_background_base_dirs_for_validation()
	if raw.begins_with("res://"):
		# 只允许背景资源目录内的路径
		for base_dir in base_dirs:
			if raw.begins_with(base_dir) and _resource_exists_with_remap(raw):
				return raw
		return ""

	# 支持用户输入文件名或相对路径（与资源列表显示一致）
	for base_dir in base_dirs:
		var candidate := base_dir + raw
		if _resource_exists_with_remap(candidate):
			return candidate
	return ""

func _resolve_music_path_for_validation(input_path: String) -> String:
	var raw := input_path.strip_edges()
	if raw.is_empty():
		return ""

	var base_dir := "res://assets/audio/music/"
	if raw.begins_with("res://"):
		if not raw.begins_with(base_dir):
			return ""
		return raw if _resource_exists_with_remap(raw) else ""

	# 支持用户输入文件名或相对路径（与资源列表显示一致）
	var candidate := base_dir + raw
	return candidate if _resource_exists_with_remap(candidate) else ""

func _update_buttons_state():
	"""根据验证状态更新按钮"""
	if has_validation_errors:
		run_button.disabled = true
		run_button.modulate = Color(0.5, 0.5, 0.5)  # 灰色
		export_button.disabled = true
		export_button.modulate = Color(0.5, 0.5, 0.5)  # 灰色
	else:
		run_button.disabled = false
		run_button.modulate = Color.WHITE
		export_button.disabled = false
		export_button.modulate = Color.WHITE

func _update_all_block_ui():
	"""更新所有脚本块的UI显示（根据验证状态）"""
	for block in script_blocks:
		if block.ui_node:
			var block_button = _get_block_button(block)
			if block_button:
				if block.has_error:
					# 有错误：显示红色边框或背景
					block_button.modulate = Color(1.0, 0.5, 0.5)  # 红色调
					# 更新文本，添加错误标记
					var index = script_blocks.find(block) + 1
					block_button.text = "[%d] %s\n%s\n⚠ %s" % [index, _get_block_type_name(block.block_type), block.get_summary(), block.error_message]
				else:
					# 无错误：恢复正常颜色
					block_button.modulate = _get_block_color(block.block_type)
					# 更新文本，移除错误标记
					var index = script_blocks.find(block) + 1
					block_button.text = "[%d] %s\n%s" % [index, _get_block_type_name(block.block_type), block.get_summary()]

func load_project(path: String):
	"""加载工程"""
	_set_project_context_from_episode_dir(path)
	project_path = path
	var config_file = FileAccess.open(path + "/project.json", FileAccess.READ)
	if config_file:
		var json = JSON.new()
		var parse_result = json.parse(config_file.get_as_text())
		if parse_result == OK:
			project_config = json.data
			project_name_label.text = project_config.get("project_name", "未命名工程")

			# 加载脚本块
			if project_config.has("scripts"):
				for script_data in project_config["scripts"]:
					_add_script_block_from_data(script_data)
		config_file.close()
	_validate_all_blocks()

func _set_project_context_from_episode_dir(episode_dir: String) -> void:
	var normalized := episode_dir.replace("\\", "/").trim_suffix("/")
	var marker := "/episodes/"
	var idx := normalized.find(marker)
	_project_root = normalized.substr(0, idx) if idx != -1 else normalized
	_editor_pins_path = "" if _project_root.is_empty() else (_project_root + "/" + EDITOR_PINS_FILENAME)
	_editor_pins_loaded = false
	_editor_pins = {}

func _load_json_dict_from_path(path: String) -> Dictionary:
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var json := JSON.new()
	var err := json.parse(f.get_as_text())
	f.close()
	if err != OK:
		return {}
	if typeof(json.data) == TYPE_DICTIONARY:
		return json.data as Dictionary
	return {}

func _save_json_dict_to_path(path: String, data: Dictionary) -> void:
	if path.is_empty():
		return
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()

func _get_editor_pins() -> Dictionary:
	if _editor_pins_loaded:
		return _editor_pins
	_editor_pins_loaded = true

	var pins := _load_json_dict_from_path(_editor_pins_path)
	if pins.is_empty():
		pins = {"version": 1, "pinned_music": [], "starred_backgrounds": [], "pinned_characters": [], "pinned_expressions": {}}
	if not pins.has("version"):
		pins["version"] = 1
	if not pins.has("pinned_music") or typeof(pins.get("pinned_music")) != TYPE_ARRAY:
		pins["pinned_music"] = []
	if not pins.has("starred_backgrounds") or typeof(pins.get("starred_backgrounds")) != TYPE_ARRAY:
		pins["starred_backgrounds"] = []
	if not pins.has("pinned_characters") or typeof(pins.get("pinned_characters")) != TYPE_ARRAY:
		pins["pinned_characters"] = []
	if not pins.has("pinned_expressions") or typeof(pins.get("pinned_expressions")) != TYPE_DICTIONARY:
		pins["pinned_expressions"] = {}

	_editor_pins = pins
	return _editor_pins

func _save_editor_pins() -> void:
	if _editor_pins_path.is_empty():
		return
	_save_json_dict_to_path(_editor_pins_path, _editor_pins)

func _get_pinned_music_paths() -> Array[String]:
	var pins := _get_editor_pins()
	var raw: Variant = pins.get("pinned_music", [])
	if typeof(raw) != TYPE_ARRAY:
		var empty: Array[String] = []
		return empty
	var unique: Dictionary = {}
	var result: Array[String] = []
	for entry in (raw as Array):
		var s := str(entry).strip_edges()
		if s.is_empty() or unique.has(s):
			continue
		unique[s] = true
		result.append(s)
	return result

func _toggle_music_pinned(full_path: String) -> void:
	if full_path.is_empty() or _editor_pins_path.is_empty():
		return
	var pins := _get_editor_pins()
	var pinned := _get_pinned_music_paths()
	var idx := pinned.find(full_path)
	if idx == -1:
		pinned.append(full_path)
	else:
		pinned.remove_at(idx)
	pins["pinned_music"] = pinned
	_editor_pins = pins
	_save_editor_pins()
	if _resource_mode == "music":
		_load_music_list()

func _on_music_pin_pressed(full_path: String) -> void:
	_toggle_music_pinned(full_path)

func _get_pinned_character_names() -> Array[String]:
	var pins := _get_editor_pins()
	var raw: Variant = pins.get("pinned_characters", [])
	if typeof(raw) != TYPE_ARRAY:
		var empty: Array[String] = []
		return empty
	var unique: Dictionary = {}
	var result: Array[String] = []
	for entry in (raw as Array):
		var s := str(entry).strip_edges()
		if s.is_empty() or unique.has(s):
			continue
		unique[s] = true
		result.append(s)
	return result

func _toggle_character_pinned(character_name: String) -> void:
	var normalized_character_name := character_name.strip_edges()
	if normalized_character_name.is_empty() or _editor_pins_path.is_empty():
		return
	var pins := _get_editor_pins()
	var pinned := _get_pinned_character_names()
	var idx := pinned.find(normalized_character_name)
	if idx == -1:
		pinned.append(normalized_character_name)
	else:
		pinned.remove_at(idx)
	pins["pinned_characters"] = pinned
	_editor_pins = pins
	_save_editor_pins()
	if _resource_mode == "character":
		_load_characters_list()

func _on_character_pin_pressed(character_name: String) -> void:
	_toggle_character_pinned(character_name)

func _get_pinned_expression_names_for_character(character_name: String) -> Array[String]:
	var c := character_name.strip_edges()
	if c.is_empty():
		var empty: Array[String] = []
		return empty
	var pins := _get_editor_pins()
	var all_any: Variant = pins.get("pinned_expressions", {})
	if typeof(all_any) != TYPE_DICTIONARY:
		var empty: Array[String] = []
		return empty

	var list_any: Variant = (all_any as Dictionary).get(c, [])
	if typeof(list_any) != TYPE_ARRAY:
		var empty: Array[String] = []
		return empty

	var unique: Dictionary = {}
	var result: Array[String] = []
	for entry in (list_any as Array):
		var s := str(entry).strip_edges()
		if s.is_empty() or unique.has(s):
			continue
		unique[s] = true
		result.append(s)
	return result

func _toggle_expression_pinned(character_name: String, expression_name: String) -> void:
	var c := character_name.strip_edges()
	var e := expression_name.strip_edges()
	if c.is_empty() or e.is_empty() or _editor_pins_path.is_empty():
		return
	var pins := _get_editor_pins()
	var all_any: Variant = pins.get("pinned_expressions", {})
	var all: Dictionary = all_any as Dictionary if typeof(all_any) == TYPE_DICTIONARY else {}

	var pinned := _get_pinned_expression_names_for_character(c)
	var idx := pinned.find(e)
	if idx == -1:
		pinned.append(e)
	else:
		pinned.remove_at(idx)

	all[c] = pinned
	pins["pinned_expressions"] = all
	_editor_pins = pins
	_save_editor_pins()

	if _resource_mode == "expression" and _expression_list_character_name == c:
		_load_expressions_list(c)

func _on_expression_pin_pressed(character_name: String, expression_name: String) -> void:
	_toggle_expression_pinned(character_name, expression_name)

func _get_starred_background_paths() -> Array[String]:
	var pins := _get_editor_pins()
	var raw: Variant = pins.get("starred_backgrounds", [])
	if typeof(raw) != TYPE_ARRAY:
		var empty: Array[String] = []
		return empty
	var unique: Dictionary = {}
	var result: Array[String] = []
	for entry in (raw as Array):
		var s := str(entry).strip_edges()
		if s.is_empty() or unique.has(s):
			continue
		unique[s] = true
		result.append(s)
	return result

func _is_background_starred(full_path: String) -> bool:
	return _get_starred_background_paths().has(full_path)

func _toggle_background_star(full_path: String) -> void:
	if full_path.is_empty() or _editor_pins_path.is_empty():
		return
	var pins := _get_editor_pins()
	var starred := _get_starred_background_paths()
	var idx := starred.find(full_path)
	if idx == -1:
		starred.append(full_path)
	else:
		starred.remove_at(idx)
	pins["starred_backgrounds"] = starred
	_editor_pins = pins
	_save_editor_pins()
	_refresh_background_star_state_ui()

func _on_background_star_pressed(full_path: String) -> void:
	_toggle_background_star(full_path)

func _refresh_background_star_state_ui() -> void:
	# 背景星标会影响所有分类tab中的星标显示（但我们不维护每个按钮引用），
	# 所以在星标变更后把所有tab标记为“需重建”，并重建当前tab。
	if _resource_mode != "background" or background_tabs == null:
		return
	if _background_tab_loaded.is_empty():
		return

	for i in range(_background_tab_loaded.size()):
		_background_tab_loaded[i] = false

	var current_idx := background_tabs.current_tab
	if current_idx >= 0 and current_idx < background_tabs.get_child_count():
		_on_background_tab_changed(current_idx)

func _create_block_palette():
	"""创建分类的脚本块工具箱"""
	# 让 Tab 与脚本块之间留出更舒适的间距，并加大行距避免过于紧凑
	for container in [dialog_blocks_container, character_blocks_container, scene_blocks_container, music_blocks_container, control_blocks_container]:
		if container == null:
			continue
		for child in container.get_children():
			child.queue_free()
		container.add_theme_constant_override("separation", 10)
		var top_spacer := Control.new()
		top_spacer.custom_minimum_size = Vector2(0, 10)
		container.add_child(top_spacer)

	var block_templates = {
		"对话": [[
			{"type": BlockType.TEXT_ONLY, "name": "纯文本", "color": Color(0.4, 0.7, 1.0)},
			{"type": BlockType.DIALOG, "name": "对话", "color": Color(0.3, 0.6, 1.0)},
		]],
		"角色": [
			[
				{"type": BlockType.SHOW_CHARACTER_1, "name": "显示角色1", "color": Color(1.0, 0.6, 0.3)},
				{"type": BlockType.HIDE_CHARACTER_1, "name": "隐藏角色1", "color": Color(0.8, 0.4, 0.2)},
				{"type": BlockType.MOVE_CHARACTER_1_LEFT, "name": "角色1左移", "color": Color(0.95, 0.55, 0.25)},
				{"type": BlockType.CHARACTER_LIGHT_1, "name": "角色1变亮", "color": Color(0.75, 0.9, 1.0)},
				{"type": BlockType.CHARACTER_DARK_1, "name": "角色1变暗", "color": Color(0.55, 0.7, 0.85)},
				{"type": BlockType.CHANGE_EXPRESSION_1, "name": "角色1表情切换", "color": Color(0.8, 0.8, 0.3)},
			],
			[
				{"type": BlockType.SHOW_CHARACTER_2, "name": "显示角色2", "color": Color(1.0, 0.7, 0.4)},
				{"type": BlockType.HIDE_CHARACTER_2, "name": "隐藏角色2", "color": Color(0.8, 0.5, 0.3)},
				{"type": BlockType.MOVE_CHARACTER_2_LEFT, "name": "角色2左移", "color": Color(0.95, 0.65, 0.35)},
				{"type": BlockType.CHARACTER_LIGHT_2, "name": "角色2变亮", "color": Color(0.75, 0.9, 1.0)},
				{"type": BlockType.CHARACTER_DARK_2, "name": "角色2变暗", "color": Color(0.55, 0.7, 0.85)},
				{"type": BlockType.CHANGE_EXPRESSION_2, "name": "角色2表情切换", "color": Color(0.8, 0.8, 0.3)},
			],
			[
				{"type": BlockType.SHOW_CHARACTER_3, "name": "显示角色3", "color": Color(1.0, 0.8, 0.5)},
				{"type": BlockType.HIDE_CHARACTER_3, "name": "隐藏角色3", "color": Color(0.8, 0.6, 0.4)},
				{"type": BlockType.MOVE_CHARACTER_3_LEFT, "name": "角色3左移", "color": Color(0.95, 0.75, 0.45)},
				{"type": BlockType.CHARACTER_LIGHT_3, "name": "角色3变亮", "color": Color(0.75, 0.9, 1.0)},
				{"type": BlockType.CHARACTER_DARK_3, "name": "角色3变暗", "color": Color(0.55, 0.7, 0.85)},
				{"type": BlockType.CHANGE_EXPRESSION_3, "name": "角色3表情切换", "color": Color(0.8, 0.8, 0.3)},
			],
			[
				{"type": BlockType.HIDE_ALL_CHARACTERS, "name": "隐藏所有", "color": Color(0.5, 0.5, 0.5)},
			],
		],
		"场景": [[
			{"type": BlockType.BACKGROUND, "name": "切换背景(渐变)", "color": Color(0.6, 1.0, 0.3)},
			{"type": BlockType.SHOW_BACKGROUND, "name": "显示背景", "color": Color(0.5, 0.95, 0.35)},
			{"type": BlockType.HIDE_BACKGROUND, "name": "隐藏背景", "color": Color(0.45, 0.8, 0.25)},
			{"type": BlockType.HIDE_BACKGROUND_FADE, "name": "渐隐背景", "color": Color(0.35, 0.7, 0.2)},
		]],
		"音乐": [[
			{"type": BlockType.MUSIC, "name": "播放音乐", "color": Color(1.0, 0.3, 0.6)},
			{"type": BlockType.CHANGE_MUSIC, "name": "切换音乐", "color": Color(1.0, 0.4, 0.7)},
			{"type": BlockType.STOP_MUSIC, "name": "停止音乐", "color": Color(0.9, 0.25, 0.45)},
		]],
	}

	# 为每个分类添加按钮
	for category in block_templates:
		var container: VBoxContainer = null
		match category:
			"对话": container = dialog_blocks_container
			"角色": container = character_blocks_container
			"场景": container = scene_blocks_container
			"音乐": container = music_blocks_container

		if container:
			for row in block_templates[category]:
				# 每行左右加“占位”控件，避免按钮贴边/视觉上超出框体
				var outer := HBoxContainer.new()
				outer.add_theme_constant_override("separation", 0)
				outer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				container.add_child(outer)

				var left_pad := Control.new()
				left_pad.custom_minimum_size = Vector2(PALETTE_ROW_SIDE_PADDING_X, 0)
				outer.add_child(left_pad)

				var hbox := HBoxContainer.new()
				hbox.add_theme_constant_override("separation", 10)
				hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				outer.add_child(hbox)

				var right_pad := Control.new()
				right_pad.custom_minimum_size = Vector2(PALETTE_ROW_SIDE_PADDING_X, 0)
				outer.add_child(right_pad)

				for template in row:
					var block_button = Button.new()
					block_button.text = template["name"]
					# 单行排布：每个按钮宽度独立随字数变化（不均分、不拉伸占满整行）
					block_button.custom_minimum_size = Vector2(_get_palette_button_width(str(block_button.text)), 32)
					block_button.size_flags_horizontal = 0
					block_button.clip_text = true
					block_button.add_theme_font_size_override("font_size", _get_palette_button_font_size(block_button.text))
					block_button.modulate = template["color"]
					block_button.pressed.connect(_on_palette_block_pressed.bind(template["type"]))
					hbox.add_child(block_button)

func _on_palette_block_pressed(block_type: BlockType):
	"""点击工具箱中的脚本块"""
	var block = ScriptBlock.new(block_type)
	script_blocks.append(block)
	_create_simplified_block_ui(block)
	_save_project()
	_validate_all_blocks()

func _create_simplified_block_ui(block: ScriptBlock, auto_select: bool = true):
	"""创建简化的脚本块UI（显示在右侧序列中）"""
	# 创建水平容器
	var hbox = HBoxContainer.new()
	hbox.custom_minimum_size = Vector2(0, 50)

	# 创建线条样式背景
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.15, 1)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.border_color = Color(0.42, 0.39, 1.0, 0.6)
	style.content_margin_left = 2
	style.content_margin_top = 2
	style.content_margin_right = 2
	style.content_margin_bottom = 2
	hbox.add_theme_stylebox_override("panel", style)

	# 拖拽手柄（只从这里开始拖动，避免误触选择）
	var drag_handle = Button.new()
	drag_handle.name = "DragHandle"
	drag_handle.custom_minimum_size = Vector2(20, 50)
	drag_handle.text = "≡"
	drag_handle.focus_mode = Control.FOCUS_NONE
	drag_handle.mouse_default_cursor_shape = Control.CURSOR_MOVE
	drag_handle.tooltip_text = "拖拽调整顺序"
	drag_handle.modulate = Color(0.85, 0.85, 0.85)

	# 脚本块内容按钮（占大部分空间）
	var block_button = Button.new()
	block_button.name = "BlockButton"
	block_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	block_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	block_button.focus_mode = Control.FOCUS_NONE
	block_button.add_theme_font_size_override("font_size", 12)
	# 防止极端长文本导致序列容器被撑宽（尤其是对话块的说话人名字）
	block_button.clip_text = true

	# 设置按钮文本
	var index = script_blocks.find(block) + 1
	block_button.text = "[%d] %s\n%s" % [index, _get_block_type_name(block.block_type), block.get_summary()]

	# 设置颜色
	block_button.modulate = _get_block_color(block.block_type)

	# 点击事件
	block_button.pressed.connect(_on_block_clicked.bind(block))

	# 拖拽排序：手柄负责开始拖动；块按钮/手柄都可作为放置目标
	drag_handle.set_drag_forwarding(
		Callable(self, "_get_drag_data_for_block").bind(drag_handle, block),
		Callable(self, "_can_drop_data_for_block").bind(block, drag_handle),
		Callable(self, "_drop_data_for_block").bind(block, drag_handle)
	)
	block_button.set_drag_forwarding(
		Callable(self, "_get_drag_data_noop").bind(block_button, block),
		Callable(self, "_can_drop_data_for_block").bind(block, block_button),
		Callable(self, "_drop_data_for_block").bind(block, block_button)
	)

	# 删除按钮
	var delete_button = Button.new()
	delete_button.name = "DeleteButton"
	delete_button.custom_minimum_size = Vector2(32, 50)
	delete_button.text = "🗑"
	delete_button.modulate = Color(1.0, 0.3, 0.3)  # 红色
	delete_button.pressed.connect(_on_delete_block.bind(block))

	# 添加到容器
	hbox.add_child(drag_handle)
	hbox.add_child(block_button)
	hbox.add_child(delete_button)

	block.ui_node = hbox
	script_sequence.add_child(hbox)

	# 可选择是否自动选中新添加的块
	if auto_select:
		_on_block_clicked(block)

func _get_block_button(block: ScriptBlock) -> Button:
	if not block or not block.ui_node:
		return null
	var node = block.ui_node.get_node_or_null("BlockButton")
	return node as Button

func _on_block_clicked(block: ScriptBlock):
	"""点击脚本块时"""
	# 如果正在预览，不响应点击
	if is_previewing:
		return

	# 取消之前选中的高亮
	current_editing_field = null
	current_editing_param = ""
	_set_resource_panel_mode("none")

	if selected_block and selected_block.ui_node:
		var prev_button = _get_block_button(selected_block)
		if prev_button:
			prev_button.add_theme_color_override("font_color", Color.WHITE)

	# 选中新的块
	selected_block = block
	if block.ui_node:
		var block_button = _get_block_button(block)
		if block_button:
			block_button.add_theme_color_override("font_color", Color.YELLOW)

	# 在Inspector中显示参数
	_show_inspector_for_block(block)

func _show_inspector_for_block(block: ScriptBlock):
	"""在Inspector中显示脚本块的详细参数"""
	# 清空Inspector
	for child in inspector_content.get_children():
		child.queue_free()

	# 根据类型添加参数控件
	match block.block_type:
		BlockType.TEXT_ONLY:
			_add_text_only_block_inspector(block)
		BlockType.DIALOG:
			_add_dialog_block_inspector(block)
		BlockType.SHOW_CHARACTER_1, BlockType.SHOW_CHARACTER_2, BlockType.SHOW_CHARACTER_3:
			_add_show_character_inspector(block)
		BlockType.MOVE_CHARACTER_1_LEFT:
			_add_character_move_left_inspector(block, 1)
		BlockType.MOVE_CHARACTER_2_LEFT:
			_add_character_move_left_inspector(block, 2)
		BlockType.MOVE_CHARACTER_3_LEFT:
			_add_character_move_left_inspector(block, 3)
		BlockType.EXPRESSION, BlockType.CHANGE_EXPRESSION_1:
			_add_character_expression_inspector(block, 1)
		BlockType.CHANGE_EXPRESSION_2:
			_add_character_expression_inspector(block, 2)
		BlockType.CHANGE_EXPRESSION_3:
			_add_character_expression_inspector(block, 3)
		BlockType.CHARACTER_LIGHT_1:
			_add_character_light_inspector(block, 1)
		BlockType.CHARACTER_LIGHT_2:
			_add_character_light_inspector(block, 2)
		BlockType.CHARACTER_LIGHT_3:
			_add_character_light_inspector(block, 3)
		BlockType.CHARACTER_DARK_1, BlockType.CHARACTER_DARK_2, BlockType.CHARACTER_DARK_3:
			var hint = Label.new()
			hint.text = "此脚本块无需参数"
			inspector_content.add_child(hint)
		BlockType.HIDE_CHARACTER_1, BlockType.HIDE_CHARACTER_2, BlockType.HIDE_CHARACTER_3, BlockType.HIDE_ALL_CHARACTERS:
			var hint = Label.new()
			hint.text = "此脚本块无需参数"
			inspector_content.add_child(hint)
		BlockType.BACKGROUND:
			_add_background_block_inspector(block)
		BlockType.SHOW_BACKGROUND:
			_add_show_background_block_inspector(block)
		BlockType.HIDE_BACKGROUND, BlockType.HIDE_BACKGROUND_FADE:
			var hint = Label.new()
			hint.text = "此脚本块无需参数"
			inspector_content.add_child(hint)
		BlockType.MUSIC, BlockType.CHANGE_MUSIC:
			_add_music_block_inspector(block)
		BlockType.STOP_MUSIC:
			var hint = Label.new()
			hint.text = "此脚本块无需参数"
			inspector_content.add_child(hint)

func _add_text_only_block_inspector(block: ScriptBlock):
	"""添加纯文本块参数到Inspector"""
	# 文本内容
	var text_label = Label.new()
	text_label.text = "文本内容:"
	inspector_content.add_child(text_label)

	var text_input = TextEdit.new()
	text_input.custom_minimum_size = Vector2(0, 100)
	text_input.text = block.params.get("text", "")
	text_input.text_changed.connect(func():
		block.params["text"] = text_input.text
		_update_block_summary(block)
		_save_project()
		_validate_all_blocks()  # 验证所有块
	)
	inspector_content.add_child(text_input)

func _add_dialog_block_inspector(block: ScriptBlock):
	"""添加对话块参数到Inspector"""
	# 说话人
	var speaker_label = Label.new()
	speaker_label.text = "说话人:"
	inspector_content.add_child(speaker_label)

	var speaker_input = LineEdit.new()
	speaker_input.placeholder_text = "角色名称"
	speaker_input.text = block.params.get("speaker", "")
	speaker_input.max_length = ScriptBlock.SPEAKER_MAX_LENGTH
	speaker_input.text_changed.connect(func(text):
		var sanitized := _sanitize_dialog_speaker(str(text))
		if speaker_input.text != sanitized:
			speaker_input.text = sanitized
			return
		block.params["speaker"] = sanitized
		_update_block_summary(block)
		_save_project()
		_validate_all_blocks()  # 验证所有块
	)
	inspector_content.add_child(speaker_input)

	# 对话内容
	var text_label = Label.new()
	text_label.text = "对话内容:"
	inspector_content.add_child(text_label)

	var text_input = TextEdit.new()
	text_input.custom_minimum_size = Vector2(0, 100)
	text_input.text = block.params.get("text", "")
	text_input.text_changed.connect(func():
		block.params["text"] = text_input.text
		_update_block_summary(block)
		_save_project()
		_validate_all_blocks()  # 验证所有块
	)
	inspector_content.add_child(text_input)

func _add_show_character_inspector(block: ScriptBlock):
	"""添加显示角色块参数到Inspector"""
	# 角色名
	var name_label = Label.new()
	name_label.text = "角色名称:"
	inspector_content.add_child(name_label)

	var name_input = LineEdit.new()
	name_input.text = block.params.get("character_name", "")
	name_input.text_changed.connect(func(text):
		block.params["character_name"] = text
		_update_block_summary(block)
		_save_project()
		_validate_all_blocks()  # 验证所有块
	)
	# 当输入框获得焦点时，加载角色列表
	name_input.focus_entered.connect(func():
		current_editing_field = name_input
		current_editing_param = "character_name"
		_set_resource_selected_key("character", name_input.text)
		_load_characters_list()
	)
	inspector_content.add_child(name_input)

	# 表情
	var expr_label = Label.new()
	expr_label.text = "表情（可选）:"
	inspector_content.add_child(expr_label)

	var expr_input = LineEdit.new()
	expr_input.placeholder_text = "留空"
	expr_input.text = block.params.get("expression", "")
	expr_input.text_changed.connect(func(text):
		block.params["expression"] = text
		_update_block_summary(block)
		_save_project()
		_validate_all_blocks()
	)
	expr_input.focus_entered.connect(func():
		current_editing_field = expr_input
		current_editing_param = "expression"
		var selected_character := str(block.params.get("character_name", "")).strip_edges()
		_set_resource_selected_key("expression", _expression_key(selected_character, expr_input.text))
		_load_expressions_list(selected_character)
	)
	inspector_content.add_child(expr_input)

	# X位置
	var xpos_label = Label.new()
	xpos_label.text = "X位置 (0-1):"
	inspector_content.add_child(xpos_label)

	var xpos_input = LineEdit.new()
	xpos_input.placeholder_text = "0"
	xpos_input.text = str(block.params.get("x_position", 0.0))
	xpos_input.text_changed.connect(func(text):
		var value = text.to_float()
		block.params["x_position"] = value
		_save_project()
		_validate_all_blocks()  # 验证所有块
	)
	inspector_content.add_child(xpos_input)

func _infer_character_name_for_slot(block: ScriptBlock, slot: int) -> String:
	var index := script_blocks.find(block)
	if index == -1:
		return ""

	var show_type := BlockType.SHOW_CHARACTER_1
	match slot:
		1: show_type = BlockType.SHOW_CHARACTER_1
		2: show_type = BlockType.SHOW_CHARACTER_2
		3: show_type = BlockType.SHOW_CHARACTER_3

	for i in range(index, -1, -1):
		var prev: ScriptBlock = script_blocks[i]
		if prev.block_type != show_type:
			continue
		var found_character_name := str(prev.params.get("character_name", "")).strip_edges()
		if not found_character_name.is_empty():
			return found_character_name

	return ""

func _infer_character_state_for_slot(block: ScriptBlock, slot: int) -> Dictionary:
	var index := script_blocks.find(block)
	if index == -1:
		return {"visible": false, "character_name": ""}

	var show_type := BlockType.SHOW_CHARACTER_1
	var hide_type := BlockType.HIDE_CHARACTER_1
	match slot:
		1:
			show_type = BlockType.SHOW_CHARACTER_1
			hide_type = BlockType.HIDE_CHARACTER_1
		2:
			show_type = BlockType.SHOW_CHARACTER_2
			hide_type = BlockType.HIDE_CHARACTER_2
		3:
			show_type = BlockType.SHOW_CHARACTER_3
			hide_type = BlockType.HIDE_CHARACTER_3

	for i in range(index, -1, -1):
		var prev: ScriptBlock = script_blocks[i]
		if prev.block_type == BlockType.HIDE_ALL_CHARACTERS:
			return {"visible": false, "character_name": ""}
		if prev.block_type == hide_type:
			return {"visible": false, "character_name": ""}
		if prev.block_type == show_type:
			var found_character_name := str(prev.params.get("character_name", "")).strip_edges()
			return {"visible": not found_character_name.is_empty(), "character_name": found_character_name}

	return {"visible": false, "character_name": ""}

func _add_character_expression_inspector(block: ScriptBlock, slot: int) -> void:
	var slot_name := "角色%d" % slot
	var state: Dictionary = _infer_character_state_for_slot(block, slot)
	var slot_is_visible: bool = bool(state.get("visible", false))
	var character_name: String = str(state.get("character_name", ""))

	var info_label: Label = Label.new()
	if slot_is_visible:
		info_label.text = "%s（推断）: %s" % [slot_name, character_name]
	else:
		info_label.text = "%s（推断）: 未显示或已隐藏（必须先显示对应角色）" % slot_name
	inspector_content.add_child(info_label)

	var label: Label = Label.new()
	label.text = "表情名称:"
	inspector_content.add_child(label)

	var input: LineEdit = LineEdit.new()
	input.placeholder_text = "从资源列表选择"
	input.text = block.params.get("expression", "")
	input.text_changed.connect(func(text):
		block.params["expression"] = text
		_update_block_summary(block)
		_save_project()
		_validate_all_blocks()
	)
	input.focus_entered.connect(func():
		var refreshed: Dictionary = _infer_character_state_for_slot(block, slot)
		var visible_now: bool = bool(refreshed.get("visible", false))
		var name_now: String = str(refreshed.get("character_name", ""))
		if visible_now:
			info_label.text = "%s（推断）: %s" % [slot_name, name_now]
			current_editing_field = input
			current_editing_param = "expression"
			_set_resource_selected_key("expression", _expression_key(name_now, input.text))
			_load_expressions_list(name_now)
		else:
			info_label.text = "%s（推断）: 未显示或已隐藏（必须先显示对应角色）" % slot_name
			current_editing_field = null
			current_editing_param = ""
			_set_resource_panel_mode("none")
			_validate_all_blocks()
	)
	inspector_content.add_child(input)

func _add_character_light_inspector(block: ScriptBlock, slot: int) -> void:
	var slot_name := "角色%d" % slot
	var state: Dictionary = _infer_character_state_for_slot(block, slot)
	var slot_is_visible: bool = bool(state.get("visible", false))
	var character_name: String = str(state.get("character_name", ""))

	var info_label: Label = Label.new()
	if slot_is_visible:
		info_label.text = "%s（推断）: %s" % [slot_name, character_name]
	else:
		info_label.text = "%s（推断）: 未显示或已隐藏（必须先显示对应角色）" % slot_name
	inspector_content.add_child(info_label)

	var duration_label: Label = Label.new()
	duration_label.text = "时长(秒):"
	inspector_content.add_child(duration_label)

	var duration_input: LineEdit = LineEdit.new()
	duration_input.placeholder_text = "0.35"
	duration_input.text = str(block.params.get("duration", 0.35))
	duration_input.text_changed.connect(func(text):
		block.params["duration"] = text.to_float()
		_save_project()
		_validate_all_blocks()
	)
	inspector_content.add_child(duration_input)

	var expr_label: Label = Label.new()
	expr_label.text = "表情(可选):"
	inspector_content.add_child(expr_label)

	var expr_input: LineEdit = LineEdit.new()
	expr_input.placeholder_text = "留空"
	expr_input.text = str(block.params.get("expression", ""))
	expr_input.text_changed.connect(func(text):
		block.params["expression"] = text
		_update_block_summary(block)
		_save_project()
		_validate_all_blocks()
	)
	expr_input.focus_entered.connect(func():
		var refreshed: Dictionary = _infer_character_state_for_slot(block, slot)
		var visible_now: bool = bool(refreshed.get("visible", false))
		var name_now: String = str(refreshed.get("character_name", ""))
		if visible_now:
			info_label.text = "%s（推断）: %s" % [slot_name, name_now]
			current_editing_field = expr_input
			current_editing_param = "expression"
			_set_resource_selected_key("expression", _expression_key(name_now, expr_input.text))
			_load_expressions_list(name_now)
		else:
			info_label.text = "%s（推断）: 未显示或已隐藏（必须先显示对应角色）" % slot_name
			current_editing_field = null
			current_editing_param = ""
			_set_resource_panel_mode("none")
			_validate_all_blocks()
	)
	inspector_content.add_child(expr_input)

func _add_character_move_left_inspector(block: ScriptBlock, slot: int) -> void:
	var slot_name := "角色%d" % slot

	var info_label := Label.new()
	var inferred := _infer_character_name_for_slot(block, slot)
	info_label.text = "%s（推断）: %s" % [slot_name, inferred if not inferred.is_empty() else "未找到（请先添加对应的“显示角色”块）"]
	inspector_content.add_child(info_label)

	var xalign_label := Label.new()
	xalign_label.text = "目标X位置:"
	inspector_content.add_child(xalign_label)

	var xalign_input := LineEdit.new()
	xalign_input.placeholder_text = "-0.25"
	xalign_input.text = str(block.params.get("to_xalign", -0.25))
	xalign_input.text_changed.connect(func(text):
		block.params["to_xalign"] = text.to_float()
		_update_block_summary(block)
		_save_project()
		_validate_all_blocks()
	)
	inspector_content.add_child(xalign_input)

	var duration_label := Label.new()
	duration_label.text = "时长(秒):"
	inspector_content.add_child(duration_label)

	var duration_input := LineEdit.new()
	duration_input.placeholder_text = "0.3"
	duration_input.text = str(block.params.get("duration", 0.3))
	duration_input.text_changed.connect(func(text):
		block.params["duration"] = text.to_float()
		_save_project()
		_validate_all_blocks()
	)
	inspector_content.add_child(duration_input)

	var brightness_label := Label.new()
	brightness_label.text = "启用明暗变化:"
	inspector_content.add_child(brightness_label)

	var brightness_checkbox := CheckBox.new()
	brightness_checkbox.text = "启用"
	brightness_checkbox.button_pressed = bool(block.params.get("enable_brightness_change", true))
	brightness_checkbox.toggled.connect(func(pressed: bool):
		block.params["enable_brightness_change"] = pressed
		_save_project()
		_validate_all_blocks()
	)
	inspector_content.add_child(brightness_checkbox)

	var expr_label := Label.new()
	expr_label.text = "表情(可选):"
	inspector_content.add_child(expr_label)

	var expr_input := LineEdit.new()
	expr_input.placeholder_text = "留空"
	expr_input.text = block.params.get("expression", "")
	expr_input.text_changed.connect(func(text):
		block.params["expression"] = text
		_update_block_summary(block)
		_save_project()
		_validate_all_blocks()
	)
	expr_input.focus_entered.connect(func():
		current_editing_field = expr_input
		current_editing_param = "expression"
		var inferred_name := _infer_character_name_for_slot(block, slot)
		_set_resource_selected_key("expression", _expression_key(inferred_name, expr_input.text))
		info_label.text = "%s（推断）: %s" % [slot_name, inferred_name if not inferred_name.is_empty() else "未找到（请先添加对应的“显示角色”块）"]
		_load_expressions_list(inferred_name)
	)
	inspector_content.add_child(expr_input)

func _add_background_block_inspector(block: ScriptBlock):
	"""添加背景块参数到Inspector"""
	var label = Label.new()
	label.text = "背景资源路径:"
	inspector_content.add_child(label)

	var input = LineEdit.new()
	input.placeholder_text = "res://assets/..."
	input.text = block.params.get("background_path", "")
	input.text_changed.connect(func(text):
		block.params["background_path"] = text
		_save_project()
		_validate_all_blocks()  # 验证所有块
	)
	# 当输入框获得焦点时，加载背景列表
	input.focus_entered.connect(func():
		current_editing_field = input
		current_editing_param = "background_path"
		_set_resource_selected_key("background", input.text)
		_load_backgrounds_list()
	)
	inspector_content.add_child(input)

func _add_show_background_block_inspector(block: ScriptBlock):
	"""添加显示背景块参数到Inspector（支持渐变）"""
	var label = Label.new()
	label.text = "背景资源路径:"
	inspector_content.add_child(label)

	var input = LineEdit.new()
	input.placeholder_text = "res://assets/..."
	input.text = block.params.get("background_path", "")
	input.text_changed.connect(func(text):
		block.params["background_path"] = text
		_save_project()
		_validate_all_blocks()
	)
	input.focus_entered.connect(func():
		current_editing_field = input
		current_editing_param = "background_path"
		_set_resource_selected_key("background", input.text)
		_load_backgrounds_list()
	)
	inspector_content.add_child(input)

	var fade_label = Label.new()
	fade_label.text = "渐变时间(秒，可选):"
	inspector_content.add_child(fade_label)

	var fade_input = LineEdit.new()
	fade_input.placeholder_text = "0"
	fade_input.text = str(block.params.get("fade_time", 0.0))
	fade_input.text_changed.connect(func(text):
		block.params["fade_time"] = text.to_float()
		_save_project()
		_validate_all_blocks()
	)
	inspector_content.add_child(fade_input)

func _add_music_block_inspector(block: ScriptBlock):
	"""添加音乐块参数到Inspector"""
	var label = Label.new()
	label.text = "音乐资源路径:"
	inspector_content.add_child(label)

	var input = LineEdit.new()
	input.placeholder_text = "res://assets/..."
	input.text = block.params.get("music_path", "")
	input.text_changed.connect(func(text):
		block.params["music_path"] = text
		_save_project()
		_validate_all_blocks()  # 验证所有块
	)
	# 当输入框获得焦点时，加载音乐列表
	input.focus_entered.connect(func():
		current_editing_field = input
		current_editing_param = "music_path"
		_set_resource_selected_key("music", input.text)
		_load_music_list()
	)
	inspector_content.add_child(input)

func _add_expression_block_inspector(block: ScriptBlock):
	"""添加表情块参数到Inspector"""
	var label = Label.new()
	label.text = "表情名称:"
	inspector_content.add_child(label)

	var input = LineEdit.new()
	input.text = block.params.get("expression", "")
	input.text_changed.connect(func(text):
		block.params["expression"] = text
		_update_block_summary(block)
		_save_project()
	)
	inspector_content.add_child(input)

func _update_block_summary(block: ScriptBlock):
	"""更新脚本块的显示摘要"""
	if block.ui_node:
		var index = script_blocks.find(block) + 1
		var block_button = _get_block_button(block)
		if block_button:
			block_button.text = "[%d] %s\n%s" % [index, _get_block_type_name(block.block_type), block.get_summary()]

func _sanitize_dialog_speaker(raw: String) -> String:
	var speaker := raw.strip_edges().replace("\n", " ").replace("\r", " ")
	if speaker.length() > ScriptBlock.SPEAKER_MAX_LENGTH:
		speaker = speaker.substr(0, ScriptBlock.SPEAKER_MAX_LENGTH)
	return speaker

func _get_palette_button_font_size(label: String) -> int:
	var count := label.strip_edges().length()
	if count >= 10:
		return 10
	if count >= 8:
		return 11
	return 12

func _get_palette_button_stretch_ratio(_label: String) -> float:
	# 已弃用：按钮不再使用“拉伸占比”的布局（用户需要每个按钮独立宽度）。
	return 1.0

func _get_palette_button_width(label: String) -> float:
	# 让每个按钮宽度“独立随字数变化”，而不是把整行空间均分/拉伸占满。
	var trimmed := label.strip_edges()
	var font_size := _get_palette_button_font_size(trimmed)
	var count := trimmed.length()
	var padding := 22.0
	var width := float(font_size * count) + padding
	return clampf(width, 64.0, 168.0)

func _get_block_type_name(type: BlockType) -> String:
	"""获取脚本块类型名称"""
	match type:
		BlockType.TEXT_ONLY: return "纯文本"
		BlockType.DIALOG: return "对话"
		BlockType.SHOW_CHARACTER_1: return "显示角色1"
		BlockType.HIDE_CHARACTER_1: return "隐藏角色1"
		BlockType.MOVE_CHARACTER_1_LEFT: return "角色1左移"
		BlockType.EXPRESSION, BlockType.CHANGE_EXPRESSION_1: return "角色1表情切换"
		BlockType.CHARACTER_LIGHT_1: return "角色1变亮"
		BlockType.CHARACTER_DARK_1: return "角色1变暗"
		BlockType.SHOW_CHARACTER_2: return "显示角色2"
		BlockType.HIDE_CHARACTER_2: return "隐藏角色2"
		BlockType.MOVE_CHARACTER_2_LEFT: return "角色2左移"
		BlockType.CHANGE_EXPRESSION_2: return "角色2表情切换"
		BlockType.CHARACTER_LIGHT_2: return "角色2变亮"
		BlockType.CHARACTER_DARK_2: return "角色2变暗"
		BlockType.SHOW_CHARACTER_3: return "显示角色3"
		BlockType.HIDE_CHARACTER_3: return "隐藏角色3"
		BlockType.MOVE_CHARACTER_3_LEFT: return "角色3左移"
		BlockType.CHANGE_EXPRESSION_3: return "角色3表情切换"
		BlockType.CHARACTER_LIGHT_3: return "角色3变亮"
		BlockType.CHARACTER_DARK_3: return "角色3变暗"
		BlockType.HIDE_ALL_CHARACTERS: return "隐藏所有角色"
		BlockType.BACKGROUND: return "切换背景(渐变)"
		BlockType.MUSIC: return "播放音乐"
		BlockType.SHOW_BACKGROUND: return "显示背景"
		BlockType.HIDE_BACKGROUND: return "隐藏背景"
		BlockType.HIDE_BACKGROUND_FADE: return "渐隐背景"
		BlockType.CHANGE_MUSIC: return "切换音乐"
		BlockType.STOP_MUSIC: return "停止音乐"
		_: return "未知"

func _get_block_color(type: BlockType) -> Color:
	"""获取脚本块颜色"""
	match type:
		BlockType.TEXT_ONLY: return Color(0.4, 0.7, 1.0)
		BlockType.DIALOG: return Color(0.3, 0.6, 1.0)
		BlockType.SHOW_CHARACTER_1: return Color(1.0, 0.6, 0.3)
		BlockType.HIDE_CHARACTER_1: return Color(0.8, 0.4, 0.2)
		BlockType.MOVE_CHARACTER_1_LEFT: return Color(0.95, 0.55, 0.25)
		BlockType.EXPRESSION, BlockType.CHANGE_EXPRESSION_1: return Color(0.8, 0.8, 0.3)
		BlockType.CHARACTER_LIGHT_1: return Color(0.75, 0.9, 1.0)
		BlockType.CHARACTER_DARK_1: return Color(0.55, 0.7, 0.85)
		BlockType.SHOW_CHARACTER_2: return Color(1.0, 0.7, 0.4)
		BlockType.HIDE_CHARACTER_2: return Color(0.8, 0.5, 0.3)
		BlockType.MOVE_CHARACTER_2_LEFT: return Color(0.95, 0.65, 0.35)
		BlockType.CHANGE_EXPRESSION_2: return Color(0.8, 0.8, 0.3)
		BlockType.CHARACTER_LIGHT_2: return Color(0.75, 0.9, 1.0)
		BlockType.CHARACTER_DARK_2: return Color(0.55, 0.7, 0.85)
		BlockType.SHOW_CHARACTER_3: return Color(1.0, 0.8, 0.5)
		BlockType.HIDE_CHARACTER_3: return Color(0.8, 0.6, 0.4)
		BlockType.MOVE_CHARACTER_3_LEFT: return Color(0.95, 0.75, 0.45)
		BlockType.CHANGE_EXPRESSION_3: return Color(0.8, 0.8, 0.3)
		BlockType.CHARACTER_LIGHT_3: return Color(0.75, 0.9, 1.0)
		BlockType.CHARACTER_DARK_3: return Color(0.55, 0.7, 0.85)
		BlockType.HIDE_ALL_CHARACTERS: return Color(0.5, 0.5, 0.5)
		BlockType.BACKGROUND: return Color(0.6, 1.0, 0.3)
		BlockType.MUSIC: return Color(1.0, 0.3, 0.6)
		BlockType.SHOW_BACKGROUND: return Color(0.5, 0.95, 0.35)
		BlockType.HIDE_BACKGROUND: return Color(0.45, 0.8, 0.25)
		BlockType.HIDE_BACKGROUND_FADE: return Color(0.35, 0.7, 0.2)
		BlockType.CHANGE_MUSIC: return Color(1.0, 0.4, 0.7)
		BlockType.STOP_MUSIC: return Color(0.9, 0.25, 0.45)
		_: return Color.WHITE

func _on_delete_block(block: ScriptBlock):
	"""删除脚本块"""
	script_blocks.erase(block)
	if block.ui_node:
		block.ui_node.queue_free()

	# 如果删除的是选中的块，清空Inspector
	if selected_block == block:
		selected_block = null
		current_editing_field = null
		current_editing_param = ""
		_set_resource_panel_mode("none")
		for child in inspector_content.get_children():
			child.queue_free()
		var hint = Label.new()
		hint.name = "EmptyHint"
		hint.text = "请在右侧选择一个脚本块"
		hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		inspector_content.add_child(hint)

	_save_project()

	# 更新所有块的序号
	_refresh_all_block_numbers()

func _refresh_all_block_numbers():
	"""刷新所有脚本块的序号显示"""
	for i in range(script_blocks.size()):
		var block = script_blocks[i]
		if block.ui_node:
			var block_button = _get_block_button(block)
			if block_button:
				block_button.text = "[%d] %s\n%s" % [i + 1, _get_block_type_name(block.block_type), block.get_summary()]

# ==================== 拖放功能 ====================

func _get_drag_data_noop(_at_position: Vector2, _source_control: Control, _block: ScriptBlock) -> Variant:
	return null

func _get_drag_data_noop_simple(_at_position: Vector2) -> Variant:
	return null

func _get_drag_data_for_block(_at_position: Vector2, source_control: Control, block: ScriptBlock) -> Variant:
	"""开始拖动脚本块时调用"""
	# 如果正在预览，不允许拖动
	if is_previewing:
		return null

	_hide_drop_placeholder()

	# 创建拖动预览（一个简化的按钮显示）
	var preview = Button.new()
	preview.text = _get_block_type_name(block.block_type)
	preview.modulate = _get_block_color(block.block_type)
	preview.custom_minimum_size = Vector2(200, 40)
	if source_control:
		source_control.set_drag_preview(preview)

	# 返回被拖动的块
	return block

func _can_drop_data_for_block(at_position: Vector2, data: Variant, target_block: ScriptBlock, target_control: Control) -> bool:
	"""检查是否可以在此位置放下"""
	if is_previewing:
		_hide_drop_placeholder()
		return false

	# 只接受ScriptBlock类型的数据
	if not (data is ScriptBlock):
		_hide_drop_placeholder()
		return false

	var dragged_block: ScriptBlock = data
	if dragged_block == target_block:
		_hide_drop_placeholder()
		return false

	var target_index = script_blocks.find(target_block)
	if target_index == -1:
		_hide_drop_placeholder()
		return false

	var insert_index = target_index
	if target_control and at_position.y > target_control.size.y * 0.5:
		insert_index = target_index + 1
	insert_index = clampi(insert_index, 0, script_blocks.size())

	_show_drop_placeholder(insert_index)
	return true

func _drop_data_for_block(at_position: Vector2, data: Variant, target_block: ScriptBlock, target_control: Control) -> void:
	"""在此位置放下脚本块，执行重排序"""
	_hide_drop_placeholder()

	if not data is ScriptBlock:
		return

	var dragged_block: ScriptBlock = data

	# 获取拖动块和目标块的索引
	var dragged_index = script_blocks.find(dragged_block)
	var target_index = script_blocks.find(target_block)

	if dragged_index == -1 or target_index == -1:
		return

	# 如果是同一个块，不做处理
	if dragged_index == target_index:
		return

	var insert_index = target_index
	if target_control and at_position.y > target_control.size.y * 0.5:
		insert_index = target_index + 1
	_reorder_block_to_index(dragged_block, insert_index)

	print("脚本块已重排序: 从索引 %d 移动到 %d" % [dragged_index, insert_index])

func _reorder_block_to_index(dragged_block: ScriptBlock, insert_index: int) -> void:
	var dragged_index := script_blocks.find(dragged_block)
	if dragged_index == -1:
		return

	insert_index = clampi(insert_index, 0, script_blocks.size())

	script_blocks.remove_at(dragged_index)
	if dragged_index < insert_index:
		insert_index -= 1

	insert_index = clampi(insert_index, 0, script_blocks.size())
	script_blocks.insert(insert_index, dragged_block)

	_rebuild_script_sequence_ui()
	_save_project()
	_validate_all_blocks()

func _can_drop_data_for_sequence(at_position: Vector2, data: Variant, target_control: Control) -> bool:
	if is_previewing:
		_hide_drop_placeholder()
		return false

	if not (data is ScriptBlock):
		_hide_drop_placeholder()
		return false

	var dragged_block: ScriptBlock = data
	var insert_index = _compute_insert_index_from_position(target_control, at_position)
	var dragged_index = script_blocks.find(dragged_block)
	if dragged_index == -1:
		_hide_drop_placeholder()
		return false

	# 拖到自身原位置附近时不显示占位
	if insert_index == dragged_index or insert_index == dragged_index + 1:
		_hide_drop_placeholder()
		return false

	_show_drop_placeholder(insert_index)
	return true

func _drop_data_for_sequence(at_position: Vector2, data: Variant, target_control: Control) -> void:
	_hide_drop_placeholder()

	if not (data is ScriptBlock):
		return

	var dragged_block: ScriptBlock = data
	var insert_index = _compute_insert_index_from_position(target_control, at_position)
	_reorder_block_to_index(dragged_block, insert_index)

func _compute_insert_index_from_position(target_control: Control, at_position: Vector2) -> int:
	# 把目标控件坐标换算到 script_sequence 的局部坐标（Control 没有 to_global/to_local）
	var target_rect := target_control.get_global_rect()
	var sequence_rect := script_sequence.get_global_rect()
	var y_local := (target_rect.position.y + at_position.y) - sequence_rect.position.y

	for i in range(script_blocks.size()):
		var ui_node: Control = script_blocks[i].ui_node
		if not is_instance_valid(ui_node):
			continue
		var midpoint := ui_node.position.y + ui_node.size.y * 0.5
		if y_local < midpoint:
			return i
	return script_blocks.size()

func _ensure_drop_placeholder() -> void:
	if is_instance_valid(drop_placeholder):
		return
	drop_placeholder = PanelContainer.new()
	drop_placeholder.name = "DropPlaceholder"
	drop_placeholder.custom_minimum_size = Vector2(0, 50)
	drop_placeholder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drop_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	drop_placeholder.visible = false

	var style := StyleBoxFlat.new()
	style.bg_color = Color(1.0, 0.9, 0.2, 0.12)
	style.border_color = Color(1.0, 0.9, 0.2, 0.9)
	style.border_width_left = 2
	style.border_width_top = 2
	style.border_width_right = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	drop_placeholder.add_theme_stylebox_override("panel", style)

	var label := Label.new()
	label.text = "放到这里"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	drop_placeholder.add_child(label)

func _show_drop_placeholder(insert_index: int) -> void:
	_ensure_drop_placeholder()
	if not is_instance_valid(drop_placeholder):
		return
	if drop_placeholder.get_parent() != script_sequence:
		script_sequence.add_child(drop_placeholder)

	insert_index = clampi(insert_index, 0, script_blocks.size())
	drop_placeholder.visible = true
	script_sequence.move_child(drop_placeholder, insert_index)

func _hide_drop_placeholder() -> void:
	if not is_instance_valid(drop_placeholder):
		return
	drop_placeholder.visible = false
	if drop_placeholder.get_parent() == script_sequence:
		script_sequence.remove_child(drop_placeholder)

func _rebuild_script_sequence_ui():
	"""重建脚本序列的UI显示"""
	# 保存当前选中的块
	var previously_selected = selected_block

	_hide_drop_placeholder()

	# 清空script_sequence中的所有子节点
	for child in script_sequence.get_children():
		child.queue_free()

	# 按新顺序重新创建UI（不自动选中）
	for block in script_blocks:
		_create_simplified_block_ui(block, false)

	# 重新应用验证状态的UI显示（错误标记/颜色等）
	_update_all_block_ui()

	# 恢复之前的选中状态
	if previously_selected:
		_on_block_clicked(previously_selected)

func _add_script_block_from_data(data: Dictionary):
	"""从数据创建脚本块"""
	var block_type = data.get("type", 0)
	var block = ScriptBlock.new(block_type)
	var params: Dictionary = data.get("params", {})
	block.params = params if typeof(params) == TYPE_DICTIONARY else {}
	if block.block_type == BlockType.DIALOG:
		block.params["speaker"] = _sanitize_dialog_speaker(str(block.params.get("speaker", "")))
	script_blocks.append(block)
	_create_simplified_block_ui(block)

func _save_project():
	"""保存工程"""
	if project_path.is_empty():
		return

	# 保存脚本块数据
	var scripts_data = []
	for block in script_blocks:
		scripts_data.append({
			"type": block.block_type,
			"params": block.params
		})

	project_config["scripts"] = scripts_data

	var config_file = FileAccess.open(project_path + "/project.json", FileAccess.WRITE)
	if config_file:
		config_file.store_string(JSON.stringify(project_config, "\t"))
		config_file.close()

func _on_export_button_pressed():
	"""导出工程"""
	push_error("导出功能已迁移到【工程管理器】中，请返回后在项目详情里使用“导出ZIP / 导入到Mods”。")
	return

func _generate_gdscript() -> String:
	"""生成GDScript代码"""
	var code = "extends Node2D\n\n"
	code += "@onready var novel_interface = $NovelInterface\n\n"
	code += "func _ready():\n"
	code += "\tnovel_interface.scene_completed.connect(_on_scene_completed)\n"
	code += "\t_start_story()\n\n"
	code += "func _start_story():\n"

	for i in range(script_blocks.size()):
		var block = script_blocks[i]
		match block.block_type:
			BlockType.TEXT_ONLY:
				var text = block.params.get("text", "")
				code += "\tawait novel_interface.show_text_only(\"%s\")\n" % text.c_escape()

			BlockType.DIALOG:
				var speaker = _sanitize_dialog_speaker(str(block.params.get("speaker", "")))
				var text = block.params.get("text", "")
				code += "\tawait novel_interface.show_dialog(\"%s\", \"%s\")\n" % [text.c_escape(), speaker]

			BlockType.SHOW_CHARACTER_1:
				var char_name = block.params.get("character_name", "")
				var expression = block.params.get("expression", "")
				var x_pos = block.params.get("x_position", 0.0)
				if expression.is_empty():
					code += "\tnovel_interface.show_character(\"%s\", \"\", %.2f)\n" % [char_name, x_pos]
				else:
					code += "\tnovel_interface.show_character(\"%s\", \"%s\", %.2f)\n" % [char_name, expression, x_pos]

			BlockType.HIDE_CHARACTER_1:
				code += "\tawait novel_interface.hide_character()\n"

			BlockType.SHOW_CHARACTER_2:
				var char_name = block.params.get("character_name", "")
				var expression = block.params.get("expression", "")
				var x_pos = block.params.get("x_position", 0.0)
				if expression.is_empty():
					code += "\tnovel_interface.show_2nd_character(\"%s\", \"\", %.2f)\n" % [char_name, x_pos]
				else:
					code += "\tnovel_interface.show_2nd_character(\"%s\", \"%s\", %.2f)\n" % [char_name, expression, x_pos]

			BlockType.HIDE_CHARACTER_2:
				code += "\tawait novel_interface.hide_2nd_character()\n"

			BlockType.SHOW_CHARACTER_3:
				var char_name = block.params.get("character_name", "")
				var expression = block.params.get("expression", "")
				var x_pos = block.params.get("x_position", 0.0)
				if expression.is_empty():
					code += "\tnovel_interface.show_3rd_character(\"%s\", \"\", %.2f)\n" % [char_name, x_pos]
				else:
					code += "\tnovel_interface.show_3rd_character(\"%s\", \"%s\", %.2f)\n" % [char_name, expression, x_pos]

			BlockType.HIDE_CHARACTER_3:
				code += "\tawait novel_interface.hide_3rd_character()\n"

			BlockType.MOVE_CHARACTER_1_LEFT:
				var to_xalign = float(block.params.get("to_xalign", -0.25))
				var duration = float(block.params.get("duration", 0.3))
				var enable_brightness_change = bool(block.params.get("enable_brightness_change", true))
				var expression = str(block.params.get("expression", ""))
				code += "\tawait novel_interface.character_move_left(%.4f, %.4f, %s, \"%s\")\n" % [to_xalign, duration, str(enable_brightness_change).to_lower(), expression.c_escape()]

			BlockType.MOVE_CHARACTER_2_LEFT:
				var to_xalign = float(block.params.get("to_xalign", -0.25))
				var duration = float(block.params.get("duration", 0.3))
				var enable_brightness_change = bool(block.params.get("enable_brightness_change", true))
				var expression = str(block.params.get("expression", ""))
				code += "\tawait novel_interface.character_2nd_move_left(%.4f, %.4f, %s, \"%s\")\n" % [to_xalign, duration, str(enable_brightness_change).to_lower(), expression.c_escape()]

			BlockType.MOVE_CHARACTER_3_LEFT:
				var to_xalign = float(block.params.get("to_xalign", -0.25))
				var duration = float(block.params.get("duration", 0.3))
				var enable_brightness_change = bool(block.params.get("enable_brightness_change", true))
				var expression = str(block.params.get("expression", ""))
				code += "\tawait novel_interface.character_3rd_move_left(%.4f, %.4f, %s, \"%s\")\n" % [to_xalign, duration, str(enable_brightness_change).to_lower(), expression.c_escape()]

			BlockType.HIDE_ALL_CHARACTERS:
				code += "\tawait novel_interface.hide_all_characters()\n"

			BlockType.BACKGROUND:
				var bg_path = block.params.get("background_path", "")
				code += "\tawait novel_interface.change_background(\"%s\")\n" % bg_path

			BlockType.MUSIC:
				var music_path = block.params.get("music_path", "")
				code += "\tnovel_interface.play_music(\"%s\")\n" % music_path

			BlockType.SHOW_BACKGROUND:
				var bg_path = block.params.get("background_path", "")
				var fade_time = block.params.get("fade_time", 0.0)
				code += "\tawait novel_interface.show_background(\"%s\", %.2f)\n" % [bg_path, float(fade_time)]

			BlockType.HIDE_BACKGROUND:
				code += "\tawait novel_interface.hide_background()\n"

			BlockType.HIDE_BACKGROUND_FADE:
				code += "\tawait novel_interface.hide_background_with_fade()\n"

			BlockType.CHANGE_MUSIC:
				var music_path = block.params.get("music_path", "")
				code += "\tawait novel_interface.change_music(\"%s\")\n" % music_path

			BlockType.STOP_MUSIC:
				code += "\tnovel_interface.stop_music()\n"
				code += "\tawait get_tree().process_frame\n"

			BlockType.EXPRESSION, BlockType.CHANGE_EXPRESSION_1:
				var expression = str(block.params.get("expression", ""))
				if not expression.is_empty():
					code += "\tnovel_interface.change_expression(\"%s\")\n" % expression.c_escape()
				code += "\tawait get_tree().process_frame\n"

			BlockType.CHANGE_EXPRESSION_2:
				var expression = str(block.params.get("expression", ""))
				if not expression.is_empty():
					code += "\tnovel_interface.change_2nd_expression(\"%s\")\n" % expression.c_escape()
				code += "\tawait get_tree().process_frame\n"

			BlockType.CHANGE_EXPRESSION_3:
				var expression = str(block.params.get("expression", ""))
				if not expression.is_empty():
					code += "\tnovel_interface.change_3rd_expression(\"%s\")\n" % expression.c_escape()
				code += "\tawait get_tree().process_frame\n"

			BlockType.CHARACTER_LIGHT_1:
				var duration = float(block.params.get("duration", 0.35))
				var expression = str(block.params.get("expression", ""))
				code += "\tawait novel_interface.character_light(%.4f, \"%s\")\n" % [duration, expression.c_escape()]

			BlockType.CHARACTER_LIGHT_2:
				var duration = float(block.params.get("duration", 0.35))
				var expression = str(block.params.get("expression", ""))
				code += "\tawait novel_interface.character_2nd_light(%.4f, \"%s\")\n" % [duration, expression.c_escape()]

			BlockType.CHARACTER_LIGHT_3:
				var duration = float(block.params.get("duration", 0.35))
				var expression = str(block.params.get("expression", ""))
				code += "\tawait novel_interface.character_3rd_light(%.4f, \"%s\")\n" % [duration, expression.c_escape()]

			BlockType.CHARACTER_DARK_1:
				code += "\tawait novel_interface.character_dark()\n"

			BlockType.CHARACTER_DARK_2:
				code += "\tawait novel_interface.character_2nd_dark()\n"

			BlockType.CHARACTER_DARK_3:
				code += "\tawait novel_interface.character_3rd_dark()\n"

	code += "\nfunc _on_scene_completed():\n"
	code += "\tprint(\"Story completed\")\n"

	return code

func _generate_scene() -> String:
	"""生成场景文件"""
	var scene = "[gd_scene load_steps=3 format=3]\n\n"
	scene += "[ext_resource type=\"Script\" path=\"res://export/story.gd\" id=\"1_script\"]\n"
	scene += "[ext_resource type=\"PackedScene\" uid=\"uid://tfmmwjuxwu4x\" path=\"res://scenes/dialog/NovelInterface.tscn\" id=\"2_novel\"]\n\n"
	scene += "[node name=\"Story\" type=\"Node2D\"]\n"
	scene += "script = ExtResource(\"1_script\")\n\n"
	scene += "[node name=\"NovelInterface\" parent=\".\" instance=ExtResource(\"2_novel\")]\n"

	return scene

func _on_back_button_pressed():
	"""返回按钮"""
	_save_project()
	_stop_music_preview()
	_resume_main_menu_bgm()
	queue_free()

func _on_run_button_pressed():
	"""运行预览按钮"""
	if not _validate_all_blocks():
		push_error("存在脚本块参数错误，无法运行预览")
		return
	if script_blocks.is_empty():
		push_error("没有脚本块可运行")
		return

	if not novel_interface:
		push_error("预览区域未初始化")
		return

	if is_previewing:
		# 如果正在预览，则停止预览
		_stop_preview()
		run_button.text = "▶ 运行"
	else:
		# 开始预览
		run_button.text = "■ 停止"
		_start_preview()

func _start_preview():
	"""开始预览脚本"""
	is_previewing = true

	# 启动预览协程
	_run_preview_script()

func _stop_preview():
	"""停止预览"""
	is_previewing = false

	# 恢复所有脚本块的正常颜色
	for b in script_blocks:
		if b.ui_node:
			var button = _get_block_button(b)
			if button:
				button.modulate = _get_block_color(b.block_type)

	# 恢复选中块的高亮
	if selected_block and selected_block.ui_node:
		var block_button = _get_block_button(selected_block)
		if block_button:
			block_button.add_theme_color_override("font_color", Color.YELLOW)

	# 预览结束后重置，准备下一次运行
	await get_tree().create_timer(0.1).timeout  # 短暂延迟确保清理完成
	_reset_preview_viewport()

func _reset_preview_viewport():
	"""重置预览视口，重新创建NovelInterface实例"""
	# 移除旧的NovelInterface
	if novel_interface:
		novel_interface.queue_free()
		novel_interface = null
		await get_tree().process_frame  # 等待删除完成

	# 重新创建NovelInterface实例
	var novel_interface_scene = load("res://scenes/dialog/NovelInterface.tscn")
	if novel_interface_scene:
		novel_interface = novel_interface_scene.instantiate()
		preview_viewport.add_child(novel_interface)
		await get_tree().process_frame  # 等待节点准备完成
		print("预览区域已重置")

func _run_preview_script():
	"""执行预览脚本"""
	for i in range(script_blocks.size()):
		if not is_previewing:
			break

		var block = script_blocks[i]

		# 高亮当前正在执行的脚本块
		_highlight_running_block(block)

		match block.block_type:
			BlockType.TEXT_ONLY:
				var text = block.params.get("text", "")
				await novel_interface.show_text_only(text)

			BlockType.DIALOG:
				var speaker = _sanitize_dialog_speaker(str(block.params.get("speaker", "")))
				var text = block.params.get("text", "")
				await novel_interface.show_dialog(text, speaker)

			BlockType.SHOW_CHARACTER_1:
				var char_name = block.params.get("character_name", "")
				var expression = block.params.get("expression", "")
				var x_pos = block.params.get("x_position", 0.0)
				if expression.is_empty():
					novel_interface.show_character(char_name, "", x_pos)
				else:
					novel_interface.show_character(char_name, expression, x_pos)

			BlockType.HIDE_CHARACTER_1:
				await novel_interface.hide_character()

			BlockType.SHOW_CHARACTER_2:
				var char_name = block.params.get("character_name", "")
				var expression = block.params.get("expression", "")
				var x_pos = block.params.get("x_position", 0.0)
				if expression.is_empty():
					novel_interface.show_2nd_character(char_name, "", x_pos)
				else:
					novel_interface.show_2nd_character(char_name, expression, x_pos)

			BlockType.HIDE_CHARACTER_2:
				await novel_interface.hide_2nd_character()

			BlockType.SHOW_CHARACTER_3:
				var char_name = block.params.get("character_name", "")
				var expression = block.params.get("expression", "")
				var x_pos = block.params.get("x_position", 0.0)
				if expression.is_empty():
					novel_interface.show_3rd_character(char_name, "", x_pos)
				else:
					novel_interface.show_3rd_character(char_name, expression, x_pos)

			BlockType.HIDE_CHARACTER_3:
				await novel_interface.hide_3rd_character()

			BlockType.MOVE_CHARACTER_1_LEFT:
				var to_xalign = float(block.params.get("to_xalign", -0.25))
				var duration = float(block.params.get("duration", 0.3))
				var enable_brightness_change = bool(block.params.get("enable_brightness_change", true))
				var expression = str(block.params.get("expression", ""))
				await novel_interface.character_move_left(to_xalign, duration, enable_brightness_change, expression)

			BlockType.MOVE_CHARACTER_2_LEFT:
				var to_xalign = float(block.params.get("to_xalign", -0.25))
				var duration = float(block.params.get("duration", 0.3))
				var enable_brightness_change = bool(block.params.get("enable_brightness_change", true))
				var expression = str(block.params.get("expression", ""))
				await novel_interface.character_2nd_move_left(to_xalign, duration, enable_brightness_change, expression)

			BlockType.MOVE_CHARACTER_3_LEFT:
				var to_xalign = float(block.params.get("to_xalign", -0.25))
				var duration = float(block.params.get("duration", 0.3))
				var enable_brightness_change = bool(block.params.get("enable_brightness_change", true))
				var expression = str(block.params.get("expression", ""))
				await novel_interface.character_3rd_move_left(to_xalign, duration, enable_brightness_change, expression)

			BlockType.HIDE_ALL_CHARACTERS:
				await novel_interface.hide_all_characters()

			BlockType.BACKGROUND:
				var bg_path = block.params.get("background_path", "")
				if not bg_path.is_empty():
					await novel_interface.change_background(bg_path)

			BlockType.SHOW_BACKGROUND:
				var bg_path = block.params.get("background_path", "")
				var fade_time = block.params.get("fade_time", 0.0)
				if not bg_path.is_empty():
					await novel_interface.show_background(bg_path, float(fade_time))

			BlockType.HIDE_BACKGROUND:
				await novel_interface.hide_background()

			BlockType.HIDE_BACKGROUND_FADE:
				await novel_interface.hide_background_with_fade()

			BlockType.MUSIC:
				var music_path = block.params.get("music_path", "")
				if not music_path.is_empty():
					novel_interface.play_music(music_path)

			BlockType.CHANGE_MUSIC:
				var music_path = block.params.get("music_path", "")
				if not music_path.is_empty():
					await novel_interface.change_music(music_path)

			BlockType.STOP_MUSIC:
				novel_interface.stop_music()
				await get_tree().process_frame

			BlockType.EXPRESSION, BlockType.CHANGE_EXPRESSION_1:
				var expression = block.params.get("expression", "")
				if not expression.is_empty():
					novel_interface.change_expression(expression)
					await get_tree().process_frame

			BlockType.CHANGE_EXPRESSION_2:
				var expression = block.params.get("expression", "")
				if not expression.is_empty():
					novel_interface.change_2nd_expression(expression)
					await get_tree().process_frame

			BlockType.CHANGE_EXPRESSION_3:
				var expression = block.params.get("expression", "")
				if not expression.is_empty():
					novel_interface.change_3rd_expression(expression)
					await get_tree().process_frame

			BlockType.CHARACTER_LIGHT_1:
				var duration = float(block.params.get("duration", 0.35))
				var expression = str(block.params.get("expression", ""))
				await novel_interface.character_light(duration, expression)

			BlockType.CHARACTER_LIGHT_2:
				var duration = float(block.params.get("duration", 0.35))
				var expression = str(block.params.get("expression", ""))
				await novel_interface.character_2nd_light(duration, expression)

			BlockType.CHARACTER_LIGHT_3:
				var duration = float(block.params.get("duration", 0.35))
				var expression = str(block.params.get("expression", ""))
				await novel_interface.character_3rd_light(duration, expression)

			BlockType.CHARACTER_DARK_1:
				await novel_interface.character_dark()

			BlockType.CHARACTER_DARK_2:
				await novel_interface.character_2nd_dark()

			BlockType.CHARACTER_DARK_3:
				await novel_interface.character_3rd_dark()

	# 预览结束
	_stop_preview()
	run_button.text = "▶ 运行"
	print("预览完成")

func _highlight_running_block(block: ScriptBlock):
	"""高亮正在运行的脚本块"""
	# 先取消所有高亮
	for b in script_blocks:
		if b.ui_node:
			var button = _get_block_button(b)
			if button:
				button.modulate = _get_block_color(b.block_type)

	# 高亮当前块
	if block.ui_node:
		var button = _get_block_button(block)
		if button:
			button.modulate = Color.WHITE
