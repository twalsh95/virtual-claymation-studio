# Virtual Claymation Studio: Design Document

Last updated: Oct 26, 2026 · Tom Walsh

Live version: https://claude.ai/artifact/71Rhm3k47PjK2EtJmjt1LB

## Project overview

A browser-based 3D claymation studio, built in Godot, for the opening Videography unit starting fall 2027. The unit teaches students to connect storytelling to visuals: a character, and something that happens to that character, told entirely in images. It works as an intro to video without video.

A gamified tutorial teaches stop motion, video vocabulary, framing, basic lighting, and editing concepts through micro-stories solved frame by frame. It doubles as a proof of concept for a possible standalone game.

**Why rebuild the unit:** real clay takes nearly a quarter and teaches few video skills. It loses time to lost clay, lost frames, camera mix-ups, and inconsistent lighting. Larger classes make it worse: more camera logistics, less one-on-one time, stretched resources. Buy-in also varies by cohort. Target length is about 3 weeks.

**What real clay offers that this won't:** tactile sculpting and hands-on physical lighting. **If the app doesn't land:** the unit may be dropped rather than run as real clay again.

## Decisions so far

| Area | Decision | Notes |
| --- | --- | --- |
| Engine | Godot 4, scripted in GDScript | GDScript is the safest choice for web export |
| Platform | Web-hosted, runs on shared class MacBooks; Chromebooks need the site allowlisted by IT | Uses Godot's lighter Compatibility renderer; verify current web-export details in Godot docs |
| Hosting | Static hosting, such as GitHub Pages | Recent Godot versions export in a way that hosts there easily (general knowledge, to verify) |
| Clay characters | Armature puppets: smooth-blended clay shapes on a simple skeleton, with a clay-look shader | Mirrors real wire armatures; poses save small |
| Free-form clay | Deferred to a later milestone | Real-time sculpting is the hardest technical piece |
| Physics | None. Students animate every object, including props | Level checks are end-state conditions |
| Shots | A project holds multiple shots, each with its own camera setup | Cutting happens in the editor, not in the app |
| Lighting | Basic, adjustable lights; settings stay consistent automatically | Consistency is handled by the app; basics are taught, not mastered |
| Saving | Student Google sign-in with cloud saves (Firebase), reusing Narrative Studio's classroom system: join codes, teacher roster, read-only student browsing | Required: MacBooks are shared across classes. A download-project-file button stays as a backup. Godot-to-Firebase connection is part of the first tech test |
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
- [ ] Data review: Google sign-in works technically, but has an administrator approved storing student data in a teacher-run Firebase project? Default until then: store only the Google account ID, first name, and class code.
- [ ] Ask IT to allowlist the app's site on Chromebooks (never requested for Narrative Studio)
- [ ] What frame rate should projects default to (12 fps is common in stop motion)?
- [ ] How much puppet detail do you want: simple blob figures, or faces with swappable mouths and eyes like real claymation?
- [ ] Should students see a score or stars per level, or just complete/not yet?
- [ ] Who playtests in spring, and how is feedback collected?
- [ ] For the possible game version: what makes it different from the classroom tutorial (story, more levels, sharing)?
