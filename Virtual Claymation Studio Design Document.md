# Virtual Claymation Studio: Design Document

Last updated: Nov 12, 2026 · Tom Walsh

**This file is the source of truth for design decisions.** It replaced the claude.ai version on Nov 12, 2026, when the project moved to Claude Code. Record decisions here, and update the status column as features are built and tested. How the code works lives in CLAUDE.md.

Live app: https://walshclassroom.com/virtual-claymation-studio/

## Project overview

A browser-based 3D claymation studio, built in Godot, for the opening Videography unit starting fall 2027. The unit teaches students to connect storytelling to visuals: a character, and something that happens to that character, told entirely in images. It works as an intro to video without video.

A gamified tutorial teaches stop motion, video vocabulary, framing, basic lighting, and editing concepts through micro-stories solved frame by frame. It doubles as a proof of concept for a possible standalone game.

**Why rebuild the unit:** real clay takes nearly a quarter and teaches few video skills. It loses time to lost clay, lost frames, camera mix-ups, and inconsistent lighting. Larger classes make it worse: more camera logistics, less one-on-one time, stretched resources. Buy-in also varies by cohort. Target length is about 3 weeks.

**What real clay offers that this won't:** tactile sculpting and hands-on physical lighting. **If the app doesn't land:** the unit may be dropped rather than run as real clay again.

## Decisions so far

| Area | Decision | Notes |
| --- | --- | --- |
| Engine | Godot 4 (4.7.2), scripted in GDScript | GDScript is the safest choice for web export |
| Platform | Web-hosted, runs on shared class MacBooks; Chromebooks need the site allowlisted by IT | Uses Godot's lighter Compatibility renderer; Thread Support off |
| Hosting | GitHub Pages from the `docs` folder of this repo, served at walshclassroom.com/virtual-claymation-studio/ as part of the Walsh Classroom hub (live Nov 12, 2026) | The repo is public. The Walsh Classroom bar runs across the top of the app |
| Clay characters | Armature puppets: smooth-blended clay shapes on a simple skeleton, with a clay-look shader | Mirrors real wire armatures; poses save small |
| Free-form clay | Deferred to a later milestone | Real-time sculpting is the hardest technical piece |
| Physics | None. Students animate every object, including props | Level checks are end-state conditions |
| Shots | A project holds multiple shots, each with its own camera setup | Cutting happens in the editor, not in the app |
| Lighting | Basic, adjustable lights; settings stay consistent automatically | Consistency is handled by the app; basics are taught, not mastered |
| Saving | Student sign-in with cloud saves, plus a download-project-file backup | Required: MacBooks are shared across classes. Sign-in is moving to the Walsh Classroom platform (one sign-in for every app, on Narrative Studio's Firebase project; see brand/PLATFORM.md in the walshclassroom repo). Waits on the student data review |
| Export | Numbered image sequence, one per shot | Students import into Premiere on the MacBooks as an image sequence, then set frame rate, cut shots, and add sound (Rush was discontinued in Sept 2026) |

## Build milestones

Milestones run in priority order; target dates are estimates and flex with available build time.

1. **Browser tech test** (target: Nov to Dec 2026). One clay puppet posed in a browser, with Google sign-in saving to Firebase.
    - Gate: runs smoothly on a MacBook; Chromebook checked second.
2. **Core studio, the minimum for class** (target: Jan to Mar 2027). Accounts, pose, shots, lights, capture, onion skin, export.
3. **Tutorial levels** (target: Mar to Apr 2027). First three levels; the rest over the summer.
4. **Spring playtest** (target: Apr to May 2027). Broadcast cohort, who did real clay this fall.
    - **Go/no-go, end of June 2027:** is the core studio solid enough for class? If not, rethink the unit (real clay or drop it).
5. **Fixes and extras** (target: summer 2027). Remaining levels, character lab, free-form clay.
6. **Launch:** Videography unit, fall 2027.

Milestone 2 alone replaces the logistics of the real-clay unit, so it is the piece the June go/no-go judges.

## Core studio (version one)

Version one is the minimum worth bringing to class: even without the game layer, it removes the logistics problems of the real-clay unit.

1. **Set:** a tabletop stage with a backdrop
2. **Puppets:** one or two preset armature characters; select a joint and rotate or move it
3. **Props:** simple objects (ball, box, goal) that can be moved and rotated
4. **Lights:** a key, fill, and back light with adjustable position, brightness, and color; settings save with the project
5. **Camera and shots:** each shot has its own camera, placed, aimed, and locked; adjustable lens (focal length); add, rename, and reorder shots
6. **Frame capture:** one button saves the full scene state as a frame
7. **Onion skin:** faint ghosts of the previous one or two frames
8. **Timeline and playback:** scrub frames, delete or replace a frame, play back at a chosen frame rate
9. **Autosave and undo**
10. **Export:** numbered image sequence

Also in version one: student sign-in with cloud saves, and a teacher view showing level progress and student shots. Later milestones: character lab (build and save custom puppets), free-form clay lump.

### Feature decisions

Decided after the first tech test (Oct 27). The tech test ran with no errors at 53 to 60 FPS in a browser on a school laptop.

| Feature | Decision | Status |
| --- | --- | --- |
| Tool controls | Large on-screen Bend, Twist, and Move Puppet buttons plus keyboard shortcuts; hover tooltips on every button; an indicator light shows the mode (green Bend, yellow Twist, purple Move Puppet, red Camera, blue reserved for lights) | In testing |
| Camera controls | On-screen zoom and reset buttons; drag empty space to look around, no modifier keys | In testing |
| Studio and Camera View | Toggle between orbiting the set and posing through the shot camera, with 16:9 frame guides | In testing |
| Onion skin | Ghost copies of the puppet from the last 1 or 3 frames, never captured | In testing |
| Undo | Undo for posing changes; Delete Last Frame for captures | In testing |
| Default pose | Set as Default Pose; Reset Pose returns to it | In testing |
| Posing without dragging | Button and keyboard posing in fixed small steps (accessibility, reinforces small increments) | Planned |
| Character and prop style | Style panel for the selected object: color buttons per part (people: Shirt, Pants, Skin, Hair, Shoes; animals: Fur, Muzzle, Ears; props: Color) with a clay palette including six skin tones, plus hairstyles for people (None, Short, Long, Ponytail, Bun, Curly). Each frame remembers its colors and hair, so restyling mid-shot only affects new frames; Undo covers style changes. Dog and cat bodies are two sections (hips and chest) so the spine can bend | In testing |
| Moving the shot camera | Locked by default. Camera View tools use real terms (Pan/Tilt, Truck/Pedestal, Dolly, Zoom with a mm lens readout); in Studio View students grab and slide the tripod. Shot size and angle presets, a default camera position, and a warning (not a block) when moved after frames are captured. Nov 13 fix (Tom's bug report): once a camera tool like Pan/Tilt was chosen, there was no way back to sliding the tripod freely. Added a **Move Tripod** tool (drag anywhere to slide the camera; works in Camera View too), and grabbing the tripod in Studio View now works whatever camera tool is chosen | In testing |
| Lighting | Key, Fill, and Back lamps per shot, mood presets, and Lock Lighting at first capture. Designed and built Nov 12; see "Lighting design" below. Nov 13: all 11 browser tests passed (moods, per-light controls, dragging lamps, Center on Selected, lock at first capture, unlock and relight, undo, new shots and Apply to All Shots, per-shot lighting in exports, reload and older files); 33 to 54 FPS, sometimes 60, on a MacBook. Not yet checked on a Chromebook | Tested (MacBook); Chromebook to check |
| Backdrops | Curved paper sweep per shot: colored paper and simple painted scenes, Make a Backdrop from students' own images, a separate floor menu, and a Background light. Designed and built Nov 13; see "Backdrop design" below | In testing |
| Green screen | A perfect-key green backdrop and floor (unaffected by lights), included as a utility rather than a taught skill. Designed and built Nov 13; see "Backdrop design" below | In testing |
| Export | Zip of numbered frames (PNG default, JPG to save space) and a Premiere package (Final Cut Pro 7 XML + frames + instructions) are built. PNG frames and the Premiere package were tested in Premiere on Windows (Oct 28): the import creates the sequence plus a Frames bin. The package keeps an "experimental" label until it's tested on a class MacBook. MP4 (H.264, 1280 x 720, made by the browser's video encoder through the bundled Mediabunny library) and animated GIF (480 x 270, gifenc) are built and tested in the browser and Premiere (Oct 29); both work in the browser version only. Libraries are bundled in the app (web/vcs-export.js, licenses in web/LICENSES.txt), so no outside servers are needed. Frame rate menu: 12 fps default, plus 10, 15, 24, 30, 60 (Premiere sequence rates, so every export imports cleanly). Audio left out for now; possible later feature. Nov 12: Size menu (Small, 720p default, 1080p, 4K for MP4 only) and one folder per shot; see "Frame memory and export size" | In testing |
| Saving projects | Frames are saved as poses, not pictures, and re-rendered when a project opens, so project files are tiny. Autosave to the browser every 5 seconds with a Welcome Back prompt (survives refreshes on the same MacBook, since students sign in with their own Google ID); New, Save, and Open Project buttons with a project file (.clay) for moving between computers. Cloud saves come later, after the data review | In testing |
| Characters and props | The scene holds any number of characters and props, added from Add Character (Kid, Man, Woman, Dog, Cat) and Add Prop (Ball, Box, Goal, Floor Marker, Table, Chair, Cone, Can, Plank, Rock) menus, with Remove (undoable) and a Scene List. Tools: Bend, Twist, Move, plus Lift (raise anything off the table, for jumps and bounces) and Squash (volume-preserving squash and stretch on props). Undo, onion skin, frames, and saved projects track every object; older one-puppet project files still open | In testing |
| Walsh Classroom bar | The shared Walsh Classroom bar (logo, app name, Help, All apps) runs across the top; the studio fills the space under it. The shot preview shrinks on short screens so the shot panel always fits | Live (Nov 12) |
| Multiple shots | Built Nov 12 as designed below: shot strip, New Shot, switching, labels, Move Earlier/Later, Delete Shot (undoable), Play All (Shift+P), Start New Shot button on the camera warning, project format v3 (older files open as Shot 1), frames exported one folder per shot, Premiere package with a Shots bin (one sequence per shot) and an empty Edit sequence, MP4/GIF All shots or This shot. Nov 12 browser check: exports work and the per-shot folders are right. Still to check: switching between shots in the strip, the Premiere import, and a class MacBook | In testing |

### Multiple shots design

Decided Nov 12, 2026, before building.

**What a shot means to a student:** one camera setup and the frames captured through it ("everything the camera records from one setup until the cut"). Moving the camera inside a shot is still allowed for a deliberate pan or dolly; the camera-moved warning stays and gains a **Start New Shot** button.

| Question | Decision | Why |
| --- | --- | --- |
| Where a new shot starts | From the end of the current shot: same poses, props, and camera. The student reframes and keeps animating | Supports matching action across shots (Level 6) with no extra steps. Picking any starting frame (for coverage) is a possible later addition |
| Active shot | One at a time. Capture adds to it, onion skin shows only its frames, Play plays it. **Play All** plays every shot in order | Students see their cuts before opening Premiere |
| Switching shots | The scene and camera return to that shot's last frame, so Capture continues it. Unsaved posing in each shot is kept | Switching never loses work |
| Telling shots apart | A strip of shot cards along the bottom: thumbnail, number (Shot 1, Shot 2), optional label (e.g. "CU of Kid's face"), frame count, and a + New Shot card. Rename, reorder, delete (confirms, undoable) | Looks like their storyboard from pre-production; the frame timeline (scrub, replace) can grow from it later |
| Shared across shots | Characters and props in the scene, frame rate, and later lighting (Lock Lighting) | Premiere needs one frame rate per sequence; consistent lighting is the app's job |
| Frames export | One folder of numbered frames per shot | Matches "one image sequence per shot" |
| Premiere package | Each shot as its own clip in a Shots bin, plus an empty sequence set to the project frame rate. Built as one short sequence per shot (Premiere treats a sequence dragged into another like a clip), since the XML format can't describe an image sequence as a single clip | Students assemble, order, and trim the edit themselves, which is the skill being taught |
| MP4 and GIF | A menu: All shots in order (default, a rough cut for screening) or This shot only | Quick sharing without making it the editing path |
| Older project files | Open as a single Shot 1 | No lost work |

### Frame memory and export size

Decided and built Nov 12, 2026 (in testing). Assumed (not yet measured) that full-size frame pictures would use too much memory on class MacBooks. The browser zip was tested on its own (opened cleanly with Windows' zip tools, including a 75 MB zip); Nov 12 browser check: the export sizes work. Still to check: the Premiere import, opening the zip on a Mac, 4K MP4 on a MacBook, and a long project on a class MacBook.

| Question | Decision | Why |
| --- | --- | --- |
| What the app keeps in memory | Each frame's picture at 480 x 270 (about 0.5 MB instead of 3.7 MB), plus its pose | Students only ever see frames at preview size or smaller. A 360-frame film drops from about 1.3 GB to under 200 MB |
| Full-size pictures | Made fresh at export: the app sets up each frame's saved pose and takes a new picture at the chosen size, then puts the scene back | Frames are already saved as poses; project files already rebuild this way |
| Export size menu | Small (480 x 270, instant, uses the stored pictures), 720p (1280 x 720, default), 1080p (1920 x 1080), and 4K (3840 x 2160) for MP4 only. GIF stays 480 x 270 | Teaches resolution as a video term. 4K frame zips would be several gigabytes; MP4 is built one frame at a time. The app checks whether the computer can make 4K video before starting. GIFs only have 256 colors, so bigger isn't better |
| Frame zips | Built by the browser piece by piece instead of all at once in memory (store-only zip, no compression needed since PNG and JPG are already compressed; no outside library) | The old way held the whole zip in memory twice, which would fail for long films at 1080p |
| Lighting (later) | Anything that changes the picture must be saved with each frame or held still | Frames are re-rendered at export, so a lighting change after capturing would otherwise change earlier frames |

### Lighting design

Decided Nov 12, 2026, before building. Today the set has three fixed lights students can't see or change (a warm shadow-casting key from the front right, a cool fill from the front left, a back light from behind and above) plus a dim room light.

**The big idea:** frames are made fresh at export, so lighting can belong to the shot instead of to each frame. Changing a shot's lighting relights every frame in it together, so lighting flicker can't happen. That's how the app keeps lighting consistent automatically. Lock Lighting then guards against relighting frames by accident.

| Question | Decision | Why |
| --- | --- | --- |
| What lighting belongs to | Each shot has its own lighting setup. A new shot copies the current shot's lighting; an "Apply to all shots" button copies it everywhere. Changing a shot's lighting relights all its frames | No flicker. Allows a mood change between scenes (day to night); mismatched lighting between shots becomes a teachable continuity moment |
| The lights | Three lamps with fixed roles: Key, Fill, and Back. Any can be turned off. Shown as lamps on stands in Studio View (like the tripod; never captured). Only the Key casts shadows; the dim room light stays | Fixed roles teach three-point lighting directly. Fill light is soft in real life, and one shadow keeps the app fast on Chromebooks |
| Per-light controls | On/off, brightness, color temperature (a warm-to-cool slider: tungsten 3200K to daylight 5600K), and colored gels (such as red, blue, green) | Real terms; color temperature and gels are basics students will meet on real sets |
| Mood presets | A starting point students then adjust: Three-Point, High-Key (bright, few shadows; comedy), Low-Key (dark, dramatic; noir), Side Light (half the face in shadow; mystery), Under Light (horror), Silhouette (back light only) | The core of Level 5 ("Set the mood"): see a mood, then learn which light makes it |
| Moving lights | In Studio View, drag a lamp around the table like the tripod; a height slider raises or lowers it. Lamps always aim at the subject | Direction is the biggest part of mood, and placement stays visible and physical |
| Lock Lighting | Lights are free while setting up a shot and lock when its first frame is captured. Unlocking warns that changes will relight all of the shot's frames | Like a real crew locking down before shooting |
| Left for later | Lighting changes during a shot (a lamp switching off, a lightning flash) | A good story tool, but it brings back flicker and adds complexity |

**Settled while building (Nov 12):**
- Where lamps aim: an aim point saved with the shot's lighting (default: the middle of the table at chest height). **Center on Selected** moves the whole setup to point at the selected character or prop. The aim never follows clicks on its own, or clicking a character would relight the shot.
- The lamps are spotlights, so they make a pool of light on the backdrop like real studio lamps (the old key light lit everything evenly). Projects saved before lighting open with Three-Point lighting, so they look a little different from before.
- Relighting happens when it's needed (before capturing, playing, switching shots, or exporting, and when locking), with a "Relighting Shot 2" progress screen. It doesn't happen on every slider move.
- Lighting changes can be undone (Ctrl+Z), including a mood preset.
- The panel opens from **Lighting** in the camera row. On short screens it scrolls so it never covers the shot strip.
- Preset looks were checked in real renders. Silhouette is a dark figure with a bright outline (a rim-light silhouette); a lit backdrop behind the subject would need the Backdrops feature.

**Frame rate (Nov 13):** 33 to 54 FPS, sometimes 60, on a MacBook (the first tech test, before lighting, ran 53 to 60). Smooth enough for posing. Still to check on a Chromebook. If it's slow there, cheap fixes exist without redesigning: a smaller or softer key shadow, or less anti-aliasing.

### Backdrop design

Decided Nov 13, 2026, before building. Today's backdrop is a flat light-blue wall behind a brown tabletop. Wide shots show a hard seam where the wall meets the table and dark gaps at the corners.

| Question | Decision | Why |
| --- | --- | --- |
| What a backdrop belongs to | Each shot, like lighting. A new shot copies the current backdrop and floor | Different scenes happen in different places |
| Changing it after capturing | Changes all of the shot's frames together (re-made the same way as relighting), so no flicker. No third lock: the app asks first when the shot has frames ("This changes the backdrop in all 14 frames of Shot 2") | Consistency is automatic; asking first prevents accidents without another lock to learn |
| Shape | A curved paper sweep (cyclorama) that curves from the wall down toward the table, wide enough to fill the corners of a wide shot | Removes the seam and horizon line. It's what real tabletop animators and product photographers use, and real studio vocabulary |
| Preset backdrops | Colored paper sweeps (white, black, gray, sky blue, and a few bold colors) plus 6 to 8 simple flat-style scenes drawn in code to match the clay look (for example: daytime sky with hills, sunset, night sky, city skyline, a room with a window) | Gives students places to start without outside art (no licensing questions in a public repo). Make a Backdrop covers anything richer |
| Make a Backdrop | The student picks a picture from their computer (a photo, a scanned drawing, anything they made). The app crops it to fill the backdrop and shrinks it (about 1920 pixels wide, JPG) so project files stay manageable. It's stored inside the project file and never sent to a server | Students design their own setting. The app can't judge whether an image is school-appropriate; that stays a classroom rule. When cloud saves arrive, student images become part of the student data review |
| Floor | A separate Floor menu, chosen independently of the backdrop: Wooden table (default, today's look), Paper (matches the backdrop, for a seamless sweep), Grass, Sand, Pavement, Wood floor, Snow, and Green screen. Floors are made in code | Tom's choice (Nov 13): more combinations than sets that pick the floor automatically |
| Green screen | A green backdrop and a green floor in pure chroma green that lights and shadows don't affect, so Premiere's Ultra Key removes them cleanly. Picking the green backdrop shows a tip to switch the floor to green too | A utility, not a lesson in lighting a green screen |
| Background light | A fourth lamp, Background, joins Key, Fill, and Back. It lights the backdrop, not the subject: it stays aimed at the backdrop when lamps are moved or Center on Selected is used. Same controls as the others (on/off, brightness, color temperature, gel, height, drag to move), no shadow. Presets set it too (for example, Silhouette lights the backdrop brightly and leaves the subject dark) | Real set role (four-point lighting). Makes a true silhouette possible (dark figure against a bright backdrop), lets a night sky glow, and a gel on it colors the backdrop. Changes the lighting design from three lamps to four |

**Settled while building (Nov 13):**
- Paper colors: White, Gray, Black, Sky Blue (the default, today's color), Yellow, Red, Purple, Mint. Scenes (7): Sunny Day, Sunset, Night Sky, City, City at Night, Room, Underwater.
- The sweep and table are now 11 units wide (the table was 7), so wide shots no longer show dark corners.
- A picture backdrop covers the middle of the sweep, about what a wide shot sees. Pictures are cropped to 16:9 from the center (trimming the top and bottom, or the sides) and kept at up to 1920 x 1080. A project holds up to 12 pictures. The browser converts any picture it can show to JPG first, so iPhone photos work in Safari.
- Remove Picture asks first; shots using that picture go back to Sky Blue paper.
- Picking the green backdrop shows a tip with a **Make Floor Green** button. A "Paper (matches the backdrop)" floor under a green backdrop is green too.
- The Backdrop button sits next to Lighting in the camera row (group renamed SET). When both panels are open, they share the space above the shot strip.
- The Background light sits low behind the subject and always points at the middle of the backdrop. Center on Selected doesn't move it. Projects saved before it existed keep their look (Background light off). Silhouette now uses it: a bright backdrop, a dim back light for a rim, and no light on the front.
- Changing the backdrop or floor can be undone (Ctrl+Z).
- Preset looks were checked in real renders on Tom's PC (Nov 13). High-Key's background light was turned down so white paper doesn't wash out.

**Technical notes:** pictures are stored once per project. Projects from before backdrops open with today's look (sky-blue paper, wooden table). Still to check: frame rate with the Background light on a MacBook and a Chromebook, and that autosave stays smooth with several pictures in a project.

## Gamified tutorial

Every level is a micro-story: a character, a problem, and an action told in frames. Each level pairs a stop-motion skill with a video skill, and authorship shifts to the student as levels progress. The sequence below is a **draft to revise together**, not final.

**Authorship progression (gradual release):**

- **Levels 1 to 3:** the game gives the character, the problem, and the solution
- **Levels 4 to 6:** the game gives the character and the problem; the student chooses the solution
- **Levels 7 to 8:** the game gives only the character; the student invents the problem
- **Final project:** "There needs to be a character, and something needs to happen to that character."

**Level design rules (proposed):**

- The movement cap per frame is a per-level setting, not one fixed number
- A level checks the end state (ball in goal) plus constraints (cap respected, minimum frame count, required shots)
- Later levels also check spacing, so students can't win by always moving the maximum
- Each level fits in half of a 50-minute period, leaving room for a Do Now and reflection

**Draft level sequence:**

| # | Challenge | Story given | Stop-motion skill | Video skill |
| --- | --- | --- | --- | --- |
| 1 | Roll the ball to the mark | Everything | Small, even increments; onion skin | Frame, frame rate |
| 2 | Make the ball stop softly | Everything | Spacing: ease in and ease out | Timing |
| 3 | Score the goal | Everything | Posing a character, anticipation | Blocking |
| 4 | Get the shot | Character and problem | Keeping action readable | Shot sizes, framing |
| 5 | Set the mood | Character and problem | Holds: letting a moment land | Key light direction, mood |
| 6 | Cut it together | Character and problem | Matching action across shots | Shots, cutting, continuity |
| 7 | Make it happen | Character only | Squash and stretch | Camera angle |
| 8 | Your scene | Character only | Combining skills | Multiple shots, basic edit |

Levels 6 and 8 include work in editing software outside the app.

**Questions to work through:**

- Is "Set the mood" the right lighting level, given lighting is basics only?
- How does a student show understanding beyond winning a level (screenshot, short reflection, exit ticket)?
- Should a level ever be failable, or only "not yet complete"?

## Unit structure

The unit opens the Videography course in fall 2027: about 15 class days of 50 minutes. Students work individually. The split below is a starting estimate.

| Days | Phase | What students do |
| --- | --- | --- |
| 1 to 6 | Tutorial levels | One or two levels a day, with a Do Now and short reflection |
| 7 | Pre-production | Concept and storyboard for the final project |
| 8 to 13 | Final project | Animate in the studio, export the image sequence, edit and add sound |
| 14 to 15 | Screening and critique | Show work, give and receive feedback |

**Assessment:** the final project is graded on animation and Videography skills, not on finishing the game. Specific criteria and student choices (UDL) to be built together.

**Primary standards framework:** Multimedia Production and Broadcast CTE, with Graphic Design CTE and Media Arts Foundational Skills as supplements. Specific standards not yet selected.

**Unit vocabulary (draft):**

| Category | Terms |
| --- | --- |
| Stop motion | frame, armature, onion skin, increment, spacing, ease in, ease out, anticipation, hold, squash and stretch |
| Video basics | frame rate (fps), timing, shot, shot size (wide, medium, close-up), framing, camera angle (high, low, eye level), lens, resolution (720p, 1080p, 4K) |
| Lighting | key light, fill light, back light, background light, three-point and four-point lighting, mood, high-key, low-key, silhouette, color temperature, gel, consistency |
| Set | backdrop, sweep (cyclorama), green screen, chroma key |
| Editing | sequence, cut, continuity, import, export |
| Story | character, problem, action, blocking |

## Open questions

- [ ] How do students control the studio: mouse and keyboard only, or also touch (Chromebook touchscreens)?
- [ ] Should the unit run entirely on MacBooks in class, with Chromebooks as a bonus for home work? Animating on Chromebooks and editing on MacBooks adds a file-transfer step.
- [ ] Data review: has an administrator approved storing student data for cloud saves? Default until then: store only the account ID, first name, and class code.
- [ ] Ask IT to allowlist walshclassroom.com on Chromebooks (never requested for Narrative Studio)
- [x] What frame rate should projects default to? 12 fps, with 10, 15, 24, 30, and 60 in the menu.
- [ ] How much puppet detail do you want: simple blob figures, or faces with swappable mouths and eyes like real claymation?
- [ ] Should students see a score or stars per level, or just complete/not yet?
- [ ] Who playtests in spring, and how is feedback collected?
- [ ] For the possible game version: what makes it different from the classroom tutorial (story, more levels, sharing)?
- [ ] Test the Premiere package and the live site on a class MacBook.
