extends Node3D
## Virtual Claymation Studio: browser tech test.
## Builds the set, lights, clay puppet, cameras, and UI in code,
## then handles posing body parts and capturing frames.

const ORBIT_SPEED := 0.006
const TWIST_SPEED := 0.01
const PLAYBACK_FPS := 12.0
const HIGHLIGHT_COLOR := Color(1.0, 0.75, 0.3)
const DEFAULT_YAW := 0.35
const DEFAULT_PITCH := -0.25
const DEFAULT_DISTANCE := 4.5

# Work view: the orbiting camera the animator looks through while posing.
var work_camera: Camera3D
var orbit_target := Vector3(0, 0.8, 0)
var orbit_yaw := DEFAULT_YAW
var orbit_pitch := DEFAULT_PITCH
var orbit_distance := DEFAULT_DISTANCE

# Shot camera: the locked "tripod" camera that captures frames.
var shot_viewport: SubViewport
var shot_camera: Camera3D

# Puppet. Each part: {name, joint, materials, shapes, tip}.
# shapes = [mesh, local point a, local point b, radius] used for click picking.
# tip = a point on the part, in joint space, used as the handle when a click lands too close to the joint.
var puppet_root: Node3D
var parts: Array[Dictionary] = []
var rest_pose: Dictionary = {}

# Posing state.
var current_tool := "bend"            # "bend", "twist", or "move"
var hovered: Dictionary = {}
var active_part: Dictionary = {}
var highlighted: Dictionary = {}
var dragging := false
var drag_mode := ""           # "bend", "twist", "move", or "orbit"
var grab_local := Vector3.ZERO
var grab_screen_offset := Vector2.ZERO
var move_offset := Vector3.ZERO
var move_plane_y := 0.0

# Captured frames and playback.
var frame_textures: Array[ImageTexture] = []
var capturing := false
var playing := false
var play_index := 0
var play_time := 0.0

# Shared clay surface texture.
var clay_normal: NoiseTexture2D

# UI references.
var frames_label: Label
var part_label: Label
var fps_label: Label
var last_frame_rect: TextureRect
var playback_rect: TextureRect
var flash_rect: ColorRect
var play_button: Button
var tool_buttons: Dictionary = {}


func _ready() -> void:
	get_viewport().msaa_3d = Viewport.MSAA_2X
	_build_environment()
	_build_set()
	_build_lights()
	_build_puppet()
	_build_work_camera()
	_build_shot_camera()
	_build_ui()
	_save_rest_pose()
	_set_tool("bend")


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


# ---------------------------------------------------------------- puppet

func _build_puppet() -> void:
	puppet_root = Node3D.new()
	puppet_root.name = "Puppet"
	add_child(puppet_root)

	var shirt := Color(0.86, 0.42, 0.22)
	var pants := Color(0.24, 0.38, 0.66)
	var skin := Color(0.93, 0.76, 0.58)
	var shoes := Color(0.2, 0.17, 0.15)

	# The puppet faces +Z, toward the shot camera, so its left side is +X.
	var hips := _make_joint(puppet_root, Vector3(0, 0.88, 0), Vector3.ZERO)
	var hips_part := _new_part("Hips (whole body)", hips)
	hips_part["tip"] = Vector3(0, 0.5, 0)
	_add_sphere(hips_part, hips, Vector3.ZERO, 0.2, Vector3(1.2, 0.85, 0.95), pants)

	var torso := _make_joint(hips, Vector3(0, 0.06, 0), Vector3.ZERO)
	var torso_part := _new_part("Torso", torso)
	_add_capsule(torso_part, torso, 0.42, 0.21, shirt, 1)

	var head := _make_joint(torso, Vector3(0, 0.5, 0), Vector3.ZERO)
	var head_part := _new_part("Head", head)
	head_part["tip"] = Vector3(0, 0.3, 0.1)
	_add_sphere(head_part, head, Vector3(0, 0.2, 0), 0.2, Vector3.ONE, skin)
	_add_sphere(head_part, head, Vector3(0, 0.19, 0.2), 0.045, Vector3.ONE, skin)
	_add_eye(head, Vector3(0.075, 0.25, 0.165))
	_add_eye(head, Vector3(-0.075, 0.25, 0.165))

	for side_value in [1.0, -1.0]:
		var s: float = side_value
		var side_name: String = "Left" if s > 0.0 else "Right"

		var shoulder := _make_joint(torso, Vector3(0.27 * s, 0.4, 0), Vector3(0, 0, 12.0 * s))
		var upper_arm := _new_part(side_name + " Upper Arm", shoulder)
		_add_capsule(upper_arm, shoulder, 0.3, 0.085, shirt, -1)

		var elbow := _make_joint(shoulder, Vector3(0, -0.3, 0), Vector3.ZERO)
		var forearm := _new_part(side_name + " Forearm", elbow)
		_add_capsule(forearm, elbow, 0.26, 0.075, skin, -1)
		_add_sphere(forearm, elbow, Vector3(0, -0.29, 0), 0.085, Vector3.ONE, skin)

		var hip := _make_joint(hips, Vector3(0.12 * s, -0.04, 0), Vector3.ZERO)
		var thigh := _new_part(side_name + " Thigh", hip)
		_add_capsule(thigh, hip, 0.38, 0.1, pants, -1)

		var knee := _make_joint(hip, Vector3(0, -0.38, 0), Vector3.ZERO)
		var shin := _new_part(side_name + " Shin and Foot", knee)
		_add_capsule(shin, knee, 0.36, 0.09, pants, -1)
		_add_sphere(shin, knee, Vector3(0, -0.4, 0.05), 0.1, Vector3(0.9, 0.55, 1.4), shoes)


func _make_joint(parent: Node3D, pos: Vector3, rot_deg: Vector3) -> Node3D:
	var joint := Node3D.new()
	joint.position = pos
	joint.rotation_degrees = rot_deg
	parent.add_child(joint)
	return joint


func _new_part(part_name: String, joint: Node3D) -> Dictionary:
	# axis = the direction the part extends from its joint (joint space); twist = turn around that axis, in radians.
	var part := {"name": part_name, "joint": joint, "materials": [], "shapes": [], "tip": Vector3.ZERO,
		"axis": Vector3.UP, "twist": 0.0}
	parts.append(part)
	return part


## direction: -1 hangs down from the joint, +1 rises up from it.
func _add_capsule(part: Dictionary, parent: Node3D, length: float, radius: float, color: Color, direction: int) -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = length + radius * 2.0
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = Vector3(0, direction * length * 0.5, 0)
	var mat := _clay_material(color)
	mi.material_override = mat
	parent.add_child(mi)
	part["materials"].append(mat)
	part["shapes"].append([mi, Vector3(0, -length * 0.5, 0), Vector3(0, length * 0.5, 0), radius])
	var tip: Vector3 = part["tip"]
	if tip == Vector3.ZERO:
		part["tip"] = Vector3(0, direction * length, 0)
		part["axis"] = Vector3(0, direction, 0)


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


func _add_eye(parent: Node3D, pos: Vector3) -> void:
	var mesh := SphereMesh.new()
	mesh.radius = 0.035
	mesh.height = 0.07
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.05, 0.06)
	mat.roughness = 0.3
	mi.material_override = mat
	parent.add_child(mi)


func _save_rest_pose() -> void:
	rest_pose[puppet_root] = puppet_root.transform
	for part in parts:
		var joint: Node3D = part["joint"]
		rest_pose[joint] = joint.transform


func _reset_pose() -> void:
	for node in rest_pose.keys():
		var n: Node3D = node
		n.transform = rest_pose[node]
	for part in parts:
		part["twist"] = 0.0


# ---------------------------------------------------------------- cameras

func _build_work_camera() -> void:
	work_camera = Camera3D.new()
	work_camera.fov = 50.0
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
	orbit_yaw -= rel.x * ORBIT_SPEED
	orbit_pitch -= rel.y * ORBIT_SPEED
	_update_orbit()


## factor lets trackpad scrolling zoom in small, smooth steps.
func _zoom(multiplier: float, factor: float) -> void:
	var f := factor if factor > 0.0 else 1.0
	orbit_distance *= pow(multiplier, f)
	_update_orbit()


func _reset_view() -> void:
	orbit_yaw = DEFAULT_YAW
	orbit_pitch = DEFAULT_PITCH
	orbit_distance = DEFAULT_DISTANCE
	_update_orbit()


func _build_shot_camera() -> void:
	shot_viewport = SubViewport.new()
	shot_viewport.size = Vector2i(640, 360)
	shot_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	shot_viewport.msaa_3d = Viewport.MSAA_2X
	add_child(shot_viewport)

	shot_camera = Camera3D.new()
	shot_camera.fov = 40.0
	shot_camera.cull_mask = 1  # Layer 1 only, so the camera prop (layer 2) never shows up in shots.
	shot_viewport.add_child(shot_camera)
	shot_camera.position = Vector3(0.0, 1.0, 3.3)
	shot_camera.look_at(Vector3(0, 0.78, 0), Vector3.UP)
	shot_camera.current = true

	_build_camera_prop()


## A visible camera on a tripod in the work view, so students can see where the shot is taken from.
func _build_camera_prop() -> void:
	var prop_mat := StandardMaterial3D.new()
	prop_mat.albedo_color = Color(0.08, 0.08, 0.09)
	prop_mat.roughness = 0.4

	var prop := Node3D.new()
	add_child(prop)
	prop.global_transform = shot_camera.global_transform

	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.32, 0.22, 0.2)
	body.mesh = body_mesh
	body.position = Vector3(0, 0, 0.12)
	prop.add_child(body)

	var lens := MeshInstance3D.new()
	var lens_mesh := CylinderMesh.new()
	lens_mesh.top_radius = 0.07
	lens_mesh.bottom_radius = 0.08
	lens_mesh.height = 0.16
	lens.mesh = lens_mesh
	lens.rotation_degrees = Vector3(90, 0, 0)
	lens.position = Vector3(0, 0, -0.06)
	prop.add_child(lens)

	var pole := MeshInstance3D.new()
	var pole_mesh := CylinderMesh.new()
	var pole_height := shot_camera.position.y - 0.11
	pole_mesh.top_radius = 0.025
	pole_mesh.bottom_radius = 0.025
	pole_mesh.height = pole_height
	pole.mesh = pole_mesh
	pole.position = Vector3(shot_camera.position.x, pole_height * 0.5, shot_camera.position.z + 0.12)
	add_child(pole)

	for mi in [body, lens, pole]:
		var m: MeshInstance3D = mi
		m.material_override = prop_mat
		m.layers = 2
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


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
			_zoom(0.9, mb.factor)
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom(1.1, mb.factor)

	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
			_orbit(mm.relative)
		elif dragging:
			if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) == 0:
				# The button was released somewhere we didn't hear about (e.g. outside the window).
				_end_drag(mm.position)
				return
			match drag_mode:
				"bend":
					_bend(mm.position)
				"twist":
					_twist(mm.relative)
				"move":
					_move_to(mm.position)
				"orbit":
					_orbit(mm.relative)
		else:
			_update_hover(mm.position)

	elif event is InputEventKey:
		var k := event as InputEventKey
		if k.pressed and not k.echo:
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
				KEY_V:
					_reset_view()
				KEY_EQUAL, KEY_PLUS, KEY_KP_ADD:
					_zoom(0.85, 1.0)
				KEY_MINUS, KEY_KP_SUBTRACT:
					_zoom(1.15, 1.0)


## Press on the puppet: start using the current tool on that part.
## Press on empty space: start looking around.
func _begin_drag(screen_pos: Vector2) -> void:
	var hit := _pick_part(screen_pos)
	dragging = true
	if hit.is_empty():
		drag_mode = "orbit"
		Input.set_default_cursor_shape(Input.CURSOR_DRAG)
		return

	var part: Dictionary = hit["part"]
	var point: Vector3 = hit["point"]
	active_part = part
	_set_highlight(part)
	part_label.text = "Part: " + str(part["name"])
	drag_mode = current_tool
	Input.set_default_cursor_shape(Input.CURSOR_DRAG)

	match current_tool:
		"bend":
			var joint: Node3D = part["joint"]
			grab_local = joint.to_local(point)
			# A click right next to the joint gives almost no leverage, so grab the far end instead.
			if grab_local.length() < 0.12:
				grab_local = part["tip"]
			# Remember where the grabbed spot sits relative to the cursor on screen,
			# so the part never jumps when the drag starts.
			grab_screen_offset = work_camera.unproject_position(joint.to_global(grab_local)) - screen_pos
		"move":
			move_plane_y = point.y
			move_offset = puppet_root.position - point


func _end_drag(screen_pos: Vector2) -> void:
	dragging = false
	drag_mode = ""
	active_part = {}
	hovered = {}
	_update_hover(screen_pos)


func _update_hover(screen_pos: Vector2) -> void:
	if capturing:
		return
	var hit := _pick_part(screen_pos)
	var part: Dictionary = {}
	if not hit.is_empty():
		part = hit["part"]
	if is_same(part, hovered):
		return
	hovered = part
	_set_highlight(part)
	if part.is_empty():
		part_label.text = "Part: (none)"
		Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	else:
		part_label.text = "Part: " + str(part["name"])
		Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)


## Returns {"part": part, "point": world point where the click landed}, or {} for a miss.
func _pick_part(screen_pos: Vector2) -> Dictionary:
	var origin := work_camera.project_ray_origin(screen_pos)
	var dir := work_camera.project_ray_normal(screen_pos)
	var far_point := origin + dir * 100.0
	var best: Dictionary = {}
	var best_t := INF
	for part in parts:
		for shape in part["shapes"]:
			var mi: MeshInstance3D = shape[0]
			var local_a: Vector3 = shape[1]
			var local_b: Vector3 = shape[2]
			var radius: float = shape[3]
			var a := mi.global_transform * local_a
			var b := mi.global_transform * local_b
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
			if d <= radius:
				var t := origin.distance_to(on_ray) - sqrt(radius * radius - d * d)
				if t < best_t:
					best_t = t
					best = {"part": part, "point": origin + dir * t}
	return best


func _ray_hit_plane(screen_pos: Vector2, plane: Plane) -> Variant:
	var origin := work_camera.project_ray_origin(screen_pos)
	var dir := work_camera.project_ray_normal(screen_pos)
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
	var joint: Node3D = active_part["joint"]
	var pivot := joint.global_position
	var grab := joint.to_global(grab_local)
	var reach := grab.distance_to(pivot)
	if reach < 0.03:
		return
	var aim := screen_pos + grab_screen_offset
	var origin := work_camera.project_ray_origin(aim)
	var dir := work_camera.project_ray_normal(aim)
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


## Twist: dragging left or right turns the part around its own length.
func _twist(rel: Vector2) -> void:
	active_part["twist"] = float(active_part["twist"]) + rel.x * TWIST_SPEED
	_aim_part(active_part, _bone_direction(active_part))


## The way a part currently points, in world space.
func _bone_direction(part: Dictionary) -> Vector3:
	var joint: Node3D = part["joint"]
	var axis: Vector3 = part["axis"]
	return (joint.global_transform.basis * axis).normalized()


## Poses a part so it points along world_dir, using its rest pose and its stored twist.
## pose = (swing from the rest direction to the new direction) * rest pose * (twist around the part's length)
func _aim_part(part: Dictionary, world_dir: Vector3) -> void:
	var joint: Node3D = part["joint"]
	var parent := joint.get_parent() as Node3D
	var parent_basis := parent.global_transform.basis.orthonormalized()
	var local_dir := (parent_basis.inverse() * world_dir).normalized()
	var rest: Transform3D = rest_pose[joint]
	var axis: Vector3 = part["axis"]
	var rest_dir := (rest.basis * axis).normalized()
	if rest_dir.dot(local_dir) < -0.9995:
		# Pointing exactly opposite its rest direction has no unique swing; nudge it slightly.
		local_dir = (local_dir + rest.basis.z.normalized() * 0.02).normalized()
	var swing := Basis(Quaternion(rest_dir, local_dir))
	var twist := Basis(Vector3.UP, float(part["twist"]))
	joint.basis = (swing * rest.basis * twist).orthonormalized()


## Move: the whole puppet slides across the tabletop under the cursor.
func _move_to(screen_pos: Vector2) -> void:
	var hit_v: Variant = _ray_hit_plane(screen_pos, Plane(Vector3.UP, move_plane_y))
	if hit_v == null:
		return
	var target: Vector3 = hit_v
	var p := target + move_offset
	p.y = puppet_root.position.y
	p.x = clampf(p.x, -3.2, 3.2)
	p.z = clampf(p.z, -2.0, 2.8)
	puppet_root.position = p


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
	current_tool = tool_name
	var b: Button = tool_buttons[tool_name]
	b.button_pressed = true


# ---------------------------------------------------------------- frames

func _capture_frame() -> void:
	if capturing:
		return
	capturing = true
	if playing:
		_stop_playback()
	# Hide the hover glow so it never ends up in a captured frame.
	_set_highlight({})
	await RenderingServer.frame_post_draw
	var img := shot_viewport.get_texture().get_image()
	capturing = false
	var restore: Dictionary = active_part if not active_part.is_empty() else hovered
	_set_highlight(restore)
	frame_textures.append(ImageTexture.create_from_image(img))
	frames_label.text = "Frames captured: %d" % frame_textures.size()
	last_frame_rect.texture = frame_textures[frame_textures.size() - 1]
	flash_rect.color = Color(1, 1, 1, 0.8)
	var tween := create_tween()
	tween.tween_property(flash_rect, "color:a", 0.0, 0.25)


func _toggle_playback() -> void:
	if playing:
		_stop_playback()
	elif frame_textures.size() > 0:
		playing = true
		play_index = 0
		play_time = 0.0
		playback_rect.texture = frame_textures[0]
		playback_rect.visible = true
		play_button.text = "Stop (P)"


func _stop_playback() -> void:
	playing = false
	playback_rect.visible = false
	play_button.text = "Play (P)"


func _process(delta: float) -> void:
	fps_label.text = "FPS: %d" % Engine.get_frames_per_second()

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
		var step := 1.0 / PLAYBACK_FPS
		while play_time >= step:
			play_time -= step
			play_index = (play_index + 1) % frame_textures.size()
		playback_rect.texture = frame_textures[play_index]


# ---------------------------------------------------------------- UI

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["margin_left", "margin_top", "margin_right", "margin_bottom"]:
		margin.add_theme_constant_override(side, 12)
	layer.add_child(margin)

	var column := VBoxContainer.new()
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(column)

	# Top left: title, tools, view controls, status.
	var top_row := HBoxContainer.new()
	top_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(top_row)

	var help := PanelContainer.new()
	help.mouse_filter = Control.MOUSE_FILTER_STOP
	top_row.add_child(help)
	var help_box := VBoxContainer.new()
	help.add_child(help_box)

	var title := Label.new()
	title.text = "Virtual Claymation Studio: Tech Test"
	title.add_theme_font_size_override("font_size", 18)
	help_box.add_child(title)

	var tool_row := HBoxContainer.new()
	help_box.add_child(tool_row)
	var tool_title := Label.new()
	tool_title.text = "Tool:"
	tool_row.add_child(tool_title)
	var group := ButtonGroup.new()
	for entry in [["bend", "Bend (B)"], ["twist", "Twist (T)"], ["move", "Move Puppet (M)"]]:
		var tool_name: String = entry[0]
		var b := _make_button(entry[1])
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(_set_tool.bind(tool_name))
		tool_row.add_child(b)
		tool_buttons[tool_name] = b

	var tips := Label.new()
	tips.text = "Bend: drag a body part to pull it into place\n" \
		+ "Twist: drag left or right to turn a part\n" \
		+ "Move Puppet: drag the puppet across the table\n" \
		+ "Drag empty space to look around. Scroll to zoom.\n" \
		+ "Space: capture a frame    P: play"
	help_box.add_child(tips)

	var view_row := HBoxContainer.new()
	help_box.add_child(view_row)
	var view_title := Label.new()
	view_title.text = "View:"
	view_row.add_child(view_title)
	var zoom_in := _make_button("Zoom +")
	zoom_in.pressed.connect(_zoom.bind(0.85, 1.0))
	view_row.add_child(zoom_in)
	var zoom_out := _make_button("Zoom -")
	zoom_out.pressed.connect(_zoom.bind(1.15, 1.0))
	view_row.add_child(zoom_out)
	var reset_view := _make_button("Reset View (V)")
	reset_view.pressed.connect(_reset_view)
	view_row.add_child(reset_view)

	part_label = Label.new()
	part_label.text = "Part: (none)"
	help_box.add_child(part_label)

	fps_label = Label.new()
	help_box.add_child(fps_label)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(spacer)

	# Bottom right: shot camera preview and capture controls.
	var bottom_row := HBoxContainer.new()
	bottom_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom_row.alignment = BoxContainer.ALIGNMENT_END
	column.add_child(bottom_row)

	var shot_panel := PanelContainer.new()
	shot_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	bottom_row.add_child(shot_panel)
	var shot_box := VBoxContainer.new()
	shot_panel.add_child(shot_box)

	var shot_title := Label.new()
	shot_title.text = "SHOT CAMERA: this is what gets captured"
	shot_box.add_child(shot_title)

	var preview := Control.new()
	preview.custom_minimum_size = Vector2(480, 270)
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

	var buttons := HBoxContainer.new()
	shot_box.add_child(buttons)

	var capture_button := _make_button("Capture Frame (Space)")
	capture_button.pressed.connect(_capture_frame)
	buttons.add_child(capture_button)

	play_button = _make_button("Play (P)")
	play_button.pressed.connect(_toggle_playback)
	buttons.add_child(play_button)

	var reset_button := _make_button("Reset Pose")
	reset_button.pressed.connect(_reset_pose)
	buttons.add_child(reset_button)

	var status_row := HBoxContainer.new()
	shot_box.add_child(status_row)

	frames_label = Label.new()
	frames_label.text = "Frames captured: 0"
	frames_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_row.add_child(frames_label)

	var last_label := Label.new()
	last_label.text = "Last frame:"
	status_row.add_child(last_label)

	last_frame_rect = TextureRect.new()
	last_frame_rect.custom_minimum_size = Vector2(128, 72)
	last_frame_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	last_frame_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	status_row.add_child(last_frame_rect)


func _fill_preview(rect: TextureRect) -> void:
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _make_button(label_text: String) -> Button:
	var b := Button.new()
	b.text = label_text
	b.focus_mode = Control.FOCUS_NONE
	return b
