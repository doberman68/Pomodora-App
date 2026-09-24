# Pomodoro Timer for macOS and iOS

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

## iPhone & iPad

The `iOS/` folder has the iOS 17+ app: the same dial, full screen, with touch controls.

| Action | What it does |
| --- | --- |
| Drag the dial | Set time, 1–60 min, with a haptic tick per minute |
| Tap the knob / big play button | Start / pause |
| Double-tap the knob / reset button | Reset to 0 |
| 25 / 5 / 15 / 50 min buttons | Set and start |
| Gear | Colors (same 8 presets + custom), keep screen awake, Lock Screen toggle |

- **Lock Screen & Dynamic Island:** live countdown while running or paused
- **Widgets:** Home Screen dial (small, large) and a Lock Screen pie
- **Alarm:** chime notification fires on time even if the app is closed

### Build

Requires the full Xcode app and an Apple Developer account.

```bash
cd iOS
./generate.sh YOURTEAMID   # installs XcodeGen via Homebrew if needed, opens Xcode
```

Your Team ID is at developer.apple.com → Account → Membership details. The Xcode project is generated from `project.yml` and is not committed; re-run `./generate.sh` after pulling changes.

In Xcode, pick your iPhone as the run destination and press ⌘R. First time on a device: enable Developer Mode on the iPhone (Settings → Privacy & Security → Developer Mode).

### TestFlight (share with others)

1. In App Store Connect, create an app with bundle ID `com.doberman68.pomodorotimer`
2. In Xcode: destination "Any iOS Device", then Product → Archive → Distribute App → TestFlight & App Store
3. In App Store Connect → TestFlight, add testers by email
