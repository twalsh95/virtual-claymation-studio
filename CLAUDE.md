# Virtual Claymation Studio

A browser-based 3D stop-motion (claymation) studio built in Godot, for the opening unit of Tom Walsh's high school Videography course (Media Arts Career Academy, Atlantis Charter School). Students pose clay characters and props, frame shots with a real-camera vocabulary, capture frames, and export for editing in Premiere on class MacBooks. A gamified tutorial (micro-story levels) comes later.

- **Design decisions, status, and the "why":** `Virtual Claymation Studio Design Document.md`. This is the source of truth. Read it before building a feature. Update its status column when something is built or tested, and record any design change Tom makes while building.
- **Live app:** https://walshclassroom.com/virtual-claymation-studio/ (GitHub Pages from `docs/`, repo `twalsh95/virtual-claymation-studio`, **public**).
- **Hub:** the Walsh Classroom site is a separate repo (`twalsh95.github.io`, local folder `SY 26-27\Personal Work\walshclassroom`). Its `brand/PLATFORM.md` describes the shared nav bar, sign-in plan, and the app list. This app's hub card and help text live in that repo's `apps.js`.

## Working with Tom

- Tom is a teacher, not a professional developer. He is detail-oriented and wants the reasoning behind recommendations. Explain in plain words and keep jargon out of what you tell him.
- Honest feedback over agreement. Challenge ideas when there's a reason to, especially when an easy-to-code choice would undercut the teaching goal.
- Ask before destructive actions (deleting files, rewriting history, overwriting his work). Minimize changes to working code; fix the root cause.
- Student-facing text in the app (buttons, tooltips, help) must be clear to 9th to 12th graders. Use real film and video terms (pan, tilt, dolly, shot size) since teaching them is part of the point, and explain them in tooltips.
- He tests in the browser and reports back. Give him a short, specific test list after each change.
- Commits and pushes: ask before pushing. End commit messages with the attribution lines your harness specifies. His batch scripts (`save-to-github.bat`, `push-to-github.bat`, `setup-git.bat`) still work and are git-ignored.
- **No student data in the repo.** It's public. Keep names, rosters, and school data out of code, specs, and commits.

## Project layout

```
Godot project/
  project.godot          Godot 4.7.2, Compatibility renderer, 1280x720, stretch canvas_items/expand
  scenes/main.tscn       One Node3D ("Studio") with the script; everything else is built in code
  scripts/studio.gd      The whole app (~3,300 lines). See "Code map"
  web/vcs-export.js      Bundled JS export libraries (Mediabunny 1.63.0 MPL-2.0, gifenc 1.0.3 MIT) + glue
  web/LICENSES.txt       Their licenses (MPL-2.0 requires shipping this)
  export_presets.cfg     Web preset; exports to ../docs/index.html
docs/                    The exported web build that GitHub Pages serves. Generated: don't hand-edit
Virtual Claymation Studio Design Document.md
CLAUDE.md
```

## Build, test, publish

Godot is installed on Tom's Windows PC (4.7.2 standard, not .NET). Find the executable before using it; ask Tom if you can't.

- **Syntax and runtime check:** run the project headless for a few seconds and read the output for script errors, e.g. `godot --headless --path "Godot project" --quit-after 300`. Fix every error and warning (Tom treats warnings as worth fixing).
- **Web export:** `godot --headless --path "Godot project" --export-release "Web" ../docs/index.html`. Always release, never debug (a debug build shows "(DEBUG)" in the tab title and runs slower).
  - If the Godot editor is open, it holds its own copy of the export settings and can overwrite `export_presets.cfg`. After changing that file, have Tom use Project > Reload Current Project, or close the editor before exporting.
- **Publish:** commit and push `main`. Pages redeploys in about 1 to 2 minutes (check the repo's Actions tab: "pages build and deployment").
  - GitHub Pages lets browsers cache files for about 10 minutes. After a push, a hard refresh (Ctrl+Shift+R / Cmd+Shift+R) shows the new build. A cache-busting query string only refreshes `index.html`, not the engine files.
- Export settings that matter: Thread Support **off** (GitHub Pages can't send the cross-origin isolation headers threads need), Extensions off, `include_filter="web/*"` so the JS libraries ship, `html/canvas_resize_policy=0`, and `html/head_include` (see next section).

### The Walsh Classroom bar

`html/head_include` in `export_presets.cfg` loads `https://walshclassroom.com/platform/wc.js` (draws the 44px hub bar and sets `--wc-bar-height` on `<html>`) and a small script that sizes the Godot canvas to the window minus the bar every frame. That's why the canvas resize policy is None (0): Godot's Adaptive policy always uses the full window height, which would put the bar over the toolbar. The head include uses only single quotes, because `export_presets.cfg` stores it as a double-quoted string. The bar also shows during Run in Browser from the editor, since it loads from the live site.

## Code map (scripts/studio.gd)

Sections are marked with `# ------ name` comment lines:

- **Constants** (top): `FRAME_RATES` [10,12,15,24,30,60] (Premiere's sequence rates; default 12), `CHARACTER_TYPES`, `PROP_TYPES`, `HAIR_STYLES`, `CLAY_PALETTE`, `SPAWN_SPOTS`, `POSE_TOOLS` [bend, twist, move, lift, squash], `CAMERA_TOOLS` [pan, truck, dolly, zoom], `MODE_INFO` (indicator light colors), render layers `LAYER_WORLD`=1, `LAYER_CAMERA_PROP`=2, `LAYER_GHOSTS`=4.
- **world**: environment (its ambient light is the "room light"), table set, shared clay texture.
- **scene objects**: every character or prop is a "figure" Dictionary (fields documented above the members). `_spawn(type, id, where)`, `_build_humanoid` (kid, man, woman), `_build_quadruped` (dog, cat: "Hips (whole body)" and "Chest" joints), `_build_prop` (each prop has a squashable "Body" node). Mesh helpers: `_add_limb`, `_add_sphere`, `_add_box`, `_add_cylinder`, `_add_cone`. Style: `_register_slots`, `_set_figure_color`, `_build_hair`/`_set_hair`, `_figure_style`/`_apply_style`.
- **adding, removing, scene list**: `_add_figure`, `_remove_selected` (confirms), `_remove_figure` (hides; undoable), `_select_figure`, `_refresh_scene_list`.
- **poses, default pose, undo**: a snapshot is `{objects:[{id,type,root,joints,twists,squash,style}], camera, fov}`. Snapshots drive undo (`MAX_UNDO` 50), captured frames, onion ghosts, and saved projects. `_get_pose`, `_apply_pose`, `_apply_object`.
- **onion skin**: ghost duplicates in a magenta no-depth-test material on `LAYER_GHOSTS`, pooled by "layer:id". The capture camera's mask excludes ghosts.
- **work view**: the orbiting Studio View camera, plus Camera View (a 16:9 `camera_screen` TextureRect fitted under the toolbar by `_layout_camera_screen`). Picking goes through `_active_cam()` and `_cam_coords()` so it works in both views.
- **shot camera**: a SubViewport camera (`SHOT_RENDER_SIZE` 1280x720 for the live picture) on a tripod model. Locked by default; real-term tools; shot size and angle presets (`_frame_shot` frames the selected figure); warns (doesn't block) when moved after frames exist.
- **input**: posing math. Bend pins the dragged tip to the cursor with a ray-sphere test (`_ray_to_sphere`). Each part stores swing-from-rest plus a separate twist (`_aim_part`), which prevents twist drift; don't replace this with incremental rotations. Picking uses capsules, spheres, and exact ray-box tests (`_pick_part`, `_ray_capsule`, `_ray_box`). Keys: B/T/M/U/Q tools, C view, O onion, V reset view, L lock camera, Space capture, P play, Ctrl/Cmd+Z undo, Delete/Backspace remove, +/- zoom.
- **frames**: capture, delete last, playback. Frame pictures are kept at `FRAME_KEEP_SIZE` (480x270, `_keep_size`) to save memory; full-size pictures are made fresh at export. Play uses `play_list` (this shot, or every shot for Play All / Shift+P).
- **shots**: `shots` is an array of `{label, poses, textures, undo, working, lighting, light_locked, relight}`; `active_shot` is the index. `_bind_active_shot` points `frame_poses`, `frame_textures`, and `undo_stack` at the active shot's own arrays, so capture, onion skin, and undo need no shot logic. `working` is the scene as the student left the shot. `_new_shot` inserts after the active shot and keeps the current scene; `_switch_shot`, `_move_shot`, `_delete_shot` (pushes a `restore_shot` step onto the landing shot's undo), `_refresh_shot_strip` (cards rebuilt on every frame change).
- **lighting**: each shot's `lighting` is `{preset, room, aim, lights: {key/fill/back: {on, brightness, temp, gel, pos}}}` (`LIGHT_PRESETS`, `GELS`, Kelvin via `_kelvin_color`). Three SpotLight3Ds (`light_nodes`; only the key casts shadows) aimed at `aim`, plus lamp models on `LAYER_CAMERA_PROP` (`lamp_models`, never captured, no shadows). `_apply_lighting` sets everything from a setup; every change goes through `_lighting_changed`, which marks the shot `relight` if it has frames. `_relight_if_needed` re-makes kept pictures (before capture, play, shot switch, export, and on Lock). Capturing a shot's first frame sets `light_locked`; `_refuse_if_lighting_locked` guards changes. Lighting undo steps are `{"lighting": setup}` in the shot's undo stack. Lamps are dragged like the tripod (`_pick_light`, `_grab_light_to`, drag mode "grab_light", indicator "light"). Panel: `_build_lighting_panel`, `_refresh_lighting_panel`, `_fit_lighting_panel` (scrolls on short screens). Export re-renders with each shot's own lighting (`render_lit_shot`).
- **UI**: all built in code in `_build_ui`. Toolbar (two rows) in a top-left column with the status toast and the How To, Scene List, and Style panels. The shot panel (preview, Capture, Play, frame rate, Export, onion skin) is bottom-right in its own full-screen MarginContainer, so side panels can't push it off-screen. `_fit_shot_preview` shrinks the preview on short screens.
- **projects and autosave**: project format v4 (`JSON.from_native`/`to_native`): `shots: [{label, frames, working, lighting, light_locked}]` plus `active_shot`. v1 and v2 files upgrade to a single Shot 1; files without lighting get Three-Point, locked where the shot has frames (`_clean_lighting` also repairs damaged setups); files from a newer version are refused with a reload hint. `.clay` files via a hidden file input (`js_open_callback`). Autosave every 5 s to `user://autosave.claymation`; a welcome-back prompt on start. Frames are stored as poses and re-rendered on load.
- **export**: Size menu (`EXPORT_SIZES`: Small 480x270, 720p default, 1080p, 4K for MP4 only; GIF is always 480x270). Small uses the kept pictures; other sizes re-render every frame from its pose: `_begin_render` (remembers the scene, resizes the SubViewport, shows the busy overlay, which also blocks input) / `_export_image` / `_end_render` (puts it all back). Formats: zip of PNG/JPG frames, one `shotNN/` folder per shot; a Premiere package (FCP7 xmeml v4: a Frames bin, a Shots bin with one sequence per shot, and an empty "<name> - Edit" sequence, plus the frames and a readme); MP4/GIF of all shots or this shot (`export_scope`). Browser work goes through `JavaScriptBridge` and `window.vcsExport` in `web/vcs-export.js`, one call per frame (base64), each answered through `js_replied`: MP4/GIF (`start`/`addFrame`/`finish`) and zips (`zipStart`/`zipAdd`/`zipFinish`/`zipCancel`, a hand-written store-only zip gathered into Blobs every 32 MB, max 4 GB). JS replies must come after the call returns (`later()`), or Godot misses them. In the editor, zips go straight to Downloads through ZIPPacker.

## Known gotchas

- Godot warnings to avoid: unused parameters, locals shadowing built-ins (e.g. `to_local`, `basis`, `convert`).
- Strings in GDScript: use `\n`, not `\\n`.
- The XML Premiere package has been tested on Windows only. It keeps an "experimental" label until it's tested on a class MacBook.
- MP4/GIF export only works in the browser build, not in the editor.
- Headless runs can't draw, so code that waits for `RenderingServer.frame_post_draw` (relighting, export, opening projects) hangs in a headless test unless the test emits that signal itself. To see real renders, run the project in a window with a `--script` that saves `shot_viewport` images.

## What's next

1. **Multiple shots** and **frame memory / export size** (Nov 12; see the design document): in testing. The new Premiere package still needs a test in Premiere, and a long project (a few hundred frames) still needs a run on a class MacBook.
2. **Lighting.** Built Nov 12, browser-tested Nov 13 (33 to 54 FPS on a MacBook). Still to check: frame rate on a Chromebook.
3. **Backdrops.** Designed Nov 13: see "Backdrop design" in the design document (includes a fourth lamp, Background). Build from that; record any changes there.
4. Button and keyboard posing in small steps (accessibility).
5. Tutorial levels.
6. Platform sign-in and cloud saves (Walsh Classroom platform; waits on the student data review).
7. Test the live site and the Premiere package on a class MacBook.
