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
| Moving the shot camera | Locked by default. Camera View tools use real terms (Pan/Tilt, Truck/Pedestal, Dolly, Zoom with a mm lens readout); in Studio View students grab and slide the tripod. Shot size and angle presets, a default camera position, and a warning (not a block) when moved after frames are captured | In testing |
| Lighting | Fully adjustable lights, with a Lock Lighting option for the scene to keep lighting consistent | Planned |
| Backdrops | Preset backdrops shown as physical backdrops in the studio, plus a Make a Backdrop option using students' own images | Planned |
| Green screen | A green backdrop option, included as a utility rather than a taught skill | Planned |
| Export | Zip of numbered frames (PNG default, JPG to save space) and a Premiere package (Final Cut Pro 7 XML + frames + instructions) are built. PNG frames and the Premiere package were tested in Premiere on Windows (Oct 28): the import creates the sequence plus a Frames bin. The package keeps an "experimental" label until it's tested on a class MacBook. MP4 (H.264, 1280 x 720, made by the browser's video encoder through the bundled Mediabunny library) and animated GIF (480 x 270, gifenc) are built and tested in the browser and Premiere (Oct 29); both work in the browser version only. Libraries are bundled in the app (web/vcs-export.js, licenses in web/LICENSES.txt), so no outside servers are needed. Frame rate menu: 12 fps default, plus 10, 15, 24, 30, 60 (Premiere sequence rates, so every export imports cleanly). Audio left out for now; possible later feature | In testing |
| Saving projects | Frames are saved as poses, not pictures, and re-rendered when a project opens, so project files are tiny. Autosave to the browser every 5 seconds with a Welcome Back prompt (survives refreshes on the same MacBook, since students sign in with their own Google ID); New, Save, and Open Project buttons with a project file (.clay) for moving between computers. Cloud saves come later, after the data review | In testing |
| Characters and props | The scene holds any number of characters and props, added from Add Character (Kid, Man, Woman, Dog, Cat) and Add Prop (Ball, Box, Goal, Floor Marker, Table, Chair, Cone, Can, Plank, Rock) menus, with Remove (undoable) and a Scene List. Tools: Bend, Twist, Move, plus Lift (raise anything off the table, for jumps and bounces) and Squash (volume-preserving squash and stretch on props). Undo, onion skin, frames, and saved projects track every object; older one-puppet project files still open | In testing |
| Walsh Classroom bar | The shared Walsh Classroom bar (logo, app name, Help, All apps) runs across the top; the studio fills the space under it. The shot preview shrinks on short screens so the shot panel always fits | Live (Nov 12) |
| Multiple shots | Next major feature. Design not started | Next |

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
| Video basics | frame rate (fps), timing, shot, shot size (wide, medium, close-up), framing, camera angle (high, low, eye level), lens |
| Lighting | key light, fill light, back light, mood, consistency |
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
