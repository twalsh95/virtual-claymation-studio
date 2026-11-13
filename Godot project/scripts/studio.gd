extends Node3D

## Fired when the browser's export code answers (see vcs-export.js).
signal js_replied
## Virtual Claymation Studio.
## Builds the set, lights, characters, props, cameras, and UI in code,
## then handles posing, camera moves, onion skinning, undo, saving, and capturing frames.

const ORBIT_SPEED := 0.006
const TWIST_SPEED := 0.01
const CAM_TURN_SPEED := 0.004
const CAM_MOVE_SPEED := 0.004
const CAM_DOLLY_SPEED := 0.006
const CAM_ZOOM_SPEED := 0.08
# Rates Premiere Pro offers for sequences, so every export imports cleanly.
const FRAME_RATES := [10, 12, 15, 24, 30, 60]
const DEFAULT_FPS := 12
const APP_NAME := "Virtual Claymation Studio"
const PROJECT_VERSION := 5
const PROJECT_EXT := "clay"
const AUTOSAVE_PATH := "user://autosave.claymation"
const AUTOSAVE_SECONDS := 5.0
const HIGHLIGHT_COLOR := Color(1.0, 0.75, 0.3)
const ACCENT := Color(0.95, 0.6, 0.2)
const DEFAULT_YAW := 0.35
const DEFAULT_PITCH := -0.25
const DEFAULT_DISTANCE := 4.5
const WORK_FOV := 50.0
const SHOT_ASPECT := 16.0 / 9.0
const PREVIEW_MAX_HEIGHT := 252.0  # shot preview size on roomy screens
const PREVIEW_MIN_HEIGHT := 126.0  # smallest it shrinks to on short screens
const MAX_UNDO := 50
const CAMERA_PICK_RADIUS := 0.22
const LIFT_SPEED := 0.004
const SQUASH_SPEED := 0.008
const MAX_SHOTS := 30
# The shot camera's live picture. Captured frames are kept in memory at FRAME_KEEP_SIZE (what the
# preview, playback, and shot cards show) and re-rendered at the chosen size when exporting.
const SHOT_RENDER_SIZE := Vector2i(1280, 720)
const FRAME_KEEP_SIZE := Vector2i(480, 270)
# Export sizes: [key, menu name, size, tooltip]. 4K is offered for MP4 only (frame zips would be gigabytes).
const EXPORT_SIZES := [
	["small", "Small (480 x 270)", Vector2i(480, 270), "Tiny and instant. Good for checking your work, too small for a final project."],
	["720", "720p HD (1280 x 720)", Vector2i(1280, 720), "Standard HD. A good size for class projects."],
	["1080", "1080p Full HD (1920 x 1080)", Vector2i(1920, 1080), "Sharper, the most common video size. Takes longer and makes bigger files."],
	["4k", "4K (3840 x 2160)", Vector2i(3840, 2160), "Very sharp and very big. MP4 only, and only on computers that can make 4K video."],
]
const DEFAULT_EXPORT_SIZE := "720"

# Lighting: three lamps with fixed roles. LIGHT_INFO: [name, lamp label, tooltip].
const LIGHT_ROLES := ["key", "fill", "back", "bg"]
const LIGHT_INFO := {
	"key": ["Key", "KEY", "The key light: the main light. It sets the mood and makes the strongest shadows."],
	"fill": ["Fill", "FILL", "The fill light: a softer light from the other side that fills in the key light's shadows."],
	"back": ["Back", "BACK", "The back light: shines from behind to outline the subject and separate it from the background."],
	"bg": ["Background", "BACKGROUND", "The background light: lights the backdrop, not the subject. Use it to make the backdrop glow, or with a gel to color it."],
}
const LIGHT_SPREAD := {"key": 40.0, "fill": 55.0, "back": 38.0, "bg": 75.0}   # spot angle in degrees
# The background light always points here (the middle of the backdrop), wherever it's moved.
const BG_LIGHT_AIM := Vector3(0, 1.5, -2.4)
const GELS := {
	"none": ["No gel", Color(1, 1, 1)], "red": ["Red", Color(1.0, 0.25, 0.2)], "orange": ["Orange", Color(1.0, 0.55, 0.2)],
	"yellow": ["Yellow", Color(1.0, 0.9, 0.35)], "green": ["Green", Color(0.35, 1.0, 0.4)],
	"blue": ["Blue", Color(0.3, 0.45, 1.0)], "purple": ["Purple", Color(0.7, 0.35, 1.0)],
}
const TEMP_MIN := 2700
const TEMP_MAX := 7500
const DEFAULT_LIGHT_AIM := Vector3(0, 0.8, 0)
const DEFAULT_LIGHT_PRESET := "three_point"
const LIGHT_ENERGY_SCALE := 0.06    # brightness 100 = this x 100 light energy
const ROOM_ENERGY_SCALE := 0.007    # room light 100 = this x 100 ambient energy
const LAMP_MIN_HEIGHT := 0.15
const LAMP_MAX_HEIGHT := 4.0
const LAMP_PICK_RADIUS := 0.2
# Mood presets. Each lamp: offset from the aim point across the table (x, z), with y as the lamp's height.
# The background lamp ("bg") is different: its offset is its actual spot, since it always points at the backdrop.
const LIGHT_PRESETS := {
	"three_point": {"name": "Three-Point", "tip": "The standard setup: a key light, a softer fill, and a back light. Clear and natural.", "room": 45,
		"key": {"on": true, "brightness": 70, "temp": 4200, "offset": Vector3(2.0, 2.4, 2.2)},
		"fill": {"on": true, "brightness": 30, "temp": 6000, "offset": Vector3(-2.4, 1.5, 2.4)},
		"back": {"on": true, "brightness": 60, "temp": 5600, "offset": Vector3(0.4, 2.6, -1.8)},
		"bg": {"on": true, "brightness": 40, "temp": 5600, "offset": Vector3(0.0, 0.3, -1.25)}},
	"high_key": {"name": "High-Key", "tip": "Bright and even, with few shadows. Feels cheerful: comedies, commercials, sitcoms.", "room": 95,
		"key": {"on": true, "brightness": 55, "temp": 5000, "offset": Vector3(0.5, 2.0, 3.2)},
		"fill": {"on": true, "brightness": 70, "temp": 5600, "offset": Vector3(-1.4, 1.8, 3.0)},
		"back": {"on": true, "brightness": 40, "temp": 5600, "offset": Vector3(0.0, 2.6, -1.8)},
		"bg": {"on": true, "brightness": 40, "temp": 5600, "offset": Vector3(0.0, 0.3, -1.25)}},
	"low_key": {"name": "Low-Key", "tip": "Dark, with deep shadows and one strong light. Feels dramatic or mysterious: film noir, thrillers.", "room": 10,
		"key": {"on": true, "brightness": 80, "temp": 3600, "offset": Vector3(2.6, 2.2, 0.8)},
		"fill": {"on": true, "brightness": 8, "temp": 6000, "offset": Vector3(-2.4, 1.4, 2.4)},
		"back": {"on": true, "brightness": 70, "temp": 5600, "offset": Vector3(-0.6, 2.6, -1.8)},
		"bg": {"on": true, "brightness": 15, "temp": 3600, "offset": Vector3(0.0, 0.3, -1.25)}},
	"side": {"name": "Side Light", "tip": "Light from one side only, so half the face is in shadow. Feels secretive or torn between two sides.", "room": 8,
		"key": {"on": true, "brightness": 85, "temp": 4200, "offset": Vector3(2.8, 1.2, 0.0)},
		"fill": {"on": false, "brightness": 20, "temp": 6000, "offset": Vector3(-2.4, 1.5, 2.4)},
		"back": {"on": true, "brightness": 35, "temp": 5600, "offset": Vector3(-0.4, 2.6, -1.8)},
		"bg": {"on": false, "brightness": 20, "temp": 5600, "offset": Vector3(0.0, 0.3, -1.25)}},
	"under": {"name": "Under Light", "tip": "Light from below the face, which never happens in nature. Feels creepy: horror, campfire stories.", "room": 10,
		"key": {"on": true, "brightness": 80, "temp": 4500, "offset": Vector3(0.4, 0.15, 1.6)},
		"fill": {"on": false, "brightness": 20, "temp": 6000, "offset": Vector3(-2.4, 1.5, 2.4)},
		"back": {"on": false, "brightness": 40, "temp": 5600, "offset": Vector3(0.4, 2.6, -1.8)},
		"bg": {"on": false, "brightness": 30, "temp": 5600, "offset": Vector3(0.0, 0.3, -1.25)}},
	"silhouette": {"name": "Silhouette", "tip": "A bright backdrop and no light on the front of the subject, so it's a dark shape. Feels mysterious; hides who someone is.", "room": 0,
		"key": {"on": false, "brightness": 70, "temp": 4200, "offset": Vector3(2.0, 2.4, 2.2)},
		"fill": {"on": false, "brightness": 30, "temp": 6000, "offset": Vector3(-2.4, 1.5, 2.4)},
		"back": {"on": true, "brightness": 45, "temp": 5600, "offset": Vector3(0.0, 2.0, -1.9)},
		"bg": {"on": true, "brightness": 100, "temp": 5600, "offset": Vector3(0.0, 0.3, -1.25)}},
}
const SHOT_LABEL_MAX := 40

# Backdrops and floors (see the backdrops section). Paper: [name, color]. Scenes: [name, ground color for a matching floor].
const PAPER_COLORS := {
	"white": ["White", Color(0.93, 0.93, 0.9)], "gray": ["Gray", Color(0.55, 0.55, 0.57)],
	"black": ["Black", Color(0.06, 0.06, 0.07)], "sky": ["Sky Blue", Color(0.55, 0.7, 0.82)],
	"yellow": ["Yellow", Color(0.98, 0.82, 0.3)], "red": ["Red", Color(0.8, 0.22, 0.2)],
	"purple": ["Purple", Color(0.45, 0.3, 0.65)], "mint": ["Mint", Color(0.6, 0.85, 0.7)],
}
const BACKDROP_SCENES := {
	"sunny": ["Sunny Day", Color(0.3, 0.58, 0.28)], "sunset": ["Sunset", Color(0.24, 0.16, 0.27)],
	"night": ["Night Sky", Color(0.06, 0.08, 0.16)], "city": ["City", Color(0.42, 0.42, 0.44)],
	"city_night": ["City at Night", Color(0.12, 0.12, 0.15)], "room": ["Room", Color(0.55, 0.37, 0.21)],
	"underwater": ["Underwater", Color(0.72, 0.64, 0.43)],
}
# Floors: [name, tooltip, texture scale (bigger = smaller pattern)].
const FLOORS := {
	"table": ["Wooden table", "The studio's wooden tabletop.", 1.0],
	"paper": ["Paper (matches the backdrop)", "The backdrop's paper continues under the characters, so there's no line where the wall meets the floor.", 1.0],
	"grass": ["Grass", "A grassy field.", 0.8],
	"sand": ["Sand", "A beach or desert.", 0.7],
	"pavement": ["Pavement", "A sidewalk or street.", 0.5],
	"wood": ["Wood floor", "Wooden floorboards, like inside a house.", 0.35],
	"snow": ["Snow", "A snowy ground.", 0.5],
	"green": ["Green screen", "Pure green for keying out in Premiere (Ultra Key), so you can put any ground behind your characters.", 1.0],
}
const CHROMA_GREEN := Color(0.0, 0.69, 0.25)
const TABLE_COLOR := Color(0.45, 0.32, 0.22)
const DEFAULT_BACKDROP := "paper:sky"
const DEFAULT_FLOOR := "table"
const BACKDROP_PICTURE_SIZE := Vector2i(1920, 1080)
const MAX_BACKDROP_PICTURES := 12
const SWEEP_WIDTH := 11.0
const SWEEP_TOP := 3.8
const SWEEP_Z := -2.4
const SWEEP_RADIUS := 0.9
const SWEEP_PICTURE_WIDTH := 7.2   # a picture backdrop covers this much of the sweep's width

# What students can add to the scene.
const CHARACTER_TYPES := {"kid": "Kid", "man": "Man", "woman": "Woman", "dog": "Dog", "cat": "Cat"}
const PROP_TYPES := {
	"ball": "Ball", "box": "Box", "goal": "Goal", "marker": "Floor Marker", "table": "Table",
	"chair": "Chair", "cone": "Cone", "can": "Can", "plank": "Plank", "rock": "Rock",
}
const HAIR_STYLES := {"none": "None", "short": "Short", "long": "Long", "ponytail": "Ponytail", "bun": "Bun", "curly": "Curly"}
# Ready-made clay colors shown first in every color picker, including a range of skin tones.
const CLAY_PALETTE := [
	Color(0.86, 0.2, 0.18), Color(0.95, 0.5, 0.15), Color(0.98, 0.82, 0.2), Color(0.6, 0.8, 0.25),
	Color(0.25, 0.6, 0.32), Color(0.15, 0.6, 0.6), Color(0.45, 0.72, 0.92), Color(0.22, 0.38, 0.75),
	Color(0.52, 0.3, 0.68), Color(0.95, 0.55, 0.7), Color(0.5, 0.32, 0.18), Color(0.82, 0.68, 0.48),
	Color(0.95, 0.95, 0.92), Color(0.55, 0.55, 0.55), Color(0.1, 0.1, 0.11),
	Color(0.98, 0.85, 0.72), Color(0.93, 0.76, 0.58), Color(0.8, 0.6, 0.45), Color(0.62, 0.43, 0.3),
	Color(0.45, 0.3, 0.2), Color(0.3, 0.2, 0.14),
]
# Where new characters and props appear, first free spot wins.
const SPAWN_SPOTS := [
	Vector3(0, 0, 0), Vector3(1.0, 0, 0.4), Vector3(-1.0, 0, 0.4), Vector3(1.8, 0, -0.3),
	Vector3(-1.8, 0, -0.3), Vector3(0.6, 0, 1.1), Vector3(-0.6, 0, 1.1), Vector3(0, 0, -1.2),
]

# Visual layers. Cameras choose which layers they can see.
const LAYER_WORLD := 1          # Set, puppet, lights: seen by every camera.
const LAYER_CAMERA_PROP := 2    # The tripod model and its view lines: only seen in Studio View.
const LAYER_GHOSTS := 4         # Onion skin ghosts: seen while working, never captured.
const ALL_LAYERS := 1048575
const SHOT_PREVIEW_MASK := LAYER_WORLD | LAYER_GHOSTS
const SHOT_CAPTURE_MASK := LAYER_WORLD

const POSE_TOOLS := ["bend", "twist", "move", "lift", "squash"]
const CAMERA_TOOLS := ["tripod", "pan", "truck", "dolly", "zoom"]
const TRIPOD_SPEED := 0.006
const MODE_INFO := {
	"bend": ["BEND", Color(0.3, 0.85, 0.35)],
	"twist": ["TWIST", Color(1.0, 0.85, 0.2)],
	"move": ["MOVE", Color(0.7, 0.45, 1.0)],
	"lift": ["LIFT", Color(0.92, 0.92, 0.95)],
	"squash": ["SQUASH", Color(1.0, 0.5, 0.8)],
	"camera": ["CAMERA", Color(1.0, 0.25, 0.22)],
	"light": ["LIGHT", Color(0.35, 0.6, 1.0)],
}
const TOOL_NAMES := {
	"bend": "Bend", "twist": "Twist", "move": "Move", "lift": "Lift", "squash": "Squash",
	"tripod": "Move Tripod", "pan": "Pan / Tilt", "truck": "Truck / Pedestal", "dolly": "Dolly", "zoom": "Zoom",
}

# Work view: the camera the animator looks through while posing.
var work_camera: Camera3D
var orbit_target := Vector3(0, 0.8, 0)
var orbit_yaw := DEFAULT_YAW
var orbit_pitch := DEFAULT_PITCH
var orbit_distance := DEFAULT_DISTANCE
var camera_view := false        # true = looking through the shot camera

# Shot camera: the "tripod" camera that captures frames.
var shot_viewport: SubViewport
var shot_camera: Camera3D
var camera_locked := true
var camera_default := Transform3D.IDENTITY
var camera_default_fov := 40.0
var shot_size := "wide"
var shot_angle := 0.0
var camera_warned := false

# Backdrops and floors (see the backdrops section).
var sweep: MeshInstance3D
var sweep_mat: StandardMaterial3D
var floor_mesh: MeshInstance3D           # the tabletop
var floor_mat: StandardMaterial3D
var chroma_mat: StandardMaterial3D       # green screen: unshaded, so lights and shadows never change it
var backdrop_textures: Dictionary = {}   # backdrop key -> texture (scenes and pictures, made when first needed)
var floor_textures: Dictionary = {}
var backdrop_pictures: Dictionary = {}   # id -> {name, b64 (JPG)}: students' pictures, saved with the project
var picture_thumbs: Dictionary = {}      # id -> small texture for the panel
var picture_floor_colors: Dictionary = {}
var next_picture := 1
var backdrop_panel: PanelContainer
var backdrop_scroll: ScrollContainer
var backdrop_box: VBoxContainer
var backdrop_title: Label
var backdrop_buttons: Dictionary = {}    # backdrop key -> Button
var picture_grid: GridContainer
var remove_picture_button: Button
var floor_option: OptionButton
var backdrop_ui_updating := false
var js_image_callback: JavaScriptObject
var image_dialog: FileDialog

# Lighting (see the lighting section).
var world_environment: Environment
var light_nodes: Dictionary = {}       # role -> SpotLight3D
var lamp_models: Dictionary = {}       # role -> {head, pole, body_mat, glow_mat, label}
var hovered_light := ""                # role of the lamp under the cursor
var grab_light_role := ""
var lighting_panel: PanelContainer
var lighting_scroll: ScrollContainer
var lighting_box: VBoxContainer
var lighting_title: Label
var light_lock_button: Button
var light_lock_label: Label
var light_preset_button: MenuButton
var light_room_slider: HSlider
var light_role_buttons: Dictionary = {}
var light_role := "key"                # the lamp the panel is showing
var light_on_check: CheckButton
var light_role_info: Label
var light_brightness_slider: HSlider
var light_temp_slider: HSlider
var light_gel_option: OptionButton
var light_height_slider: HSlider
var light_controls: Array[Control] = []   # Greyed out while lighting is locked.
var light_slider_titles: Dictionary = {}  # Label -> its title, for showing slider values.
var lighting_ui_updating := false
var light_slider_dragging := false

# Tripod model and the lines showing what the camera sees.
var camera_prop: Node3D
var camera_pole: MeshInstance3D
var camera_prop_mat: StandardMaterial3D
var view_lines: MeshInstance3D
var view_lines_mesh: ImmediateMesh

# Scene objects: characters and props. Each one (a "figure") is a Dictionary:
#   {id, type, kind ("character" or "prop"), name, root, body (props: the node that squashes),
#    parts, center (props: the point it spins around, in body space), height, torso, head,
#    head_center, squash, rest_squash}
# Each part: {name, joint, materials, shapes, tip, axis, twist, figure, is_prop}.
var scene_root: Node3D
var figures: Array[Dictionary] = []
var parts: Array[Dictionary] = []    # Every part of every figure, for picking.
var rest_pose: Dictionary = {}       # Node3D -> its default transform (figure roots and joints).
var next_number: Dictionary = {}     # type -> next number, for ids like "ball-2".
var selected_figure: Dictionary = {}

# Tools and dragging.
var current_tool := "bend"
var hovered: Dictionary = {}
var hovered_camera := false
var active_part: Dictionary = {}
var highlighted: Dictionary = {}
var dragging := false
var drag_mode := ""             # a tool name, "grab_camera", "orbit", or "none"
var grab_local := Vector3.ZERO
var grab_screen_offset := Vector2.ZERO
var move_offset := Vector3.ZERO
var move_plane_y := 0.0
var grab_figure: Dictionary = {}
var undo_stack: Array[Dictionary] = []
var undo_pending := false

# Shots. A shot is one camera setup and the frames captured through it. Each shot is a Dictionary:
#   {label, poses (one scene snapshot per frame), textures (the frame pictures), undo (its own undo steps),
#    working (the scene as the student left it when they switched away; {} if never left)}
# frame_poses, frame_textures, and undo_stack always point at the active shot's arrays (see _bind_active_shot).
var shots: Array[Dictionary] = []
var active_shot := 0

# Frames, playback, and onion skin (all for the active shot).
var frame_textures: Array[ImageTexture] = []
var frame_poses: Array[Dictionary] = []
var play_list: Array[ImageTexture] = []   # What Play or Play All is showing.
var capturing := false
var playing := false
var play_index := 0
var play_time := 0.0
var onion_layers := 1
var ghost_pool: Dictionary = {}       # "layer:id" -> {root, joints, body}: ghost copies of figures.
var ghost_materials: Array[StandardMaterial3D] = []

# Shared clay surface texture.
var clay_normal: NoiseTexture2D

# UI references.
var indicator_style: StyleBoxFlat
var indicator_label: Label
var status_panel: PanelContainer
var status_label: Label
var status_action_button: Button   # Optional button in a status message, like Start New Shot.
var status_action: Callable
var status_timer := 0.0
var fps_label: Label
var lens_label: Label
var frames_label: Label
var cursor_label: Label
var shot_title: Label
var preview: Control
var last_frame_rect: TextureRect
var playback_rect: TextureRect
var flash_rect: ColorRect
var camera_backdrop: ColorRect   # Dark background behind the camera screen in Camera View.
var camera_border: ColorRect
var camera_screen: TextureRect   # The shot camera's picture, fitted into the open space in Camera View.
var toolbar: PanelContainer
var shot_panel: PanelContainer
var help_panel: PanelContainer
var play_button: Button
var play_all_button: Button
var shot_strip: PanelContainer
var shot_cards: HBoxContainer
var shot_scroll: ScrollContainer
var shot_label_edit: LineEdit
var lock_button: Button
var tool_buttons: Dictionary = {}
var view_buttons: Dictionary = {}
var onion_buttons: Dictionary = {}
var selected_label: Label
var scene_list_panel: PanelContainer
var scene_list_box: VBoxContainer
var style_panel: PanelContainer
var style_box: VBoxContainer
var style_panel_for := ""           # id of the figure the Style panel is showing.

# Frame rate and export.
var playback_fps := DEFAULT_FPS
var export_panel: PanelContainer
var export_name: LineEdit
var export_status: Label
var export_format := "png"
var export_scope := "all"           # MP4 and GIF: "all" shots in order, or "this" shot only.
var export_scope_row: HBoxContainer
var export_size := DEFAULT_EXPORT_SIZE
var export_size_row: HBoxContainer
var export_size_option: OptionButton
var export_size_keys: Array[String] = []   # Which size each menu item is, for the current format.
var render_restore: Dictionary = {}        # The scene to put back after exporting re-renders frames.
var render_lit_shot := -1                  # Which shot's lighting is on while re-rendering.
var zip_packer: ZIPPacker                  # Frame zips when running in the editor (the browser builds its own).
var zip_path := ""
var exporting := false
var js_ready := false
var js_callback: JavaScriptObject   # Kept alive so the browser can keep calling back into Godot.
var js_reply := ""
var js_open_callback: JavaScriptObject

# Projects and autosave.
var factory_camera := Transform3D.IDENTITY
var factory_fov := 40.0
var autosave_enabled := false        # Off until the student decides about any earlier autosave.
var autosave_timer := 0.0
var last_saved_text := ""
var loading := false
var ui_theme: Theme
var fps_option: OptionButton
var busy_overlay: Control
var busy_label: Label
var confirm_dialog: ConfirmationDialog
var pending_confirm: Callable
var open_dialog: FileDialog
var camera_controls: Array[Button] = []   # Disabled while the camera is locked.


func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_2X
	get_viewport().positional_shadow_atlas_size = 2048   # Room for the key light's shadow.
	_build_environment()
	_build_set()
	_build_lights()
	scene_root = Node3D.new()
	scene_root.name = "Scene"
	add_child(scene_root)
	_build_ghost_materials()
	_build_work_camera()
	_build_shot_camera()
	shots.append(_make_shot())
	_bind_active_shot()
	_apply_look(shots[active_shot])
	selected_figure = _spawn("kid", "", Vector3.ZERO)
	_build_ui()
	get_viewport().size_changed.connect(_on_viewport_resized)
	toolbar.resized.connect(_on_viewport_resized)
	shot_panel.resized.connect(_on_viewport_resized)
	_set_tool("bend")
	_set_onion_layers(1)
	_set_camera_locked(true)
	_set_view(false)
	_sync_camera()
	# No status message at startup.
	status_panel.visible = false
	status_timer = 0.0
	factory_camera = camera_default
	_refresh_scene_list()
	factory_fov = camera_default_fov
	_check_autosave()


# ---------------------------------------------------------------- world

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.11, 0.11, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.55, 0.58, 0.65)
	env.ambient_light_energy = 0.35   # The room light; each shot's lighting sets it.
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world_environment = env
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _build_set() -> void:
	# Tabletop, deep enough for the tripod to stand on, and as wide as the backdrop. Each shot's floor choice
	# sets its look. Patterned floors are laid out in world space, so they never stretch.
	floor_mesh = MeshInstance3D.new()
	var table_mesh := BoxMesh.new()
	table_mesh.size = Vector3(SWEEP_WIDTH, 0.2, 6.5)
	floor_mesh.mesh = table_mesh
	floor_mesh.position = Vector3(0, -0.1, 0.9)
	floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = TABLE_COLOR
	floor_mat.roughness = 0.75
	floor_mat.uv1_triplanar = true
	floor_mat.uv1_world_triplanar = true
	floor_mesh.material_override = floor_mat
	add_child(floor_mesh)

	# The backdrop: a curved paper sweep behind the table.
	sweep = _build_sweep()
	sweep_mat = StandardMaterial3D.new()
	sweep_mat.albedo_color = PAPER_COLORS["sky"][1]
	sweep_mat.roughness = 0.95
	sweep_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	sweep_mat.texture_repeat = false
	sweep.material_override = sweep_mat
	add_child(sweep)

	# Green screen: pure green that lights and shadows don't change, so it keys out cleanly.
	chroma_mat = StandardMaterial3D.new()
	chroma_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	chroma_mat.albedo_color = CHROMA_GREEN
	chroma_mat.cull_mode = BaseMaterial3D.CULL_DISABLED


func _clay_material(color: Color) -> StandardMaterial3D:
	if clay_normal == null:
		var noise := FastNoiseLite.new()
		noise.frequency = 0.03
		noise.fractal_octaves = 4
		clay_normal = NoiseTexture2D.new()
		clay_normal.width = 256
		clay_normal.height = 256
		clay_normal.seamless = true
		clay_normal.as_normal_map = true
		clay_normal.bump_strength = 3.0
		clay_normal.noise = noise
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.85
	mat.metallic_specular = 0.25
	mat.normal_enabled = true
	mat.normal_texture = clay_normal
	mat.normal_scale = 0.35
	mat.uv1_triplanar = true
	mat.uv1_scale = Vector3(2.5, 2.5, 2.5)
	return mat


# ---------------------------------------------------------------- scene objects: characters and props

## Adds a character or prop to the scene and returns it.
## `id` is passed when loading a saved project; `where` places it (otherwise the first free spot).
func _spawn(type: String, id: String = "", where: Variant = null) -> Dictionary:
	var number := 1
	if id == "":
		number = int(next_number.get(type, 1))
		id = "%s-%d" % [type, number]
	else:
		number = maxi(1, int(id.get_slice("-", id.get_slice_count("-") - 1)))
	next_number[type] = maxi(int(next_number.get(type, 1)), number + 1)

	var is_character := CHARACTER_TYPES.has(type)
	var label: String = CHARACTER_TYPES[type] if is_character else PROP_TYPES[type]
	if number > 1:
		label += " %d" % number
	var spot: Vector3 = where if where != null else _free_spot()

	var root := Node3D.new()
	root.name = id
	scene_root.add_child(root)
	root.position = spot
	var figure := {
		"id": id, "type": type, "kind": "character" if is_character else "prop", "name": label,
		"root": root, "body": null, "parts": [], "center": Vector3.ZERO, "height": 1.0,
		"torso": null, "head": null, "head_center": Vector3.ZERO, "squash": 1.0, "rest_squash": 1.0,
		"slots": {}, "colors": {}, "hair": "",
	}
	figures.append(figure)

	match type:
		"kid":
			_build_humanoid(figure, 1.0, Color(0.86, 0.42, 0.22), Color(0.24, 0.38, 0.66), Color(0.93, 0.76, 0.58), "short", Color(0.3, 0.2, 0.12))
		"man":
			_build_humanoid(figure, 1.18, Color(0.25, 0.55, 0.35), Color(0.25, 0.25, 0.3), Color(0.8, 0.6, 0.45), "short", Color(0.25, 0.17, 0.1), 1.12)
		"woman":
			_build_humanoid(figure, 1.12, Color(0.55, 0.3, 0.65), Color(0.2, 0.3, 0.5), Color(0.62, 0.43, 0.3), "long", Color(0.12, 0.08, 0.06), 0.95)
		"dog":
			_build_quadruped(figure, 0.75, 0.5, Color(0.62, 0.43, 0.25), Color(0.88, 0.78, 0.62), Color(0.4, 0.27, 0.16), "floppy", false)
		"cat":
			_build_quadruped(figure, 0.55, 0.34, Color(0.92, 0.58, 0.28), Color(0.98, 0.9, 0.8), Color(0.75, 0.42, 0.18), "pointy", true)
		_:
			_build_prop(figure)

	# Animals stand side-on to the camera so their shape reads clearly.
	if type == "dog" or type == "cat":
		root.rotation_degrees.y = 90.0

	rest_pose[root] = root.transform
	for part in figure["parts"]:
		var joint: Node3D = part["joint"]
		rest_pose[joint] = joint.transform
	return figure


func _free_spot() -> Vector3:
	for spot_value in SPAWN_SPOTS:
		var spot: Vector3 = spot_value
		var taken := false
		for figure in figures:
			var root: Node3D = figure["root"]
			if root.visible and Vector2(root.position.x - spot.x, root.position.z - spot.z).length() < 0.6:
				taken = true
				break
		if not taken:
			return spot
	return Vector3(randf_range(-2.0, 2.0), 0, randf_range(-1.0, 1.5))


func _find_figure(id: String) -> Dictionary:
	for figure in figures:
		if figure["id"] == id:
			return figure
	return {}


## Returns the figure with this id, creating it if it doesn't exist yet (used when loading).
func _ensure_figure(type: String, id: String) -> Dictionary:
	var found := _find_figure(id)
	if not found.is_empty():
		return found
	if not CHARACTER_TYPES.has(type) and not PROP_TYPES.has(type):
		return {}
	return _spawn(type, id)


## People: Kid, Man, Woman. k scales the whole body; width scales shoulders and hips.
func _build_humanoid(figure: Dictionary, k: float, shirt: Color, pants: Color, skin: Color, hair_style: String, hair: Color, width: float = 1.0) -> void:
	var shoes := Color(0.2, 0.17, 0.15)
	var root: Node3D = figure["root"]
	var hips := _make_joint(root, "Hips", Vector3(0, 0.88 * k, 0), Vector3.ZERO)
	var hips_part := _new_part(figure, "Hips (whole body)", hips)
	hips_part["tip"] = Vector3(0, 0.5 * k, 0)
	_add_sphere(hips_part, hips, Vector3.ZERO, 0.2 * k, Vector3(1.2 * width, 0.85, 0.95), pants)

	var torso := _make_joint(hips, "Torso", Vector3(0, 0.06 * k, 0), Vector3.ZERO)
	var torso_part := _new_part(figure, "Torso", torso)
	_add_limb(torso_part, torso, Vector3.ZERO, Vector3(0, 0.42 * k, 0), 0.21 * k * width, shirt)

	var head := _make_joint(torso, "Head", Vector3(0, 0.5 * k, 0), Vector3.ZERO)
	var head_part := _new_part(figure, "Head", head)
	head_part["tip"] = Vector3(0, 0.3 * k, 0.1 * k)
	_add_sphere(head_part, head, Vector3(0, 0.2 * k, 0), 0.2 * k, Vector3.ONE, skin)
	_add_sphere(head_part, head, Vector3(0, 0.19 * k, 0.2 * k), 0.045 * k, Vector3.ONE, skin)
	_add_eye(head, Vector3(0.075 * k, 0.25 * k, 0.165 * k), 0.035 * k)
	_add_eye(head, Vector3(-0.075 * k, 0.25 * k, 0.165 * k), 0.035 * k)
	# Hair lives in its own node so the hairstyle can be swapped later.
	var hair_node := Node3D.new()
	hair_node.name = "Hair"
	head.add_child(hair_node)
	figure["k"] = k
	figure["head_part"] = head_part
	figure["hair_node"] = hair_node
	figure["hair"] = hair_style
	_build_hair(figure, hair_style, hair)

	figure["torso"] = torso
	figure["head"] = head
	figure["head_center"] = Vector3(0, 0.2 * k, 0)
	figure["height"] = 1.6 * k

	for side_value in [1.0, -1.0]:
		var s: float = side_value
		var side_name: String = "Left" if s > 0.0 else "Right"

		var shoulder := _make_joint(torso, side_name + "Shoulder", Vector3(0.27 * k * width * s, 0.4 * k, 0), Vector3(0, 0, 12.0 * s))
		var upper_arm := _new_part(figure, side_name + " Upper Arm", shoulder)
		_add_limb(upper_arm, shoulder, Vector3.ZERO, Vector3(0, -0.3 * k, 0), 0.085 * k, shirt)

		var elbow := _make_joint(shoulder, side_name + "Elbow", Vector3(0, -0.3 * k, 0), Vector3.ZERO)
		var forearm := _new_part(figure, side_name + " Forearm", elbow)
		_add_limb(forearm, elbow, Vector3.ZERO, Vector3(0, -0.26 * k, 0), 0.075 * k, skin)
		_add_sphere(forearm, elbow, Vector3(0, -0.29 * k, 0), 0.085 * k, Vector3.ONE, skin)

		var hip := _make_joint(hips, side_name + "Hip", Vector3(0.12 * k * width * s, -0.04 * k, 0), Vector3.ZERO)
		var thigh := _new_part(figure, side_name + " Thigh", hip)
		_add_limb(thigh, hip, Vector3.ZERO, Vector3(0, -0.38 * k, 0), 0.1 * k, pants)

		var knee := _make_joint(hip, side_name + "Knee", Vector3(0, -0.38 * k, 0), Vector3.ZERO)
		var shin := _new_part(figure, side_name + " Shin and Foot", knee)
		_add_limb(shin, knee, Vector3.ZERO, Vector3(0, -0.36 * k, 0), 0.09 * k, pants)
		_add_sphere(shin, knee, Vector3(0, -0.4 * k, 0.05 * k), 0.1 * k, Vector3(0.9, 0.55, 1.4), shoes)

	_register_slots(figure, {"Shirt": shirt, "Pants": pants, "Skin": skin, "Hair": hair, "Shoes": shoes})


## Four-legged animals: Dog, Cat. The body runs front-to-back in two sections (hips and chest)
## joined in the middle, so the back can arch, curl, and twist. Each leg has two parts.
func _build_quadruped(figure: Dictionary, length: float, height: float, fur: Color, muzzle: Color, ears: Color, ear_style: String, tall_tail: bool) -> void:
	var root: Node3D = figure["root"]
	var r := height * 0.42
	var leg := height * 0.4

	var body := _make_joint(root, "Hips", Vector3(0, height, 0), Vector3.ZERO)
	var body_part := _new_part(figure, "Hips (whole body)", body)
	_add_limb(body_part, body, Vector3.ZERO, Vector3(0, 0, -length * 0.5), r, fur)
	var chest := _make_joint(body, "Chest", Vector3.ZERO, Vector3.ZERO)
	var chest_part := _new_part(figure, "Chest", chest)
	_add_limb(chest_part, chest, Vector3.ZERO, Vector3(0, 0, length * 0.5), r * 1.05, fur)

	var hr := r * 0.95
	var head := _make_joint(chest, "Head", Vector3(0, r * 0.6, length * 0.5), Vector3.ZERO)
	var head_part := _new_part(figure, "Head", head)
	head_part["tip"] = Vector3(0, hr * 0.7, hr * 1.5)
	_add_sphere(head_part, head, Vector3(0, hr * 0.7, hr * 0.5), hr, Vector3.ONE, fur)
	_add_sphere(head_part, head, Vector3(0, hr * 0.45, hr * 1.3), hr * 0.5, Vector3(1.0, 0.8, 1.1), muzzle)
	_add_eye(head, Vector3(0, hr * 0.62, hr * 1.82), hr * 0.13)
	_add_eye(head, Vector3(hr * 0.38, hr * 0.95, hr * 1.2), hr * 0.12)
	_add_eye(head, Vector3(-hr * 0.38, hr * 0.95, hr * 1.2), hr * 0.12)
	for side_value in [1.0, -1.0]:
		var s: float = side_value
		if ear_style == "floppy":
			_add_sphere(head_part, head, Vector3(hr * 0.85 * s, hr * 0.85, hr * 0.35), hr * 0.42, Vector3(0.45, 1.25, 0.8), ears)
		else:
			_add_cone(head_part, head, Vector3(hr * 0.55 * s, hr * 1.55, hr * 0.4), hr * 0.32, hr * 0.6, ears)
	figure["torso"] = chest
	figure["head"] = head
	figure["head_center"] = Vector3(0, hr * 0.7, hr * 0.5)
	figure["height"] = height + hr * 1.6

	for front_value in [1.0, -1.0]:
		var f: float = front_value
		var end_name: String = "Front" if f > 0.0 else "Back"
		for side_value in [1.0, -1.0]:
			var s: float = side_value
			var leg_name: String = "%s %s" % [end_name, "Left" if s > 0.0 else "Right"]
			# Front legs hang from the chest, back legs from the hips.
			var leg_parent: Node3D = chest if f > 0.0 else body
			var hip := _make_joint(leg_parent, leg_name.replace(" ", "") + "Hip", Vector3(r * 0.55 * s, -r * 0.3, length * 0.38 * f), Vector3.ZERO)
			var upper := _new_part(figure, leg_name + " Leg", hip)
			_add_limb(upper, hip, Vector3.ZERO, Vector3(0, -leg, 0), r * 0.32, fur)
			var knee := _make_joint(hip, leg_name.replace(" ", "") + "Knee", Vector3(0, -leg, 0), Vector3.ZERO)
			var lower := _new_part(figure, leg_name + " Paw", knee)
			_add_limb(lower, knee, Vector3.ZERO, Vector3(0, -leg, 0), r * 0.27, fur)
			_add_sphere(lower, knee, Vector3(0, -leg, r * 0.1), r * 0.3, Vector3(1.0, 0.6, 1.3), fur)

	var tail := _make_joint(body, "Tail", Vector3(0, r * 0.4, -length * 0.5), Vector3.ZERO)
	var tail_part := _new_part(figure, "Tail", tail)
	var tail_end := Vector3(0, height * 0.9, -height * 0.3) if tall_tail else Vector3(0, height * 0.35, -height * 0.45)
	_add_limb(tail_part, tail, Vector3.ZERO, tail_end, r * (0.14 if tall_tail else 0.18), fur)

	_register_slots(figure, {"Fur": fur, "Muzzle": muzzle, "Ears": ears})


## Props are one solid piece. Their meshes sit inside a "Body" node that squashes and stretches.
func _build_prop(figure: Dictionary) -> void:
	var root: Node3D = figure["root"]
	var body := Node3D.new()
	body.name = "Body"
	root.add_child(body)
	figure["body"] = body
	var part := _new_part(figure, figure["name"], root)
	part["is_prop"] = true
	var wood := Color(0.62, 0.42, 0.25)
	match figure["type"]:
		"ball":
			_add_sphere(part, body, Vector3(0, 0.15, 0), 0.15, Vector3.ONE, Color(0.9, 0.22, 0.2))
			figure["center"] = Vector3(0, 0.15, 0)
		"box":
			_add_box(part, body, Vector3(0, 0.2, 0), Vector3(0.4, 0.4, 0.4), Color(0.85, 0.65, 0.35))
			figure["center"] = Vector3(0, 0.2, 0)
		"goal":
			var white := Color(0.95, 0.95, 0.95)
			_add_box(part, body, Vector3(0.6, 0.4, 0), Vector3(0.06, 0.8, 0.06), white)
			_add_box(part, body, Vector3(-0.6, 0.4, 0), Vector3(0.06, 0.8, 0.06), white)
			_add_box(part, body, Vector3(0, 0.8, 0), Vector3(1.26, 0.06, 0.06), white)
			_add_box(part, body, Vector3(0, 0.03, -0.4), Vector3(1.26, 0.06, 0.06), white)
			_add_box(part, body, Vector3(0.6, 0.03, -0.2), Vector3(0.06, 0.06, 0.4), white)
			_add_box(part, body, Vector3(-0.6, 0.03, -0.2), Vector3(0.06, 0.06, 0.4), white)
			_add_net(body, Vector3(0, 0.42, -0.2), Vector3(1.2, 0.8, 0.4))
			figure["center"] = Vector3(0, 0.4, -0.2)
		"marker":
			var yellow := Color(1.0, 0.85, 0.1)
			_add_box(part, body, Vector3(0, 0.011, 0), Vector3(0.5, 0.02, 0.08), yellow, Vector3(0, 45, 0))
			_add_box(part, body, Vector3(0, 0.011, 0), Vector3(0.5, 0.02, 0.08), yellow, Vector3(0, -45, 0))
			figure["center"] = Vector3(0, 0.01, 0)
		"table":
			_add_box(part, body, Vector3(0, 0.71, 0), Vector3(1.2, 0.08, 0.8), wood)
			for x in [-0.52, 0.52]:
				for z in [-0.32, 0.32]:
					_add_box(part, body, Vector3(x, 0.335, z), Vector3(0.08, 0.67, 0.08), wood)
			figure["center"] = Vector3(0, 0.4, 0)
		"chair":
			_add_box(part, body, Vector3(0, 0.45, 0), Vector3(0.45, 0.06, 0.45), wood)
			for x in [-0.19, 0.19]:
				for z in [-0.19, 0.19]:
					_add_box(part, body, Vector3(x, 0.21, z), Vector3(0.05, 0.42, 0.05), wood)
			_add_box(part, body, Vector3(0, 0.73, -0.2), Vector3(0.45, 0.5, 0.05), wood)
			figure["center"] = Vector3(0, 0.45, 0)
		"cone":
			var orange := Color(1.0, 0.45, 0.1)
			_add_cone(part, body, Vector3(0, 0.24, 0), 0.16, 0.44, orange)
			_add_box(part, body, Vector3(0, 0.015, 0), Vector3(0.36, 0.03, 0.36), orange)
			figure["center"] = Vector3(0, 0.2, 0)
		"can":
			_add_cylinder(part, body, Vector3(0, 0.15, 0), 0.12, 0.3, Color(0.5, 0.6, 0.72))
			figure["center"] = Vector3(0, 0.15, 0)
		"plank":
			_add_box(part, body, Vector3(0, 0.025, 0), Vector3(1.2, 0.05, 0.3), Color(0.72, 0.52, 0.32))
			figure["center"] = Vector3(0, 0.025, 0)
		"rock":
			_add_sphere(part, body, Vector3(0, 0.13, 0), 0.18, Vector3(1.2, 0.75, 1.0), Color(0.5, 0.5, 0.48))
			figure["center"] = Vector3(0, 0.13, 0)
	var center: Vector3 = figure["center"]
	figure["height"] = maxf(center.y * 2.0, 0.3)
	# A prop has one Color that paints every clay piece of it.
	var materials: Array = part["materials"]
	var first: StandardMaterial3D = materials[0]
	figure["slots"] = {"Color": materials.duplicate()}
	figure["colors"] = {"Color": first.albedo_color}


func _make_joint(parent: Node3D, joint_name: String, pos: Vector3, rot_deg: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.name = joint_name
	joint.position = pos
	joint.rotation_degrees = rot_deg
	parent.add_child(joint)
	return joint


func _new_part(figure: Dictionary, part_name: String, joint: Node3D) -> Dictionary:
	# axis = the direction the part extends from its joint (joint space); twist = turn around that axis, in radians.
	var part := {"name": part_name, "joint": joint, "materials": [], "shapes": [], "tip": Vector3.ZERO,
		"axis": Vector3.UP, "twist": 0.0, "figure": figure, "is_prop": false}
	figure["parts"].append(part)
	parts.append(part)
	return part


## A clay capsule from one point to another (in the parent's space). The first limb added to a part
## also sets which way that part points.
func _add_limb(part: Dictionary, parent: Node3D, from: Vector3, to: Vector3, radius: float, color: Color) -> void:
	var dir := to - from
	var length := dir.length()
	var up := dir.normalized()
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = length + radius * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var limb_basis := Basis.IDENTITY
	if absf(up.dot(Vector3.UP)) < 0.999:
		limb_basis = Basis(Quaternion(Vector3.UP, up))
	mi.transform = Transform3D(limb_basis, (from + to) * 0.5)
	var mat := _clay_material(color)
	mi.material_override = mat
	parent.add_child(mi)
	part["materials"].append(mat)
	part["shapes"].append([mi, Vector3(0, -length * 0.5, 0), Vector3(0, length * 0.5, 0), radius])
	var tip: Vector3 = part["tip"]
	if tip == Vector3.ZERO:
		part["tip"] = to
		part["axis"] = up


func _add_sphere(part: Dictionary, parent: Node3D, pos: Vector3, radius: float, scale_v: Vector3, color: Color) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scale_v
	var mat := _clay_material(color)
	mi.material_override = mat
	parent.add_child(mi)
	part["materials"].append(mat)
	var pick_radius := radius * maxf(scale_v.x, maxf(scale_v.y, scale_v.z))
	part["shapes"].append([mi, Vector3.ZERO, Vector3.ZERO, pick_radius])


func _add_box(part: Dictionary, parent: Node3D, pos: Vector3, size: Vector3, color: Color, rot_deg: Vector3 = Vector3.ZERO) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.rotation_degrees = rot_deg
	var mat := _clay_material(color)
	mi.material_override = mat
	parent.add_child(mi)
	part["materials"].append(mat)
	# Picking: an exact box. A negative radius marks it as a box; the second entry is its half size.
	part["shapes"].append([mi, size * 0.5, Vector3.ZERO, -1.0])


func _add_cylinder(part: Dictionary, parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var mat := _clay_material(color)
	mi.material_override = mat
	parent.add_child(mi)
	part["materials"].append(mat)
	var reach := maxf(height * 0.5 - radius, 0.0)
	part["shapes"].append([mi, Vector3(0, -reach, 0), Vector3(0, reach, 0), maxf(radius, height * 0.5 - reach)])


func _add_cone(part: Dictionary, parent: Node3D, pos: Vector3, radius: float, height: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = radius
	mesh.height = height
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var mat := _clay_material(color)
	mi.material_override = mat
	parent.add_child(mi)
	part["materials"].append(mat)
	part["shapes"].append([mi, Vector3.ZERO, Vector3.ZERO, maxf(radius, height * 0.5) * 0.85])


## The goal's net: see-through, so the ball shows behind it.
func _add_net(parent: Node3D, pos: Vector3, size: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1, 1, 1, 0.18)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 1.0
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)


func _add_eye(parent: Node3D, pos: Vector3, radius: float) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.06)
	mat.roughness = 0.3
	mi.material_override = mat
	parent.add_child(mi)


func _squash_scale(amount: float) -> Vector3:
	var side := 1.0 / sqrt(amount)
	return Vector3(side, amount, side)


## Squash and stretch keeps the volume the same: taller means thinner, flatter means wider.
func _set_squash(figure: Dictionary, amount: float) -> void:
	figure["squash"] = amount
	var body: Node3D = figure["body"]
	if body != null:
		body.scale = _squash_scale(amount)


## Groups a figure's clay materials by what they paint (Shirt, Skin, Fur, ...), using the colors it was built with.
func _register_slots(figure: Dictionary, slot_colors: Dictionary) -> void:
	var slots := {}
	for slot in slot_colors:
		slots[slot] = []
	for part in figure["parts"]:
		for mat_value in part["materials"]:
			var mat: StandardMaterial3D = mat_value
			for slot in slot_colors:
				if mat.albedo_color.is_equal_approx(slot_colors[slot]):
					slots[slot].append(mat)
					break
	figure["slots"] = slots
	figure["colors"] = slot_colors.duplicate()


func _set_figure_color(figure: Dictionary, slot: String, color: Color) -> void:
	var slots: Dictionary = figure["slots"]
	if not slots.has(slot):
		return
	figure["colors"][slot] = color
	for mat_value in slots[slot]:
		var mat: StandardMaterial3D = mat_value
		mat.albedo_color = color


## Builds one hairstyle inside the head's Hair node. Hair is part of the head, so it moves with it.
func _build_hair(figure: Dictionary, style: String, color: Color) -> void:
	var k: float = figure["k"]
	var head_part: Dictionary = figure["head_part"]
	var hair_node: Node3D = figure["hair_node"]
	match style:
		"short":
			_add_sphere(head_part, hair_node, Vector3(0, 0.3 * k, -0.05 * k), 0.19 * k, Vector3(1.08, 0.75, 1.05), color)
		"long":
			_add_sphere(head_part, hair_node, Vector3(0, 0.3 * k, -0.04 * k), 0.2 * k, Vector3(1.12, 0.8, 1.1), color)
			# Hair falls on both sides of the face to the shoulders, so it reads as long from the front.
			for lock_side in [1.0, -1.0]:
				var ls: float = lock_side
				_add_limb(head_part, hair_node, Vector3(0.17 * k * ls, 0.27 * k, -0.03 * k), Vector3(0.19 * k * ls, -0.06 * k, -0.06 * k), 0.065 * k, color)
			# The back of the hair falls past the shoulders.
			_add_limb(head_part, hair_node, Vector3(0, 0.26 * k, -0.12 * k), Vector3(0, -0.14 * k, -0.2 * k), 0.15 * k, color)
		"ponytail":
			_add_sphere(head_part, hair_node, Vector3(0, 0.3 * k, -0.05 * k), 0.19 * k, Vector3(1.08, 0.75, 1.05), color)
			_add_sphere(head_part, hair_node, Vector3(0, 0.29 * k, -0.2 * k), 0.06 * k, Vector3.ONE, color)
			_add_limb(head_part, hair_node, Vector3(0, 0.27 * k, -0.24 * k), Vector3(0, 0.02 * k, -0.3 * k), 0.07 * k, color)
		"bun":
			_add_sphere(head_part, hair_node, Vector3(0, 0.3 * k, -0.05 * k), 0.19 * k, Vector3(1.08, 0.75, 1.05), color)
			_add_sphere(head_part, hair_node, Vector3(0, 0.43 * k, -0.12 * k), 0.1 * k, Vector3.ONE, color)
		"curly":
			_add_sphere(head_part, hair_node, Vector3(0, 0.33 * k, -0.1 * k), 0.25 * k, Vector3(1.1, 0.85, 1.0), color)
	# When restyling later, the new hair joins the Hair color slot.
	var slots: Dictionary = figure["slots"]
	if slots.has("Hair"):
		for child in hair_node.get_children():
			var mi := child as MeshInstance3D
			if mi != null and not slots["Hair"].has(mi.material_override):
				slots["Hair"].append(mi.material_override)


## Swaps a person's hairstyle, keeping the hair color.
func _set_hair(figure: Dictionary, style: String) -> void:
	if not figure.has("hair_node") or figure["hair"] == style:
		return
	var head_part: Dictionary = figure["head_part"]
	var hair_node: Node3D = figure["hair_node"]
	var slots: Dictionary = figure["slots"]
	var head_materials: Array = head_part["materials"]
	for child in hair_node.get_children():
		var mi := child as MeshInstance3D
		if mi != null:
			head_materials.erase(mi.material_override)
			if slots.has("Hair"):
				slots["Hair"].erase(mi.material_override)
	var kept_shapes: Array = []
	for shape in head_part["shapes"]:
		var shape_mesh: Node = shape[0]
		if shape_mesh.get_parent() != hair_node:
			kept_shapes.append(shape)
	head_part["shapes"] = kept_shapes
	for child in hair_node.get_children():
		child.free()
	figure["hair"] = style
	_build_hair(figure, style, figure["colors"].get("Hair", Color(0.2, 0.15, 0.1)))


func _figure_style(figure: Dictionary) -> Dictionary:
	return {"colors": (figure["colors"] as Dictionary).duplicate(), "hair": figure["hair"]}


func _apply_style(figure: Dictionary, style: Dictionary) -> void:
	var colors: Dictionary = style.get("colors", {})
	for slot in colors:
		var current: Color = figure["colors"].get(slot, Color.BLACK)
		var wanted: Color = colors[slot]
		if not current.is_equal_approx(wanted):
			_set_figure_color(figure, str(slot), wanted)
	var hair := str(style.get("hair", ""))
	if hair != "" and figure.has("hair_node"):
		_set_hair(figure, hair)


## The Style panel: color buttons for the selected figure, and a hairstyle menu for people.
func _refresh_style_panel(force: bool = false) -> void:
	if style_box == null or not style_panel.visible:
		return
	var showing := "" if selected_figure.is_empty() else str(selected_figure["id"])
	if showing == style_panel_for and not force:
		return
	style_panel_for = showing
	for child in style_box.get_children():
		child.queue_free()
	if selected_figure.is_empty():
		var hint := Label.new()
		hint.text = "Click a character or prop\nto change how it looks."
		style_box.add_child(hint)
		return
	var figure := selected_figure
	var title := Label.new()
	title.text = "STYLE: %s" % figure["name"]
	title.add_theme_font_size_override("font_size", 14)
	style_box.add_child(title)
	var colors: Dictionary = figure["colors"]
	for slot_value in colors:
		var slot := str(slot_value)
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = slot
		label.custom_minimum_size = Vector2(70, 0)
		row.add_child(label)
		var button := ColorPickerButton.new()
		button.color = colors[slot]
		button.edit_alpha = false
		button.custom_minimum_size = Vector2(110, 30)
		button.focus_mode = Control.FOCUS_NONE
		button.tooltip_text = "Pick a %s color." % slot.to_lower()
		_setup_color_picker(button)
		button.pressed.connect(_push_undo)
		button.color_changed.connect(func(c: Color) -> void: _set_figure_color(figure, slot, c))
		row.add_child(button)
		style_box.add_child(row)
	if figure.has("hair_node"):
		var hair_row := HBoxContainer.new()
		var hair_label := Label.new()
		hair_label.text = "Hairstyle"
		hair_label.custom_minimum_size = Vector2(70, 0)
		hair_row.add_child(hair_label)
		var hair_menu := OptionButton.new()
		hair_menu.focus_mode = Control.FOCUS_NONE
		hair_menu.tooltip_text = "Change this person's hairstyle."
		var keys: Array = HAIR_STYLES.keys()
		for i in keys.size():
			hair_menu.add_item(str(HAIR_STYLES[keys[i]]), i)
		hair_menu.select(keys.find(figure["hair"]))
		hair_menu.item_selected.connect(func(index: int) -> void:
			_push_undo()
			_set_hair(figure, str(keys[index])))
		hair_row.add_child(hair_menu)
		style_box.add_child(hair_row)
	var note := Label.new()
	note.text = "Changes show up in the frames\nyou capture from now on."
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(0.65, 0.67, 0.72))
	style_box.add_child(note)


## Keeps the color picker simple: the clay palette first, a color wheel, no advanced controls.
func _setup_color_picker(button: ColorPickerButton) -> void:
	button.get_popup().theme = ui_theme
	var picker := button.get_picker()
	picker.sampler_visible = false
	picker.color_modes_visible = false
	picker.sliders_visible = false
	picker.hex_visible = false
	picker.can_add_swatches = false
	picker.presets_visible = true
	for c in CLAY_PALETTE:
		picker.add_preset(c)


# ---------------------------------------------------------------- adding, removing, and the scene list

func _add_figure(type: String) -> void:
	_push_undo()
	var figure := _spawn(type)
	selected_figure = figure
	_refresh_scene_list()
	_flash_status("Added %s. Use Move to place it, or Lift to raise it." % figure["name"], 5.0)


func _remove_selected() -> void:
	if selected_figure.is_empty() or not (selected_figure["root"] as Node3D).visible:
		_flash_status("Click a character or prop first, then press Remove.")
		return
	var figure := selected_figure
	_confirm("Remove %s from the scene? You can bring it back with Undo." % figure["name"], func() -> void: _remove_figure(figure))


## Removing hides the figure instead of deleting it, so frames that already include it
## can still be rebuilt, and Undo can bring it back.
func _remove_figure(figure: Dictionary) -> void:
	_push_undo()
	(figure["root"] as Node3D).visible = false
	_clear_stale_selection()
	_refresh_scene_list()
	_refresh_style_panel(true)
	_flash_status("Removed %s. Undo brings it back." % figure["name"])


func _select_figure(figure: Dictionary) -> void:
	selected_figure = figure
	var figure_parts: Array = figure["parts"]
	if not figure_parts.is_empty():
		_set_highlight(figure_parts[0])
	_update_selected_label()


## Forgets anything selected or highlighted that is no longer in the scene.
func _clear_stale_selection() -> void:
	if not selected_figure.is_empty() and not (selected_figure["root"] as Node3D).visible:
		selected_figure = {}
	_set_highlight({})
	hovered = {}
	active_part = {}
	_update_selected_label()


func _update_selected_label() -> void:
	if selected_label == null:
		return
	_refresh_style_panel()
	selected_label.text = "Selected: none" if selected_figure.is_empty() else "Selected: %s" % selected_figure["name"]


func _refresh_scene_list() -> void:
	if scene_list_box == null:
		return
	for child in scene_list_box.get_children():
		child.queue_free()
	for figure in figures:
		if not (figure["root"] as Node3D).visible:
			continue
		var row := HBoxContainer.new()
		var name_button := _make_button(figure["name"], "Select %s." % figure["name"])
		name_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		name_button.pressed.connect(func() -> void: _select_figure(figure))
		row.add_child(name_button)
		var remove := _make_button("Remove", "Take %s out of the scene. Undo brings it back." % figure["name"])
		remove.pressed.connect(func() -> void: _confirm("Remove %s from the scene? You can bring it back with Undo." % figure["name"], func() -> void: _remove_figure(figure)))
		row.add_child(remove)
		scene_list_box.add_child(row)
	_update_selected_label()


## The character the shot presets frame: the selected one, or else the first in the scene.
func _subject_figure() -> Dictionary:
	if not selected_figure.is_empty() and selected_figure["kind"] == "character" and (selected_figure["root"] as Node3D).visible:
		return selected_figure
	for figure in figures:
		if figure["kind"] == "character" and (figure["root"] as Node3D).visible:
			return figure
	return {}


# ---------------------------------------------------------------- poses, default pose, undo

## A snapshot of the whole scene: every character and prop that's in it (where it stands,
## its joints, twists, and squash), plus the camera. Undo, frames, and saved projects all use these.
func _get_pose() -> Dictionary:
	var objects: Array = []
	for figure in figures:
		var root: Node3D = figure["root"]
		if not root.visible:
			continue
		var joints: Array = []
		var twists: Array = []
		if figure["kind"] == "character":
			for part in figure["parts"]:
				var joint: Node3D = part["joint"]
				joints.append(joint.transform)
				twists.append(part["twist"])
		objects.append({"id": figure["id"], "type": figure["type"], "root": root.transform,
			"joints": joints, "twists": twists, "squash": figure["squash"], "style": _figure_style(figure)})
	return {"objects": objects, "camera": shot_camera.global_transform, "fov": shot_camera.fov}


func _apply_pose(pose: Dictionary) -> void:
	var present := {}
	for obj_value in pose.get("objects", []):
		var obj: Dictionary = obj_value
		var figure := _ensure_figure(str(obj.get("type", "")), str(obj.get("id", "")))
		if figure.is_empty():
			continue
		present[figure["id"]] = true
		_apply_object(figure, obj)
	for figure in figures:
		(figure["root"] as Node3D).visible = present.has(figure["id"])
	shot_camera.global_transform = pose["camera"]
	shot_camera.fov = pose["fov"]
	_sync_camera()
	if not loading:
		_clear_stale_selection()
		_refresh_scene_list()


func _apply_object(figure: Dictionary, obj: Dictionary) -> void:
	var root: Node3D = figure["root"]
	root.transform = obj["root"]
	if obj.has("style"):
		_apply_style(figure, obj["style"])
	if figure["kind"] == "character":
		var joints: Array = obj.get("joints", [])
		var twists: Array = obj.get("twists", [])
		var figure_parts: Array = figure["parts"]
		if joints.size() == figure_parts.size():
			for i in figure_parts.size():
				var joint: Node3D = figure_parts[i]["joint"]
				joint.transform = joints[i]
				figure_parts[i]["twist"] = float(twists[i]) if i < twists.size() else 0.0
	else:
		_set_squash(figure, float(obj.get("squash", 1.0)))


func _reset_pose() -> void:
	_push_undo()
	for figure in figures:
		var root: Node3D = figure["root"]
		if not root.visible:
			continue
		root.transform = rest_pose[root]
		if figure["kind"] == "character":
			for part in figure["parts"]:
				var joint: Node3D = part["joint"]
				joint.transform = rest_pose[joint]
				part["twist"] = 0.0
		else:
			_set_squash(figure, figure["rest_squash"])
	_flash_status("Everything is back in its default pose.")


## Makes the current scene the one Reset Pose returns to.
func _set_default_pose() -> void:
	for figure in figures:
		var root: Node3D = figure["root"]
		rest_pose[root] = root.transform
		for part in figure["parts"]:
			var joint: Node3D = part["joint"]
			rest_pose[joint] = joint.transform
			# Twist is measured from the default pose, so the new default starts with no extra twist.
			part["twist"] = 0.0
		figure["rest_squash"] = figure["squash"]
	# Older undo steps were measured from the old default, so they no longer apply.
	# (Every shot's, except the ones that bring back a deleted shot.)
	for shot in shots:
		var undo: Array[Dictionary] = shot["undo"]
		undo.assign(undo.filter(func(step: Dictionary) -> bool: return step.has("restore_shot")))
	_flash_status("Saved this as the default. Reset Pose now returns here.")


func _push_undo() -> void:
	undo_stack.append(_get_pose())
	if undo_stack.size() > MAX_UNDO:
		undo_stack.pop_front()


func _undo() -> void:
	if undo_stack.is_empty():
		_flash_status("Nothing to undo.")
		return
	var pose: Dictionary = undo_stack.pop_back()
	if pose.has("restore_shot"):
		_restore_deleted_shot(pose["restore_shot"], int(pose["index"]))
		return
	if pose.has("set"):
		shots[active_shot]["set"] = pose["set"]
		_set_changed()
		_flash_status("Undid the last backdrop or floor change.")
		return
	if pose.has("lighting"):
		shots[active_shot]["lighting"] = pose["lighting"]
		_lighting_changed(false)
		# Lighting may have been locked since; its frames need the restored lighting right away.
		if _lighting_locked():
			await _relight_if_needed()
		_flash_status("Undid the last lighting change.")
		return
	_apply_pose(pose)
	_flash_status("Undid the last change.")


# ---------------------------------------------------------------- onion skin

## Three see-through magenta materials, fading from the most recent frame to the oldest.
func _build_ghost_materials() -> void:
	var tint := [0.55, 0.35, 0.2]
	for i in 3:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		# Magenta stands out against the clay, table, and backdrop colors.
		# No depth test: ghosts show through the puppet, like onion skin on a real frame grabber.
		mat.no_depth_test = true
		mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		mat.render_priority = 1
		mat.albedo_color = Color(1.0, 0.2, 0.75, tint[i])
		ghost_materials.append(mat)


## A ghost copy of a figure for one onion skin layer, made the first time it's needed.
func _ghost_for(layer: int, figure: Dictionary) -> Dictionary:
	var key := "%d:%s" % [layer, figure["id"]]
	if ghost_pool.has(key):
		return ghost_pool[key]
	var root: Node3D = figure["root"]
	var ghost := root.duplicate() as Node3D
	ghost.name = "Ghost%d-%s" % [layer, figure["id"]]
	add_child(ghost)
	var joints: Array = []
	if figure["kind"] == "character":
		for part in figure["parts"]:
			var joint: Node3D = part["joint"]
			joints.append(ghost.get_node(root.get_path_to(joint)))
	var body: Node3D = null
	if figure["kind"] == "prop":
		body = ghost.get_node("Body")
	_make_ghost_look(ghost, ghost_materials[layer])
	var entry := {"root": ghost, "joints": joints, "body": body}
	ghost_pool[key] = entry
	return entry


func _make_ghost_look(node: Node, mat: Material) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			var mi := child as MeshInstance3D
			mi.material_override = mat
			mi.layers = LAYER_GHOSTS
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_make_ghost_look(child, mat)


func _update_ghosts() -> void:
	for key in ghost_pool:
		(ghost_pool[key]["root"] as Node3D).visible = false
	if playing:
		return
	for layer in mini(onion_layers, 3):
		var frame_index := frame_poses.size() - 1 - layer
		if frame_index < 0:
			break
		var pose: Dictionary = frame_poses[frame_index]
		for obj_value in pose.get("objects", []):
			var obj: Dictionary = obj_value
			var figure := _find_figure(str(obj.get("id", "")))
			if figure.is_empty():
				continue
			var ghost := _ghost_for(layer, figure)
			var ghost_root: Node3D = ghost["root"]
			ghost_root.transform = obj["root"]
			if figure["kind"] == "character":
				var joints: Array = ghost["joints"]
				var transforms: Array = obj.get("joints", [])
				if transforms.size() == joints.size():
					for k in joints.size():
						var j: Node3D = joints[k]
						j.transform = transforms[k]
			else:
				var body: Node3D = ghost["body"]
				if body != null:
					body.scale = _squash_scale(float(obj.get("squash", 1.0)))
			ghost_root.visible = true


func _clear_ghosts() -> void:
	for key in ghost_pool:
		(ghost_pool[key]["root"] as Node3D).queue_free()
	ghost_pool.clear()


func _set_onion_layers(count: int) -> void:
	onion_layers = count
	var key := str(count)
	if onion_buttons.has(key):
		var b: Button = onion_buttons[key]
		b.button_pressed = true
	_update_ghosts()


func _cycle_onion_layers() -> void:
	match onion_layers:
		0:
			_set_onion_layers(1)
		1:
			_set_onion_layers(3)
		_:
			_set_onion_layers(0)


# ---------------------------------------------------------------- work view

func _build_work_camera() -> void:
	work_camera = Camera3D.new()
	work_camera.fov = WORK_FOV
	add_child(work_camera)
	work_camera.current = true
	_update_orbit()


func _update_orbit() -> void:
	orbit_pitch = clampf(orbit_pitch, -1.35, 0.05)
	orbit_distance = clampf(orbit_distance, 1.5, 10.0)
	var offset := Vector3(0, 0, orbit_distance)
	offset = offset.rotated(Vector3.RIGHT, orbit_pitch).rotated(Vector3.UP, orbit_yaw)
	work_camera.position = orbit_target + offset
	work_camera.look_at(orbit_target, Vector3.UP)


func _orbit(rel: Vector2) -> void:
	if camera_view:
		return
	orbit_yaw -= rel.x * ORBIT_SPEED
	orbit_pitch -= rel.y * ORBIT_SPEED
	_update_orbit()


## factor lets trackpad scrolling zoom in small, smooth steps.
func _view_zoom(multiplier: float, factor: float) -> void:
	if camera_view:
		_flash_status("View In and View Out work in Studio View. To change the shot itself, unlock the camera and use Dolly or Zoom.")
		return
	var f := factor if factor > 0.0 else 1.0
	orbit_distance *= pow(multiplier, f)
	_update_orbit()


func _reset_view() -> void:
	if camera_view:
		_set_view(false)
	orbit_yaw = DEFAULT_YAW
	orbit_pitch = DEFAULT_PITCH
	orbit_distance = DEFAULT_DISTANCE
	_update_orbit()


## Studio View: orbit freely around the set.
## Camera View: the shot camera's picture fills the open space between the toolbar and the capture
## controls, so the whole frame is always visible and nothing covers it.
func _set_view(through_camera: bool) -> void:
	camera_view = through_camera
	if camera_view:
		# The main view is hidden behind the camera screen, so draw nothing there.
		work_camera.cull_mask = 0
	else:
		work_camera.cull_mask = ALL_LAYERS
		_update_orbit()
	hovered_camera = false
	_set_camera_glow(false)
	hovered_light = ""
	if not lamp_models.is_empty():
		_set_lamp_glow("")
	if camera_screen != null:
		camera_backdrop.visible = camera_view
		camera_border.visible = camera_view
		camera_screen.visible = camera_view
		preview.visible = not camera_view
		_update_shot_title()
		var key := "camera" if camera_view else "studio"
		var b: Button = view_buttons[key]
		b.button_pressed = true
		_layout_camera_screen.call_deferred()


## Fits the 16:9 camera screen into the space below the toolbar and above the capture controls.
func _layout_camera_screen() -> void:
	if not camera_view or camera_screen == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var top := toolbar.get_global_rect().end.y + 8.0
	var bottom := shot_panel.get_global_rect().position.y - 8.0
	var left := 10.0
	var right := vs.x - 10.0
	var w := right - left
	var h := bottom - top
	if w <= 0.0 or h <= 0.0:
		return
	var fw := w
	var fh := fw / SHOT_ASPECT
	if fh > h:
		fh = h
		fw = fh * SHOT_ASPECT
	var rect := Rect2(left + (w - fw) * 0.5, top + (h - fh) * 0.5, fw, fh)
	camera_screen.position = rect.position
	camera_screen.size = rect.size
	camera_border.position = rect.position - Vector2(2, 2)
	camera_border.size = rect.size + Vector2(4, 4)


func _on_viewport_resized() -> void:
	_fit_shot_preview.call_deferred()
	_layout_camera_screen.call_deferred()


## Shrinks the shot preview on short screens (or under the Walsh Classroom bar) so the whole shot panel stays on screen.
func _fit_shot_preview() -> void:
	if preview == null:
		return
	var vs := get_viewport().get_visible_rect().size
	var room := vs.y - 10.0 - (toolbar.get_global_rect().end.y + 8.0)
	var rest := shot_panel.size.y - preview.size.y
	var h := floorf(clampf(room - rest, PREVIEW_MIN_HEIGHT, PREVIEW_MAX_HEIGHT))
	var fitted := Vector2(roundf(h * SHOT_ASPECT), h)
	if fitted != preview.custom_minimum_size:
		preview.custom_minimum_size = fitted


## The camera the cursor is working through: the shot camera in Camera View, otherwise the work view.
func _active_cam() -> Camera3D:
	return shot_camera if camera_view else work_camera


## Converts a mouse position into the active camera's own picture coordinates.
func _cam_coords(screen_pos: Vector2) -> Vector2:
	if not camera_view or camera_screen.size.x <= 0.0:
		return screen_pos
	var local := (screen_pos - camera_screen.position) / camera_screen.size
	return local * Vector2(shot_viewport.size)


func _toggle_view() -> void:
	_set_view(not camera_view)


# ---------------------------------------------------------------- shot camera

func _build_shot_camera() -> void:
	shot_viewport = SubViewport.new()
	shot_viewport.size = SHOT_RENDER_SIZE
	shot_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	shot_viewport.msaa_3d = Viewport.MSAA_2X
	shot_viewport.positional_shadow_atlas_size = 2048
	add_child(shot_viewport)

	shot_camera = Camera3D.new()
	shot_camera.fov = 40.0
	shot_camera.cull_mask = SHOT_PREVIEW_MASK
	shot_viewport.add_child(shot_camera)
	shot_camera.position = Vector3(0.0, 1.0, 3.3)
	shot_camera.look_at(Vector3(0, 0.78, 0), Vector3.UP)
	shot_camera.current = true
	camera_default = shot_camera.global_transform
	camera_default_fov = shot_camera.fov

	_build_camera_prop()


## A visible camera on a tripod in Studio View, plus lines showing what it sees.
func _build_camera_prop() -> void:
	camera_prop_mat = StandardMaterial3D.new()
	camera_prop_mat.albedo_color = Color(0.08, 0.08, 0.09)
	camera_prop_mat.roughness = 0.4
	camera_prop_mat.emission = Color(1.0, 0.3, 0.25)
	camera_prop_mat.emission_energy_multiplier = 0.6

	camera_prop = Node3D.new()
	add_child(camera_prop)

	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.32, 0.22, 0.2)
	body.mesh = body_mesh
	body.position = Vector3(0, 0, 0.12)
	camera_prop.add_child(body)

	var lens := MeshInstance3D.new()
	var lens_mesh := CylinderMesh.new()
	lens_mesh.top_radius = 0.07
	lens_mesh.bottom_radius = 0.08
	lens_mesh.height = 0.16
	lens.mesh = lens_mesh
	lens.rotation_degrees = Vector3(90, 0, 0)
	lens.position = Vector3(0, 0, -0.06)
	camera_prop.add_child(lens)

	# The pole is 1 unit tall and stretched to the camera's height in _sync_camera.
	camera_pole = MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.025
	pole_mesh.bottom_radius = 0.025
	pole_mesh.height = 1.0
	camera_pole.mesh = pole_mesh
	add_child(camera_pole)

	for mi in [body, lens, camera_pole]:
		var m: MeshInstance3D = mi
		m.material_override = camera_prop_mat
		m.layers = LAYER_CAMERA_PROP
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	view_lines_mesh = ImmediateMesh.new()
	view_lines = MeshInstance3D.new()
	view_lines.mesh = view_lines_mesh
	var line_mat := StandardMaterial3D.new()
	line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_mat.albedo_color = Color(1.0, 0.35, 0.3, 0.8)
	line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	view_lines.material_override = line_mat
	view_lines.layers = LAYER_CAMERA_PROP
	view_lines.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view_lines)


## Keeps the tripod model, view lines, lens readout, and Camera View in step with the shot camera.
func _sync_camera() -> void:
	var t := shot_camera.global_transform
	camera_prop.global_transform = t
	var height := maxf(t.origin.y - 0.11, 0.05)
	var behind := t.origin + t.basis.z * 0.12
	camera_pole.position = Vector3(behind.x, height * 0.5, behind.z)
	camera_pole.scale = Vector3(1, height, 1)

	# Lines from the lens out to the edges of the frame.
	var dist := 2.5
	var half_h := tan(deg_to_rad(shot_camera.fov) * 0.5) * dist
	var half_w := half_h * SHOT_ASPECT
	var o := t.origin
	var corners: Array[Vector3] = []
	for c in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var v: Vector2 = c
		corners.append(t * Vector3(v.x * half_w, v.y * half_h, -dist))
	view_lines_mesh.clear_surfaces()
	view_lines_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in 4:
		view_lines_mesh.surface_add_vertex(o)
		view_lines_mesh.surface_add_vertex(corners[i])
		view_lines_mesh.surface_add_vertex(corners[i])
		view_lines_mesh.surface_add_vertex(corners[(i + 1) % 4])
	view_lines_mesh.surface_end()

	if lens_label != null:
		lens_label.text = "Lens: %d mm" % roundi(_focal_length_mm())


## The lens as a photographer would describe it (35mm-equivalent focal length).
func _focal_length_mm() -> float:
	return 12.0 / tan(deg_to_rad(shot_camera.fov) * 0.5)


func _set_camera_locked(locked: bool) -> void:
	camera_locked = locked
	if lock_button != null:
		lock_button.set_pressed_no_signal(not locked)
		lock_button.text = "Unlock Camera" if locked else "Lock Camera"
	for b in camera_controls:
		b.disabled = locked
	if locked and current_tool in CAMERA_TOOLS:
		_set_tool("bend")
	if status_label != null:
		_flash_status("Camera locked. It can't be moved by accident." if locked
			else "Camera unlocked. Use the camera tools, or grab the tripod in Studio View.")


func _on_lock_toggled(unlocked: bool) -> void:
	_set_camera_locked(not unlocked)


## Warns once per camera move if frames have already been captured with the old framing.
func _warn_camera_moved() -> void:
	if camera_warned or frame_textures.is_empty():
		return
	camera_warned = true
	_flash_status("Heads up: moving the camera after capturing frames makes your animation jump. "
		+ "Want a new angle? Start a new shot.", 8.0, "Start New Shot", _new_shot.bind(true))


func _camera_change_begins() -> void:
	_push_undo()
	camera_warned = false
	_warn_camera_moved()


func _clamp_camera() -> void:
	var p := shot_camera.global_position
	p.x = clampf(p.x, -3.4, 3.4)
	p.y = clampf(p.y, 0.25, 4.0)
	p.z = clampf(p.z, -2.1, 4.1)
	shot_camera.global_position = p


func _camera_drag(rel: Vector2) -> void:
	var t := shot_camera.global_transform
	match drag_mode:
		"tripod":
			# Camera View: slide the whole tripod across the table, keeping its height and aim.
			# Left/right moves sideways, up/down moves forward and back.
			var flat_right := Vector3(t.basis.x.x, 0, t.basis.x.z).normalized()
			var flat_forward := Vector3(-t.basis.z.x, 0, -t.basis.z.z).normalized()
			t.origin += flat_right * rel.x * TRIPOD_SPEED + flat_forward * -rel.y * TRIPOD_SPEED
		"pan":
			# Swivel in place: left/right turns (pan), up/down tips (tilt). The horizon stays level.
			var b := Basis(Vector3.UP, -rel.x * CAM_TURN_SPEED) * t.basis
			var tilted := b * Basis(Vector3.RIGHT, -rel.y * CAM_TURN_SPEED)
			if absf((tilted * Vector3.FORWARD).y) < 0.97:
				b = tilted
			t.basis = b.orthonormalized()
		"truck":
			# Slide left/right (truck) and up/down (pedestal) without turning.
			var right := t.basis.x.normalized()
			t.origin += right * rel.x * CAM_MOVE_SPEED + Vector3.UP * -rel.y * CAM_MOVE_SPEED
		"dolly":
			# Move toward or away from where the camera points.
			var forward := -t.basis.z.normalized()
			t.origin += forward * -rel.y * CAM_DOLLY_SPEED
		"zoom":
			# Change the lens without moving the camera. Drag up to zoom in.
			shot_camera.fov = clampf(shot_camera.fov + rel.y * CAM_ZOOM_SPEED, 12.0, 75.0)
	shot_camera.global_transform = t
	_clamp_camera()
	_sync_camera()


## Shot size and angle presets frame the puppet from the camera's current side.
func _frame_shot(size_name: String, angle_deg: float) -> void:
	if camera_locked:
		_flash_status("Unlock the camera to change the shot.")
		return
	var figure := _subject_figure()
	if figure.is_empty():
		_flash_status("Add a character first, so the camera has someone to frame.")
		return
	shot_size = size_name
	shot_angle = angle_deg
	_camera_change_begins()
	var subject: Vector3
	var frame_height: float
	var root: Node3D = figure["root"]
	var torso: Node3D = figure["torso"]
	var head: Node3D = figure["head"]
	var height: float = figure["height"]
	match size_name:
		"wide":
			subject = root.global_position + Vector3(0, height * 0.51, 0)
			frame_height = height * 1.45
		"medium":
			subject = torso.global_position + Vector3(0, height * 0.22, 0)
			frame_height = height * 0.72
		_:
			subject = head.to_global(figure["head_center"])
			frame_height = height * 0.375
	var distance := (frame_height * 0.5) / tan(deg_to_rad(shot_camera.fov) * 0.5)
	var flat := shot_camera.global_position - subject
	flat.y = 0.0
	if flat.length() < 0.01:
		flat = Vector3(0, 0, 1)
	flat = flat.normalized()
	var a := deg_to_rad(angle_deg)
	var pos := subject + flat * cos(a) * distance + Vector3.UP * sin(a) * distance
	shot_camera.global_position = pos
	_clamp_camera()
	shot_camera.look_at(subject, Vector3.UP)
	_sync_camera()


func _reset_camera() -> void:
	if camera_locked:
		_flash_status("Unlock the camera to reset it.")
		return
	_camera_change_begins()
	shot_camera.global_transform = camera_default
	shot_camera.fov = camera_default_fov
	_sync_camera()
	_flash_status("Camera back to its default position.")


func _set_camera_default() -> void:
	camera_default = shot_camera.global_transform
	camera_default_fov = shot_camera.fov
	_flash_status("Saved this camera position as the default. Reset Camera now returns here.")


func _set_camera_glow(on: bool) -> void:
	camera_prop_mat.emission_enabled = on


# ---------------------------------------------------------------- input

func _unhandled_input(event: InputEvent) -> void:
	# While a project loads or an export makes fresh frames, the scene isn't the student's to change.
	if busy_overlay != null and busy_overlay.visible:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin_drag(mb.position)
			else:
				_end_drag(mb.position)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_view_zoom(0.9, mb.factor)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_view_zoom(1.1, mb.factor)

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
			_orbit(mm.relative)
		elif dragging:
			if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
				# The button was released somewhere we didn't hear about (e.g. outside the window).
				_end_drag(mm.position)
				return
			if undo_pending:
				undo_pending = false
				if drag_mode in CAMERA_TOOLS or drag_mode == "grab_camera":
					_camera_change_begins()
				elif drag_mode == "grab_light":
					_push_light_undo()
				else:
					_push_undo()
			match drag_mode:
				"bend":
					_bend(mm.position)
				"twist":
					_twist(mm.relative)
				"move":
					_move_to(mm.position)
				"lift":
					_lift(mm.relative)
				"squash":
					_squash_drag(mm.relative)
				"grab_camera":
					_grab_camera_to(mm.position)
				"grab_light":
					_grab_light_to(mm.position)
				"orbit":
					_orbit(mm.relative)
				"pan", "truck", "dolly", "zoom":
					_camera_drag(mm.relative)
		else:
			_update_hover(mm.position)

	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
			if k.keycode == KEY_Z and (k.ctrl_pressed or k.meta_pressed):
				_undo()
				return
			match k.keycode:
				KEY_SPACE:
					_capture_frame()
				KEY_P:
					_toggle_playback(k.shift_pressed)
				KEY_B:
					_set_tool("bend")
				KEY_T:
					_set_tool("twist")
				KEY_M:
					_set_tool("move")
				KEY_U:
					_set_tool("lift")
				KEY_Q:
					_set_tool("squash")
				KEY_DELETE, KEY_BACKSPACE:
					_remove_selected()
				KEY_C:
					_toggle_view()
				KEY_O:
					_cycle_onion_layers()
				KEY_V:
					_reset_view()
				KEY_L:
					_set_camera_locked(not camera_locked)
				KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
					_view_zoom(0.85, 1.0)
				KEY_MINUS, KEY_KP_SUBTRACT:
					_view_zoom(1.15, 1.0)


func _begin_drag(screen_pos: Vector2) -> void:
	# Clicking the scene takes focus away from any text box, so keyboard shortcuts work again.
	get_viewport().gui_release_focus()
	dragging = true
	undo_pending = false

	# Camera tools move the camera wherever you drag. In Studio View, though, grabbing the tripod itself
	# always slides it (whatever camera tool is chosen), and with Move Tripod any drag slides it.
	if current_tool in CAMERA_TOOLS:
		if not camera_view:
			var tripod_t := _pick_camera(screen_pos)
			if (tripod_t < INF or current_tool == "tripod") and _start_tripod_grab(screen_pos, tripod_t):
				return
		drag_mode = current_tool
		undo_pending = true
		Input.set_default_cursor_shape(Input.CURSOR_DRAG)
		return

	var hit := _pick_part(screen_pos)
	var cam_t := _pick_camera(screen_pos)
	var hit_t: float = hit["t"] if not hit.is_empty() else INF
	var lamp := _pick_light(screen_pos)
	var lamp_t: float = lamp.get("t", INF)

	# Grabbing a lamp in Studio View slides it across the table.
	if lamp_t < hit_t and lamp_t < cam_t:
		var role: String = lamp["role"]
		_select_light_role(role)
		if _refuse_if_lighting_locked():
			drag_mode = "none"
			return
		var lamp_origin := work_camera.project_ray_origin(screen_pos)
		var lamp_dir := work_camera.project_ray_normal(screen_pos)
		var lamp_point := lamp_origin + lamp_dir * lamp_t
		move_plane_y = lamp_point.y
		move_offset = (_lighting()["lights"][role]["pos"] as Vector3) - lamp_point
		grab_light_role = role
		drag_mode = "grab_light"
		undo_pending = true
		_update_indicator()
		Input.set_default_cursor_shape(Input.CURSOR_DRAG)
		return

	# Grabbing the tripod in Studio View slides it across the table.
	if cam_t < hit_t:
		if camera_locked:
			drag_mode = "none"
			_flash_status("The camera is locked. Press Unlock Camera (L) to move it.")
			return
		_start_tripod_grab(screen_pos, cam_t)
		return

	if hit.is_empty():
		drag_mode = "none" if camera_view else "orbit"
		if not camera_view:
			Input.set_default_cursor_shape(Input.CURSOR_DRAG)
		return

	var part: Dictionary = hit["part"]
	var point: Vector3 = hit["point"]
	var figure: Dictionary = part["figure"]
	active_part = part
	grab_figure = figure
	selected_figure = figure
	_update_selected_label()
	_set_highlight(part)
	drag_mode = current_tool
	undo_pending = true
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)

	if current_tool == "squash" and figure["kind"] != "prop":
		drag_mode = "none"
		undo_pending = false
		_flash_status("Squash works on props. Try it on a ball!")
		return

	match current_tool:
		"bend":
			if part["is_prop"]:
				var prop_root: Node3D = figure["root"]
				grab_local = prop_root.to_local(point)
				grab_screen_offset = _active_cam().unproject_position(point) - _cam_coords(screen_pos)
				return
			var joint: Node3D = part["joint"]
			grab_local = joint.to_local(point)
			# A click right next to the joint gives almost no leverage, so grab the far end instead.
			if grab_local.length() < 0.12:
				grab_local = part["tip"]
			# Remember where the grabbed spot sits relative to the cursor on screen,
			# so the part never jumps when the drag starts.
			grab_screen_offset = _active_cam().unproject_position(joint.to_global(grab_local)) - _cam_coords(screen_pos)
		"move":
			var figure_root: Node3D = figure["root"]
			move_plane_y = point.y
			move_offset = figure_root.position - point


func _end_drag(screen_pos: Vector2) -> void:
	dragging = false
	drag_mode = ""
	undo_pending = false
	active_part = {}
	grab_figure = {}
	hovered = {}
	hovered_camera = false
	hovered_light = ""
	grab_light_role = ""
	_update_indicator()
	_update_hover(screen_pos)


func _update_hover(screen_pos: Vector2) -> void:
	if capturing:
		return
	if current_tool in CAMERA_TOOLS:
		_set_highlight({})
		hovered = {}
		hovered_light = ""
		_set_lamp_glow("")
		# The tripod still glows under the cursor, since grabbing it slides it.
		var over_tripod := _pick_camera(screen_pos) < INF
		if over_tripod != hovered_camera:
			hovered_camera = over_tripod
			_set_camera_glow(over_tripod)
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND if over_tripod else Input.CURSOR_MOVE)
		return
	var hit := _pick_part(screen_pos)
	var cam_t := _pick_camera(screen_pos)
	var hit_t: float = hit["t"] if not hit.is_empty() else INF
	var lamp := _pick_light(screen_pos)
	var lamp_t: float = lamp.get("t", INF)
	var over_lamp := lamp_t < hit_t and lamp_t < cam_t
	var over_camera := cam_t < hit_t and not over_lamp
	var part: Dictionary = {}
	if not hit.is_empty() and not over_camera and not over_lamp:
		part = hit["part"]
	if over_camera != hovered_camera:
		hovered_camera = over_camera
		_set_camera_glow(over_camera)
	var lamp_role: String = lamp["role"] if over_lamp else ""
	if lamp_role != hovered_light:
		hovered_light = lamp_role
		_set_lamp_glow(lamp_role)
	if not is_same(part, hovered):
		hovered = part
		_set_highlight(part)
	if over_camera or over_lamp or not part.is_empty():
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
	else:
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)


## Returns {"part", "point", "t"} for the nearest puppet part under the cursor, or {} for a miss.
func _pick_part(screen_pos: Vector2) -> Dictionary:
	var cam := _active_cam()
	var p := _cam_coords(screen_pos)
	var origin := cam.project_ray_origin(p)
	var dir := cam.project_ray_normal(p)
	var far_point := origin + dir * 100.0
	var best: Dictionary = {}
	var best_t := INF
	for part in parts:
		var figure_root: Node3D = part["figure"]["root"]
		if not figure_root.visible:
			continue
		for shape in part["shapes"]:
			var mi: MeshInstance3D = shape[0]
			var local_a: Vector3 = shape[1]
			var local_b: Vector3 = shape[2]
			var radius: float = shape[3]
			var t := INF
			if radius < 0.0:
				# Boxes are picked exactly (local_a holds the box's half size).
				t = _ray_box(origin, dir, mi, local_a)
			else:
				t = _ray_capsule(origin, far_point, mi.global_transform * local_a, mi.global_transform * local_b, radius)
			if t < best_t:
				best_t = t
				best = {"part": part, "point": origin + dir * t, "t": t}
	return best


## Distance along the cursor ray to the tripod, or INF if the cursor isn't on it (or it's hidden).
func _pick_camera(screen_pos: Vector2) -> float:
	if camera_view:
		return INF
	var origin := work_camera.project_ray_origin(screen_pos)
	var dir := work_camera.project_ray_normal(screen_pos)
	var far_point := origin + dir * 100.0
	var cam_pos := shot_camera.global_position
	var head_t := _ray_capsule(origin, far_point, cam_pos, cam_pos, CAMERA_PICK_RADIUS)
	var pole_t := _ray_capsule(origin, far_point, cam_pos, Vector3(cam_pos.x, 0.0, cam_pos.z), 0.06)
	return minf(head_t, pole_t)


## Distance along a ray to a box mesh (half = half its size, in the mesh's own space), or INF for a miss.
func _ray_box(origin: Vector3, dir: Vector3, mi: MeshInstance3D, half: Vector3) -> float:
	var world_to_mesh := mi.global_transform.affine_inverse()
	var o := world_to_mesh * origin
	var d := world_to_mesh.basis * dir
	var t_near := -INF
	var t_far := INF
	for i in 3:
		if absf(d[i]) < 0.000001:
			if absf(o[i]) > half[i]:
				return INF
		else:
			var t1 := (-half[i] - o[i]) / d[i]
			var t2 := (half[i] - o[i]) / d[i]
			t_near = maxf(t_near, minf(t1, t2))
			t_far = minf(t_far, maxf(t1, t2))
	if t_far < maxf(t_near, 0.0):
		return INF
	var t_local := t_near if t_near > 0.0 else t_far
	return origin.distance_to(mi.global_transform * (o + d * t_local))


## Distance along a ray to a capsule (a sphere when a == b), or INF for a miss.
func _ray_capsule(origin: Vector3, far_point: Vector3, a: Vector3, b: Vector3, radius: float) -> float:
	var on_ray: Vector3
	var on_shape: Vector3
	if a.is_equal_approx(b):
		on_shape = a
		on_ray = Geometry3D.get_closest_point_to_segment(a, origin, far_point)
	else:
		var pts := Geometry3D.get_closest_points_between_segments(origin, far_point, a, b)
		on_ray = pts[0]
		on_shape = pts[1]
	var d := on_ray.distance_to(on_shape)
	if d > radius:
		return INF
	return origin.distance_to(on_ray) - sqrt(radius * radius - d * d)


func _ray_hit_plane(screen_pos: Vector2, plane: Plane) -> Variant:
	var cam := _active_cam()
	var p := _cam_coords(screen_pos)
	var origin := cam.project_ray_origin(p)
	var dir := cam.project_ray_normal(p)
	return plane.intersects_ray(origin, dir)


## Where a ray meets a sphere. If it crosses twice, take the crossing nearest `current`
## so the part moves smoothly instead of flipping to the far side. If the ray misses,
## take the point on the sphere closest to the ray, so the part points at the cursor.
func _ray_to_sphere(origin: Vector3, dir: Vector3, center: Vector3, radius: float, current: Vector3) -> Vector3:
	var oc := origin - center
	var b := oc.dot(dir)
	var c := oc.dot(oc) - radius * radius
	var disc := b * b - c
	if disc >= 0.0:
		var s := sqrt(disc)
		var near_hit := origin + dir * (-b - s)
		var far_hit := origin + dir * (-b + s)
		if near_hit.distance_to(current) <= far_hit.distance_to(current):
			return near_hit
		return far_hit
	var closest_on_ray := origin + dir * (-b)
	return center + (closest_on_ray - center).normalized() * radius


## Bend: the grabbed spot stays pinned under the cursor, swinging the part around its joint.
## The spot can only travel on a sphere around the joint (the part can't stretch),
## so the target is where the cursor's ray meets that sphere.
func _bend(screen_pos: Vector2) -> void:
	if active_part["is_prop"]:
		_bend_prop(screen_pos)
		return
	var joint: Node3D = active_part["joint"]
	var pivot := joint.global_position
	var grab := joint.to_global(grab_local)
	var reach := grab.distance_to(pivot)
	if reach < 0.03:
		return
	var cam := _active_cam()
	var aim := _cam_coords(screen_pos) + grab_screen_offset
	var origin := cam.project_ray_origin(aim)
	var dir := cam.project_ray_normal(aim)
	var target := _ray_to_sphere(origin, dir, pivot, reach, grab)
	var from_v := grab - pivot
	var to_v := target - pivot
	if from_v.length() < 0.03 or to_v.length() < 0.03:
		return
	# Work out which way the part should now point, then rebuild its pose from that direction
	# plus its stored twist. Rebuilding (instead of stacking small rotations) stops twist from creeping in.
	var q := Quaternion(from_v.normalized(), to_v.normalized())
	var new_dir := Basis(q) * _bone_direction(active_part)
	_aim_part(active_part, new_dir)


## Twist: dragging left or right turns a body part around its own length, or spins a prop in place.
func _twist(rel: Vector2) -> void:
	if active_part["is_prop"]:
		var figure: Dictionary = active_part["figure"]
		var body: Node3D = figure["body"]
		_rotate_figure_about(figure["root"], body.to_global(figure["center"]), Basis(Vector3.UP, rel.x * TWIST_SPEED))
		return
	active_part["twist"] = float(active_part["twist"]) + rel.x * TWIST_SPEED
	_aim_part(active_part, _bone_direction(active_part))


## Bend on a prop: the grabbed spot follows the cursor, tipping and rolling the prop around its center.
func _bend_prop(screen_pos: Vector2) -> void:
	var figure: Dictionary = active_part["figure"]
	var root: Node3D = figure["root"]
	var body: Node3D = figure["body"]
	var center := body.to_global(figure["center"])
	var grab := root.to_global(grab_local)
	var reach := grab.distance_to(center)
	if reach < 0.03:
		return
	var cam := _active_cam()
	var aim := _cam_coords(screen_pos) + grab_screen_offset
	var target := _ray_to_sphere(cam.project_ray_origin(aim), cam.project_ray_normal(aim), center, reach, grab)
	var from_v := grab - center
	var to_v := target - center
	if from_v.length() < 0.03 or to_v.length() < 0.03:
		return
	_rotate_figure_about(root, center, Basis(Quaternion(from_v.normalized(), to_v.normalized())))


## Turns a whole figure around a point in the world.
func _rotate_figure_about(root: Node3D, center: Vector3, rot: Basis) -> void:
	var t := root.global_transform
	t.origin = center + rot * (t.origin - center)
	t.basis = (rot * t.basis).orthonormalized()
	root.global_transform = t


## Lift: drag up to raise whatever you grabbed off the table, down to lower it (for jumps and bounces).
func _lift(rel: Vector2) -> void:
	if grab_figure.is_empty():
		return
	var root: Node3D = grab_figure["root"]
	var step := LIFT_SPEED * (1.0 if camera_view else orbit_distance / DEFAULT_DISTANCE)
	root.position.y = clampf(root.position.y - rel.y * step, 0.0, 3.0)


## Squash: drag up to stretch a prop tall and thin, down to squash it short and wide.
func _squash_drag(rel: Vector2) -> void:
	if grab_figure.is_empty() or grab_figure["kind"] != "prop":
		return
	var amount: float = grab_figure["squash"]
	_set_squash(grab_figure, clampf(amount * exp(-rel.y * SQUASH_SPEED), 0.35, 2.5))


## The way a part currently points, in world space.
func _bone_direction(part: Dictionary) -> Vector3:
	var joint: Node3D = part["joint"]
	var axis: Vector3 = part["axis"]
	return (joint.global_transform.basis * axis).normalized()


## Poses a part so it points along world_dir, using its default pose and its stored twist.
## pose = (swing from the default direction to the new direction) * default pose * (twist around the part's length)
func _aim_part(part: Dictionary, world_dir: Vector3) -> void:
	var joint: Node3D = part["joint"]
	var parent := joint.get_parent() as Node3D
	var parent_basis := parent.global_transform.basis.orthonormalized()
	var local_dir := (parent_basis.inverse() * world_dir).normalized()
	var rest: Transform3D = rest_pose[joint]
	var axis: Vector3 = part["axis"]
	var rest_dir := (rest.basis * axis).normalized()
	if rest_dir.dot(local_dir) < -0.9995:
		# Pointing exactly opposite its default direction has no unique swing; nudge it slightly.
		local_dir = (local_dir + rest.basis.z.normalized() * 0.02).normalized()
	var swing := Basis(Quaternion(rest_dir, local_dir))
	# Twist turns around the part's own length (kept pointing "up-ish" so the turn direction stays consistent).
	var twist_axis := axis.normalized()
	if twist_axis.y < -0.5:
		twist_axis = -twist_axis
	var twist := Basis(twist_axis, float(part["twist"]))
	joint.basis = (swing * rest.basis * twist).orthonormalized()


## Move: whatever you grabbed slides across the tabletop under the cursor.
func _move_to(screen_pos: Vector2) -> void:
	if grab_figure.is_empty():
		return
	var hit_v: Variant = _ray_hit_plane(screen_pos, Plane(Vector3.UP, move_plane_y))
	if hit_v == null:
		return
	var root: Node3D = grab_figure["root"]
	var target: Vector3 = hit_v
	var p := target + move_offset
	p.y = root.position.y
	p.x = clampf(p.x, -3.2, 3.2)
	p.z = clampf(p.z, -2.0, 2.8)
	root.position = p


## Starts sliding the tripod in Studio View. tripod_t: how far along the cursor ray the tripod was hit,
## or INF when the drag started elsewhere (Move Tripod), in which case the grab point is level with the camera.
## Returns false if there's nothing to grab from (the cursor points up into the sky).
func _start_tripod_grab(screen_pos: Vector2, tripod_t: float) -> bool:
	var origin := work_camera.project_ray_origin(screen_pos)
	var dir := work_camera.project_ray_normal(screen_pos)
	var point: Vector3
	if tripod_t < INF:
		point = origin + dir * tripod_t
	else:
		var hit_v: Variant = Plane(Vector3.UP, shot_camera.global_position.y).intersects_ray(origin, dir)
		if hit_v == null:
			return false
		point = hit_v
	move_plane_y = point.y
	move_offset = shot_camera.global_position - point
	drag_mode = "grab_camera"
	undo_pending = true
	_update_indicator()
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)
	return true


## Grabbing the tripod: it slides across the table under the cursor, keeping its height and aim.
func _grab_camera_to(screen_pos: Vector2) -> void:
	var hit_v: Variant = _ray_hit_plane(screen_pos, Plane(Vector3.UP, move_plane_y))
	if hit_v == null:
		return
	var target: Vector3 = hit_v
	var p := target + move_offset
	p.y = shot_camera.global_position.y
	shot_camera.global_position = p
	_clamp_camera()
	_sync_camera()


func _set_highlight(part: Dictionary) -> void:
	if not highlighted.is_empty():
		_apply_glow(highlighted, false)
	highlighted = part
	if not highlighted.is_empty():
		_apply_glow(highlighted, true)


func _apply_glow(part: Dictionary, on: bool) -> void:
	for mat in part["materials"]:
		var m: StandardMaterial3D = mat
		m.emission_enabled = on
		m.emission = HIGHLIGHT_COLOR
		m.emission_energy_multiplier = 0.3


func _set_tool(tool_name: String) -> void:
	if tool_name in CAMERA_TOOLS and camera_locked:
		_flash_status("Unlock the camera (L) to use the camera tools.")
		tool_name = current_tool if current_tool in POSE_TOOLS else "bend"
	current_tool = tool_name
	if tool_buttons.has(tool_name):
		var b: Button = tool_buttons[tool_name]
		b.button_pressed = true
	_update_indicator()


## The indicator light: green Bend, yellow Twist, purple Move Puppet, red Camera.
func _update_indicator() -> void:
	if indicator_style == null:
		return
	var mode := current_tool
	if current_tool in CAMERA_TOOLS or drag_mode == "grab_camera":
		mode = "camera"
	elif drag_mode == "grab_light":
		mode = "light"
	var info: Array = MODE_INFO[mode]
	var color: Color = info[1]
	indicator_style.bg_color = color
	indicator_style.shadow_color = Color(color, 0.6)
	indicator_label.text = info[0]
	indicator_label.add_theme_color_override("font_color", color)
	cursor_label.add_theme_color_override("font_color", color)


# ---------------------------------------------------------------- frames

func _capture_frame() -> void:
	if capturing:
		return
	# Frames whose lighting changed get fresh pictures first, so the onion skin and playback match.
	await _relight_if_needed()
	# Capturing locks the shot's lighting, like a crew locking down before shooting.
	var just_locked := not _lighting_locked()
	if just_locked:
		shots[active_shot]["light_locked"] = true
		_refresh_lighting_panel()
	capturing = true
	if playing:
		_stop_playback()
	# Hide the hover glow and the onion skin ghosts so they never end up in a captured frame.
	_set_highlight({})
	shot_camera.cull_mask = SHOT_CAPTURE_MASK
	await RenderingServer.frame_post_draw
	var img := _keep_size(shot_viewport.get_texture().get_image())
	shot_camera.cull_mask = SHOT_PREVIEW_MASK
	capturing = false
	var restore: Dictionary = active_part if not active_part.is_empty() else hovered
	_set_highlight(restore)

	frame_textures.append(ImageTexture.create_from_image(img))
	frame_poses.append(_get_pose())
	_update_frame_info()
	_update_ghosts()
	flash_rect.color = Color(1, 1, 1, 0.8)
	var tween := create_tween()
	tween.tween_property(flash_rect, "color:a", 0.0, 0.25)
	if just_locked:
		_flash_status("Lighting is now locked for Shot %d, so it stays the same in every frame. " % (active_shot + 1)
			+ "To change it, open Lighting and press Unlock Lighting.", 6.0)


## Shrinks a captured picture to the size kept in memory. Full-size pictures are made fresh at export.
func _keep_size(img: Image) -> Image:
	if img != null and img.get_size() != FRAME_KEEP_SIZE:
		img.resize(FRAME_KEEP_SIZE.x, FRAME_KEEP_SIZE.y, Image.INTERPOLATE_CUBIC)
	return img


func _delete_last_frame() -> void:
	if frame_textures.is_empty():
		_flash_status("No frames to delete yet.")
		return
	if playing:
		_stop_playback()
	frame_textures.pop_back()
	frame_poses.pop_back()
	_update_frame_info()
	_update_ghosts()
	_flash_status("Deleted the last frame.")


func _update_frame_info() -> void:
	frames_label.text = "Frames: %d" % frame_textures.size()
	if frame_textures.is_empty():
		last_frame_rect.texture = null
	else:
		last_frame_rect.texture = frame_textures[frame_textures.size() - 1]
	_refresh_shot_strip()


## Play shows the active shot. Play All (all_shots) shows every shot in order, like a rough cut.
func _toggle_playback(all_shots: bool = false) -> void:
	if playing:
		_stop_playback()
		return
	await _relight_if_needed()
	play_list.clear()
	if all_shots:
		for shot in shots:
			var textures: Array[ImageTexture] = shot["textures"]
			play_list.append_array(textures)
	else:
		play_list.append_array(frame_textures)
	if play_list.is_empty():
		_flash_status("Capture some frames first, then press Play.")
		return
	if camera_view:
		_set_view(false)
	playing = true
	play_index = 0
	play_time = 0.0
	playback_rect.texture = play_list[0]
	playback_rect.visible = true
	var stop_button := play_all_button if all_shots else play_button
	stop_button.text = "Stop (P)"
	_update_ghosts()


func _stop_playback() -> void:
	playing = false
	play_list.clear()
	playback_rect.visible = false
	play_button.text = "Play (P)"
	play_all_button.text = "Play All"
	_update_ghosts()


## Shows a message under the toolbar. action_text and action add a button to the message.
func _flash_status(text: String, seconds: float = 3.0, action_text: String = "", action: Callable = Callable()) -> void:
	if status_label == null:
		return
	status_label.text = text
	status_action = action
	status_action_button.text = action_text
	status_action_button.visible = action.is_valid()
	status_panel.visible = true
	status_timer = seconds


func _on_status_action() -> void:
	status_panel.visible = false
	status_timer = 0.0
	if status_action.is_valid():
		status_action.call()


func _process(delta: float) -> void:
	if autosave_enabled and not loading and not capturing and not exporting:
		autosave_timer += delta
		if autosave_timer >= AUTOSAVE_SECONDS:
			autosave_timer = 0.0
			_autosave()

	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()
	_fit_side_panels()

	if status_timer > 0.0:
		status_timer -= delta
		if status_timer <= 0.0:
			status_panel.visible = false

	# The red view lines only show while the camera is being worked on.
	view_lines.visible = current_tool in CAMERA_TOOLS or hovered_camera or drag_mode == "grab_camera"

	# Small label by the cursor naming what a drag will do.
	var label_text := ""
	if hovered_camera or drag_mode == "grab_camera":
		label_text = "Move Camera"
	elif current_tool in CAMERA_TOOLS:
		label_text = TOOL_NAMES[current_tool]
	elif drag_mode == "grab_light" or hovered_light != "":
		var role := grab_light_role if drag_mode == "grab_light" else hovered_light
		label_text = "Move %s Light" % LIGHT_INFO[role][0]
	elif not hovered.is_empty() or (dragging and drag_mode == current_tool):
		label_text = TOOL_NAMES[current_tool]
	cursor_label.visible = label_text != ""
	if cursor_label.visible:
		cursor_label.text = label_text
		cursor_label.position = get_viewport().get_mouse_position() + Vector2(18, 14)

	# Arrow keys look around, unless the student is typing in a text box.
	if not camera_view and not (get_viewport().gui_get_focus_owner() is LineEdit):
		var turn := 0.0
		var tilt := 0.0
		if Input.is_key_pressed(KEY_LEFT):
			turn -= 1.0
		if Input.is_key_pressed(KEY_RIGHT):
			turn += 1.0
		if Input.is_key_pressed(KEY_UP):
			tilt -= 1.0
		if Input.is_key_pressed(KEY_DOWN):
			tilt += 1.0
		if turn != 0.0 or tilt != 0.0:
			orbit_yaw += turn * 1.5 * delta
			orbit_pitch += tilt * 1.0 * delta
			_update_orbit()

	if playing and play_list.size() > 0:
		play_time += delta
		var step := 1.0 / float(playback_fps)
		while play_time >= step:
			play_time -= step
			play_index = (play_index + 1) % play_list.size()
		playback_rect.texture = play_list[play_index]


# ---------------------------------------------------------------- shots

## lighting: the shot's lighting setup ({} for the default). light_locked: lighting can't change until
## unlocked. relight: its lighting changed since its frames' pictures were made.
## set_data: the shot's backdrop and floor ({} for the default).
func _make_shot(label: String = "", lighting: Dictionary = {}, set_data: Dictionary = {}) -> Dictionary:
	var poses: Array[Dictionary] = []
	var textures: Array[ImageTexture] = []
	var undo: Array[Dictionary] = []
	if lighting.is_empty():
		lighting = _make_lighting(DEFAULT_LIGHT_PRESET, DEFAULT_LIGHT_AIM)
	if set_data.is_empty():
		set_data = {"backdrop": DEFAULT_BACKDROP, "floor": DEFAULT_FLOOR}
	return {"label": label, "poses": poses, "textures": textures, "undo": undo, "working": {},
		"lighting": lighting, "light_locked": false, "relight": false, "set": set_data}


## Points frame_poses, frame_textures, and undo_stack at the active shot's own arrays,
## so capture, delete, onion skin, and undo all work on that shot.
func _bind_active_shot() -> void:
	var shot: Dictionary = shots[active_shot]
	frame_poses = shot["poses"]
	frame_textures = shot["textures"]
	undo_stack = shot["undo"]


## "Shot 2", or "Shot 2 (CU of Kid's face)" when it has a label.
func _shot_name(index: int) -> String:
	var label := str(shots[index]["label"]).strip_edges()
	return "Shot %d" % (index + 1) if label == "" else "Shot %d (%s)" % [index + 1, label]


func _total_frames() -> int:
	var total := 0
	for shot in shots:
		total += (shot["poses"] as Array).size()
	return total


## Puts the scene and camera back where the active shot was left: where the student
## was working when they switched away, or else its last frame.
func _load_shot_scene() -> void:
	var shot: Dictionary = shots[active_shot]
	var pose: Dictionary = shot["working"]
	if pose.is_empty() and not frame_poses.is_empty():
		pose = frame_poses[frame_poses.size() - 1]
	if not pose.is_empty():
		_apply_pose(pose)
	_apply_look(shot)
	_refresh_lighting_panel()
	_refresh_backdrop_panel()
	camera_warned = false
	shot_label_edit.text = str(shot["label"])
	_update_shot_title()
	_update_frame_info()
	_update_ghosts()


func _switch_shot(index: int) -> void:
	if index == active_shot or capturing or exporting or loading:
		_refresh_shot_strip()
		return
	if playing:
		_stop_playback()
	shots[active_shot]["working"] = _get_pose()
	await _relight_if_needed()
	active_shot = index
	_bind_active_shot()
	_load_shot_scene()
	_flash_status("Now working on %s." % _shot_name(index))


## Starts a new shot right after the active one. It picks up exactly where the active shot
## leaves off (same characters, poses, and camera), so the action can continue across the cut.
## from_warning: started from the "moved the camera" warning, so the old shot keeps its old camera.
func _new_shot(from_warning: bool = false) -> void:
	if capturing or exporting or loading:
		return
	if shots.size() >= MAX_SHOTS:
		_flash_status("That's the most shots one project can hold (%d)." % MAX_SHOTS)
		return
	if playing:
		_stop_playback()
	var working := _get_pose()
	if from_warning and not frame_poses.is_empty():
		var last: Dictionary = frame_poses[frame_poses.size() - 1]
		working["camera"] = last["camera"]
		working["fov"] = last["fov"]
	shots[active_shot]["working"] = working
	var from_name := "Shot %d" % (active_shot + 1)
	# The new shot starts with the same lighting, unlocked until its first capture.
	var lighting: Dictionary = _lighting().duplicate(true)
	var set_data: Dictionary = _shot_set().duplicate()
	active_shot += 1
	shots.insert(active_shot, _make_shot("", lighting, set_data))
	_bind_active_shot()
	_refresh_lighting_panel()
	_refresh_backdrop_panel()
	camera_warned = false
	shot_label_edit.text = ""
	_update_shot_title()
	_update_frame_info()
	_update_ghosts()
	var next_step := "Unlock the camera (L) and set up your new angle, then capture." if camera_locked \
		else "Set up your new angle, then capture."
	_flash_status("Started Shot %d. It picks up where %s left off. %s" % [active_shot + 1, from_name, next_step], 7.0)


## Moves the active shot one place earlier (-1) or later (+1) in the order.
func _move_shot(direction: int) -> void:
	var to := active_shot + direction
	if to < 0 or to >= shots.size():
		_flash_status("That's already the %s shot." % ("first" if direction < 0 else "last"))
		return
	var shot: Dictionary = shots[active_shot]
	shots.remove_at(active_shot)
	shots.insert(to, shot)
	active_shot = to
	_update_shot_title()
	_refresh_shot_strip()
	_flash_status("Moved it. It's now Shot %d." % (to + 1))


func _on_shot_label_changed(text: String) -> void:
	shots[active_shot]["label"] = text
	_update_shot_title()
	_refresh_shot_strip()


func _delete_shot_pressed() -> void:
	if shots.size() <= 1:
		_flash_status("A project needs at least one shot. To remove frames, use Delete Last Frame.", 5.0)
		return
	var count := frame_poses.size()
	_confirm("Delete %s and its %d frame%s? You can press Undo right after to bring it back." % [
		_shot_name(active_shot), count, "" if count == 1 else "s"], _delete_shot)


func _delete_shot() -> void:
	if playing:
		_stop_playback()
	var index := active_shot
	var removed: Dictionary = shots[index]
	removed["working"] = _get_pose()
	var removed_name := _shot_name(index)
	shots.remove_at(index)
	active_shot = maxi(index - 1, 0)
	_bind_active_shot()
	_load_shot_scene()
	# Undo in the shot the student lands on brings the deleted shot back.
	undo_stack.append({"restore_shot": removed, "index": index})
	if undo_stack.size() > MAX_UNDO:
		undo_stack.pop_front()
	_flash_status("Deleted %s. Press Undo (Ctrl+Z) now if you want it back." % removed_name, 6.0)


func _restore_deleted_shot(shot: Dictionary, index: int) -> void:
	if playing:
		_stop_playback()
	shots[active_shot]["working"] = _get_pose()
	active_shot = clampi(index, 0, shots.size())
	shots.insert(active_shot, shot)
	_bind_active_shot()
	_load_shot_scene()
	_flash_status("Brought back %s." % _shot_name(active_shot))


func _update_shot_title() -> void:
	if shot_title == null:
		return
	var shot_name := "SHOT %d" % (active_shot + 1)
	shot_title.text = "%s: you're looking through the camera" % shot_name if camera_view \
		else "%s CAMERA: this is what gets captured" % shot_name


## Rebuilds the row of shot cards. Each card shows the shot's first frame, its number,
## frame count, and label. The last card starts a new shot.
func _refresh_shot_strip() -> void:
	if shot_cards == null:
		return
	for child in shot_cards.get_children():
		shot_cards.remove_child(child)
		child.queue_free()
	for i in shots.size():
		var shot: Dictionary = shots[i]
		var textures: Array[ImageTexture] = shot["textures"]
		var count := textures.size()
		var label := str(shot["label"]).strip_edges()
		var card := _make_shot_card()
		card.toggle_mode = true
		card.button_pressed = i == active_shot
		if count > 0:
			card.icon = textures[0]
		var count_text := "no frames yet" if count == 0 else "%d frame%s" % [count, "" if count == 1 else "s"]
		card.text = "Shot %d · %s\n%s" % [i + 1, count_text, label]
		card.tooltip_text = "%s: %s. Click to work on this shot." % [_shot_name(i), count_text]
		card.pressed.connect(_switch_shot.bind(i))
		shot_cards.add_child(card)
	var add_card := _make_shot_card()
	add_card.text = "+ New Shot"
	add_card.tooltip_text = "Start a new shot: a new camera setup. It picks up exactly where this shot leaves off, so the action can continue across the cut."
	add_card.disabled = shots.size() >= MAX_SHOTS
	add_card.pressed.connect(_new_shot)
	shot_cards.add_child(add_card)
	_scroll_to_active_card.call_deferred()


## Scrolls the strip so the active shot's card is in view. Runs after layout, when the cards have their sizes.
func _scroll_to_active_card() -> void:
	if active_shot < shot_cards.get_child_count():
		shot_scroll.ensure_control_visible(shot_cards.get_child(active_shot) as Control)


func _make_shot_card() -> Button:
	var card := Button.new()
	card.focus_mode = Control.FOCUS_NONE
	card.custom_minimum_size = Vector2(136, 104)
	card.add_theme_font_size_override("font_size", 13)
	card.expand_icon = true
	card.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	card.clip_text = true
	return card


## The shot strip along the bottom: the shot controls on top, then a scrolling row of shot cards.
func _build_shot_strip(parent: Control) -> void:
	var strip := PanelContainer.new()
	shot_strip = strip
	strip.mouse_filter = Control.MOUSE_FILTER_STOP
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.size_flags_vertical = Control.SIZE_SHRINK_END
	parent.add_child(strip)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	strip.add_child(box)

	# A flow row, so the controls wrap instead of pushing the shot panel off screen when space is tight.
	var controls := HFlowContainer.new()
	controls.add_theme_constant_override("h_separation", 6)
	controls.add_theme_constant_override("v_separation", 6)
	box.add_child(controls)
	var title := Label.new()
	title.text = "SHOTS"
	title.add_theme_font_size_override("font_size", 14)
	title.tooltip_text = "A shot is everything one camera setup records, from the start until the cut. " \
		+ "Each shot has its own frames and camera. You'll cut your shots together in Premiere."
	title.mouse_filter = Control.MOUSE_FILTER_STOP
	controls.add_child(title)
	shot_label_edit = LineEdit.new()
	shot_label_edit.placeholder_text = "Label this shot (like CU of Kid's face)"
	shot_label_edit.max_length = SHOT_LABEL_MAX
	shot_label_edit.custom_minimum_size = Vector2(250, 0)
	shot_label_edit.tooltip_text = "A short name for the selected shot, to match your storyboard. Shot sizes are often shortened: WS = wide, MS = medium, CU = close-up."
	shot_label_edit.text_changed.connect(_on_shot_label_changed)
	shot_label_edit.text_submitted.connect(func(_text: String) -> void: shot_label_edit.release_focus())
	controls.add_child(shot_label_edit)
	_add_button(controls, "Move Earlier", "Move the selected shot one place earlier in the order.", _move_shot.bind(-1))
	_add_button(controls, "Move Later", "Move the selected shot one place later in the order.", _move_shot.bind(1))
	_add_button(controls, "Delete Shot", "Delete the selected shot and all its frames. You can undo right after.", _delete_shot_pressed)

	shot_scroll = ScrollContainer.new()
	shot_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	shot_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	shot_scroll.custom_minimum_size = Vector2(0, 116)
	box.add_child(shot_scroll)
	shot_cards = HBoxContainer.new()
	shot_cards.add_theme_constant_override("separation", 6)
	shot_scroll.add_child(shot_cards)


# ---------------------------------------------------------------- lighting
# Each shot has its own lighting setup (see "Lighting design" in the design document):
#   {preset, room (0-100), aim (the point every lamp points at),
#    lights: {key/fill/back: {on, brightness (0-100), temp (Kelvin), gel, pos}}}
# Frames store poses, not lighting, so changing a shot's lighting relights every frame in it together.

## The three lamps (spot lights) and their models on stands, seen only in Studio View.
func _build_lights() -> void:
	for role in LIGHT_ROLES:
		var spot := SpotLight3D.new()
		spot.name = "%sLight" % role.capitalize()
		spot.spot_angle = LIGHT_SPREAD[role]
		spot.spot_angle_attenuation = 0.6
		# Only the key light casts shadows: fill light is soft in real life, and one shadow keeps the app fast.
		spot.shadow_enabled = role == "key"
		spot.shadow_bias = 0.04
		spot.shadow_normal_bias = 1.5
		add_child(spot)
		light_nodes[role] = spot
		lamp_models[role] = _build_lamp_model(role)


func _build_lamp_model(role: String) -> Dictionary:
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.16, 0.16, 0.18)
	body_mat.roughness = 0.5
	body_mat.emission = Color(0.35, 0.6, 1.0)
	body_mat.emission_energy_multiplier = 0.8
	var glow_mat := StandardMaterial3D.new()
	glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	# The lamp head points along -Z, so look_at aims it.
	var head := Node3D.new()
	add_child(head)
	var can := MeshInstance3D.new()
	var can_mesh := CylinderMesh.new()
	can_mesh.top_radius = 0.13
	can_mesh.bottom_radius = 0.09
	can_mesh.height = 0.24
	can.mesh = can_mesh
	can.rotation_degrees = Vector3(-90, 0, 0)
	can.material_override = body_mat
	head.add_child(can)
	var lens := MeshInstance3D.new()
	var lens_mesh := CylinderMesh.new()
	lens_mesh.top_radius = 0.12
	lens_mesh.bottom_radius = 0.12
	lens_mesh.height = 0.01
	lens.mesh = lens_mesh
	lens.rotation_degrees = Vector3(-90, 0, 0)
	lens.position = Vector3(0, 0, -0.125)
	lens.material_override = glow_mat
	head.add_child(lens)

	# The pole is 1 unit tall and stretched to the lamp's height in _apply_lighting.
	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.02
	pole_mesh.bottom_radius = 0.02
	pole_mesh.height = 1.0
	pole.mesh = pole_mesh
	pole.material_override = body_mat
	add_child(pole)

	for mi in [can, lens, pole]:
		var m: MeshInstance3D = mi
		m.layers = LAYER_CAMERA_PROP
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var label := Label3D.new()
	label.text = LIGHT_INFO[role][1]
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.font_size = 40
	label.outline_size = 8
	label.pixel_size = 0.004
	label.layers = LAYER_CAMERA_PROP
	add_child(label)
	return {"head": head, "pole": pole, "body_mat": body_mat, "glow_mat": glow_mat, "label": label}


## A lighting setup from a mood preset, centered on aim.
func _make_lighting(preset_key: String, aim: Vector3) -> Dictionary:
	var preset: Dictionary = LIGHT_PRESETS[preset_key]
	var lights := {}
	for role in LIGHT_ROLES:
		var p: Dictionary = preset[role]
		var offset: Vector3 = p["offset"]
		var pos := offset if role == "bg" else Vector3(aim.x + offset.x, offset.y, aim.z + offset.z)
		lights[role] = {"on": p["on"], "brightness": float(p["brightness"]), "temp": int(p["temp"]),
			"gel": str(p.get("gel", "none")), "pos": _clamp_lamp(pos)}
	return {"preset": preset_key, "room": float(preset["room"]), "aim": aim, "lights": lights}


## Fills in anything missing from a saved lighting setup (older files, damaged files).
func _clean_lighting(raw: Variant) -> Dictionary:
	var setup := _make_lighting(DEFAULT_LIGHT_PRESET, DEFAULT_LIGHT_AIM)
	if typeof(raw) != TYPE_DICTIONARY:
		return setup
	var saved: Dictionary = raw
	if saved.get("aim") is Vector3:
		setup["aim"] = saved["aim"]
	setup["preset"] = str(saved.get("preset", "custom"))
	setup["room"] = clampf(float(saved.get("room", setup["room"])), 0.0, 100.0)
	var saved_lights: Variant = saved.get("lights")
	# Lighting saved before the background light existed keeps its old look: background light off.
	if typeof(saved_lights) != TYPE_DICTIONARY or not (saved_lights as Dictionary).has("bg"):
		setup["lights"]["bg"]["on"] = false
	if typeof(saved_lights) == TYPE_DICTIONARY:
		for role in LIGHT_ROLES:
			var info: Variant = (saved_lights as Dictionary).get(role)
			if typeof(info) != TYPE_DICTIONARY:
				continue
			var light: Dictionary = setup["lights"][role]
			var d: Dictionary = info
			light["on"] = bool(d.get("on", light["on"]))
			light["brightness"] = clampf(float(d.get("brightness", light["brightness"])), 0.0, 100.0)
			light["temp"] = clampi(int(d.get("temp", light["temp"])), TEMP_MIN, TEMP_MAX)
			light["gel"] = str(d.get("gel", "none")) if GELS.has(str(d.get("gel", "none"))) else "none"
			if d.get("pos") is Vector3:
				light["pos"] = _clamp_lamp(d["pos"])
	return setup


func _clamp_lamp(p: Vector3) -> Vector3:
	return Vector3(clampf(p.x, -3.4, 3.4), clampf(p.y, LAMP_MIN_HEIGHT, LAMP_MAX_HEIGHT), clampf(p.z, -2.1, 4.1))


func _lighting() -> Dictionary:
	return shots[active_shot]["lighting"]


## A color temperature in Kelvin as a light color: low numbers are warm (orange), high numbers cool (blue).
func _kelvin_color(kelvin: float) -> Color:
	var t := kelvin / 100.0
	var r := 255.0
	var g: float
	var b := 255.0
	if t <= 66.0:
		g = 99.4708025861 * log(t) - 161.1195681661
		b = 0.0 if t <= 19.0 else 138.5177312231 * log(t - 10.0) - 305.0447927307
	else:
		r = 329.698727446 * pow(t - 60.0, -0.1332047592)
		g = 288.1221695283 * pow(t - 60.0, -0.0755148492)
	var c := Color(clampf(r, 0.0, 255.0) / 255.0, clampf(g, 0.0, 255.0) / 255.0, clampf(b, 0.0, 255.0) / 255.0)
	var top := maxf(c.r, maxf(c.g, c.b))
	return Color(c.r / top, c.g / top, c.b / top)


func _light_color(light: Dictionary) -> Color:
	var gel: Color = GELS.get(str(light["gel"]), GELS["none"])[1]
	return _kelvin_color(float(light["temp"])) * gel


## Sets the lamps, their models, and the room light from a lighting setup.
func _apply_lighting(setup: Dictionary) -> void:
	var aim: Vector3 = setup["aim"]
	world_environment.ambient_light_energy = float(setup["room"]) * ROOM_ENERGY_SCALE
	for role in LIGHT_ROLES:
		var light: Dictionary = setup["lights"][role]
		var spot: SpotLight3D = light_nodes[role]
		var pos: Vector3 = light["pos"]
		spot.position = pos
		var target: Vector3 = BG_LIGHT_AIM if role == "bg" else aim
		var to_aim := target - pos
		if to_aim.length() > 0.01:
			# look_at can't use "up" when a lamp points straight down.
			var up := Vector3.FORWARD if absf(to_aim.normalized().y) > 0.98 else Vector3.UP
			spot.look_at(target, up)
		spot.spot_range = to_aim.length() + 6.0
		spot.visible = light["on"]
		spot.light_energy = float(light["brightness"]) * LIGHT_ENERGY_SCALE
		var color := _light_color(light)
		spot.light_color = color

		var model: Dictionary = lamp_models[role]
		var head: Node3D = model["head"]
		head.transform = spot.transform
		var pole: MeshInstance3D = model["pole"]
		var height := maxf(pos.y - 0.08, 0.05)
		pole.position = Vector3(pos.x, height * 0.5, pos.z)
		pole.scale = Vector3(1, height, 1)
		var label: Label3D = model["label"]
		label.position = pos + Vector3(0, 0.3, 0)
		label.modulate = color if light["on"] else Color(0.55, 0.55, 0.6)
		var glow: StandardMaterial3D = model["glow_mat"]
		glow.albedo_color = color if light["on"] else Color(0.12, 0.12, 0.14)


## Called after any change to the active shot's lighting.
func _lighting_changed(custom: bool = true) -> void:
	var setup := _lighting()
	if custom:
		setup["preset"] = "custom"
	_apply_lighting(setup)
	if not frame_poses.is_empty():
		shots[active_shot]["relight"] = true
	_refresh_lighting_panel()


func _lighting_locked() -> bool:
	return bool(shots[active_shot]["light_locked"])


## Returns true (after telling the student) when lighting can't be changed right now.
func _refuse_if_lighting_locked() -> bool:
	if not _lighting_locked():
		return false
	_flash_status("Lighting is locked for Shot %d. Press Unlock Lighting in the Lighting panel to change it." % (active_shot + 1), 5.0)
	return true


func _push_light_undo() -> void:
	undo_stack.append({"lighting": _lighting().duplicate(true)})
	if undo_stack.size() > MAX_UNDO:
		undo_stack.pop_front()


## Makes fresh kept pictures for any shot whose lighting changed since its frames were captured.
func _relight_if_needed() -> void:
	var waiting: Array[int] = []
	for i in shots.size():
		if shots[i].get("relight", false):
			waiting.append(i)
	if waiting.is_empty():
		return
	var total := 0
	for s in waiting:
		total += (shots[s]["poses"] as Array).size()
	_begin_render(SHOT_RENDER_SIZE)
	await RenderingServer.frame_post_draw
	var done := 0
	for s in waiting:
		_apply_look(shots[s])
		var poses: Array[Dictionary] = shots[s]["poses"]
		var textures: Array[ImageTexture] = shots[s]["textures"]
		for i in poses.size():
			done += 1
			busy_label.text = "Updating Shot %d's frames: %d of %d" % [s + 1, done, total]
			_apply_pose(poses[i])
			await RenderingServer.frame_post_draw
			textures[i] = ImageTexture.create_from_image(_keep_size(shot_viewport.get_texture().get_image()))
		shots[s]["relight"] = false
	_end_render()
	_update_frame_info()


func _apply_light_preset(preset_key: String) -> void:
	if _refuse_if_lighting_locked():
		return
	_push_light_undo()
	shots[active_shot]["lighting"] = _make_lighting(preset_key, _lighting()["aim"])
	_lighting_changed(false)
	var preset: Dictionary = LIGHT_PRESETS[preset_key]
	_flash_status("%s: %s" % [preset["name"], preset["tip"]], 6.0)


## Moves the whole lighting setup so it's centered on the selected character or prop.
func _center_lights_on_selected() -> void:
	if _refuse_if_lighting_locked():
		return
	if selected_figure.is_empty() or not (selected_figure["root"] as Node3D).visible:
		_flash_status("Click a character or prop first, then press Center on Selected.")
		return
	var root: Node3D = selected_figure["root"]
	var spot := root.global_position
	var target := Vector3(spot.x, clampf(spot.y + float(selected_figure["height"]) * 0.6, 0.2, 2.5), spot.z)
	_push_light_undo()
	var setup := _lighting()
	var old_aim: Vector3 = setup["aim"]
	var shift := Vector3(target.x - old_aim.x, 0.0, target.z - old_aim.z)
	for role in LIGHT_ROLES:
		if role == "bg":
			continue   # The background light stays aimed at the backdrop.
		var light: Dictionary = setup["lights"][role]
		light["pos"] = _clamp_lamp((light["pos"] as Vector3) + shift)
	setup["aim"] = target
	_lighting_changed(false)
	_flash_status("The lights now point at the %s." % str(selected_figure["name"]))


func _on_light_lock_pressed() -> void:
	var shot: Dictionary = shots[active_shot]
	if not shot["light_locked"]:
		shot["light_locked"] = true
		_refresh_lighting_panel()
		await _relight_if_needed()
		_flash_status("Lighting locked for Shot %d." % (active_shot + 1))
		return
	if frame_poses.is_empty():
		_unlock_lighting()
		return
	var count := frame_poses.size()
	_confirm("Unlock lighting for Shot %d? Any change will relight all %d of its frame%s, so they stay consistent." % [
		active_shot + 1, count, "" if count == 1 else "s"], _unlock_lighting)


func _unlock_lighting() -> void:
	shots[active_shot]["light_locked"] = false
	_refresh_lighting_panel()
	_flash_status("Lighting unlocked for Shot %d. It locks again when you press Lock Lighting or capture a frame." % (active_shot + 1), 5.0)


func _apply_lighting_to_all_pressed() -> void:
	if shots.size() <= 1:
		_flash_status("There's only one shot so far. New shots start with this shot's lighting.")
		return
	var frames := 0
	for i in shots.size():
		if i != active_shot:
			frames += (shots[i]["poses"] as Array).size()
	var relight_note := " This relights %d frames in your other shots." % frames if frames > 0 else ""
	_confirm("Give every shot the same lighting as Shot %d?%s" % [active_shot + 1, relight_note], _apply_lighting_to_all)


func _apply_lighting_to_all() -> void:
	for i in shots.size():
		if i == active_shot:
			continue
		shots[i]["lighting"] = _lighting().duplicate(true)
		if not (shots[i]["poses"] as Array).is_empty():
			shots[i]["relight"] = true
	await _relight_if_needed()
	_flash_status("Every shot now has the same lighting as Shot %d." % (active_shot + 1))


## Distance along the cursor ray to the nearest lamp, as {role, t}, or {} (lamps only show in Studio View).
func _pick_light(screen_pos: Vector2) -> Dictionary:
	if camera_view:
		return {}
	var origin := work_camera.project_ray_origin(screen_pos)
	var dir := work_camera.project_ray_normal(screen_pos)
	var far_point := origin + dir * 100.0
	var best := {}
	var best_t := INF
	for role in LIGHT_ROLES:
		var pos: Vector3 = _lighting()["lights"][role]["pos"]
		var head_t := _ray_capsule(origin, far_point, pos, pos, LAMP_PICK_RADIUS)
		var pole_t := _ray_capsule(origin, far_point, pos, Vector3(pos.x, 0.0, pos.z), 0.06)
		var t := minf(head_t, pole_t)
		if t < best_t:
			best_t = t
			best = {"role": role, "t": t}
	return best


func _set_lamp_glow(role: String) -> void:
	for r in LIGHT_ROLES:
		var mat: StandardMaterial3D = lamp_models[r]["body_mat"]
		mat.emission_enabled = r == role


## Dragging a lamp: it slides across the table under the cursor, keeping its height and aim.
func _grab_light_to(screen_pos: Vector2) -> void:
	var hit_v: Variant = _ray_hit_plane(screen_pos, Plane(Vector3.UP, move_plane_y))
	if hit_v == null:
		return
	var light: Dictionary = _lighting()["lights"][grab_light_role]
	var p: Vector3 = (hit_v as Vector3) + move_offset
	p.y = (light["pos"] as Vector3).y
	light["pos"] = _clamp_lamp(p)
	_lighting_changed()


# ---- Lighting panel

func _build_lighting_panel(parent: Control) -> void:
	lighting_panel = PanelContainer.new()
	lighting_panel.visible = false
	lighting_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	lighting_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(lighting_panel)
	# The panel scrolls when the screen is too short to show it all above the shot strip (_fit_lighting_panel).
	lighting_scroll = ScrollContainer.new()
	lighting_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	lighting_panel.add_child(lighting_scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	box.custom_minimum_size = Vector2(390, 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lighting_scroll.add_child(box)
	lighting_box = box

	lighting_title = Label.new()
	lighting_title.add_theme_font_size_override("font_size", 14)
	box.add_child(lighting_title)

	var lock_row := HBoxContainer.new()
	box.add_child(lock_row)
	light_lock_button = _add_button(lock_row, "Lock Lighting", "", _on_light_lock_pressed)
	light_lock_label = Label.new()
	light_lock_label.add_theme_font_size_override("font_size", 12)
	light_lock_label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	light_lock_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	light_lock_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lock_row.add_child(light_lock_label)

	var mood_row := HBoxContainer.new()
	box.add_child(mood_row)
	var mood_title := Label.new()
	mood_title.text = "Mood:"
	mood_title.tooltip_text = "Start from a lighting mood, then adjust each light. Hover over a mood to see what it's for."
	mood_title.mouse_filter = Control.MOUSE_FILTER_STOP
	mood_row.add_child(mood_title)
	light_preset_button = MenuButton.new()
	light_preset_button.flat = false
	light_preset_button.focus_mode = Control.FOCUS_NONE
	light_preset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	light_preset_button.tooltip_text = mood_title.tooltip_text
	var popup := light_preset_button.get_popup()
	popup.theme = ui_theme
	var keys: Array = LIGHT_PRESETS.keys()
	for i in keys.size():
		var preset: Dictionary = LIGHT_PRESETS[keys[i]]
		popup.add_item(str(preset["name"]), i)
		popup.set_item_tooltip(i, str(preset["tip"]))
	popup.id_pressed.connect(func(index: int) -> void: _apply_light_preset(str(keys[index])))
	mood_row.add_child(light_preset_button)
	light_controls.append(light_preset_button)

	light_room_slider = _add_light_slider(box, "Room light", "Soft light that fills the whole room. Turn it down for dark, dramatic moods; up for bright ones.", 0.0, 100.0, 1.0)
	light_room_slider.value_changed.connect(func(value: float) -> void:
		if _light_slider_change():
			_lighting()["room"] = value
			_lighting_changed())

	box.add_child(HSeparator.new())
	var role_row := HBoxContainer.new()
	box.add_child(role_row)
	var role_group := ButtonGroup.new()
	for role in LIGHT_ROLES:
		var b := _make_button(LIGHT_INFO[role][0], LIGHT_INFO[role][2])
		b.toggle_mode = true
		b.button_group = role_group
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_select_light_role.bind(role))
		role_row.add_child(b)
		light_role_buttons[role] = b

	# The On switch sits beside the light buttons. Plain switch look (the theme's button colors don't fit it).
	light_on_check = CheckButton.new()
	light_on_check.text = "On"
	light_on_check.focus_mode = Control.FOCUS_NONE
	light_on_check.tooltip_text = "Turn this light on or off. Some moods use only one or two lights."
	for state in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		light_on_check.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	for state in ["font_pressed_color", "font_hover_pressed_color"]:
		light_on_check.add_theme_color_override(state, Color(0.95, 0.95, 0.97))
	light_on_check.toggled.connect(func(on: bool) -> void:
		if lighting_ui_updating:
			return
		_push_light_undo()
		_lighting()["lights"][light_role]["on"] = on
		_lighting_changed())
	var on_row := HBoxContainer.new()
	on_row.add_theme_constant_override("separation", 10)
	box.add_child(on_row)
	on_row.add_child(light_on_check)
	light_role_info = Label.new()
	light_role_info.add_theme_font_size_override("font_size", 12)
	light_role_info.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	light_role_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	light_role_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	on_row.add_child(light_role_info)
	light_controls.append(light_on_check)

	light_brightness_slider = _add_light_slider(box, "Brightness", "How strong this light is.", 0.0, 100.0, 1.0)
	light_brightness_slider.value_changed.connect(func(value: float) -> void:
		if _light_slider_change():
			_lighting()["lights"][light_role]["brightness"] = value
			_lighting_changed())

	light_temp_slider = _add_light_slider(box, "Color temperature", "Warm (orange) to cool (blue), measured in Kelvin. "
		+ "Indoor tungsten bulbs are about 3200K; daylight is about 5600K.", TEMP_MIN, TEMP_MAX, 100.0)
	light_temp_slider.value_changed.connect(func(value: float) -> void:
		if _light_slider_change():
			_lighting()["lights"][light_role]["temp"] = int(value)
			_lighting_changed())

	var gel_row := HBoxContainer.new()
	box.add_child(gel_row)
	var gel_title := Label.new()
	gel_title.text = "Gel:"
	gel_title.tooltip_text = "A gel is a sheet of colored plastic clipped in front of a light to tint it. Try blue for night or red for danger."
	gel_title.mouse_filter = Control.MOUSE_FILTER_STOP
	gel_row.add_child(gel_title)
	light_gel_option = OptionButton.new()
	light_gel_option.focus_mode = Control.FOCUS_NONE
	light_gel_option.tooltip_text = gel_title.tooltip_text
	light_gel_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for key in GELS:
		light_gel_option.add_item(str(GELS[key][0]))
	light_gel_option.item_selected.connect(func(index: int) -> void:
		if lighting_ui_updating:
			return
		_push_light_undo()
		_lighting()["lights"][light_role]["gel"] = str(GELS.keys()[index])
		_lighting_changed())
	gel_row.add_child(light_gel_option)
	light_controls.append(light_gel_option)

	light_height_slider = _add_light_slider(box, "Height", "Raise or lower this lamp. High light looks natural; light from down low looks strange and scary. "
		+ "To move a lamp around the subject, drag it in Studio View.", LAMP_MIN_HEIGHT, LAMP_MAX_HEIGHT, 0.05)
	light_height_slider.value_changed.connect(func(value: float) -> void:
		if _light_slider_change():
			var light: Dictionary = _lighting()["lights"][light_role]
			var p: Vector3 = light["pos"]
			light["pos"] = _clamp_lamp(Vector3(p.x, value, p.z))
			_lighting_changed())

	box.add_child(HSeparator.new())
	var button_row := HBoxContainer.new()
	box.add_child(button_row)
	light_controls.append(_add_button(button_row, "Center on Selected", "Move the key, fill, and back lights so they point at the selected character or prop. The background light stays on the backdrop.", _center_lights_on_selected))
	_add_button(button_row, "Apply to All Shots", "Give every shot this shot's lighting, so the lighting matches from shot to shot (continuity).", _apply_lighting_to_all_pressed)
	_select_light_role("key")


## Keeps the Backdrop and Lighting panels above the shot strip: on short screens they get scroll bars
## instead of sliding underneath, and when both are open they share the space. Checked every frame,
## since other panels above them can open and close.
func _fit_side_panels() -> void:
	if lighting_panel == null or backdrop_panel == null:
		return
	var open: Array = []
	for entry in [[backdrop_panel, backdrop_scroll, backdrop_box], [lighting_panel, lighting_scroll, lighting_box]]:
		if (entry[0] as Control).visible:
			open.append(entry)
	if open.is_empty():
		return
	var top := (open[0][1] as Control).get_global_rect().position.y
	var bottom := shot_strip.get_global_rect().position.y - 18.0
	# Each panel's own padding, plus the gap between two panels.
	var room := bottom - top - 26.0 * float(open.size() - 1)
	var wants: Array[float] = []
	for entry in open:
		wants.append((entry[2] as Control).get_combined_minimum_size().y)
	var heights: Array[float] = []
	if open.size() == 1:
		heights.append(room)
	else:
		# The first panel gets half, or more if the second doesn't need its half.
		var first := minf(wants[0], maxf(room * 0.5, room - wants[1]))
		heights.append(first)
		heights.append(room - first)
	for i in open.size():
		var scroll: ScrollContainer = open[i][1]
		var h := floorf(clampf(heights[i], minf(wants[i], 120.0), wants[i]))
		if not is_equal_approx(scroll.custom_minimum_size.y, h):
			scroll.custom_minimum_size = Vector2(0, h)


## A slider with its label (and value) on the same line. Drags count as one undo step.
func _add_light_slider(parent: Control, title: String, tip: String, low: float, high: float, step_size: float) -> HSlider:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var title_label := Label.new()
	title_label.text = title + ":"
	title_label.tooltip_text = tip
	title_label.mouse_filter = Control.MOUSE_FILTER_STOP
	title_label.custom_minimum_size = Vector2(235, 0)
	title_label.add_theme_font_size_override("font_size", 14)
	row.add_child(title_label)
	light_slider_titles[title_label] = title
	var slider := HSlider.new()
	slider.min_value = low
	slider.max_value = high
	slider.step = step_size
	slider.tooltip_text = tip
	slider.focus_mode = Control.FOCUS_NONE
	slider.custom_minimum_size = Vector2(130, 0)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.set_meta("title_label", title_label)
	slider.drag_started.connect(func() -> void:
		light_slider_dragging = true
		_push_light_undo())
	slider.drag_ended.connect(func(_changed: bool) -> void: light_slider_dragging = false)
	row.add_child(slider)
	light_controls.append(slider)
	return slider


## True when a slider change came from the student (not from the panel updating itself).
## A click on the slider bar (not a drag) gets its own undo step here.
func _light_slider_change() -> bool:
	if lighting_ui_updating:
		return false
	if not light_slider_dragging:
		_push_light_undo()
	return true


func _select_light_role(role: String) -> void:
	light_role = role
	var b: Button = light_role_buttons[role]
	b.button_pressed = true
	_refresh_lighting_panel()


## Shows the active shot's lighting in the panel, and greys out the controls while lighting is locked.
func _refresh_lighting_panel() -> void:
	if lighting_panel == null:
		return
	lighting_ui_updating = true
	var setup := _lighting()
	var locked := _lighting_locked()
	lighting_title.text = "LIGHTING: SHOT %d" % (active_shot + 1)
	light_lock_button.text = "Unlock Lighting" if locked else "Lock Lighting"
	light_lock_button.tooltip_text = "Unlock to change this shot's lighting. Every frame in the shot is relit together, so it stays consistent." if locked \
		else "Lock this shot's lighting so it can't be changed by accident. It also locks when you capture the shot's first frame."
	light_lock_label.text = "Locked. Unlock to change it." if locked else "Unlocked: set up your lights."
	var preset_key := str(setup["preset"])
	light_preset_button.text = (str(LIGHT_PRESETS[preset_key]["name"]) if LIGHT_PRESETS.has(preset_key) else "Custom") + "..."
	light_room_slider.value = float(setup["room"])
	var light: Dictionary = setup["lights"][light_role]
	light_on_check.button_pressed = light["on"]
	light_role_info.text = LIGHT_INFO[light_role][2]
	light_brightness_slider.value = float(light["brightness"])
	light_temp_slider.value = float(light["temp"])
	light_gel_option.select(GELS.keys().find(str(light["gel"])))
	light_height_slider.value = (light["pos"] as Vector3).y
	for control in light_controls:
		if control is Slider:
			(control as Slider).editable = not locked
		elif control is BaseButton:
			(control as BaseButton).disabled = locked
		elif control is OptionButton:
			(control as OptionButton).disabled = locked
	_update_light_slider_titles()
	lighting_ui_updating = false


## Slider titles show their values, like "Color temperature: 3200K (warm)".
func _update_light_slider_titles() -> void:
	var temp := int(light_temp_slider.value)
	var feel := "warm" if temp < 4300 else ("cool" if temp > 6000 else "neutral")
	var values := {
		light_room_slider: "%d%%" % int(light_room_slider.value),
		light_brightness_slider: "%d%%" % int(light_brightness_slider.value),
		light_temp_slider: "%dK (%s)" % [temp, feel],
		light_height_slider: "%.1f" % light_height_slider.value,
	}
	for slider in values:
		var title_label: Label = (slider as Slider).get_meta("title_label")
		title_label.text = "%s: %s" % [light_slider_titles[title_label], values[slider]]


# ---------------------------------------------------------------- backdrops and floors
# Each shot has a set: {backdrop, floor}. backdrop is "paper:<color>", "scene:<name>", "picture:<id>", or "green".
# Like lighting, the set belongs to the shot, so changing it changes every frame in the shot together.
# Students' pictures (Make a Backdrop) live in backdrop_pictures and are saved once in the project file.

## The curved paper sweep: a wall that curves down onto the table, so there's no seam or horizon line.
## A picture backdrop covers the middle SWEEP_PICTURE_WIDTH (about what a wide shot sees); past that its edges carry on.
func _build_sweep() -> MeshInstance3D:
	var profile: Array[Vector2] = []   # (y, z) points from the top of the wall down to the table
	var normals: Array[Vector2] = []
	profile.append(Vector2(SWEEP_TOP, SWEEP_Z))
	normals.append(Vector2(0, 1))
	var steps := 16
	for i in steps + 1:
		var a := (PI * 0.5) * float(i) / float(steps)
		profile.append(Vector2(SWEEP_RADIUS - SWEEP_RADIUS * sin(a), SWEEP_Z + SWEEP_RADIUS - SWEEP_RADIUS * cos(a)))
		normals.append(Vector2(sin(a), cos(a)))
	var lengths: Array[float] = [0.0]
	for i in range(1, profile.size()):
		lengths.append(lengths[i - 1] + profile[i].distance_to(profile[i - 1]))
	var total: float = lengths[lengths.size() - 1]
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var half := SWEEP_WIDTH * 0.5
	for i in profile.size():
		for x in [-half, half]:
			# A hair above the table, so the two never flicker where they meet.
			verts.append(Vector3(x, profile[i].x + 0.003, profile[i].y))
			norms.append(Vector3(0, normals[i].x, normals[i].y))
			uvs.append(Vector2(x / SWEEP_PICTURE_WIDTH + 0.5, lengths[i] / total))
	var indices := PackedInt32Array()
	for i in profile.size() - 1:
		var a0 := i * 2
		indices.append_array([a0, a0 + 1, a0 + 2, a0 + 1, a0 + 3, a0 + 2])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	return mi


func _clean_set(raw: Variant) -> Dictionary:
	var set_data := {"backdrop": DEFAULT_BACKDROP, "floor": DEFAULT_FLOOR}
	if typeof(raw) != TYPE_DICTIONARY:
		return set_data
	var saved: Dictionary = raw
	var backdrop := str(saved.get("backdrop", DEFAULT_BACKDROP))
	if _backdrop_exists(backdrop):
		set_data["backdrop"] = backdrop
	var floor_key := str(saved.get("floor", DEFAULT_FLOOR))
	if FLOORS.has(floor_key):
		set_data["floor"] = floor_key
	return set_data


func _backdrop_exists(key: String) -> bool:
	if key == "green":
		return true
	if key.begins_with("paper:"):
		return PAPER_COLORS.has(key.trim_prefix("paper:"))
	if key.begins_with("scene:"):
		return BACKDROP_SCENES.has(key.trim_prefix("scene:"))
	if key.begins_with("picture:"):
		return backdrop_pictures.has(key.trim_prefix("picture:"))
	return false


func _backdrop_name(key: String) -> String:
	if key == "green":
		return "Green Screen"
	if key.begins_with("paper:"):
		return "%s paper" % PAPER_COLORS[key.trim_prefix("paper:")][0]
	if key.begins_with("scene:"):
		return str(BACKDROP_SCENES[key.trim_prefix("scene:")][0])
	if key.begins_with("picture:") and backdrop_pictures.has(key.trim_prefix("picture:")):
		return "your picture \"%s\"" % backdrop_pictures[key.trim_prefix("picture:")]["name"]
	return "backdrop"


func _shot_set() -> Dictionary:
	return shots[active_shot]["set"]


## Puts a shot's lighting and set (backdrop and floor) on the stage.
func _apply_look(shot: Dictionary) -> void:
	_apply_lighting(shot["lighting"])
	_apply_set(shot["set"])


func _apply_set(set_data: Dictionary) -> void:
	var backdrop := str(set_data["backdrop"])
	if backdrop == "green":
		sweep.material_override = chroma_mat
	else:
		sweep.material_override = sweep_mat
		if backdrop.begins_with("paper:"):
			sweep_mat.albedo_texture = null
			sweep_mat.albedo_color = PAPER_COLORS[backdrop.trim_prefix("paper:")][1]
		else:
			sweep_mat.albedo_texture = _backdrop_texture(backdrop)
			sweep_mat.albedo_color = Color(1, 1, 1)
	var floor_key := str(set_data["floor"])
	if floor_key == "green" or (floor_key == "paper" and backdrop == "green"):
		floor_mesh.material_override = chroma_mat
		return
	floor_mesh.material_override = floor_mat
	match floor_key:
		"table":
			floor_mat.albedo_texture = null
			floor_mat.albedo_color = TABLE_COLOR
		"paper":
			floor_mat.albedo_texture = null
			floor_mat.albedo_color = _backdrop_floor_color(backdrop)
		_:
			floor_mat.albedo_texture = _floor_texture(floor_key)
			floor_mat.albedo_color = Color(1, 1, 1)
			var scale_by: float = FLOORS[floor_key][2]
			floor_mat.uv1_scale = Vector3(scale_by, scale_by, scale_by)


## The color a "Paper (matches the backdrop)" floor uses: the paper color, or the ground color of a scene or picture.
func _backdrop_floor_color(backdrop: String) -> Color:
	if backdrop.begins_with("paper:"):
		return PAPER_COLORS[backdrop.trim_prefix("paper:")][1]
	if backdrop.begins_with("scene:"):
		return BACKDROP_SCENES[backdrop.trim_prefix("scene:")][1]
	if backdrop.begins_with("picture:"):
		var id := backdrop.trim_prefix("picture:")
		_backdrop_texture(backdrop)   # Works out the picture's ground color the first time.
		return picture_floor_colors.get(id, TABLE_COLOR)
	return TABLE_COLOR


## The picture for a scene or a student's picture, made the first time it's needed.
func _backdrop_texture(backdrop: String) -> Texture2D:
	if backdrop_textures.has(backdrop):
		return backdrop_textures[backdrop]
	var img: Image
	if backdrop.begins_with("scene:"):
		img = _draw_scene(backdrop.trim_prefix("scene:"), BACKDROP_PICTURE_SIZE)
	else:
		var id := backdrop.trim_prefix("picture:")
		img = Image.new()
		if not backdrop_pictures.has(id) or img.load_jpg_from_buffer(Marshalls.base64_to_raw(str(backdrop_pictures[id]["b64"]))) != OK:
			img = Image.create(16, 9, false, Image.FORMAT_RGB8)
			img.fill(PAPER_COLORS["sky"][1])
		picture_floor_colors[id] = _bottom_color(img)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	backdrop_textures[backdrop] = tex
	return tex


## The average color along the bottom of a picture (its "ground"), for a matching paper floor.
func _bottom_color(img: Image) -> Color:
	var strip := img.get_region(Rect2i(0, int(img.get_height() * 0.85), img.get_width(), maxi(1, int(img.get_height() * 0.15))))
	strip.convert(Image.FORMAT_RGB8)
	strip.resize(16, 4, Image.INTERPOLATE_BILINEAR)
	var sum := Color(0, 0, 0)
	for y in 4:
		for x in 16:
			sum += strip.get_pixel(x, y)
	return Color(sum.r / 64.0, sum.g / 64.0, sum.b / 64.0)


func _floor_texture(key: String) -> Texture2D:
	if floor_textures.has(key):
		return floor_textures[key]
	var tex: Texture2D
	match key:
		"grass":
			tex = _noise_floor([Color(0.18, 0.4, 0.14), Color(0.3, 0.56, 0.22), Color(0.42, 0.68, 0.3)], 0.09)
		"sand":
			tex = _noise_floor([Color(0.76, 0.65, 0.44), Color(0.85, 0.75, 0.54), Color(0.92, 0.84, 0.64)], 0.05)
		"pavement":
			tex = _noise_floor([Color(0.3, 0.3, 0.32), Color(0.43, 0.43, 0.45), Color(0.55, 0.55, 0.56)], 0.14)
		"snow":
			tex = _noise_floor([Color(0.82, 0.86, 0.94), Color(0.93, 0.95, 0.99), Color(1, 1, 1)], 0.03)
		_:
			tex = _wood_floor()
	floor_textures[key] = tex
	return tex


func _noise_floor(colors: Array, frequency: float) -> Texture2D:
	var noise := FastNoiseLite.new()
	noise.frequency = frequency
	noise.fractal_octaves = 4
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	ramp.colors = PackedColorArray(colors)
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.generate_mipmaps = true
	tex.noise = noise
	tex.color_ramp = ramp
	return tex


## Wooden floorboards: rows of planks in slightly different browns, with dark seams and a little grain.
func _wood_floor() -> Texture2D:
	var size := 256
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var plank_h := 32
	for row in size / plank_h:
		var x := -rng.randi_range(0, 120)
		while x < size:
			var length := rng.randi_range(90, 170)
			var shade := rng.randf_range(-0.06, 0.06)
			var base := Color(0.55 + shade, 0.37 + shade * 0.8, 0.21 + shade * 0.5)
			img.fill_rect(Rect2i(x, row * plank_h, length, plank_h), base)
			for _line in 5:
				var gy := row * plank_h + rng.randi_range(3, plank_h - 4)
				img.fill_rect(Rect2i(x, gy, length, 1), base.darkened(0.12))
			img.fill_rect(Rect2i(x, row * plank_h, 2, plank_h), base.darkened(0.45))
			x += length
		img.fill_rect(Rect2i(0, row * plank_h, size, 2), Color(0.25, 0.16, 0.09))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


# ---- Painted scenes, drawn in code with simple shapes (no outside art).

func _draw_scene(key: String, size: Vector2i) -> Image:
	var img := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	var w := float(size.x)
	var h := float(size.y)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(key)
	match key:
		"sunny":
			_paint_gradient(img, 0.0, 0.8, Color(0.38, 0.65, 0.95), Color(0.78, 0.9, 1.0))
			_paint_circle(img, w * 0.8, h * 0.2, h * 0.08, Color(1.0, 0.9, 0.45))
			for c in [Vector2(0.2, 0.18), Vector2(0.5, 0.12), Vector2(0.66, 0.3)]:
				_paint_cloud(img, w * c.x, h * c.y, h * 0.05)
			_paint_hills(img, 0.62, 0.05, 2.0, 0.3, Color(0.45, 0.7, 0.4))
			_paint_hills(img, 0.72, 0.04, 3.0, 1.7, Color(0.3, 0.58, 0.28))
		"sunset":
			_paint_gradient(img, 0.0, 0.4, Color(0.3, 0.22, 0.48), Color(0.9, 0.45, 0.5))
			_paint_gradient(img, 0.4, 0.75, Color(0.9, 0.45, 0.5), Color(1.0, 0.75, 0.4))
			_paint_circle(img, w * 0.5, h * 0.7, h * 0.12, Color(1.0, 0.86, 0.5))
			_paint_hills(img, 0.68, 0.05, 2.0, 0.9, Color(0.36, 0.22, 0.38))
			_paint_hills(img, 0.76, 0.03, 3.5, 2.2, Color(0.24, 0.16, 0.27))
		"night":
			_paint_gradient(img, 0.0, 0.8, Color(0.02, 0.03, 0.1), Color(0.1, 0.13, 0.3))
			_paint_stars(img, rng, 0.0, 0.65, 160)
			_paint_circle(img, w * 0.2, h * 0.2, h * 0.07, Color(0.92, 0.92, 0.8))
			_paint_circle(img, w * 0.2 + h * 0.035, h * 0.18, h * 0.065, Color(0.03, 0.04, 0.12))
			_paint_hills(img, 0.7, 0.05, 2.5, 0.4, Color(0.06, 0.08, 0.16))
		"city":
			_paint_gradient(img, 0.0, 0.8, Color(0.45, 0.7, 0.95), Color(0.82, 0.9, 1.0))
			_paint_cloud(img, w * 0.25, h * 0.15, h * 0.045)
			_paint_buildings(img, rng, Color(0.55, 0.58, 0.64), Color(0.72, 0.82, 0.92), 0.0)
			img.fill_rect(Rect2i(0, int(h * 0.8), size.x, size.y), Color(0.42, 0.42, 0.44))
		"city_night":
			_paint_gradient(img, 0.0, 0.8, Color(0.03, 0.03, 0.1), Color(0.14, 0.12, 0.28))
			_paint_stars(img, rng, 0.0, 0.35, 60)
			_paint_buildings(img, rng, Color(0.1, 0.11, 0.16), Color(1.0, 0.85, 0.45), 0.45)
			img.fill_rect(Rect2i(0, int(h * 0.8), size.x, size.y), Color(0.12, 0.12, 0.15))
		"room":
			img.fill_rect(Rect2i(0, 0, size.x, size.y), Color(0.86, 0.78, 0.6))
			# A window with sky and a hill outside.
			var wx := int(w * 0.18)
			var wy := int(h * 0.18)
			var ww := int(w * 0.26)
			var wh := int(h * 0.38)
			var frame := maxi(2, int(h * 0.015))
			img.fill_rect(Rect2i(wx - frame, wy - frame, ww + frame * 2, wh + frame * 2), Color(0.96, 0.96, 0.94))
			var sky := Image.create(ww, wh, false, Image.FORMAT_RGB8)
			_paint_gradient(sky, 0.0, 1.0, Color(0.45, 0.7, 0.95), Color(0.8, 0.9, 1.0))
			_paint_hills(sky, 0.75, 0.08, 1.5, 0.5, Color(0.35, 0.62, 0.3))
			img.blit_rect(sky, Rect2i(0, 0, ww, wh), Vector2i(wx, wy))
			img.fill_rect(Rect2i(wx + ww / 2 - frame / 2, wy, frame, wh), Color(0.96, 0.96, 0.94))
			img.fill_rect(Rect2i(wx, wy + wh / 2 - frame / 2, ww, frame), Color(0.96, 0.96, 0.94))
			# A framed picture on the wall.
			var px := int(w * 0.62)
			var py := int(h * 0.24)
			img.fill_rect(Rect2i(px, py, int(w * 0.16), int(h * 0.22)), Color(0.4, 0.26, 0.15))
			img.fill_rect(Rect2i(px + frame * 2, py + frame * 2, int(w * 0.16) - frame * 4, int(h * 0.22) - frame * 4), Color(0.95, 0.7, 0.35))
			_paint_circle(img, px + w * 0.08, py + h * 0.11, h * 0.05, Color(0.85, 0.35, 0.3))
			# Baseboard and wooden floor.
			img.fill_rect(Rect2i(0, int(h * 0.8), size.x, int(h * 0.04)), Color(0.97, 0.96, 0.92))
			img.fill_rect(Rect2i(0, int(h * 0.84), size.x, size.y), Color(0.55, 0.37, 0.21))
		"underwater":
			_paint_gradient(img, 0.0, 1.0, Color(0.12, 0.58, 0.78), Color(0.02, 0.2, 0.36))
			for _bubble in 30:
				var bx := rng.randf_range(0.0, w)
				var by := rng.randf_range(h * 0.05, h * 0.75)
				_paint_circle(img, bx, by, rng.randf_range(h * 0.006, h * 0.018), Color(0.6, 0.85, 0.95))
			_paint_hills(img, 0.82, 0.03, 3.0, 0.6, Color(0.72, 0.64, 0.43))
			for _weed in 9:
				_paint_seaweed(img, rng.randf_range(0.03, 0.97) * w, h * rng.randf_range(0.45, 0.62), h * 0.86, maxf(2.0, w * 0.008))
	return img


func _paint_gradient(img: Image, top: float, bottom: float, top_color: Color, bottom_color: Color) -> void:
	var h := img.get_height()
	var y0 := int(top * h)
	var y1 := int(bottom * h)
	for y in range(y0, y1):
		var t := float(y - y0) / maxf(1.0, float(y1 - y0))
		img.fill_rect(Rect2i(0, y, img.get_width(), 1), top_color.lerp(bottom_color, t))
	# Anything below the gradient gets its bottom color.
	if bottom >= 1.0 or y1 >= h:
		return
	img.fill_rect(Rect2i(0, y1, img.get_width(), h - y1), bottom_color)


func _paint_circle(img: Image, cx: float, cy: float, r: float, color: Color) -> void:
	for dy in range(int(-r), int(r) + 1):
		var half := sqrt(maxf(0.0, r * r - dy * dy))
		img.fill_rect(Rect2i(int(cx - half), int(cy + dy), int(half * 2.0) + 1, 1), color)


func _paint_cloud(img: Image, cx: float, cy: float, r: float) -> void:
	for p in [Vector3(-1.4, 0.3, 0.75), Vector3(-0.5, -0.2, 1.0), Vector3(0.6, -0.1, 0.9), Vector3(1.5, 0.3, 0.7), Vector3(0.0, 0.4, 0.9)]:
		_paint_circle(img, cx + p.x * r, cy + p.y * r, p.z * r, Color(1, 1, 1))


## Rolling hills from base (a fraction of the height) down to the bottom of the picture.
func _paint_hills(img: Image, base: float, amount: float, waves: float, phase: float, color: Color) -> void:
	var w := img.get_width()
	var h := float(img.get_height())
	var step := maxi(1, w / 480)
	for x in range(0, w, step):
		var t := float(x) / float(w)
		var y := h * (base + amount * sin(t * TAU * waves + phase) + amount * 0.4 * sin(t * TAU * waves * 2.3 + phase * 2.0))
		img.fill_rect(Rect2i(x, int(y), step, img.get_height() - int(y)), color)


func _paint_stars(img: Image, rng: RandomNumberGenerator, top: float, bottom: float, count: int) -> void:
	var dot := maxi(1, img.get_width() / 640)
	for _star in count:
		var x := rng.randi_range(0, img.get_width() - 1)
		var y := rng.randi_range(int(top * img.get_height()), int(bottom * img.get_height()))
		var big := dot * (2 if rng.randf() < 0.15 else 1)
		img.fill_rect(Rect2i(x, y, big, big), Color(1, 1, 0.9))


## A row of buildings standing on the street line, with windows. lit_chance: how many windows glow (night).
func _paint_buildings(img: Image, rng: RandomNumberGenerator, wall: Color, window: Color, lit_chance: float) -> void:
	var w := img.get_width()
	var h := float(img.get_height())
	var ground := int(h * 0.8)
	var x := -rng.randi_range(0, int(w * 0.04))
	while x < w:
		var bw := int(w * rng.randf_range(0.07, 0.13))
		var bh := int(h * rng.randf_range(0.25, 0.6))
		var shade := rng.randf_range(-0.05, 0.05)
		var color := Color(wall.r + shade, wall.g + shade, wall.b + shade)
		img.fill_rect(Rect2i(x, ground - bh, bw - maxi(1, w / 400), bh), color)
		var win := maxi(2, int(h * 0.025))
		var gap := maxi(2, int(h * 0.02))
		var wy := ground - bh + gap
		while wy + win < ground - gap:
			var wx := x + gap
			while wx + win < x + bw - gap:
				var lit := lit_chance <= 0.0 or rng.randf() < lit_chance
				img.fill_rect(Rect2i(wx, wy, win, win), window if lit else color.darkened(0.3))
				wx += win + gap
			wy += win + gap
		x += bw


func _paint_seaweed(img: Image, x: float, top: float, bottom: float, thickness: float) -> void:
	for y in range(int(top), int(bottom)):
		var sway := sin(float(y) * 0.02 + x) * thickness * 2.5
		img.fill_rect(Rect2i(int(x + sway), y, int(thickness), 1), Color(0.15, 0.5, 0.3))


# ---- Choosing a backdrop and floor

func _choose_backdrop(key: String) -> void:
	_change_set("backdrop", key)


func _choose_floor(key: String) -> void:
	_change_set("floor", key)


## Changes the active shot's backdrop or floor. If the shot has frames, asks first, since every frame changes.
func _change_set(field: String, value: String) -> void:
	_refresh_backdrop_panel()   # Show the current choice until it's confirmed.
	var set_data := _shot_set()
	if str(set_data[field]) == value:
		return
	var apply := func() -> void:
		undo_stack.append({"set": set_data.duplicate()})
		if undo_stack.size() > MAX_UNDO:
			undo_stack.pop_front()
		set_data[field] = value
		_set_changed()
		if field == "backdrop" and value == "green" and str(set_data["floor"]) != "green":
			_flash_status("Green screen: in Premiere, Ultra Key removes the green. Make the floor green too, so the whole set keys out.",
				8.0, "Make Floor Green", _choose_floor.bind("green"))
		else:
			var what := _backdrop_name(value) if field == "backdrop" else str(FLOORS[value][0])
			_flash_status("%s: %s." % ["Backdrop" if field == "backdrop" else "Floor", what])
	if frame_poses.is_empty():
		apply.call()
		return
	var count := frame_poses.size()
	_confirm("This changes the %s in all %d frame%s of Shot %d. Go ahead?" % [
		field, count, "" if count == 1 else "s", active_shot + 1], apply)


func _set_changed() -> void:
	_apply_set(_shot_set())
	if not frame_poses.is_empty():
		shots[active_shot]["relight"] = true
	_refresh_backdrop_panel()


## Forgets the project's pictures (New Project, or before opening another project).
func _clear_backdrop_pictures() -> void:
	for key in backdrop_textures.keys():
		if str(key).begins_with("picture:"):
			backdrop_textures.erase(key)
	backdrop_pictures.clear()
	picture_thumbs.clear()
	picture_floor_colors.clear()
	next_picture = 1


func _make_backdrop_pressed() -> void:
	if backdrop_pictures.size() >= MAX_BACKDROP_PICTURES:
		_flash_status("A project can hold %d pictures. Remove one you don't use first." % MAX_BACKDROP_PICTURES, 5.0)
		return
	if OS.has_feature("web"):
		if not _load_export_tools():
			_flash_status("Couldn't open the file picker. Try reloading the page.")
			return
		var api = JavaScriptBridge.get_interface("vcsExport")
		api.openImage(js_image_callback)
		return
	# Running from the Godot editor: use Godot's own file window.
	if image_dialog == null:
		image_dialog = FileDialog.new()
		image_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		image_dialog.access = FileDialog.ACCESS_FILESYSTEM
		image_dialog.use_native_dialog = true
		image_dialog.filters = PackedStringArray(["*.png, *.jpg, *.jpeg, *.webp ; Pictures"])
		image_dialog.file_selected.connect(func(path: String) -> void:
			var img := Image.load_from_file(path)
			if img == null:
				_flash_status("That picture couldn't be opened. Try a JPG or PNG.", 5.0)
				return
			_add_backdrop_picture(path.get_file().get_basename(), img))
		add_child(image_dialog)
	image_dialog.popup_centered_ratio(0.6)


## The browser's picture picker sends back "image:<name>|<JPG as base64>", "cancel", or "error: <reason>".
func _on_js_image_opened(args: Array) -> void:
	var reply := str(args[0]) if args.size() > 0 else ""
	if reply.begins_with("error"):
		_flash_status("Couldn't use that picture: " + reply.trim_prefix("error: "), 6.0)
		return
	if not reply.begins_with("image:"):
		return
	var parts := reply.substr(6).split("|", true, 1)
	var img := Image.new()
	if parts.size() < 2 or img.load_jpg_from_buffer(Marshalls.base64_to_raw(parts[1])) != OK:
		_flash_status("That picture couldn't be opened. Try a JPG or PNG.", 5.0)
		return
	_add_backdrop_picture(parts[0].get_basename(), img)


## Crops a student's picture to fill the backdrop (16:9), shrinks it, keeps it in the project, and uses it.
func _add_backdrop_picture(picture_name: String, img: Image) -> void:
	img.convert(Image.FORMAT_RGB8)
	var aspect := float(BACKDROP_PICTURE_SIZE.x) / float(BACKDROP_PICTURE_SIZE.y)
	var w := img.get_width()
	var h := img.get_height()
	var crop := Rect2i(0, 0, w, h)
	if float(w) / float(h) > aspect:
		crop.size.x = int(h * aspect)
		crop.position.x = (w - crop.size.x) / 2
	else:
		crop.size.y = int(w / aspect)
		crop.position.y = (h - crop.size.y) / 2
	img = img.get_region(crop)
	if img.get_width() > BACKDROP_PICTURE_SIZE.x:
		img.resize(BACKDROP_PICTURE_SIZE.x, BACKDROP_PICTURE_SIZE.y, Image.INTERPOLATE_CUBIC)
	var id := "pic%d" % next_picture
	next_picture += 1
	var label := picture_name.strip_edges()
	backdrop_pictures[id] = {"name": label.left(40) if label != "" else "Picture", "b64": Marshalls.raw_to_base64(img.save_jpg_to_buffer(0.85))}
	_refresh_backdrop_panel()
	_choose_backdrop("picture:" + id)


func _remove_picture_pressed() -> void:
	var backdrop := str(_shot_set()["backdrop"])
	if not backdrop.begins_with("picture:"):
		_flash_status("Pick one of your pictures first, then press Remove Picture.")
		return
	var using := 0
	for shot in shots:
		if str(shot["set"]["backdrop"]) == backdrop:
			using += 1
	_confirm("Remove this picture from your project? %d shot%s using it will go back to Sky Blue paper." % [using, "" if using == 1 else "s"],
		_remove_picture.bind(backdrop))


func _remove_picture(backdrop: String) -> void:
	for shot in shots:
		if str(shot["set"]["backdrop"]) == backdrop:
			shot["set"]["backdrop"] = DEFAULT_BACKDROP
			if not (shot["poses"] as Array).is_empty():
				shot["relight"] = true
		# Undo steps that would bring the picture back can't anymore.
		var undo: Array[Dictionary] = shot["undo"]
		undo.assign(undo.filter(func(step: Dictionary) -> bool: return not (step.has("set") and str(step["set"]["backdrop"]) == backdrop)))
	backdrop_pictures.erase(backdrop.trim_prefix("picture:"))
	picture_thumbs.erase(backdrop.trim_prefix("picture:"))
	backdrop_textures.erase(backdrop)
	_apply_set(_shot_set())
	_refresh_backdrop_panel()
	_flash_status("Removed the picture.")


# ---- Backdrop panel

func _build_backdrop_panel(parent: Control) -> void:
	backdrop_panel = PanelContainer.new()
	backdrop_panel.visible = false
	backdrop_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	backdrop_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(backdrop_panel)
	backdrop_scroll = ScrollContainer.new()
	backdrop_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	backdrop_panel.add_child(backdrop_scroll)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	box.custom_minimum_size = Vector2(390, 0)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	backdrop_scroll.add_child(box)
	backdrop_box = box

	backdrop_title = Label.new()
	backdrop_title.add_theme_font_size_override("font_size", 14)
	box.add_child(backdrop_title)
	var note := Label.new()
	note.text = "The backdrop is the background behind your characters. Changing it changes every frame in this shot."
	note.add_theme_font_size_override("font_size", 12)
	note.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.custom_minimum_size = Vector2(380, 0)
	box.add_child(note)

	_add_section_label(box, "Paper", "Colored paper on a curved sweep, like a real tabletop studio. The curve hides the line where the wall meets the floor.")
	var paper_grid := GridContainer.new()
	paper_grid.columns = 8
	box.add_child(paper_grid)
	for key in PAPER_COLORS:
		var swatch := Image.create(28, 28, false, Image.FORMAT_RGB8)
		swatch.fill(PAPER_COLORS[key][1])
		var b := _make_backdrop_button("paper:" + key, ImageTexture.create_from_image(swatch), "", "%s paper" % PAPER_COLORS[key][0])
		b.custom_minimum_size = Vector2(42, 42)
		paper_grid.add_child(b)

	_add_section_label(box, "Scenes", "Simple painted places. Hover over one to see its name.")
	var scene_grid := GridContainer.new()
	scene_grid.columns = 4
	box.add_child(scene_grid)
	for key in BACKDROP_SCENES:
		var thumb := _draw_scene(key, Vector2i(160, 90))
		var b := _make_backdrop_button("scene:" + key, ImageTexture.create_from_image(thumb), str(BACKDROP_SCENES[key][0]), str(BACKDROP_SCENES[key][0]))
		b.custom_minimum_size = Vector2(92, 74)
		scene_grid.add_child(b)

	_add_section_label(box, "Your pictures", "Make a Backdrop from your own picture: a photo, a drawing you scanned, or anything you made. It's cropped to fit and saved in your project, not online.")
	picture_grid = GridContainer.new()
	picture_grid.columns = 4
	box.add_child(picture_grid)
	var picture_row := HBoxContainer.new()
	box.add_child(picture_row)
	_add_button(picture_row, "Make a Backdrop...", "Use your own picture as the backdrop. It's cropped to fill the backdrop and saved in your project file.", _make_backdrop_pressed)
	remove_picture_button = _add_button(picture_row, "Remove Picture", "Take the selected picture out of your project.", _remove_picture_pressed)

	_add_section_label(box, "Green screen", "Pure green that lights and shadows don't change. In Premiere, the Ultra Key effect removes it so you can put any background behind your characters.")
	var green := Image.create(28, 28, false, Image.FORMAT_RGB8)
	green.fill(CHROMA_GREEN)
	var green_button := _make_backdrop_button("green", ImageTexture.create_from_image(green), "Green Screen", "Green Screen")
	green_button.expand_icon = false
	green_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(green_button)

	box.add_child(HSeparator.new())
	var floor_row := HBoxContainer.new()
	box.add_child(floor_row)
	var floor_title := Label.new()
	floor_title.text = "Floor:"
	floor_title.tooltip_text = "The surface your characters stand on."
	floor_title.mouse_filter = Control.MOUSE_FILTER_STOP
	floor_row.add_child(floor_title)
	floor_option = OptionButton.new()
	floor_option.focus_mode = Control.FOCUS_NONE
	floor_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	floor_option.tooltip_text = floor_title.tooltip_text
	var floor_keys: Array = FLOORS.keys()
	for i in floor_keys.size():
		floor_option.add_item(str(FLOORS[floor_keys[i]][0]))
		floor_option.set_item_tooltip(i, str(FLOORS[floor_keys[i]][1]))
	floor_option.item_selected.connect(func(index: int) -> void:
		if not backdrop_ui_updating:
			_choose_floor(str(floor_keys[index])))
	floor_row.add_child(floor_option)
	_refresh_backdrop_panel()


func _add_section_label(parent: Control, text: String, tip: String) -> void:
	var label := Label.new()
	label.text = text
	label.tooltip_text = tip
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(0.75, 0.77, 0.82))
	parent.add_child(label)


func _make_backdrop_button(key: String, icon: Texture2D, text: String, tip: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.toggle_mode = true
	b.icon = icon
	b.expand_icon = true
	b.text = text
	b.tooltip_text = tip
	b.add_theme_font_size_override("font_size", 11)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.clip_text = true
	b.pressed.connect(_choose_backdrop.bind(key))
	backdrop_buttons[key] = b
	return b


## Shows the active shot's backdrop and floor, and rebuilds the student's picture buttons.
func _refresh_backdrop_panel() -> void:
	if backdrop_panel == null:
		return
	backdrop_ui_updating = true
	backdrop_title.text = "BACKDROP AND FLOOR: SHOT %d" % (active_shot + 1)
	# Picture buttons come and go with the student's pictures.
	for key in backdrop_buttons.keys():
		if str(key).begins_with("picture:"):
			backdrop_buttons.erase(key)
	for child in picture_grid.get_children():
		picture_grid.remove_child(child)
		child.queue_free()
	for id in backdrop_pictures:
		var key := "picture:" + str(id)
		if not picture_thumbs.has(id):
			var img := Image.new()
			if img.load_jpg_from_buffer(Marshalls.base64_to_raw(str(backdrop_pictures[id]["b64"]))) != OK:
				continue
			img.resize(160, 90, Image.INTERPOLATE_BILINEAR)
			picture_thumbs[id] = ImageTexture.create_from_image(img)
		var b := _make_backdrop_button(key, picture_thumbs[id], str(backdrop_pictures[id]["name"]), "Your picture: %s" % backdrop_pictures[id]["name"])
		b.custom_minimum_size = Vector2(92, 74)
		picture_grid.add_child(b)
	var current := str(_shot_set()["backdrop"])
	for key in backdrop_buttons:
		(backdrop_buttons[key] as Button).button_pressed = key == current
	remove_picture_button.disabled = not current.begins_with("picture:")
	floor_option.select(FLOORS.keys().find(str(_shot_set()["floor"])))
	backdrop_ui_updating = false


# ---------------------------------------------------------------- UI

func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 15

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.22, 0.23, 0.27)
	normal.set_corner_radius_all(6)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 7
	normal.content_margin_bottom = 7
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.32, 0.33, 0.38)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = ACCENT
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.16, 0.16, 0.19)
	t.set_stylebox("normal", "Button", normal)
	t.set_stylebox("hover", "Button", hover)
	t.set_stylebox("pressed", "Button", pressed)
	t.set_stylebox("hover_pressed", "Button", pressed)
	t.set_stylebox("disabled", "Button", disabled)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_pressed_color", "Button", Color(0.1, 0.08, 0.05))
	t.set_color("font_hover_pressed_color", "Button", Color(0.1, 0.08, 0.05))
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.46, 0.5))

	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.1, 0.1, 0.12, 0.92)
	panel.set_corner_radius_all(8)
	panel.content_margin_left = 10
	panel.content_margin_right = 10
	panel.content_margin_top = 8
	panel.content_margin_bottom = 8
	t.set_stylebox("panel", "PanelContainer", panel)

	var tip := StyleBoxFlat.new()
	tip.bg_color = Color(0.06, 0.06, 0.08, 0.96)
	tip.set_corner_radius_all(6)
	tip.content_margin_left = 8
	tip.content_margin_right = 8
	tip.content_margin_top = 5
	tip.content_margin_bottom = 5
	t.set_stylebox("panel", "TooltipPanel", tip)

	# Sliders (Lighting panel): a visible track, filled in the accent color up to the handle.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.3, 0.31, 0.36)
	track.set_corner_radius_all(3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	var filled := track.duplicate() as StyleBoxFlat
	filled.bg_color = ACCENT
	t.set_stylebox("slider", "HSlider", track)
	t.set_stylebox("grabber_area", "HSlider", filled)
	t.set_stylebox("grabber_area_highlight", "HSlider", filled)
	return t


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# Camera View screen: a dark background with the shot camera's picture fitted on top.
	camera_backdrop = ColorRect.new()
	camera_backdrop.color = Color(0.05, 0.05, 0.06)
	camera_backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	camera_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camera_backdrop.visible = false
	layer.add_child(camera_backdrop)
	camera_border = ColorRect.new()
	camera_border.color = Color(0.85, 0.85, 0.88)
	camera_border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camera_border.visible = false
	layer.add_child(camera_border)
	camera_screen = TextureRect.new()
	camera_screen.texture = shot_viewport.get_texture()
	camera_screen.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	camera_screen.stretch_mode = TextureRect.STRETCH_SCALE
	camera_screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	camera_screen.visible = false
	layer.add_child(camera_screen)

	var margin := MarginContainer.new()
	ui_theme = _make_theme()
	margin.theme = ui_theme
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 10)
	layer.add_child(margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_theme_constant_override("separation", 8)
	margin.add_child(column)

	# ---- Toolbar: indicator light, then tool/view/pose buttons, then camera buttons.
	toolbar = PanelContainer.new()
	toolbar.mouse_filter = Control.MOUSE_FILTER_STOP
	column.add_child(toolbar)
	var toolbar_rows := VBoxContainer.new()
	toolbar_rows.add_theme_constant_override("separation", 6)
	toolbar.add_child(toolbar_rows)

	var row1 := HBoxContainer.new()
	row1.add_theme_constant_override("separation", 10)
	toolbar_rows.add_child(row1)

	var indicator_box := HBoxContainer.new()
	indicator_box.tooltip_text = "Mode light: green = Bend, yellow = Twist, purple = Move, white = Lift, pink = Squash, red = Camera."
	indicator_box.mouse_filter = Control.MOUSE_FILTER_STOP
	indicator_box.custom_minimum_size = Vector2(150, 0)
	row1.add_child(indicator_box)
	var light := Panel.new()
	light.custom_minimum_size = Vector2(16, 16)
	light.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator_style = StyleBoxFlat.new()
	indicator_style.set_corner_radius_all(8)
	indicator_style.shadow_size = 6
	light.add_theme_stylebox_override("panel", indicator_style)
	indicator_box.add_child(light)
	indicator_label = Label.new()
	indicator_label.add_theme_font_size_override("font_size", 16)
	indicator_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	indicator_box.add_child(indicator_label)

	row1.add_child(VSeparator.new())

	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	row1.add_child(flow)

	var tool_group := ButtonGroup.new()
	_add_group_label(flow, "TOOL")
	for entry in [
		["bend", "Bend (B)", "Drag a body part to pull it into place. The spot you grab follows your cursor."],
		["twist", "Twist (T)", "Drag a body part left or right to turn it around its own length, like turning a head."],
		["move", "Move (M)", "Drag a character or prop to slide it across the table."],
		["lift", "Lift (U)", "Drag up to raise a character or prop off the table, down to lower it. Great for jumps and bounces."],
		["squash", "Squash (Q)", "Drag up to stretch a prop tall and thin, down to squash it flat. Try it on a bouncing ball!"],
	]:
		var b := _add_tool_button(flow, tool_group, entry[0], entry[1], entry[2])
		tool_buttons[entry[0]] = b

	_add_divider(flow)
	_add_group_label(flow, "VIEW")
	var view_group := ButtonGroup.new()
	for entry in [
		["studio", "Studio View", "Walk around the set. Drag empty space to look around, scroll to move closer."],
		["camera", "Camera View (C)", "Look through the shot camera. The darkened edges are outside the frame."],
	]:
		var key: String = entry[0]
		var b := _make_button(entry[1], entry[2])
		b.toggle_mode = true
		b.button_group = view_group
		b.pressed.connect(_set_view.bind(key == "camera"))
		flow.add_child(b)
		view_buttons[key] = b
	_add_button(flow, "View In", "Move your view closer (Studio View). Does not change the shot.", _view_zoom.bind(0.85, 1.0))
	_add_button(flow, "View Out", "Move your view farther away (Studio View). Does not change the shot.", _view_zoom.bind(1.15, 1.0))
	_add_button(flow, "Reset View (V)", "Return to the starting Studio View.", _reset_view)

	_add_divider(flow)
	_add_group_label(flow, "POSE")
	_add_button(flow, "Undo (Ctrl+Z)", "Undo the last posing or camera change.", _undo)
	_add_button(flow, "Reset Pose", "Put every character and prop back in its default pose.", _reset_pose)
	_add_button(flow, "Set as Default Pose", "Make the current scene the one Reset Pose returns to.", _set_default_pose)

	_add_divider(flow)
	_add_group_label(flow, "SCENE")
	flow.add_child(_make_menu_button("Add Character", "Add a person or animal to the scene.", CHARACTER_TYPES, _add_figure))
	flow.add_child(_make_menu_button("Add Prop", "Add an object to the scene.", PROP_TYPES, _add_figure))
	_add_button(flow, "Remove", "Take the selected character or prop (the last one you clicked) out of the scene. (Delete)", _remove_selected)
	var style_button := _make_button("Style", "Change colors (and hairstyles for people) on the selected character or prop.")
	style_button.toggle_mode = true
	style_button.toggled.connect(func(on: bool) -> void:
		style_panel.visible = on
		_refresh_style_panel(true))
	flow.add_child(style_button)
	var list_button := _make_button("Scene List", "Show everything in the scene.")
	list_button.toggle_mode = true
	list_button.toggled.connect(func(on: bool) -> void: scene_list_panel.visible = on)
	flow.add_child(list_button)
	selected_label = Label.new()
	selected_label.add_theme_color_override("font_color", Color(0.75, 0.77, 0.82))
	flow.add_child(selected_label)

	_add_divider(flow)
	_add_group_label(flow, "PROJECT")
	_add_button(flow, "New Project", "Start a new animation from scratch.", func() -> void: _confirm("Start a new project? Your current animation will be replaced. Save it first if you want to keep it.", _new_project))
	_add_button(flow, "Save Project", "Download your project as a small file you can open again later, on any computer.", _save_project)
	_add_button(flow, "Open Project", "Open a project file you saved earlier.", func() -> void: _confirm("Open a project? Your current animation will be replaced. Save it first if you want to keep it.", _open_project))

	_add_divider(flow)
	var help_button := _make_button("How To", "Show or hide how to use the studio: the tools, shortcut keys, and tips.")
	help_button.toggle_mode = true
	help_button.toggled.connect(func(on: bool) -> void: help_panel.visible = on)
	flow.add_child(help_button)
	fps_label = Label.new()
	fps_label.add_theme_font_size_override("font_size", 12)
	fps_label.add_theme_color_override("font_color", Color(0.55, 0.57, 0.62))
	flow.add_child(fps_label)

	# Camera row.
	var cam_flow := HFlowContainer.new()
	cam_flow.add_theme_constant_override("h_separation", 6)
	cam_flow.add_theme_constant_override("v_separation", 6)
	toolbar_rows.add_child(cam_flow)

	_add_group_label(cam_flow, "CAMERA")
	lock_button = _make_button("Unlock Camera", "The camera stays locked so it can't be bumped by accident, like a tripod lock. Unlock it to move it. (L)")
	lock_button.toggle_mode = true
	lock_button.toggled.connect(_on_lock_toggled)
	cam_flow.add_child(lock_button)

	_add_divider(cam_flow)
	_add_group_label(cam_flow, "MOVE")
	for entry in [
		["tripod", "Move Tripod", "Slide the whole camera and tripod around the table. It keeps its height and where it's pointing. (In Studio View you can also grab the tripod anytime.)"],
		["pan", "Pan / Tilt", "Swivel the camera in place. Drag left/right to pan, up/down to tilt."],
		["truck", "Truck / Pedestal", "Slide the camera without turning it. Left/right is a truck, up/down is a pedestal."],
		["dolly", "Dolly", "Move the camera toward or away from what it's pointing at. Drag up to dolly in."],
		["zoom", "Zoom", "Change the lens without moving the camera. Drag up to zoom in. Compare it with a dolly!"],
	]:
		var b := _add_tool_button(cam_flow, tool_group, entry[0], entry[1], entry[2])
		tool_buttons[entry[0]] = b
		camera_controls.append(b)

	_add_divider(cam_flow)
	_add_group_label(cam_flow, "SHOT")
	for entry in [
		["wide", "Wide", "Frame the puppet's whole body with room around it."],
		["medium", "Medium", "Frame the puppet from about the waist up."],
		["close", "Close-up", "Frame the puppet's face."],
	]:
		var size_name: String = entry[0]
		var b := _add_button(cam_flow, entry[1], entry[2], func() -> void: _frame_shot(size_name, shot_angle))
		camera_controls.append(b)

	_add_divider(cam_flow)
	_add_group_label(cam_flow, "ANGLE")
	for entry in [
		[30.0, "High", "Look down on the puppet. It can make a character seem small or weak."],
		[3.0, "Eye Level", "Look at the puppet straight on. The most neutral angle."],
		[-15.0, "Low", "Look up at the puppet. It can make a character seem big or powerful."],
	]:
		var angle: float = entry[0]
		var b := _add_button(cam_flow, entry[1], entry[2], func() -> void: _frame_shot(shot_size, angle))
		camera_controls.append(b)

	_add_divider(cam_flow)
	camera_controls.append(_add_button(cam_flow, "Reset Camera", "Put the camera back in its default position.", _reset_camera))
	camera_controls.append(_add_button(cam_flow, "Set Camera Default", "Make the current camera position the one Reset Camera returns to.", _set_camera_default))
	lens_label = Label.new()
	lens_label.tooltip_text = "The lens focal length. Lower numbers are wider; higher numbers zoom in."
	lens_label.mouse_filter = Control.MOUSE_FILTER_STOP
	cam_flow.add_child(lens_label)

	_add_divider(cam_flow)
	_add_group_label(cam_flow, "SET")
	var backdrop_button := _make_button("Backdrop", "Choose this shot's backdrop (paper, a painted scene, your own picture, or green screen) and floor.")
	backdrop_button.toggle_mode = true
	backdrop_button.toggled.connect(func(on: bool) -> void:
		backdrop_panel.visible = on
		_refresh_backdrop_panel())
	cam_flow.add_child(backdrop_button)
	var lighting_button := _make_button("Lighting", "Set up this shot's key, fill, and back lights, or pick a mood. In Studio View, drag a lamp to move it.")
	lighting_button.toggle_mode = true
	lighting_button.toggled.connect(func(on: bool) -> void:
		lighting_panel.visible = on
		_refresh_lighting_panel())
	cam_flow.add_child(lighting_button)

	# ---- Status messages (appear briefly under the toolbar).
	var status_row := HBoxContainer.new()
	status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(status_row)
	status_panel = PanelContainer.new()
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.visible = false
	status_row.add_child(status_panel)
	var status_box := HBoxContainer.new()
	status_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_box.add_theme_constant_override("separation", 10)
	status_panel.add_child(status_box)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(420, 0)
	status_box.add_child(status_label)
	status_action_button = _add_button(status_box, "", "", _on_status_action)
	status_action_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	status_action_button.visible = false

	# ---- How To panel (hidden until How To is pressed).
	help_panel = PanelContainer.new()
	help_panel.visible = false
	help_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	help_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(help_panel)
	var help_text := Label.new()
	help_text.text = "HOW TO USE THE STUDIO\n" \
		+ "Hover over any button to see what it does.\n" \
		+ "The light at the top left shows your mode: green Bend, yellow Twist, purple Move, white Lift, pink Squash, red Camera.\n" \
		+ "Add Character and Add Prop put new things in the scene. Click something to select it; Remove takes it out.\n" \
		+ "Style changes colors, and hairstyles for people, on whatever is selected.\n" \
		+ "Bend and Twist work on props too. Lift raises anything off the table. Squash stretches and flattens props.\n" \
		+ "Hover over a character or prop: the part you'd grab glows.\n" \
		+ "Drag empty space, right-drag, or use arrow keys to look around (Studio View).\n" \
		+ "Camera View (C): pose while looking through the shot camera.\n" \
		+ "Unlock Camera (L), then use the camera tools, or grab the tripod in Studio View.\n" \
		+ "Backdrop: pick paper, a painted scene, green screen, or Make a Backdrop from your own picture. Pick a floor too.\n" \
		+ "Lighting: pick a mood, then adjust the key, fill, back, and background lights. Drag a lamp in Studio View to move it.\n" \
		+ "    Lighting locks when you capture a shot's first frame, so every frame matches.\n" \
		+ "Onion skin (O): see faint ghosts of your last 1 or 3 frames.\n" \
		+ "Space: capture a frame. P: play this shot. Shift+P: play all shots. Ctrl+Z: undo.\n" \
		+ "Shots (bottom): a shot is one camera setup. + New Shot picks up where this shot left off,\n" \
		+ "    so you can change the angle and keep the action going. Click a shot to work on it.\n" \
		+ "Your work autosaves in this browser on this computer. Save Project makes a file you can open anywhere."
	help_panel.add_child(help_text)

	# ---- Scene list (hidden until Scene List is pressed).
	scene_list_panel = PanelContainer.new()
	scene_list_panel.visible = false
	scene_list_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	scene_list_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(scene_list_panel)
	var list_column := VBoxContainer.new()
	list_column.custom_minimum_size = Vector2(260, 0)
	scene_list_panel.add_child(list_column)
	var list_title := Label.new()
	list_title.text = "IN THE SCENE"
	list_title.add_theme_font_size_override("font_size", 14)
	list_column.add_child(list_title)
	scene_list_box = VBoxContainer.new()
	list_column.add_child(scene_list_box)

	# ---- Style panel (hidden until Style is pressed).
	style_panel = PanelContainer.new()
	style_panel.visible = false
	style_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	style_panel.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	column.add_child(style_panel)
	style_box = VBoxContainer.new()
	style_box.custom_minimum_size = Vector2(230, 0)
	style_panel.add_child(style_box)

	# ---- Backdrop and Lighting panels (hidden until their buttons are pressed).
	_build_backdrop_panel(column)
	_build_lighting_panel(column)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	# ---- Bottom right: shot camera preview, capture, playback, onion skin.
	# It has its own layer of the screen, so open side panels (Help, Style, Scene List) can't push it off the bottom.
	var bottom_margin := MarginContainer.new()
	bottom_margin.theme = ui_theme
	bottom_margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	bottom_margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		bottom_margin.add_theme_constant_override(side, 10)
	layer.add_child(bottom_margin)
	var bottom_row := HBoxContainer.new()
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_row.alignment = BoxContainer.ALIGNMENT_END
	bottom_row.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom_margin.add_child(bottom_row)

	_build_shot_strip(bottom_row)
	_build_export_panel(bottom_row)

	shot_panel = PanelContainer.new()
	shot_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	shot_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	bottom_row.add_child(shot_panel)
	var shot_box := VBoxContainer.new()
	shot_box.add_theme_constant_override("separation", 6)
	shot_panel.add_child(shot_box)

	shot_title = Label.new()
	shot_box.add_child(shot_title)

	preview = Control.new()
	preview.custom_minimum_size = Vector2(PREVIEW_MAX_HEIGHT * SHOT_ASPECT, PREVIEW_MAX_HEIGHT)
	shot_box.add_child(preview)

	var live := TextureRect.new()
	live.texture = shot_viewport.get_texture()
	_fill_preview(live)
	preview.add_child(live)

	playback_rect = TextureRect.new()
	playback_rect.visible = false
	_fill_preview(playback_rect)
	preview.add_child(playback_rect)

	flash_rect = ColorRect.new()
	flash_rect.color = Color(1, 1, 1, 0)
	flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	preview.add_child(flash_rect)

	var capture_button := _make_button("CAPTURE FRAME (Space)", "Take a picture through the shot camera. Each picture is one frame of your animation.")
	capture_button.add_theme_font_size_override("font_size", 18)
	var capture_style := StyleBoxFlat.new()
	capture_style.bg_color = Color(0.8, 0.22, 0.2)
	capture_style.set_corner_radius_all(6)
	capture_style.content_margin_top = 10
	capture_style.content_margin_bottom = 10
	var capture_hover := capture_style.duplicate() as StyleBoxFlat
	capture_hover.bg_color = Color(0.9, 0.3, 0.26)
	capture_button.add_theme_stylebox_override("normal", capture_style)
	capture_button.add_theme_stylebox_override("hover", capture_hover)
	capture_button.add_theme_stylebox_override("pressed", capture_hover)
	capture_button.pressed.connect(_capture_frame)
	shot_box.add_child(capture_button)

	var play_row := HBoxContainer.new()
	shot_box.add_child(play_row)
	play_button = _add_button(play_row, "Play (P)", "Play this shot's frames as an animation at the frame rate below.", _toggle_playback)
	play_all_button = _add_button(play_row, "Play All", "Play every shot in order, so you can see how your cuts work. (Shift+P)", _toggle_playback.bind(true))
	_add_button(play_row, "Delete Last Frame", "Remove this shot's most recent frame.", _delete_last_frame)
	frames_label = Label.new()
	frames_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	frames_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	play_row.add_child(frames_label)

	var rate_row := HBoxContainer.new()
	shot_box.add_child(rate_row)
	var rate_title := Label.new()
	rate_title.text = "Frame rate:"
	rate_title.tooltip_text = "How many frames play each second. 12 is standard for stop motion. Higher numbers need more frames for the same length of animation."
	rate_title.mouse_filter = Control.MOUSE_FILTER_STOP
	rate_row.add_child(rate_title)
	fps_option = OptionButton.new()
	fps_option.focus_mode = Control.FOCUS_NONE
	fps_option.tooltip_text = rate_title.tooltip_text
	for r in FRAME_RATES:
		fps_option.add_item("%d fps" % r)
	fps_option.select(FRAME_RATES.find(DEFAULT_FPS))
	fps_option.item_selected.connect(func(index: int) -> void: playback_fps = FRAME_RATES[index])
	rate_row.add_child(fps_option)
	var rate_spacer := Control.new()
	rate_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rate_row.add_child(rate_spacer)
	var export_button := _make_button("Export...", "Download your animation: frames for each shot, a Premiere package, a video, or a GIF.")
	export_button.toggle_mode = true
	export_button.toggled.connect(func(on: bool) -> void: export_panel.visible = on)
	rate_row.add_child(export_button)

	var onion_row := HBoxContainer.new()
	shot_box.add_child(onion_row)
	var onion_title := Label.new()
	onion_title.text = "Onion skin (O):"
	onion_title.tooltip_text = "Shows faint pink ghosts of your last frames so you can space your movements evenly."
	onion_title.mouse_filter = Control.MOUSE_FILTER_STOP
	onion_row.add_child(onion_title)
	var onion_group := ButtonGroup.new()
	for entry in [
		["0", "Off", "Hide the onion skin ghosts."],
		["1", "1 frame", "Show a ghost of your last frame."],
		["3", "3 frames", "Show ghosts of your last three frames, fading as they get older."],
	]:
		var key: String = entry[0]
		var b := _make_button(entry[1], entry[2])
		b.toggle_mode = true
		b.button_group = onion_group
		b.pressed.connect(_set_onion_layers.bind(int(key)))
		onion_row.add_child(b)
		onion_buttons[key] = b
	var onion_spacer := Control.new()
	onion_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	onion_row.add_child(onion_spacer)
	last_frame_rect = TextureRect.new()
	last_frame_rect.custom_minimum_size = Vector2(96, 54)
	last_frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	last_frame_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	last_frame_rect.tooltip_text = "Your most recent frame."
	onion_row.add_child(last_frame_rect)

	# ---- Name of what a drag will do, following the cursor.
	cursor_label = Label.new()
	cursor_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor_label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	cursor_label.add_theme_constant_override("outline_size", 4)
	cursor_label.visible = false
	layer.add_child(cursor_label)

	# ---- Blocks clicks and shows progress while a project loads.
	busy_overlay = ColorRect.new()
	(busy_overlay as ColorRect).color = Color(0, 0, 0, 0.55)
	busy_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	busy_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	busy_overlay.theme = ui_theme
	busy_overlay.visible = false
	layer.add_child(busy_overlay)
	var busy_center := CenterContainer.new()
	busy_center.set_anchors_preset(Control.PRESET_FULL_RECT)
	busy_overlay.add_child(busy_center)
	var busy_panel := PanelContainer.new()
	busy_center.add_child(busy_panel)
	busy_label = Label.new()
	busy_label.add_theme_font_size_override("font_size", 18)
	busy_panel.add_child(busy_label)

	confirm_dialog = ConfirmationDialog.new()
	confirm_dialog.theme = ui_theme
	confirm_dialog.title = "Are you sure?"
	confirm_dialog.ok_button_text = "Yes, continue"
	confirm_dialog.cancel_button_text = "Cancel"
	confirm_dialog.confirmed.connect(_on_confirmed)
	add_child(confirm_dialog)

	_update_frame_info()


# ---------------------------------------------------------------- projects and autosave

## Everything needed to rebuild the animation. Frames are saved as scene snapshots, not pictures,
## so project files stay tiny; the pictures are re-rendered when a project opens.
func _project_data() -> Dictionary:
	var rest := {}
	for figure in figures:
		var root: Node3D = figure["root"]
		var joints: Array = []
		if figure["kind"] == "character":
			for part in figure["parts"]:
				var joint: Node3D = part["joint"]
				joints.append(rest_pose[joint])
		rest[figure["id"]] = {"type": figure["type"], "root": rest_pose[root], "joints": joints, "squash": figure["rest_squash"]}
	var current := _get_pose()
	var shot_list: Array = []
	for i in shots.size():
		var shot: Dictionary = shots[i]
		shot_list.append({"label": shot["label"], "frames": shot["poses"],
			"lighting": shot["lighting"], "light_locked": shot["light_locked"], "set": shot["set"],
			"working": current if i == active_shot else shot["working"]})
	return {
		"app": APP_NAME,
		"version": PROJECT_VERSION,
		"name": export_name.text,
		"fps": playback_fps,
		"onion": onion_layers,
		"rest": rest,
		"camera_default": {"transform": camera_default, "fov": camera_default_fov},
		"current": current,
		"shots": shot_list,
		"active_shot": active_shot,
		"backdrop_pictures": backdrop_pictures,
		"next_picture": next_picture,
	}


func _project_text() -> String:
	return JSON.stringify(JSON.from_native(_project_data()), "", true, true)


## Reads project text. Returns the project, or {} with an "error" key explaining what's wrong.
func _parse_project(text: String) -> Dictionary:
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return {"error": "That file isn't a claymation project."}
	var data: Variant = JSON.to_native(parsed, false)
	if typeof(data) != TYPE_DICTIONARY:
		return {"error": "That file isn't a claymation project."}
	var project: Dictionary = data
	if project.get("app", "") != APP_NAME:
		return {"error": "That file isn't a claymation project."}
	var version := int(project.get("version", 1))
	if version > PROJECT_VERSION:
		return {"error": "That project was saved by a newer version of the studio. Reload the page (Ctrl+Shift+R or Cmd+Shift+R) and try again."}
	if version == 1:
		project = _upgrade_v1_project(project)
	if project.has("error") or typeof(project.get("rest")) != TYPE_DICTIONARY:
		return {"error": "That project file is damaged, so it can't be opened here."}
	# Projects from before shots: all their frames become Shot 1.
	if not project.has("shots"):
		project["shots"] = [{"label": "", "frames": project.get("frames", []), "working": {}}]
	if typeof(project["shots"]) != TYPE_ARRAY:
		return {"error": "That project file is damaged, so it can't be opened here."}
	return project


## Projects saved before props and characters had one puppet. This turns that into a scene with one Kid.
func _upgrade_v1_project(old: Dictionary) -> Dictionary:
	var rest: Dictionary = old.get("rest", {})
	var joints: Array = rest.get("joints", [])
	if joints.size() != 11:
		return {"error": "unknown puppet"}
	var to_scene := func(pose: Dictionary) -> Dictionary:
		return {
			"objects": [{"id": "kid-1", "type": "kid", "root": pose.get("root", Transform3D.IDENTITY),
				"joints": pose.get("joints", []), "twists": pose.get("twists", []), "squash": 1.0}],
			"camera": pose.get("camera", factory_camera), "fov": pose.get("fov", factory_fov),
		}
	var frames: Array = []
	for frame in old.get("frames", []):
		frames.append(to_scene.call(frame))
	var project := old.duplicate()
	project["rest"] = {"kid-1": {"type": "kid", "root": rest.get("root", Transform3D.IDENTITY), "joints": joints, "squash": 1.0}}
	project["frames"] = frames
	if old.has("current"):
		project["current"] = to_scene.call(old["current"])
	project["version"] = 2
	return project


func _load_project_text(text: String) -> void:
	var project := _parse_project(text)
	if project.has("error"):
		_flash_status(project["error"], 6.0)
		return
	await _apply_project(project)
	_flash_status("Opened %s." % export_name.text)


func _apply_project(project: Dictionary) -> void:
	loading = true
	if playing:
		_stop_playback()
	_clear_scene()
	var rest: Dictionary = project["rest"]
	for id in rest:
		var info: Dictionary = rest[id]
		var figure := _ensure_figure(str(info.get("type", "")), str(id))
		if figure.is_empty():
			continue
		var root: Node3D = figure["root"]
		rest_pose[root] = info.get("root", root.transform)
		var joints: Array = info.get("joints", [])
		var figure_parts: Array = figure["parts"]
		if figure["kind"] == "character" and joints.size() == figure_parts.size():
			for i in figure_parts.size():
				var joint: Node3D = figure_parts[i]["joint"]
				rest_pose[joint] = joints[i]
		figure["rest_squash"] = float(info.get("squash", 1.0))
	var cam: Dictionary = project.get("camera_default", {})
	camera_default = cam.get("transform", factory_camera)
	camera_default_fov = cam.get("fov", factory_fov)
	export_name.text = str(project.get("name", "my-animation"))
	_set_fps(int(project.get("fps", DEFAULT_FPS)))
	_set_onion_layers(int(project.get("onion", 1)))
	# Students' backdrop pictures come first, so shots can find theirs.
	_clear_backdrop_pictures()
	var pictures: Variant = project.get("backdrop_pictures", {})
	if typeof(pictures) == TYPE_DICTIONARY:
		for id in pictures:
			var picture: Variant = (pictures as Dictionary)[id]
			if typeof(picture) == TYPE_DICTIONARY and (picture as Dictionary).has("b64"):
				backdrop_pictures[str(id)] = {"name": str((picture as Dictionary).get("name", "Picture")), "b64": str(picture["b64"])}
	next_picture = maxi(int(project.get("next_picture", 1)), backdrop_pictures.size() + 1)
	shots.clear()
	for entry_value in project["shots"]:
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value
		# Projects from before lighting get the default lighting, locked if the shot has frames.
		var shot := _make_shot(str(entry.get("label", "")).left(SHOT_LABEL_MAX), _clean_lighting(entry.get("lighting")),
			_clean_set(entry.get("set")))
		var poses: Array[Dictionary] = shot["poses"]
		for pose in entry.get("frames", []):
			if typeof(pose) == TYPE_DICTIONARY:
				poses.append(pose)
		var working: Variant = entry.get("working", {})
		if typeof(working) == TYPE_DICTIONARY:
			shot["working"] = working
		shot["light_locked"] = bool(entry.get("light_locked", not poses.is_empty()))
		shots.append(shot)
	if shots.is_empty():
		shots.append(_make_shot())
	active_shot = clampi(int(project.get("active_shot", 0)), 0, shots.size() - 1)
	_bind_active_shot()
	await _rebuild_frames()
	var current: Dictionary = project.get("current", {})
	if current.is_empty():
		current = shots[active_shot]["working"]
	if current.is_empty() and not frame_poses.is_empty():
		current = frame_poses[frame_poses.size() - 1]
	if not current.is_empty():
		_apply_pose(current)
	shots[active_shot]["working"] = {}
	_apply_look(shots[active_shot])
	_refresh_lighting_panel()
	_refresh_backdrop_panel()
	shot_label_edit.text = str(shots[active_shot]["label"])
	_update_shot_title()
	_update_frame_info()
	loading = false
	selected_figure = _subject_figure()
	_clear_stale_selection()
	_refresh_scene_list()
	_update_ghosts()
	last_saved_text = ""


## Takes every character and prop out of the scene for good (New Project and opening a project).
func _clear_scene() -> void:
	_set_highlight({})
	hovered = {}
	active_part = {}
	grab_figure = {}
	selected_figure = {}
	_clear_ghosts()
	for figure in figures:
		(figure["root"] as Node3D).free()
	figures.clear()
	parts.clear()
	rest_pose.clear()
	next_number.clear()


## Re-renders every frame of every shot from its saved pose through the shot camera.
func _rebuild_frames() -> void:
	for shot in shots:
		(shot["textures"] as Array).clear()
	var total := _total_frames()
	if total == 0:
		_update_frame_info()
		return
	busy_overlay.visible = true
	capturing = true
	_set_highlight({})
	for key in ghost_pool:
		(ghost_pool[key]["root"] as Node3D).visible = false
	shot_camera.cull_mask = SHOT_CAPTURE_MASK
	var done := 0
	for shot in shots:
		var poses: Array[Dictionary] = shot["poses"]
		var textures: Array[ImageTexture] = shot["textures"]
		_apply_look(shot)
		shot["relight"] = false
		for pose in poses:
			done += 1
			busy_label.text = "Rebuilding your frames: %d of %d" % [done, total]
			_apply_pose(pose)
			await RenderingServer.frame_post_draw
			textures.append(ImageTexture.create_from_image(_keep_size(shot_viewport.get_texture().get_image())))
	shot_camera.cull_mask = SHOT_PREVIEW_MASK
	_apply_look(shots[active_shot])
	capturing = false
	busy_overlay.visible = false
	_update_frame_info()


func _new_project() -> void:
	if playing:
		_stop_playback()
	_clear_scene()
	selected_figure = _spawn("kid", "", Vector3.ZERO)
	camera_default = factory_camera
	camera_default_fov = factory_fov
	shot_camera.global_transform = factory_camera
	shot_camera.fov = factory_fov
	_sync_camera()
	_clear_backdrop_pictures()
	shots.clear()
	shots.append(_make_shot())
	active_shot = 0
	_bind_active_shot()
	_apply_look(shots[active_shot])
	_refresh_lighting_panel()
	_refresh_backdrop_panel()
	shot_label_edit.text = ""
	_update_shot_title()
	export_name.text = "my-animation"
	_set_fps(DEFAULT_FPS)
	_set_onion_layers(1)
	_update_frame_info()
	_update_ghosts()
	_refresh_scene_list()
	_flash_status("Started a new project.")


func _save_project() -> void:
	var file_name := "%s.%s" % [_safe_name(export_name.text), PROJECT_EXT]
	_flash_status(_deliver_file(_project_text().to_utf8_buffer(), file_name, "application/json"), 5.0)


func _open_project() -> void:
	if OS.has_feature("web"):
		if not _load_export_tools():
			_flash_status("Couldn't open the file picker. Try reloading the page.")
			return
		var api = JavaScriptBridge.get_interface("vcsExport")
		api.openFile(js_open_callback)
		return
	# Running from the Godot editor: use Godot's own file window.
	if open_dialog == null:
		open_dialog = FileDialog.new()
		open_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
		open_dialog.access = FileDialog.ACCESS_FILESYSTEM
		open_dialog.use_native_dialog = true
		# Older .claymation files from early testing still open.
		open_dialog.filters = PackedStringArray(["*.clay, *.claymation ; Claymation projects"])
		open_dialog.file_selected.connect(func(path: String) -> void: _load_project_text(FileAccess.get_file_as_string(path)))
		add_child(open_dialog)
	open_dialog.popup_centered_ratio(0.6)


## The browser's file picker sends back "file:<project text>", "cancel", or "error: <reason>".
func _on_js_file_opened(args: Array) -> void:
	var reply := str(args[0]) if args.size() > 0 else ""
	if reply.begins_with("file:"):
		_load_project_text(reply.substr(5))
	elif reply.begins_with("error"):
		_flash_status("Couldn't open that file: " + reply.trim_prefix("error: "), 6.0)


func _autosave() -> void:
	var text := _project_text()
	if text == last_saved_text:
		return
	var f := FileAccess.open(AUTOSAVE_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(text)
	f.close()
	last_saved_text = text


## On startup: if there's autosaved work with frames in it, offer to bring it back.
func _check_autosave() -> void:
	if not FileAccess.file_exists(AUTOSAVE_PATH):
		autosave_enabled = true
		return
	var text := FileAccess.get_file_as_string(AUTOSAVE_PATH)
	var project := _parse_project(text)
	var frame_count := 0
	var shot_count := 0
	if not project.has("error"):
		for entry in project["shots"]:
			if typeof(entry) == TYPE_DICTIONARY:
				shot_count += 1
				frame_count += ((entry as Dictionary).get("frames", []) as Array).size()
	if frame_count == 0:
		autosave_enabled = true
		return
	var shots_text := "" if shot_count <= 1 else " in %d shots" % shot_count
	confirm_dialog.title = "Welcome back"
	confirm_dialog.dialog_text = "You have saved work here: \"%s\" with %d frames%s.\nPick up where you left off?" % [project.get("name", "my-animation"), frame_count, shots_text]
	confirm_dialog.ok_button_text = "Pick up where I left off"
	confirm_dialog.cancel_button_text = "Start fresh"
	pending_confirm = func() -> void:
		_restore_dialog_defaults()
		await _apply_project(project)
		autosave_enabled = true
		_flash_status("Welcome back! Your work is restored.")
	confirm_dialog.canceled.connect(_on_start_fresh, CONNECT_ONE_SHOT)
	confirm_dialog.popup_centered()


func _on_start_fresh() -> void:
	_restore_dialog_defaults()
	pending_confirm = Callable()
	autosave_enabled = true


func _restore_dialog_defaults() -> void:
	confirm_dialog.title = "Are you sure?"
	confirm_dialog.ok_button_text = "Yes, continue"
	confirm_dialog.cancel_button_text = "Cancel"


func _on_confirmed() -> void:
	if pending_confirm.is_valid():
		pending_confirm.call()


func _confirm(message: String, action: Callable) -> void:
	confirm_dialog.dialog_text = message
	pending_confirm = action
	confirm_dialog.popup_centered()


func _set_fps(fps: int) -> void:
	var index := FRAME_RATES.find(fps)
	if index < 0:
		index = FRAME_RATES.find(DEFAULT_FPS)
	playback_fps = FRAME_RATES[index]
	fps_option.select(index)


# ---------------------------------------------------------------- export

func _build_export_panel(parent: Control) -> void:
	export_panel = PanelContainer.new()
	export_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	export_panel.size_flags_vertical = Control.SIZE_SHRINK_END
	export_panel.visible = false
	parent.add_child(export_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.custom_minimum_size = Vector2(300, 0)
	export_panel.add_child(box)

	var title := Label.new()
	title.text = "EXPORT YOUR ANIMATION"
	title.add_theme_font_size_override("font_size", 16)
	box.add_child(title)

	var name_title := Label.new()
	name_title.text = "Name:"
	box.add_child(name_title)
	export_name = LineEdit.new()
	export_name.text = "my-animation"
	export_name.tooltip_text = "Used for the downloaded file and the frame names."
	box.add_child(export_name)

	var format_title := Label.new()
	format_title.text = "Format:"
	box.add_child(format_title)
	var group := ButtonGroup.new()
	for entry in [
		["png", "Frames: PNG", "Full-quality images, one per frame, in a folder for each shot, in a zip. Best for editing in Premiere.", true],
		["jpg", "Frames: JPG (saves space)", "Smaller images, one per frame, in a folder for each shot, in a zip. Slightly lower quality.", true],
		["xml", "Premiere XML + frames (experimental)", "For Premiere Pro: each shot as its own clip, plus an empty sequence where you edit them together. Open it with File > Import in Premiere.", true],
		["mp4", "MP4 video", "A video file that plays anywhere and imports straight into Premiere. Works in the browser version.", true],
		["gif", "Animated GIF", "A small looping animation (480 x 270) for sharing. Limited colors, so not for editing. Works in the browser version.", true],
	]:
		var key: String = entry[0]
		var b := _make_button(entry[1], entry[2])
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not entry[3]
		b.button_pressed = key == export_format
		b.pressed.connect(func() -> void:
			export_format = key
			_update_export_options())
		box.add_child(b)

	# Resolution. GIFs are always 480 x 270, so the menu hides for them.
	export_size_row = HBoxContainer.new()
	box.add_child(export_size_row)
	var size_title := Label.new()
	size_title.text = "Size:"
	size_title.tooltip_text = "Resolution: how many pixels wide and tall your export is. More pixels look sharper " \
		+ "but take longer to export and make bigger files. Your frames are made fresh at this size, so bigger really is sharper."
	size_title.mouse_filter = Control.MOUSE_FILTER_STOP
	export_size_row.add_child(size_title)
	export_size_option = OptionButton.new()
	export_size_option.focus_mode = Control.FOCUS_NONE
	export_size_option.tooltip_text = size_title.tooltip_text
	export_size_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	export_size_option.item_selected.connect(func(index: int) -> void: export_size = export_size_keys[index])
	export_size_row.add_child(export_size_option)

	# Which shots go into an MP4 or GIF. Frames and the Premiere package always include every shot.
	export_scope_row = HBoxContainer.new()
	box.add_child(export_scope_row)
	var scope_title := Label.new()
	scope_title.text = "Include:"
	scope_title.tooltip_text = "All shots plays your whole animation in order, like a rough cut. This shot only is just the shot you're working on."
	scope_title.mouse_filter = Control.MOUSE_FILTER_STOP
	export_scope_row.add_child(scope_title)
	var scope_option := OptionButton.new()
	scope_option.focus_mode = Control.FOCUS_NONE
	scope_option.tooltip_text = scope_title.tooltip_text
	scope_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scope_option.add_item("All shots, in order")
	scope_option.add_item("This shot only")
	scope_option.item_selected.connect(func(index: int) -> void: export_scope = "all" if index == 0 else "this")
	export_scope_row.add_child(scope_option)

	var download := _make_button("DOWNLOAD", "Package your animation and download it.")
	download.add_theme_font_size_override("font_size", 16)
	download.pressed.connect(_export)
	box.add_child(download)

	export_status = Label.new()
	export_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	export_status.custom_minimum_size = Vector2(300, 0)
	box.add_child(export_status)
	_update_export_options()


## Shows the menus that fit the chosen format: Size (not for GIF; 4K only for MP4) and Include (MP4 and GIF).
func _update_export_options() -> void:
	export_scope_row.visible = export_format == "mp4" or export_format == "gif"
	export_size_row.visible = export_format != "gif"
	export_size_option.clear()
	export_size_keys.clear()
	for entry in EXPORT_SIZES:
		var key: String = entry[0]
		if key == "4k" and export_format != "mp4":
			continue
		export_size_keys.append(key)
		export_size_option.add_item(entry[1])
		export_size_option.set_item_tooltip(export_size_keys.size() - 1, entry[3])
	if not export_size_keys.has(export_size):
		export_size = DEFAULT_EXPORT_SIZE
	export_size_option.select(export_size_keys.find(export_size))


## The pixel size this export will be.
func _export_pixels() -> Vector2i:
	if export_format == "gif":
		return FRAME_KEEP_SIZE
	for entry in EXPORT_SIZES:
		if entry[0] == export_size:
			return entry[2]
	return SHOT_RENDER_SIZE


## Turns whatever the student typed into a safe file name.
func _safe_name(raw: String) -> String:
	var cleaned := raw.strip_edges().replace(" ", "-").validate_filename()
	return cleaned if cleaned != "" else "my-animation"


## Folder for one shot's frames, like "shot02".
func _shot_folder(shot_index: int) -> String:
	return "shot%02d" % (shot_index + 1)


## File name for one frame, like "shot02_0015.png".
func _frame_file(shot_index: int, index: int, ext: String) -> String:
	return "%s_%04d.%s" % [_shot_folder(shot_index), index + 1, ext]


## Every frame going into this export, in order, as (shot, frame) pairs.
func _export_frame_list(only_active: bool) -> Array[Vector2i]:
	var list: Array[Vector2i] = []
	for s in shots.size():
		if only_active and s != active_shot:
			continue
		for i in (shots[s]["poses"] as Array).size():
			list.append(Vector2i(s, i))
	return list


func _export() -> void:
	if exporting:
		return
	if _total_frames() == 0:
		export_status.text = "Capture some frames first, then export."
		return
	var video := export_format == "mp4" or export_format == "gif"
	var only_active := video and export_scope == "this"
	if only_active and frame_poses.is_empty():
		export_status.text = "Shot %d has no frames yet. Capture some, or choose All shots." % (active_shot + 1)
		return
	var web := OS.has_feature("web")
	if video and not web:
		export_status.text = "MP4 and GIF work in the browser version. Use Run in Browser to try them."
		return
	if web and not _load_export_tools():
		export_status.text = "Couldn't load the export tools. Try reloading the page."
		return
	if playing:
		_stop_playback()
	await _relight_if_needed()
	exporting = true

	var pixels := _export_pixels()
	var frames := _export_frame_list(only_active)
	var base := _safe_name(export_name.text)
	if only_active:
		base += "-shot%02d" % (active_shot + 1)
	# Small exports use the pictures already in memory. Bigger ones make each frame fresh from its pose.
	var render := pixels != FRAME_KEEP_SIZE
	if render:
		_begin_render(pixels)
		await RenderingServer.frame_post_draw
	var message: String
	if video:
		message = await _export_video(export_format, base, frames, pixels)
	else:
		message = await _export_zip(base, frames, pixels)
	if render:
		_end_render()
	export_status.text = message
	exporting = false


func _export_progress(text: String) -> void:
	export_status.text = text
	busy_label.text = text


## Before making fresh pictures for an export: remembers the scene, hides the onion skin and hover glow,
## covers the screen (the scene jumps from frame to frame while this runs), and sets the picture size.
func _begin_render(pixels: Vector2i) -> void:
	render_restore = _get_pose()
	render_lit_shot = -1
	capturing = true
	loading = true   # Skips scene list updates while each frame is set up.
	_set_highlight({})
	for key in ghost_pool:
		(ghost_pool[key]["root"] as Node3D).visible = false
	shot_camera.cull_mask = SHOT_CAPTURE_MASK
	shot_viewport.size = pixels
	busy_label.text = "Getting ready..."
	busy_overlay.visible = true


## Puts everything back the way the student left it.
func _end_render() -> void:
	shot_viewport.size = SHOT_RENDER_SIZE
	shot_camera.cull_mask = SHOT_PREVIEW_MASK
	loading = false
	if not render_restore.is_empty():
		_apply_pose(render_restore)
	render_restore = {}
	_apply_look(shots[active_shot])
	capturing = false
	busy_overlay.visible = false
	_update_ghosts()


## One frame's picture at the export size: the picture in memory for Small, otherwise made fresh from its pose.
func _export_image(shot_index: int, frame_index: int, pixels: Vector2i) -> Image:
	if pixels == FRAME_KEEP_SIZE:
		var kept: ImageTexture = shots[shot_index]["textures"][frame_index]
		return kept.get_image()
	if render_lit_shot != shot_index:
		_apply_look(shots[shot_index])
		render_lit_shot = shot_index
	_apply_pose(shots[shot_index]["poses"][frame_index])
	await RenderingServer.frame_post_draw
	return shot_viewport.get_texture().get_image()


## Frames (PNG or JPG, a folder per shot) or the Premiere package, as one zip. Returns a message for the student.
func _export_zip(base: String, frames: Array[Vector2i], pixels: Vector2i) -> String:
	var use_jpg := export_format == "jpg"
	var ext := "jpg" if use_jpg else "png"
	# The Premiere package keeps the shot folders inside "frames".
	var frame_dir := base + "/frames/" if export_format == "xml" else base + "/"
	var problem: String = await _zip_begin(base + ".zip")
	if problem != "":
		return "Couldn't start the export: " + problem
	for n in frames.size():
		var f := frames[n]
		_export_progress("Exporting frame %d of %d..." % [n + 1, frames.size()])
		var img: Image = await _export_image(f.x, f.y, pixels)
		if img == null:
			_zip_cancel()
			return "Export stopped: couldn't make frame %d." % (n + 1)
		var bytes: PackedByteArray = img.save_jpg_to_buffer(0.9) if use_jpg else img.save_png_to_buffer()
		problem = await _zip_add("%s%s/%s" % [frame_dir, _shot_folder(f.x), _frame_file(f.x, f.y, ext)], bytes)
		if problem != "":
			_zip_cancel()
			return "Export stopped: " + problem
		if pixels == FRAME_KEEP_SIZE:
			# Let the screen update so the app doesn't look frozen during big exports.
			await get_tree().process_frame
	if export_format == "xml":
		problem = await _zip_add("%s/%s.xml" % [base, base], _build_premiere_xml(base, ext, pixels).to_utf8_buffer())
		if problem == "":
			problem = await _zip_add("%s/How to open in Premiere.txt" % base, _premiere_readme(base, pixels).to_utf8_buffer())
		if problem != "":
			_zip_cancel()
			return "Export stopped: " + problem
	_export_progress("Finishing up...")
	return await _zip_end()


## Zips: in the browser, vcs-export.js builds the zip piece by piece, so a long animation never sits in
## memory all at once. In the editor, ZIPPacker writes straight into Downloads.
## _zip_begin and _zip_add return "" when all is well, or what went wrong.
func _zip_begin(file_name: String) -> String:
	if OS.has_feature("web"):
		var api = JavaScriptBridge.get_interface("vcsExport")
		api.zipStart(file_name, js_callback)
		await js_replied
		return _js_problem()
	zip_path = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS).path_join(file_name)
	zip_packer = ZIPPacker.new()
	if zip_packer.open(zip_path) != OK:
		zip_packer = null
		return "couldn't save to your Downloads folder."
	return ""


func _zip_add(path: String, bytes: PackedByteArray) -> String:
	if OS.has_feature("web"):
		var api = JavaScriptBridge.get_interface("vcsExport")
		api.zipAdd(path, Marshalls.raw_to_base64(bytes), js_callback)
		await js_replied
		return _js_problem()
	zip_packer.start_file(path)
	zip_packer.write_file(bytes)
	zip_packer.close_file()
	return ""


## Finishes the zip and downloads it. Returns a message for the student.
func _zip_end() -> String:
	if OS.has_feature("web"):
		var api = JavaScriptBridge.get_interface("vcsExport")
		api.zipFinish(js_callback)
		await js_replied
		if js_reply.begins_with("done: "):
			return "Downloaded %s. Check your Downloads folder." % js_reply.trim_prefix("done: ")
		return "Export stopped: " + _js_problem()
	zip_packer.close()
	zip_packer = null
	OS.shell_show_in_file_manager(zip_path)
	return "Saved to %s" % zip_path


func _zip_cancel() -> void:
	if OS.has_feature("web"):
		var api = JavaScriptBridge.get_interface("vcsExport")
		api.zipCancel()
		return
	if zip_packer != null:
		zip_packer.close()
		zip_packer = null
		DirAccess.remove_absolute(zip_path)


## What went wrong in the browser's last reply, or "" if nothing did.
func _js_problem() -> String:
	return js_reply.trim_prefix("error: ") if js_reply.begins_with("error") else ""


## MP4 and GIF are made by the browser (vcs-export.js), so they only work in the browser version.
## Frames go across one at a time so even long animations don't use too much memory.
## Returns a message for the student.
func _export_video(kind: String, base: String, frames: Array[Vector2i], pixels: Vector2i) -> String:
	# Left untyped on purpose: start/addFrame/finish live in the browser, not in Godot.
	var api = JavaScriptBridge.get_interface("vcsExport")
	_export_progress("Getting ready...")
	api.start(kind, pixels.x, pixels.y, playback_fps, base, js_callback)
	await js_replied
	if js_reply.begins_with("error"):
		return "Export stopped: " + _js_problem()

	for n in frames.size():
		var f := frames[n]
		_export_progress("Making your %s: frame %d of %d..." % [kind.to_upper(), n + 1, frames.size()])
		var img: Image = await _export_image(f.x, f.y, pixels)
		if img == null:
			return "Export stopped: couldn't make frame %d." % (n + 1)
		if img.get_size() != pixels:
			img.resize(pixels.x, pixels.y, Image.INTERPOLATE_CUBIC)
		api.addFrame(Marshalls.raw_to_base64(img.save_jpg_to_buffer(0.92)), js_callback)
		await js_replied
		if js_reply.begins_with("error"):
			return "Export stopped: " + _js_problem()
		if pixels == FRAME_KEEP_SIZE:
			await get_tree().process_frame

	_export_progress("Finishing up...")
	api.finish(js_callback)
	await js_replied
	if js_reply.begins_with("done: "):
		return "Downloaded %s. Check your Downloads folder." % js_reply.trim_prefix("done: ")
	return "Export stopped: " + _js_problem()


## Loads the bundled browser code (res://web/vcs-export.js: MP4/GIF export, frame zips, and the file picker)
## into the page the first time it's needed.
func _load_export_tools() -> bool:
	if js_ready:
		return true
	var code := FileAccess.get_file_as_string("res://web/vcs-export.js")
	if code == "":
		return false
	JavaScriptBridge.eval(code, true)
	js_callback = JavaScriptBridge.create_callback(_on_js_reply)
	js_open_callback = JavaScriptBridge.create_callback(_on_js_file_opened)
	js_image_callback = JavaScriptBridge.create_callback(_on_js_image_opened)
	js_ready = JavaScriptBridge.get_interface("vcsExport") != null
	return js_ready


func _on_js_reply(args: Array) -> void:
	js_reply = str(args[0]) if args.size() > 0 else ""
	js_replied.emit()


## In a browser, downloads the file. When run from the Godot editor, saves it to Downloads instead.
## Returns a message for the student saying where the file went.
func _deliver_file(data: PackedByteArray, file_name: String, mime: String) -> String:
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(data, file_name, mime)
		return "Downloaded %s. Check your Downloads folder." % file_name
	var path := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS).path_join(file_name)
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return "Couldn't save the file to Downloads."
	f.store_buffer(data)
	f.close()
	OS.shell_show_in_file_manager(path)
	return "Saved to %s" % path


## A Final Cut Pro 7 XML project, which Premiere Pro can import (File > Import). It holds:
##   - a "Frames" bin with every frame of every shot (each file is described in full here, once),
##   - a "Shots" bin with one sequence per shot, its frames in order. In Premiere these act like clips:
##     students drag them into the edit sequence and trim them,
##   - an empty "<name> - Edit" sequence at the project frame rate, where students cut their shots together.
## Assembling the shots is left to the student on purpose: putting the edit together is the skill being taught.
func _build_premiere_xml(base: String, ext: String, pixels: Vector2i) -> String:
	var rate := "<rate><timebase>%d</timebase><ntsc>FALSE</ntsc></rate>" % playback_fps
	var w := pixels.x
	var h := pixels.y
	var size := "<samplecharacteristics>%s<width>%d</width><height>%d</height><pixelaspectratio>square</pixelaspectratio></samplecharacteristics>" % [rate, w, h]
	var timecode := "<timecode>%s<string>00:00:00:00</string><frame>0</frame><displayformat>NDF</displayformat></timecode>" % rate
	var lines := PackedStringArray()
	lines.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
	lines.append("<!DOCTYPE xmeml>")
	lines.append("<xmeml version=\"4\">")
	lines.append("<project><name>%s</name><children>" % base.xml_escape())

	# The Frames bin: one master clip per frame.
	lines.append("<bin><name>Frames</name><children>")
	for s in shots.size():
		var count := (shots[s]["textures"] as Array).size()
		for i in count:
			var id := "%d-%d" % [s + 1, i + 1]
			var file_name := _frame_file(s, i, ext)
			lines.append("<clip id=\"masterclip-%s\"><masterclipid>masterclip-%s</masterclipid><ismasterclip>TRUE</ismasterclip><name>%s</name><duration>1</duration>%s" % [id, id, file_name, rate])
			lines.append("<media><video><track><clipitem id=\"masterclipitem-%s\"><masterclipid>masterclip-%s</masterclipid><name>%s</name>" % [id, id, file_name])
			lines.append("<file id=\"file-%s\"><name>%s</name><pathurl>frames/%s/%s</pathurl>%s<duration>1</duration><media><video>%s</video></media></file>" % [id, file_name, _shot_folder(s), file_name, rate, size])
			lines.append("</clipitem></track></video></media></clip>")
	lines.append("</children></bin>")

	# The Shots bin: one sequence per shot, every frame in order, each one frame long.
	lines.append("<bin><name>Shots</name><children>")
	for s in shots.size():
		var count := (shots[s]["textures"] as Array).size()
		if count == 0:
			continue
		var shot_name := "Shot %d" % (s + 1)
		var label := str(shots[s]["label"]).strip_edges()
		if label != "":
			shot_name += " - " + label
		lines.append("<sequence id=\"shot-%d\">" % (s + 1))
		lines.append("<name>%s</name>" % shot_name.xml_escape())
		lines.append("<duration>%d</duration>" % count)
		lines.append(rate)
		lines.append(timecode)
		lines.append("<media><video><format>%s</format><track>" % size)
		for i in count:
			var id := "%d-%d" % [s + 1, i + 1]
			lines.append("<clipitem id=\"clipitem-%s\"><masterclipid>masterclip-%s</masterclipid><name>%s</name><enabled>TRUE</enabled><duration>1</duration>%s<start>%d</start><end>%d</end><in>0</in><out>1</out><file id=\"file-%s\"/></clipitem>" % [id, id, _frame_file(s, i, ext), rate, i, i + 1, id])
		lines.append("</track></video></media>")
		lines.append("</sequence>")
	lines.append("</children></bin>")

	# The edit sequence: empty, but already set to the right frame rate and size.
	lines.append("<sequence id=\"sequence-edit\">")
	lines.append("<name>%s - Edit</name>" % base.xml_escape())
	lines.append("<duration>0</duration>")
	lines.append(rate)
	lines.append(timecode)
	lines.append("<media><video><format>%s</format><track></track></video></media>" % size)
	lines.append("</sequence>")

	lines.append("</children></project>")
	lines.append("</xmeml>")
	return "\n".join(lines)


func _premiere_readme(base: String, pixels: Vector2i) -> String:
	return "HOW TO OPEN THIS IN PREMIERE PRO\n\n" \
		+ "1. Unzip this folder and keep it somewhere it won't get deleted (not just in Downloads).\n" \
		+ "2. In Premiere Pro, choose File > Import and pick %s.xml.\n" % base \
		+ "   Premiere makes a new bin. Inside it you'll find:\n" \
		+ "   - Shots: each of your shots as its own clip (Shot 1, Shot 2, ...).\n" \
		+ "   - %s - Edit: an empty sequence, already set up for your animation.\n" % base \
		+ "   - Frames: every single frame. You won't need to touch these.\n" \
		+ "3. Double-click %s - Edit to open it. Drag your shots from the Shots bin onto the\n" % base \
		+ "   timeline in the order you want, then trim the start and end of each shot to choose\n" \
		+ "   exactly where each cut happens. Add your sound here too.\n" \
		+ "4. If Premiere says your media is offline or asks you to link media, click Locate,\n" \
		+ "   open the frames folder, then the shot's folder, and pick its first frame.\n" \
		+ "   Premiere should find the rest.\n" \
		+ "5. Everything is %d frames per second, %d x %d pixels.\n" % [playback_fps, pixels.x, pixels.y]


func _add_group_label(parent: Control, text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(0.65, 0.67, 0.72))
	parent.add_child(label)


func _add_divider(parent: Control) -> void:
	var sep := VSeparator.new()
	sep.custom_minimum_size = Vector2(10, 0)
	parent.add_child(sep)


func _add_tool_button(parent: Control, group: ButtonGroup, tool_name: String, text: String, tip: String) -> Button:
	var b := _make_button(text, tip)
	b.toggle_mode = true
	b.button_group = group
	b.pressed.connect(_set_tool.bind(tool_name))
	parent.add_child(b)
	return b


func _add_button(parent: Control, text: String, tip: String, action: Callable) -> Button:
	var b := _make_button(text, tip)
	b.pressed.connect(action)
	parent.add_child(b)
	return b


## A button that opens a menu of choices (like Add Prop). catalog: {type: name}.
func _make_menu_button(text: String, tip: String, catalog: Dictionary, action: Callable) -> MenuButton:
	var mb := MenuButton.new()
	mb.text = text + "..."
	mb.tooltip_text = tip
	mb.flat = false
	mb.focus_mode = Control.FOCUS_NONE
	var popup := mb.get_popup()
	popup.theme = ui_theme
	var keys: Array = catalog.keys()
	for i in keys.size():
		popup.add_item(str(catalog[keys[i]]), i)
	popup.id_pressed.connect(func(index: int) -> void: action.call(str(keys[index])))
	return mb


func _fill_preview(rect: TextureRect) -> void:
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _make_button(label_text: String, tip: String = "") -> Button:
	var b := Button.new()
	b.text = label_text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	return b
