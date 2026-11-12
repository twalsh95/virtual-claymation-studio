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
const PROJECT_VERSION := 2
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
const MAX_UNDO := 50
const CAMERA_PICK_RADIUS := 0.22
const LIFT_SPEED := 0.004
const SQUASH_SPEED := 0.008

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
const CAMERA_TOOLS := ["pan", "truck", "dolly", "zoom"]
const MODE_INFO := {
	"bend": ["BEND", Color(0.3, 0.85, 0.35)],
	"twist": ["TWIST", Color(1.0, 0.85, 0.2)],
	"move": ["MOVE", Color(0.7, 0.45, 1.0)],
	"lift": ["LIFT", Color(0.92, 0.92, 0.95)],
	"squash": ["SQUASH", Color(1.0, 0.5, 0.8)],
	"camera": ["CAMERA", Color(1.0, 0.25, 0.22)],
}
const TOOL_NAMES := {
	"bend": "Bend", "twist": "Twist", "move": "Move", "lift": "Lift", "squash": "Squash",
	"pan": "Pan / Tilt", "truck": "Truck / Pedestal", "dolly": "Dolly", "zoom": "Zoom",
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

# Frames, playback, and onion skin.
var frame_textures: Array[ImageTexture] = []
var frame_poses: Array[Dictionary] = []
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
	_build_environment()
	_build_set()
	_build_lights()
	scene_root = Node3D.new()
	scene_root.name = "Scene"
	add_child(scene_root)
	_build_ghost_materials()
	_build_work_camera()
	_build_shot_camera()
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
	env.ambient_light_energy = 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


func _build_set() -> void:
	# Tabletop, deep enough for the tripod to stand on.
	var table := MeshInstance3D.new()
	var table_mesh := BoxMesh.new()
	table_mesh.size = Vector3(7.0, 0.2, 6.5)
	table.mesh = table_mesh
	table.position = Vector3(0, -0.1, 0.9)
	var table_mat := StandardMaterial3D.new()
	table_mat.albedo_color = Color(0.45, 0.32, 0.22)
	table_mat.roughness = 0.75
	table.material_override = table_mat
	add_child(table)

	# Painted backdrop behind the puppet.
	var backdrop := MeshInstance3D.new()
	var backdrop_mesh := BoxMesh.new()
	backdrop_mesh.size = Vector3(7.0, 3.6, 0.1)
	backdrop.mesh = backdrop_mesh
	backdrop.position = Vector3(0, 1.8, -2.3)
	var backdrop_mat := StandardMaterial3D.new()
	backdrop_mat.albedo_color = Color(0.55, 0.7, 0.82)
	backdrop_mat.roughness = 0.95
	backdrop.material_override = backdrop_mat
	add_child(backdrop)


func _build_lights() -> void:
	# Key light: warm, from the front right, casts shadows.
	var key := DirectionalLight3D.new()
	key.light_energy = 1.1
	key.light_color = Color(1.0, 0.95, 0.85)
	key.shadow_enabled = true
	key.directional_shadow_max_distance = 12.0
	key.rotation_degrees = Vector3(-45, 35, 0)
	add_child(key)

	# Fill light: soft and cool, from the front left.
	var fill := OmniLight3D.new()
	fill.position = Vector3(-3.0, 2.0, 3.0)
	fill.light_energy = 0.4
	fill.light_color = Color(0.8, 0.88, 1.0)
	fill.omni_range = 10.0
	add_child(fill)

	# Back light: rim of light from behind and above.
	var back := SpotLight3D.new()
	back.position = Vector3(0, 2.6, -1.6)
	back.light_energy = 2.0
	back.spot_range = 6.0
	back.spot_angle = 35.0
	add_child(back)
	back.look_at(Vector3(0, 1.1, 0), Vector3.UP)


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
	undo_stack.clear()
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
	if camera_screen != null:
		camera_backdrop.visible = camera_view
		camera_border.visible = camera_view
		camera_screen.visible = camera_view
		preview.visible = not camera_view
		shot_title.text = "You're looking through the shot camera" if camera_view \
			else "SHOT CAMERA: this is what gets captured"
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
	_layout_camera_screen.call_deferred()


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
	shot_viewport.size = Vector2i(1280, 720)  # Frames are captured at 720p.
	shot_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	shot_viewport.msaa_3d = Viewport.MSAA_2X
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
		+ "Start a new shot if you want a new angle.", 6.0)


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
					_toggle_playback()
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

	# Camera tools move the camera wherever you drag.
	if current_tool in CAMERA_TOOLS:
		drag_mode = current_tool
		undo_pending = true
		Input.set_default_cursor_shape(Input.CURSOR_DRAG)
		return

	var hit := _pick_part(screen_pos)
	var cam_t := _pick_camera(screen_pos)
	var hit_t: float = hit["t"] if not hit.is_empty() else INF

	# Grabbing the tripod in Studio View slides it across the table.
	if cam_t < hit_t:
		if camera_locked:
			drag_mode = "none"
			_flash_status("The camera is locked. Press Unlock Camera (L) to move it.")
			return
		var origin := work_camera.project_ray_origin(screen_pos)
		var dir := work_camera.project_ray_normal(screen_pos)
		var cam_point := origin + dir * cam_t
		move_plane_y = cam_point.y
		move_offset = shot_camera.global_position - cam_point
		drag_mode = "grab_camera"
		undo_pending = true
		_update_indicator()
		Input.set_default_cursor_shape(Input.CURSOR_DRAG)
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
	_update_indicator()
	_update_hover(screen_pos)


func _update_hover(screen_pos: Vector2) -> void:
	if capturing:
		return
	if current_tool in CAMERA_TOOLS:
		_set_highlight({})
		hovered = {}
		_set_camera_glow(false)
		Input.set_default_cursor_shape(Input.CURSOR_MOVE)
		return
	var hit := _pick_part(screen_pos)
	var cam_t := _pick_camera(screen_pos)
	var hit_t: float = hit["t"] if not hit.is_empty() else INF
	var over_camera := cam_t < hit_t
	var part: Dictionary = {}
	if not hit.is_empty() and not over_camera:
		part = hit["part"]
	if over_camera != hovered_camera:
		hovered_camera = over_camera
		_set_camera_glow(over_camera)
	if not is_same(part, hovered):
		hovered = part
		_set_highlight(part)
	if over_camera or not part.is_empty():
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
	capturing = true
	if playing:
		_stop_playback()
	# Hide the hover glow and the onion skin ghosts so they never end up in a captured frame.
	_set_highlight({})
	shot_camera.cull_mask = SHOT_CAPTURE_MASK
	await RenderingServer.frame_post_draw
	var img := shot_viewport.get_texture().get_image()
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


func _toggle_playback() -> void:
	if playing:
		_stop_playback()
	elif frame_textures.size() > 0:
		if camera_view:
			_set_view(false)
		playing = true
		play_index = 0
		play_time = 0.0
		playback_rect.texture = frame_textures[0]
		playback_rect.visible = true
		play_button.text = "Stop (P)"
		_update_ghosts()
	else:
		_flash_status("Capture some frames first, then press Play.")


func _stop_playback() -> void:
	playing = false
	playback_rect.visible = false
	play_button.text = "Play (P)"
	_update_ghosts()


func _flash_status(text: String, seconds: float = 3.0) -> void:
	if status_label == null:
		return
	status_label.text = text
	status_panel.visible = true
	status_timer = seconds


func _process(delta: float) -> void:
	if autosave_enabled and not loading and not capturing and not exporting:
		autosave_timer += delta
		if autosave_timer >= AUTOSAVE_SECONDS:
			autosave_timer = 0.0
			_autosave()

	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

	if status_timer > 0.0:
		status_timer -= delta
		if status_timer <= 0.0:
			status_panel.visible = false

	# The red view lines only show while the camera is being worked on.
	view_lines.visible = current_tool in CAMERA_TOOLS or hovered_camera or drag_mode == "grab_camera"

	# Small label by the cursor naming what a drag will do.
	var label_text := ""
	if current_tool in CAMERA_TOOLS:
		label_text = TOOL_NAMES[current_tool]
	elif hovered_camera or drag_mode == "grab_camera":
		label_text = "Move Camera"
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

	if playing and frame_textures.size() > 0:
		play_time += delta
		var step := 1.0 / float(playback_fps)
		while play_time >= step:
			play_time -= step
			play_index = (play_index + 1) % frame_textures.size()
		playback_rect.texture = frame_textures[play_index]


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
	var help_button := _make_button("Help", "Show or hide the list of controls.")
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

	# ---- Status messages (appear briefly under the toolbar).
	var status_row := HBoxContainer.new()
	status_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(status_row)
	status_panel = PanelContainer.new()
	status_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_panel.visible = false
	status_row.add_child(status_panel)
	status_label = Label.new()
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(420, 0)
	status_panel.add_child(status_label)

	# ---- Help panel (hidden until Help is pressed).
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
		+ "Onion skin (O): see faint ghosts of your last 1 or 3 frames.\n" \
		+ "Space: capture a frame. P: play your animation. Ctrl+Z: undo.\n" \
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

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	# ---- Bottom right: shot camera preview, capture, playback, onion skin.
	var bottom_row := HBoxContainer.new()
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_row.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(bottom_row)

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
	preview.custom_minimum_size = Vector2(448, 252)
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
	play_button = _add_button(play_row, "Play (P)", "Play your frames as an animation at the frame rate below.", _toggle_playback)
	_add_button(play_row, "Delete Last Frame", "Remove the most recent frame.", _delete_last_frame)
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
	var export_button := _make_button("Export...", "Download your animation as image files (and more formats soon).")
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
	return {
		"app": APP_NAME,
		"version": PROJECT_VERSION,
		"name": export_name.text,
		"fps": playback_fps,
		"onion": onion_layers,
		"rest": rest,
		"camera_default": {"transform": camera_default, "fov": camera_default_fov},
		"current": _get_pose(),
		"frames": frame_poses,
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
	if int(project.get("version", 1)) == 1:
		project = _upgrade_v1_project(project)
	if project.has("error") or typeof(project.get("rest")) != TYPE_DICTIONARY:
		return {"error": "That project file is damaged or from a newer version, so it can't be opened here."}
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
	frame_poses.assign(project.get("frames", []))
	undo_stack.clear()
	await _rebuild_frames()
	var current: Dictionary = project.get("current", {})
	if current.is_empty() and not frame_poses.is_empty():
		current = frame_poses[frame_poses.size() - 1]
	if not current.is_empty():
		_apply_pose(current)
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


## Re-renders every frame from its saved pose through the shot camera.
func _rebuild_frames() -> void:
	frame_textures.clear()
	if frame_poses.is_empty():
		_update_frame_info()
		return
	busy_overlay.visible = true
	capturing = true
	_set_highlight({})
	for key in ghost_pool:
		(ghost_pool[key]["root"] as Node3D).visible = false
	shot_camera.cull_mask = SHOT_CAPTURE_MASK
	var count := frame_poses.size()
	for i in count:
		busy_label.text = "Rebuilding your frames: %d of %d" % [i + 1, count]
		_apply_pose(frame_poses[i])
		await RenderingServer.frame_post_draw
		frame_textures.append(ImageTexture.create_from_image(shot_viewport.get_texture().get_image()))
	shot_camera.cull_mask = SHOT_PREVIEW_MASK
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
	frame_poses.clear()
	frame_textures.clear()
	undo_stack.clear()
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
	var frames: Array = project.get("frames", [])
	if project.has("error") or frames.is_empty():
		autosave_enabled = true
		return
	confirm_dialog.title = "Welcome back"
	confirm_dialog.dialog_text = "You have saved work here: \"%s\" with %d frames.\nPick up where you left off?" % [project.get("name", "my-animation"), frames.size()]
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
		["png", "Frames: PNG", "Full-quality images, one per frame, in a zip. Best for editing in Premiere.", true],
		["jpg", "Frames: JPG (saves space)", "Smaller images, one per frame, in a zip. Slightly lower quality.", true],
		["xml", "Premiere XML + frames (experimental)", "A Premiere Pro sequence with your frames already in order, plus the frames, in one zip. Open it with File > Import in Premiere.", true],
		["mp4", "MP4 video", "A video file at 1280 x 720 that plays anywhere and imports straight into Premiere. Works in the browser version.", true],
		["gif", "Animated GIF", "A small looping animation (480 x 270) for sharing. Limited colors, so not for editing. Works in the browser version.", true],
	]:
		var key: String = entry[0]
		var b := _make_button(entry[1], entry[2])
		b.toggle_mode = true
		b.button_group = group
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.disabled = not entry[3]
		b.button_pressed = key == export_format
		b.pressed.connect(func() -> void: export_format = key)
		box.add_child(b)

	var download := _make_button("DOWNLOAD", "Package your frames and download them.")
	download.add_theme_font_size_override("font_size", 16)
	download.pressed.connect(_export)
	box.add_child(download)

	export_status = Label.new()
	export_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	export_status.custom_minimum_size = Vector2(300, 0)
	box.add_child(export_status)


## Turns whatever the student typed into a safe file name.
func _safe_name(raw: String) -> String:
	var cleaned := raw.strip_edges().replace(" ", "-").validate_filename()
	return cleaned if cleaned != "" else "my-animation"


func _frame_file(index: int, ext: String) -> String:
	return "shot01_%04d.%s" % [index + 1, ext]


func _export() -> void:
	if exporting:
		return
	if frame_textures.is_empty():
		export_status.text = "Capture some frames first, then export."
		return
	exporting = true
	if playing:
		_stop_playback()

	var base := _safe_name(export_name.text)
	if export_format == "mp4" or export_format == "gif":
		await _export_video(export_format, base)
		exporting = false
		return
	var use_jpg := export_format == "jpg"
	var ext := "jpg" if use_jpg else "png"
	var frame_dir := base + "/frames/" if export_format == "xml" else base + "/"
	var zip_path := "user://%s.zip" % base
	var zip := ZIPPacker.new()
	if zip.open(zip_path) != OK:
		export_status.text = "Couldn't start the export. Try again."
		exporting = false
		return

	var count := frame_textures.size()
	for i in count:
		var img := frame_textures[i].get_image()
		var bytes: PackedByteArray = img.save_jpg_to_buffer(0.9) if use_jpg else img.save_png_to_buffer()
		zip.start_file(frame_dir + _frame_file(i, ext))
		zip.write_file(bytes)
		zip.close_file()
		export_status.text = "Packing frame %d of %d..." % [i + 1, count]
		# Let the screen update so the app doesn't look frozen during big exports.
		await get_tree().process_frame

	if export_format == "xml":
		zip.start_file("%s/%s.xml" % [base, base])
		zip.write_file(_build_premiere_xml(base, count, ext).to_utf8_buffer())
		zip.close_file()
		zip.start_file("%s/How to open in Premiere.txt" % base)
		zip.write_file(_premiere_readme(base).to_utf8_buffer())
		zip.close_file()
	zip.close()

	var data := FileAccess.get_file_as_bytes(zip_path)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(zip_path))
	export_status.text = _deliver_file(data, base + ".zip", "application/zip")
	exporting = false


## MP4 and GIF are made by the browser (vcs-export.js), so they only work in the browser version.
## Frames go across one at a time so even long animations don't use too much memory.
func _export_video(kind: String, base: String) -> void:
	if not OS.has_feature("web"):
		export_status.text = "MP4 and GIF work in the browser version. Use Run in Browser to try them."
		return
	if not _load_export_tools():
		export_status.text = "Couldn't load the video tools. Try reloading the page."
		return
	# Left untyped on purpose: start/addFrame/finish live in the browser, not in Godot.
	var api = JavaScriptBridge.get_interface("vcsExport")
	var w := 1280 if kind == "mp4" else 480
	var h := 720 if kind == "mp4" else 270
	var count := frame_textures.size()

	export_status.text = "Getting ready..."
	api.start(kind, w, h, playback_fps, base, js_callback)
	await js_replied
	if js_reply.begins_with("error"):
		export_status.text = "Export stopped: " + js_reply.trim_prefix("error: ")
		return

	for i in count:
		var img := frame_textures[i].get_image()
		if img.get_width() != w or img.get_height() != h:
			img.resize(w, h, Image.INTERPOLATE_BILINEAR)
		api.addFrame(Marshalls.raw_to_base64(img.save_jpg_to_buffer(0.92)), js_callback)
		await js_replied
		if js_reply.begins_with("error"):
			export_status.text = "Export stopped: " + js_reply.trim_prefix("error: ")
			return
		export_status.text = "Making your %s: frame %d of %d..." % [kind.to_upper(), i + 1, count]

	export_status.text = "Finishing up..."
	api.finish(js_callback)
	await js_replied
	if js_reply.begins_with("done: "):
		export_status.text = "Downloaded %s. Check your Downloads folder." % js_reply.trim_prefix("done: ")
	else:
		export_status.text = "Export stopped: " + js_reply.trim_prefix("error: ")


## Loads the bundled browser code (res://web/vcs-export.js: MP4/GIF export and the file picker)
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


## A Final Cut Pro 7 XML project, which Premiere Pro can import (File > Import).
## It holds two things: a "Frames" bin with every frame, and the sequence, with each frame
## as a one-frame clip in order at the chosen frame rate. Keeping the frames in their own bin
## means the sequence is easy to find instead of being buried among the frames.
func _build_premiere_xml(base: String, count: int, ext: String) -> String:
	var rate := "<rate><timebase>%d</timebase><ntsc>FALSE</ntsc></rate>" % playback_fps
	var w := shot_viewport.size.x
	var h := shot_viewport.size.y
	var size := "<samplecharacteristics>%s<width>%d</width><height>%d</height><pixelaspectratio>square</pixelaspectratio></samplecharacteristics>" % [rate, w, h]
	var lines := PackedStringArray()
	lines.append("<?xml version=\"1.0\" encoding=\"UTF-8\"?>")
	lines.append("<!DOCTYPE xmeml>")
	lines.append("<xmeml version=\"4\">")
	lines.append("<project><name>%s</name><children>" % base.xml_escape())

	# The Frames bin: one master clip per frame. Each file is described in full here, once.
	lines.append("<bin><name>Frames</name><children>")
	for i in count:
		var file_name := _frame_file(i, ext)
		lines.append("<clip id=\"masterclip-%d\"><masterclipid>masterclip-%d</masterclipid><ismasterclip>TRUE</ismasterclip><name>%s</name><duration>1</duration>%s" % [i + 1, i + 1, file_name, rate])
		lines.append("<media><video><track><clipitem id=\"masterclipitem-%d\"><masterclipid>masterclip-%d</masterclipid><name>%s</name>" % [i + 1, i + 1, file_name])
		lines.append("<file id=\"file-%d\"><name>%s</name><pathurl>frames/%s</pathurl>%s<duration>1</duration><media><video>%s</video></media></file>" % [i + 1, file_name, file_name, rate, size])
		lines.append("</clipitem></track></video></media></clip>")
	lines.append("</children></bin>")

	# The sequence: every frame in order, each one frame long, pointing back to its master clip.
	lines.append("<sequence id=\"sequence-1\">")
	lines.append("<name>%s</name>" % base.xml_escape())
	lines.append("<duration>%d</duration>" % count)
	lines.append(rate)
	lines.append("<timecode>%s<string>00:00:00:00</string><frame>0</frame><displayformat>NDF</displayformat></timecode>" % rate)
	lines.append("<media><video><format>%s</format><track>" % size)
	for i in count:
		var file_name := _frame_file(i, ext)
		lines.append("<clipitem id=\"clipitem-%d\"><masterclipid>masterclip-%d</masterclipid><name>%s</name><enabled>TRUE</enabled><duration>1</duration>%s<start>%d</start><end>%d</end><in>0</in><out>1</out><file id=\"file-%d\"/></clipitem>" % [i + 1, i + 1, file_name, rate, i, i + 1, i + 1])
	lines.append("</track></video></media>")
	lines.append("</sequence>")

	lines.append("</children></project>")
	lines.append("</xmeml>")
	return "\n".join(lines)


func _premiere_readme(base: String) -> String:
	return "HOW TO OPEN THIS IN PREMIERE PRO\n\n" \
		+ "1. Unzip this folder and keep it somewhere it won't get deleted (not just in Downloads).\n" \
		+ "2. In Premiere Pro, choose File > Import and pick %s.xml.\n" % base \
		+ "   Premiere makes a new bin. Open it and double-click the sequence named %s\n" % base \
		+ "   to see your animation on the timeline. Your frames are in the Frames bin.\n" \
		+ "3. If Premiere says your media is offline or asks you to link media, click Locate,\n" \
		+ "   open the frames folder, and pick the first frame. Premiere should find the rest.\n" \
		+ "4. The sequence is %d frames per second, %d x %d pixels.\n" % [playback_fps, shot_viewport.size.x, shot_viewport.size.y]


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
