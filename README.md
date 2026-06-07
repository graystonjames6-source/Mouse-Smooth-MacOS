# Mouse Smooth

A clean, lightweight macOS menu bar utility that customizes external mouse
scrolling **independently** from the trackpad.

Tired of macOS forcing the same "natural scrolling" setting on both your
trackpad and your external mouse? Mouse Smooth fixes that.

> **Status: v1 feature-complete.** All seven listed features work. Remaining
> work is polish (app icon, CONTRIBUTING.md, signed release builds).

## Download

**[⬇ Download the latest release](https://github.com/graystonjames6-source/Mouse-Smooth-MacOS/releases/latest)**

1. Download `MouseSmooth-vX.Y.Z.dmg` from the release page.
2. Open the DMG and drag **Mouse Smooth** into your **Applications** folder.
3. First launch: macOS will refuse with *"Mouse Smooth cannot be opened
   because the developer cannot be verified."* This is expected — see below.

### Allowing the app past Gatekeeper

This release is **ad-hoc signed, not notarized** (no $99/yr Apple Developer
ID). The code is identical to what's in this repo — there's no malware
risk above what you accept by trusting this repo.

**Recommended fix (works on every macOS version):**

```sh
xattr -dr com.apple.quarantine "/Applications/Mouse Smooth.app"
```

Then open the app normally. That's it.

> Why this is the recommended path: on macOS Sonoma / Sequoia, ad-hoc signed
> apps downloaded from the internet sometimes get rejected with
> *"Mouse Smooth is damaged and can't be opened"* — a misleading message;
> the binary is fine, but Gatekeeper refuses to validate it. The `xattr`
> command removes the "downloaded from the internet" tag and Gatekeeper
> stops caring.

**Alternative (right-click → Open):** on macOS 14 and earlier, right-click
`Mouse Smooth.app` → **Open** → confirm in the dialog. On macOS 15+ this
path sometimes works, sometimes is replaced by **System Settings → Privacy
& Security → Open Anyway**.

Once opened the first time, macOS remembers and won't block subsequent launches.

## v1 features

- [x] Reverse scroll direction for the **external mouse only**
- [x] Keep trackpad natural scrolling unchanged
- [x] Adjustable scroll speed (0.1×–5.0×)
- [x] Optional smooth scrolling (60 Hz event synthesis with exponential decay)
- [x] Optional mouse acceleration toggle (software, scroll-only)
- [x] Menu bar only — no Dock icon
- [x] Simple settings window
- [x] Launch at login toggle

## Requirements

- macOS 13 Ventura or later
- Xcode 15 or later (to build)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (to generate the Xcode project)

## Building from source

```sh
# 1. Install XcodeGen (one-time)
brew install xcodegen

# 2. Generate the Xcode project
xcodegen generate

# 3. Open and run
open MouseSmooth.xcodeproj
```

Hit ⌘R in Xcode. A mouse icon appears in your menu bar.

> `MouseSmooth.xcodeproj` is **not** committed to git. It is generated from
> `project.yml`. This keeps the repo diff-friendly for contributors.

## Permissions

Mouse Smooth needs one permission:

- **Accessibility** (System Settings → Privacy & Security → Accessibility)

This is required because macOS only allows apps with Accessibility access to
observe and modify low-level input events via `CGEventTap`. There is no
public, sandbox-safe API to do scroll customization differently. Comparable
tools (Mos, LinearMouse, Scroll Reverser) work the same way.

On first launch, Settings will show a permission banner with three buttons:

- **Request Access…** — triggers the standard macOS prompt
- **Open System Settings** — deep-links to the right pane
- **I've granted access** — manual recheck (we also poll once per second)

Once granted, the banner disappears and the menu bar icon changes from outline
to filled to indicate "active".

## Limitations & honest caveats

- **Not sandboxed.** App Sandbox blocks `CGEventTap`, which is the only public
  way to intercept scroll events. We trade sandbox for the feature actually
  working. The hardened runtime is still enabled.
- **No kernel extensions.** Everything runs in userspace.
- **No private APIs.**
- **"Mouse acceleration" is a *scroll-only* setting in Mouse Smooth.** When
  OFF, we replace the OS's velocity-curved pixel delta with a flat constant
  per wheel tick. We deliberately do **not** touch `com.apple.mouse.scaling`
  (which would affect cursor movement and require re-login) — that's
  surprising behavior we don't want hidden behind a checkbox.
- **Smooth scrolling works by event synthesis.** When enabled, we consume
  the original wheel event and emit a series of small synthesized continuous
  scroll events on a 60 Hz timer with exponential decay (~130 ms time
  constant). Self-event de-duplication uses a magic value in the synthesized
  events' `eventSourceUserData` field so our own tap doesn't re-process them.
  Modifier flags (⌘/⌃/⌥) are preserved across synthesized events.
- **Slow-wheel floor.** macOS applies a steep velocity curve to scroll
  events — slow wheel rotation produces tiny pixel deltas. We apply a
  per-tick floor (`minPixelsPerTick` in `ScrollTransformer.swift`, default
  30 px) so slow scrolling stays usable. Fast scrolls already exceed the
  floor and are unaffected.
- **Launch at login** uses `SMAppService.mainApp` (macOS 13+). The first time
  you enable it, macOS may show its own approval prompt in System Settings.
  Unsigned debug builds may be rejected — this is a macOS guardrail.

## Project layout

```
.
├── project.yml                       # XcodeGen spec
├── Sources/
│   ├── MouseSmoothApp.swift          # @main, MenuBarExtra, Window scene
│   ├── MouseSmoothController.swift   # Wires settings ↔ monitor ↔ permission
│   ├── SettingsStore.swift           # @Published, UserDefaults-backed
│   ├── SettingsView.swift            # SwiftUI settings UI
│   ├── AccessibilityPermission.swift # AX trust state + system-settings deep link
│   ├── MouseEventMonitor.swift       # CGEventTap lifecycle
│   ├── ScrollTransformer.swift       # Pure event-mutation logic
│   ├── SmoothScrollEngine.swift      # 60Hz event-synthesis smoother
│   └── LaunchAtLoginManager.swift    # SMAppService.mainApp wrapper
├── README.md
└── LICENSE
```

## Contributing

Issues and PRs welcome. A `CONTRIBUTING.md` will be added once the app has
real functionality to contribute against.

## License

MIT — see [LICENSE](LICENSE).
