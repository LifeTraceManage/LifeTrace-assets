# LifeTrace-assets V1 specification

## Core interaction

1. Dock floats above the primary-monitor Windows taskbar; it does not modify or replace the taskbar.
2. Hover lifts and enlarges an icon once, and returns it on exit.
3. Clicking a pinned folder opens an upward drawer. Clicking descendants navigates within the same drawer.
4. Back navigates toward pinned root, then closes; files launch via the Windows default handler.
5. Maximized or fullscreen foreground windows hide Dock. Bringing the pointer to the last 5px of the work area in Dock horizontal range reveals it.
6. Add a pinned folder or program via pasted absolute path. Persist in JSON and restore on restart.

## Architecture

Single Rust process, independent Slint DockWindow and DrawerWindow, platform module via windows-sys 0.61, async worker-thread directory listing with stale-result generation guard, local JSON configuration. The taskbar and Explorer remain untouched. No file deletions or renames are performed by V1.

## Verification checklist

- [ ] Windows CI cargo check, tests and release build pass.
- [ ] Manual smoke test on Windows 10/11.
- [ ] Frameless Dock renders and pointer events are limited to visible surface.
- [ ] Pin, restart, click folder, descend, back and open a file.
- [ ] Maximize external app; hide; edge-reveal; hide on mouse exit.
- [ ] Test fullscreen games/video, taskbar auto-hide, secondary monitors, display scaling.
- [ ] Measure idle CPU/RAM and first-folder-frame latency.

## V1 caveats and follow-ups

The code is an alpha. Polling interval is 260ms, pin cap 9, directory list cap 450, primary-screen fixed layout. Add arbitrary item edit/reorder, native icons, file drag-drop, tray/autorun, event-driven window monitoring, virtualization, paging, and app signing later.
