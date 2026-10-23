# LifeTrace-assets — Windows Dock & Drawer

A lightweight floating Dock that preserves the Windows taskbar. The V1.1 source separates everyday desktop actions from configuration: the Dock opens applications and folder drawers, and a **management window stays hidden until explicitly opened from the system tray**.

> Status: implementation source. Windows CI and real-device behavior require validation; no verified EXE or memory benchmark is currently claimed.

## Interface

- **Dock:** dark translucent-looking low-decoration shelf with soft rounded tiles, single hover lift and consistent icon spacing. No add/delete/exit controls on the visible Dock.
- **Folder drawer:** clean light surface; click a folder to navigate within the same panel, click a file to open with Windows, back button, close button, or open in Explorer.
- **Manager:** separate normal window, **not always-on-top** and **hidden by default**; open from the LifeTrace icon in the Windows notification area (left click, or right click → 打开管理中心). Add folders/app paths, rename pinned titles, move up/down, remove shortcuts without changing underlying files.
- **Appearance/behavior:** manager switches for smart hide on maximize/fullscreen and hover animation, persisted in JSON.
- **Tray:** background entry to manage Dock, reveal Dock, and quit. Closing the manager hides it, leaving Dock/tray alive.

## Build

Windows 10/11, stable MSVC Rust toolchain, C++ build tools:

```powershell
git clone https://github.com/LifeTraceManage/LifeTrace-assets.git
cd LifeTrace-assets
cargo run --release
```

CI is defined at `.github/workflows/windows-ci.yml`. `cargo check` + tests + Release build are intended but must **actually pass** before distributing an executable.

## Persistence

`%APPDATA%\LifeTrace-assets\config.json`

The app manages only shortcuts and app settings; it doesn't move or delete referenced files.

## V1.1 known limits

- **Windows CI/runtime validation pending.** This source has not been built on a Windows host in this session.
- Fixed primary-monitor layout; high-DPI/multi-monitor/taskbar auto-hide and transparency hit-testing need real-device testing.
- Pin dialog currently accepts absolute pasted paths, up to 9 entries; direct Explorer drag/drop and per-app extracted icons are upcoming.
- First 450 files of a folder are shown, no full paging or thumbnails yet.
- Smart-hide currently checks foreground state and mouse position every 260ms. No WinEventHook or system tray activation shell integration beyond Slint's built-in tray.
- Slint native software renderer may require compatibility validation with layered transparent Windows windows.

## Structure

- `ui/dock.slint`, `ui/drawer.slint`, `ui/manager.slint`, `ui/tray.slint`
- `src/main.rs`: window visibility, model synchronization and navigation
- `src/config.rs`: persisted shortcut list and settings
- `src/directory.rs`: async directory data source
- `src/platform.rs`: Win32 working-area, cursor, fullscreen checks, ShellExecute
- `docs/V1_SPEC.md`: interaction and QA checklist
