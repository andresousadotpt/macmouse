# Clean-room notes

MacMouse is an independent implementation. It is **not** derived from the source
code of any other mouse utility, and no code, assets, strings, or configuration
files from another product are included in this repository.

## Process

1. **Observation (spec phase).** A shipped build of an existing mouse utility
   was inspected only at the *behavioural* level: which features are offered to
   the user, which public/system frameworks the program links against, and its
   process layout. No functions were decompiled and no implementation details
   (algorithms, constants, curves, data layouts) were transcribed.
2. **Specification.** The observations were rewritten as the functional
   requirements below, in our own words.
3. **Implementation.** MacMouse was written from this specification and from
   Apple's public documentation / well-known macOS event APIs, using the
   [macskeleton](https://github.com/andresousadotpt/macskeleton) template.

## Functional specification

### Process & permissions

- R1. Runs as a menu-bar agent (no Dock icon) with an optional settings window.
- R2. Requires the Accessibility permission to observe and modify mouse events.
  It must detect a missing permission, prompt the user, and start working
  automatically once granted — without a restart.
- R3. Optional "launch at login".
- R4. A global on/off switch that leaves all mouse input untouched when off.

### Scrolling (mouse wheels only)

- R5. Only discrete (line-based) wheel input is altered. Continuous input from
  trackpads and Magic Mouse passes through unchanged.
- R6. Smooth scrolling: each wheel notch becomes an animated, decelerating glide
  instead of a jump. Smoothness is selectable (off / regular / high).
- R7. Scroll speed is selectable (slow / medium / fast). Fast, consecutive wheel
  flicks accelerate the distance travelled.
- R8. Reverse the mouse-wheel direction independently of the trackpad.
- R9. Holding a keyboard modifier while scrolling changes the behaviour:
  horizontal scroll, precise (small, unsmoothed steps), fast scroll and zoom
  (one app zoom step per notch). Unassigned modifiers pass through, still
  honouring R8.

### Buttons

- R10. Extra buttons (middle and up) can be remapped. Primary/secondary buttons
  are never intercepted.
- R11. Triggers: single, double and triple click, and press-and-hold.
- R12. Actions: Mission Control, Application Windows, Show Desktop, Launchpad,
  move one Space left/right, Back, Forward, Middle Click, Look Up, Zoom In/Out,
  and a user-recorded keyboard shortcut.
- R13. Holding a button and moving the mouse ("drag") can trigger a directional
  gesture: up → Mission Control, down → Application Windows, left/right → move
  between Spaces. Alternatively the drag can pan/scroll the content.
- R14. Holding a button and turning the wheel can trigger a per-button action:
  zoom, horizontal scroll, or move between Spaces.
- R15. A button with no configured mapping behaves exactly as it did before.

### Configuration

- R16. Settings persist across launches in the user's Application Support folder
  and apply immediately.
- R17. Sensible defaults for a typical 5-button mouse.

## Design choices (ours, not observed)

- Single process: the event tap runs inside the menu-bar app (no helper app).
- System actions are triggered by pressing the shortcut macOS itself has bound
  to that action (read from the system's symbolic-hotkey table), or a standard
  key combination for app-level actions (Back = ⌘[, Look Up = ⌃⌘D, Zoom = ⌘= / ⌘−).
- No synthesized trackpad gestures; drag/scroll gestures map to discrete actions.
- Smooth scrolling uses an exponential-decay animator (see
  `Sources/MacMouseCore/Logic/ScrollAnimator.swift`).
- Pointer speed/acceleration control is out of scope for v0.1.
- No licensing, telemetry, or auto-updater; updates ship through Homebrew.
