#![cfg_attr(windows, windows_subsystem = "windows")]

mod config;
mod directory;
mod platform;

use config::{Config, PinKind};
use directory::FolderContents;
use slint::{ComponentHandle, Model, ModelRc, PhysicalPosition, Timer, TimerMode, VecModel};
use std::{
    cell::RefCell,
    path::PathBuf,
    rc::Rc,
    sync::{atomic::{AtomicU64, Ordering}, Arc},
    time::{Duration, Instant},
};

slint::include_modules!();

const DOCK_WIDTH: i32 = 740;
const DOCK_HEIGHT: i32 = 98;
const DRAWER_WIDTH: i32 = 484;
const DRAWER_HEIGHT: i32 = 490;
const BOTTOM_GAP: i32 = 12;

struct State {
    config: Config,
    config_path: PathBuf,
    folder_root: Option<PathBuf>,
    current: Option<PathBuf>,
    drawer_open: bool,
    blocked_by_window: bool,
    edge_revealed: bool,
    mouse_down_before: bool,
    reveal_until: Option<Instant>,
    scan_version: Arc<AtomicU64>,
}

impl State {
    fn save(&self) {
        if let Err(error) = self.config.save(&self.config_path) {
            eprintln!("Failed to save configuration: {error}");
        }
    }
}

fn entry_rows(data: FolderContents) -> (Vec<FileRow>, String) {
    let count = data.items.len();
    let description = if let Some(error) = data.error {
        format!("读取失败：{error}")
    } else if data.truncated {
        format!("已展示前 {count} 项；大型目录将在后续版本支持完整分页")
    } else if count == 0 {
        "文件夹为空".to_owned()
    } else {
        format!("共 {count} 项 · 单击进入文件夹或打开文件")
    };
    let entries: Vec<FileEntry> = data.items.into_iter().map(|item| FileEntry {
        title: item.name.into(),
        glyph: item.glyph.into(),
        is_folder: item.is_dir,
        exists: true,
        path: item.path.to_string_lossy().into_owned().into(),
    }).collect();
    let blank = || FileEntry {
        title: "".into(), glyph: "".into(), is_folder:false, exists:false, path:"".into()
    };
    let rows = entries.chunks(3).map(|chunk| FileRow {
        a: chunk.first().cloned().unwrap_or_else(blank),
        b: chunk.get(1).cloned().unwrap_or_else(blank),
        c: chunk.get(2).cloned().unwrap_or_else(blank),
    }).collect();
    (rows, description)
}

fn set_dock_entries(dock: &DockWindow, config: &Config) {
    let entries = config.pins.iter().map(|p| DockEntry {
        title: p.title.clone().into(),
        glyph: match p.kind {
            PinKind::Folder => "▣",
            PinKind::Application => "◆",
        }.into(),
        is_folder: p.kind == PinKind::Folder,
    }).collect::<Vec<_>>();
    dock.set_entries(ModelRc::new(VecModel::from(entries)));
}

fn update_drawer_position(dock: &DockWindow, drawer: &DrawerWindow, dock_index: Option<usize>, pin_count: usize) {
    let work = platform::work_area();
    let dock_x = work.left + (work.width() - DOCK_WIDTH) / 2;
    let dock_y = work.bottom - DOCK_HEIGHT - BOTTOM_GAP;
    let group_width = (pin_count as i32 * 67).max(1);
    let first_x = dock_x + (DOCK_WIDTH - group_width) / 2;
    let target_x = dock_index
        .map(|i| first_x + i as i32 * 67 + 29)
        .unwrap_or(dock_x + DOCK_WIDTH / 2);
    let drawer_x = (target_x - DRAWER_WIDTH / 2)
        .max(work.left + 8)
        .min((work.right - DRAWER_WIDTH - 8).max(work.left + 8));
    let drawer_y = (dock_y - DRAWER_HEIGHT - 8).max(work.top + 6);
    dock.window().set_position(PhysicalPosition::new(dock_x, dock_y));
    drawer.window().set_position(PhysicalPosition::new(drawer_x, drawer_y));
}

fn load_folder(drawer: &DrawerWindow, state: &Rc<RefCell<State>>, path: PathBuf) {
    let generation = {
        let mut state = state.borrow_mut();
        state.current = Some(path.clone());
        state.scan_version.fetch_add(1, Ordering::SeqCst) + 1
    };
    drawer.set_current_path(path.to_string_lossy().into_owned().into());
    drawer.set_current_title(path.file_name().and_then(|n| n.to_str()).unwrap_or("文件夹").into());
    drawer.set_status_line("正在读取…".into());
    drawer.set_rows(ModelRc::new(VecModel::from(Vec::<FileRow>::new())));
    let weak = drawer.as_weak();
    let sequence = state.borrow().scan_version.clone();
    std::thread::spawn(move || {
        let data = directory::inspect(&path);
        let (rows, description) = entry_rows(data);
        let _ = slint::invoke_from_event_loop(move || {
            if sequence.load(Ordering::SeqCst) != generation { return; }
            if let Some(drawer) = weak.upgrade() {
                drawer.set_rows(ModelRc::new(VecModel::from(rows)));
                drawer.set_status_line(description.into());
            }
        });
    });
}

fn open_folder(drawer: &DrawerWindow, state: &Rc<RefCell<State>>, path: PathBuf) {
    {
        let mut state = state.borrow_mut();
        state.folder_root = Some(path.clone());
        state.drawer_open = true;
    }
    load_folder(drawer, state, path);
    if let Err(error) = drawer.show() {
        eprintln!("Failed to display drawer: {error}");
    }
}

fn close_drawer(drawer: &DrawerWindow, state: &Rc<RefCell<State>>) {
    state.borrow_mut().drawer_open = false;
    state.borrow().scan_version.fetch_add(1, Ordering::SeqCst);
    let _ = drawer.hide();
}

fn wire_callbacks(dock: &DockWindow, drawer: &DrawerWindow, state: &Rc<RefCell<State>>) {
    dock.on_activate({
        let state = state.clone();
        let dock = dock.as_weak();
        let drawer = drawer.as_weak();
        move |index| {
            let Some(drawer) = drawer.upgrade() else { return };
            let Some(dock) = dock.upgrade() else { return };
            let (pin, length) = {
                let state = state.borrow();
                (state.config.pins.get(index as usize).cloned(), state.config.pins.len())
            };
            let Some(pin) = pin else { return };
            match pin.kind {
                PinKind::Folder => {
                    update_drawer_position(&dock, &drawer, Some(index as usize), length);
                    open_folder(&drawer, &state, pin.path);
                }
                PinKind::Application => {
                    close_drawer(&drawer, &state);
                    if let Err(error) = platform::open_path(&pin.path) {
                        eprintln!("{error}");
                    }
                }
            }
        }
    });

    drawer.on_close_requested({
        let state = state.clone();
        let drawer = drawer.as_weak();
        move || { if let Some(drawer) = drawer.upgrade() { close_drawer(&drawer, &state); } }
    });

    drawer.on_go_back({
        let state = state.clone();
        let drawer = drawer.as_weak();
        move || {
            let Some(drawer) = drawer.upgrade() else { return };
            let current = state.borrow().current.clone();
            let root = state.borrow().folder_root.clone();
            if let (Some(current), Some(root)) = (current, root) {
                if current == root { close_drawer(&drawer, &state); }
                else if let Some(parent) = current.parent() {
                    let parent = parent.to_path_buf();
                    if parent.starts_with(&root) { load_folder(&drawer, &state, parent); }
                    else { load_folder(&drawer, &state, root); }
                }
            }
        }
    });

    drawer.on_open_index({
        let state = state.clone();
        let drawer = drawer.as_weak();
        move |index| {
            let Some(drawer) = drawer.upgrade() else { return };
            if index < 0 { return; }
            let rows = drawer.get_rows();
            let Some(row) = rows.row_data(index as usize / 3) else { return };
            let item = match index % 3 { 0 => row.a, 1 => row.b, _ => row.c };
            if !item.exists { return; }
            let path = PathBuf::from(item.path.as_str());
            if item.is_folder { load_folder(&drawer, &state, path); }
            else if let Err(error) = platform::open_path(&path) {
                drawer.set_status_line(error.into());
            }
        }
    });

    drawer.on_open_explorer({
        let state = state.clone();
        move || {
            if let Some(path) = state.borrow().current.as_ref() {
                if let Err(error) = platform::open_path(path) { eprintln!("{error}"); }
            }
        }
    });


}


fn refresh_manager(manager: &ManagerWindow, config: &Config) {
    let pins = config.pins.iter().map(|pin| PinnedEntry {
        title: pin.title.clone().into(),
        path: pin.path.to_string_lossy().into_owned().into(),
        is_folder: pin.kind == PinKind::Folder,
    }).collect::<Vec<_>>();
    manager.set_pins(ModelRc::new(VecModel::from(pins)));
    manager.set_smart_hide_enabled(config.smart_hide);
    manager.set_hover_enabled(config.hover_animation);
}

fn open_manager(manager: &ManagerWindow, state: &Rc<RefCell<State>>) {
    refresh_manager(manager, &state.borrow().config);
    let work = platform::work_area();
    let x = work.left + (work.width() - 900).max(0) / 2;
    let y = work.top + (work.bottom - work.top - 640).max(0) / 2;
    manager.window().set_position(PhysicalPosition::new(x, y));
    if let Err(error) = manager.show() { eprintln!("Unable to show manager: {error}"); }
}

fn wire_manager(manager: &ManagerWindow, dock: &DockWindow, state: &Rc<RefCell<State>>) {
    manager.on_add_pin({
        let manager = manager.as_weak();
        let dock = dock.as_weak();
        let state = state.clone();
        move |path, is_folder| {
            let (Some(manager), Some(dock)) = (manager.upgrade(), dock.upgrade()) else { return; };
            let result = state.borrow_mut().config.pin(path.as_str(), is_folder);
            match result {
                Ok(()) => {
                    let current = state.borrow();
                    current.save();
                    refresh_manager(&manager, &current.config);
                    set_dock_entries(&dock, &current.config);
                    manager.set_status_line("已固定到 Dock".into());
                }
                Err(message) => manager.set_status_line(message.into()),
            }
        }
    });
    manager.on_remove_pin({
        let manager = manager.as_weak();
        let dock = dock.as_weak();
        let state = state.clone();
        move |index| {
            let (Some(manager), Some(dock)) = (manager.upgrade(), dock.upgrade()) else { return; };
            let mut current = state.borrow_mut();
            if index < 0 || index as usize >= current.config.pins.len() { return; }
            current.config.pins.remove(index as usize);
            current.save();
            refresh_manager(&manager, &current.config);
            set_dock_entries(&dock, &current.config);
            manager.set_status_line("已从 Dock 移除入口；原文件未更改".into());
        }
    });
    manager.on_rename_pin({
        let manager = manager.as_weak();
        let dock = dock.as_weak();
        let state = state.clone();
        move |index, title| {
            let (Some(manager), Some(dock)) = (manager.upgrade(), dock.upgrade()) else { return; };
            let name = title.trim();
            if name.is_empty() || name.chars().count() > 20 {
                manager.set_status_line("名称需要在 1～20 个字符之间".into());
                return;
            }
            let mut current = state.borrow_mut();
            if index < 0 || index as usize >= current.config.pins.len() {
                manager.set_status_line("请先点击列表中的“改名”".into());
                return;
            }
            current.config.pins[index as usize].title = name.to_owned();
            current.save();
            refresh_manager(&manager, &current.config);
            set_dock_entries(&dock, &current.config);
            manager.set_status_line("名称已更新".into());
        }
    });
    manager.on_move_pin({
        let manager = manager.as_weak();
        let dock = dock.as_weak();
        let state = state.clone();
        move |index, step| {
            let (Some(manager), Some(dock)) = (manager.upgrade(), dock.upgrade()) else { return; };
            let mut current = state.borrow_mut();
            let target = index + step;
            if index < 0 || target < 0 || index as usize >= current.config.pins.len() || target as usize >= current.config.pins.len() { return; }
            current.config.pins.swap(index as usize, target as usize);
            current.save();
            refresh_manager(&manager, &current.config);
            set_dock_entries(&dock, &current.config);
            manager.set_status_line("Dock 排序已保存".into());
        }
    });
    manager.on_change_smart_hide({
        let state = state.clone();
        move |value| {
            let mut current = state.borrow_mut();
            current.config.smart_hide = value;
            current.save();
        }
    });
    manager.on_change_hover({
        let state = state.clone();
        let dock = dock.as_weak();
        move |value| {
            let mut current = state.borrow_mut();
            current.config.hover_animation = value;
            current.save();
            if let Some(dock) = dock.upgrade() { dock.set_hover_enabled(value); }
        }
    });
    manager.on_show_dock({
        let dock = dock.as_weak();
        let state = state.clone();
        move || {
            {
                let mut state = state.borrow_mut();
                state.edge_revealed = true;
                state.reveal_until = Some(Instant::now() + Duration::from_secs(6));
            }
            if let Some(dock) = dock.upgrade() { let _ = dock.show(); }
        }
    });
}

fn wire_tray(tray: &AppTray, manager: &ManagerWindow, dock: &DockWindow, state: &Rc<RefCell<State>>) {
    tray.on_open_manager({
        let manager = manager.as_weak();
        let state = state.clone();
        move || { if let Some(manager) = manager.upgrade() { open_manager(&manager, &state); } }
    });
    tray.on_reveal_dock({
        let dock = dock.as_weak();
        let state = state.clone();
        move || {
            {
                let mut state = state.borrow_mut();
                state.edge_revealed = true;
                state.reveal_until = Some(Instant::now() + Duration::from_secs(6));
            }
            if let Some(dock) = dock.upgrade() { let _ = dock.show(); }
        }
    });
    tray.on_quit_app(|| { let _ = slint::quit_event_loop(); });
}

fn hover_controller(dock: &DockWindow, drawer: &DrawerWindow, state: &Rc<RefCell<State>>) -> Timer {
    let timer = Timer::default();
    let state = state.clone();
    let dock = dock.as_weak();
    let drawer = drawer.as_weak();
    timer.start(TimerMode::Repeated, Duration::from_millis(260), move || {
        let (Some(dock), Some(drawer)) = (dock.upgrade(), drawer.upgrade()) else { return };
        let work = platform::work_area();
        let dock_rect = platform::Rect {
            left:work.left + (work.width() - DOCK_WIDTH) / 2,
            right:work.left + (work.width() + DOCK_WIDTH) / 2,
            top:work.bottom - DOCK_HEIGHT - BOTTOM_GAP,
            bottom:work.bottom - BOTTOM_GAP,
        };
        let drawer_position = drawer.window().position();
        let drawer_rect = platform::Rect {
            left:drawer_position.x,
            top:drawer_position.y,
            right:drawer_position.x + DRAWER_WIDTH,
            bottom:drawer_position.y + DRAWER_HEIGHT,
        };
        let cursor = platform::cursor();
        let mut state = state.borrow_mut();
        if let Some(blocks) = platform::foreground_blocks_dock() {
            state.blocked_by_window = blocks;
        }
        let inside_dock = cursor.is_some_and(|(x,y)| dock_rect.contains(x,y,10));
        let inside_drawer = state.drawer_open && cursor.is_some_and(|(x,y)| drawer_rect.contains(x,y,8));
        let at_edge = cursor.is_some_and(|(x,y)| x >= dock_rect.left && x < dock_rect.right &&
            y >= work.bottom - 5 && y <= work.bottom + 5);
        if state.blocked_by_window {
            if at_edge { state.edge_revealed = true; }
            if state.edge_revealed && !inside_dock && !inside_drawer && !at_edge {
                state.edge_revealed = false;
            }
        } else {
            state.edge_revealed = false;
        }
        let manual_reveal = state.reveal_until.is_some_and(|time| time > Instant::now());
        if !manual_reveal { state.reveal_until = None; }
        let should_show = !state.config.smart_hide || !state.blocked_by_window || state.edge_revealed || manual_reveal;
        if should_show && !dock.window().is_visible() { let _ = dock.show(); }
        if !should_show && dock.window().is_visible() { let _ = dock.hide(); }
        if !should_show && state.drawer_open {
            state.drawer_open = false;
            state.scan_version.fetch_add(1, Ordering::SeqCst);
            let _ = drawer.hide();
        }
        let down = platform::left_mouse_down();
        if down && !state.mouse_down_before && state.drawer_open && !inside_dock && !inside_drawer {
            state.drawer_open = false;
            state.scan_version.fetch_add(1, Ordering::SeqCst);
            let _ = drawer.hide();
        }
        state.mouse_down_before = down;
    });
    timer
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let config_path = config::config_path();
    let config = Config::load(&config_path);
    let dock = DockWindow::new()?;
    let drawer = DrawerWindow::new()?;
    let manager = ManagerWindow::new()?;
    let tray = AppTray::new()?;
    set_dock_entries(&dock, &config);
    refresh_manager(&manager, &config);
    dock.set_hover_enabled(config.hover_animation);
    let state = Rc::new(RefCell::new(State {
        config, config_path, folder_root: None, current: None,
        drawer_open:false, blocked_by_window:false, edge_revealed:false,
        mouse_down_before:false, reveal_until: None, scan_version:Arc::new(AtomicU64::new(0)),
    }));
    wire_callbacks(&dock, &drawer, &state);
    wire_manager(&manager, &dock, &state);
    wire_tray(&tray, &manager, &dock, &state);
    update_drawer_position(&dock, &drawer, None, state.borrow().config.pins.len());
    dock.show()?;
    tray.show()?;
    let _timer = hover_controller(&dock, &drawer, &state);
    slint::run_event_loop_until_quit()?;
    Ok(())
}
