# Pomodoro Timer for macOS

A floating, always-on-top visual countdown timer modeled on the physical "Time Timer": grey bezel, white face, navy disk that shrinks as time runs out. You set it by turning the dial with the mouse, like the real one.

## Build & run

Requires macOS 13+ and the Xcode Command Line Tools (`xcode-select --install`).

```bash
./build.sh              # builds build/PomodoroTimer.app
open build/PomodoroTimer.app

./build.sh --install    # or install to /Applications
```

The app lives in the menu bar (timer icon). It has no Dock icon.

## Controls

| Action | What it does |
| --- | --- |
| Drag the dial face | Set time, 1–60 min, snaps to whole minutes (stops at 0 and 60) |
| Click the center knob | Start / pause. At 0 it restarts the last duration |
| Double-click the knob | Reset to 0 |
| Drag the small tab on the right bezel | Transparency (up = solid, down = 20%) |
| Scroll over the timer | Transparency |
| Drag any corner of the bezel | Resize (stays square, 160 px up to screen height) |
| Drag the bezel edges or face corners | Move the window |
| Right-click / control-click | Menu: presets, transparency slider, float on top, color, size, hide, quit |

**Color:** pick one of 8 frame + disk combos, or choose any disk or frame color with the system color picker (applies live).

Menu bar icon shows the countdown while running and has the same menu.

When time is up it plays a chime and posts a notification. Allow notifications on first launch.

Position, size, color, transparency, float-on-top and last duration are remembered.
