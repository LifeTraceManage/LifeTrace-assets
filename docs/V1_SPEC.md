# V1.1 interaction and technical specification

## Window lifecycle

1. DockWindow: floating, frameless, always-on-top on primary-monitor working area. Only launcher/shortcut content is displayed.
2. DrawerWindow: frameless, stays closed until a pinned folder is activated, fixed maximum size. It reuses the same panel when navigating subfolders.
3. ManagerWindow: normal decorated desktop window, not topmost, hidden on startup. Open **only on explicit tray action**. Close means hide, not application exit.
4. AppTray: Slint SystemTrayIcon (introduced in Slint 1.18), menu: Open Manager / Reveal Dock / Quit.
5. While an external fullscreen/maximized window is foreground, auto-hide Dock. Reveal on bottom edge, and also through tray menu with short grace period.

## Management actions

- Add: folder or application/file full path, reject missing/duplicate paths, cap at nine pins.
- Rename: select pin, input a 1–20 character title, persist without filesystem rename.
- Reorder: buttons move pinned entry up/down. Persist order.
- Remove: unpin one item, never delete actual file or directory.
- Smart-hide and hover animation: persisted boolean switches; should affect behavior without restart.
- Data compatibility: old configs without the two new settings fields use `true` defaults.

## Design guidelines

- Separate appearance between desktop launcher (dark, restrained) and content browsing (light, legible).
- Keep folder icons consistent; no typography less than 10px for content labels.
- Avoid continuous animations; hover changes settle after a single movement.
- No acrylic blur or large unbounded render effects in V1.
- Maintain visible focus and keyboard navigation via native widgets in management screen.

## Testing and acceptance

- [ ] Windows CI cargo fmt/check/test/release succeeds.
- [ ] Tray icon displays and can open/restore manager without requiring Dock to be shown.
- [ ] Manager stays hidden on startup; system tray right-click menu works.
- [ ] Close manager; Dock still operates. Tray Quit actually ends process.
- [ ] Add, remove, rename, reorder reflect in Dock and persist across restart.
- [ ] Smart hide and hover animation toggles take effect immediately.
- [ ] Drawer opens and browses real nested folders, files open in default application.
- [ ] Verify no transparent hit regions steal clicks from unrelated apps.
- [ ] Test Windows 10 and 11; 100%, 150%, 200% scale; standard and auto-hide taskbar; fullscreen video and games; Explorer restart.
- [ ] Measure CPU at idle and process memory on test hardware (no claims before measurement).

## Backlog

Actual system app icons, Explorer drag-and-drop, friendly path picker, virtualized/paged file list, user-selectable icon size and themes, full multi-monitor positioning, event-driven foreground monitoring, proper single-instance guard, startup installation, signed release artifacts.
