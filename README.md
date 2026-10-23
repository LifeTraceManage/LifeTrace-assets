# LifeTrace-assets · Windows Dock (V1 alpha)

An independent floating Dock for Windows 10/11. **Keeps the Windows taskbar**. Clicking pinned folders opens an upward drawer with the real files and nested folders, without opening a new Explorer window.

**Development status:** first functional implementation slice. Not yet verified by Windows CI or on-device testing; no CPU/RAM performance measurement is claimed.

## V1 alpha functionality

- Rust + Slint UI: a frameless, always-on-top Dock with one-shot hover float/scale animation, plus a separate folder drawer.
- Click folders to navigate, open regular files with Windows Shell, go back, or open current folder in Windows Explorer.
- Pin folders or application paths from the **+** panel (paste absolute Windows path). Pins are stored in the APPDATA/LifeTrace-assets/config.json folder.
- Hide when an external window is maximized or fullscreen; touching the bottom edge of the Windows work area reveals the Dock. On mouse exit it hides again.
- Async directory reads prevent blocking the animations. An AtomicU64 generation token discards stale results. Up to 450 entries are shown per folder.
- Click outside drawer to dismiss. Use the **×** at the right of Dock to quit; hidden windows do not end the event loop.

## Build / Run

Requires Windows 10/11, recent stable Rust (MSVC), Visual Studio C++ Build Tools and network access for the first dependency install.

    cargo run --release

CI produces a Windows release executable as a GitHub Actions artifact when the build passes.

## Important V1 limits

- Uses generic symbols instead of native app icons/thumbnails.
- Pinning currently requires pasting an absolute path; Explorer drag-and-drop is planned.
- Maximum of nine pinned items; currently removal is limited to **remove last pin** in the Add panel.
- First 450 entries per folder; scrolling supported, but no complete pagination.
- Smart-hide uses a light 260ms polling timer, not WinEventHook.
- The primary display uses a fixed 740×98 Dock. High-DPI, multi-monitor, taskbar orientation, exclusive fullscreen and transparent hit testing still need hardware validation.
- No installer, system tray, single-instance guard, autorun, or folder watcher yet.

No user files are copied, moved or deleted when pinning. All filesystem navigation is read-only; opening files uses the operating system default handler.

## Files

- ui/dock.slint: Dock window and hover visuals.
- ui/drawer.slint: folder drawer and Add panel.
- src/config.rs: persisted shortcuts.
- src/directory.rs: bounded folder enumeration.
- src/platform.rs: Win32 API and ShellExecute.
- src/main.rs: navigation, background loading and smart visibility.
- docs/V1_SPEC.md: tests, constraints and backlog.
