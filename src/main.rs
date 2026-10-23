#![cfg_attr(windows, windows_subsystem = "windows")]

mod config;
mod directory;
mod platform;

use config::{Config, PinKind};
use directory::FolderContents;
use slint::{ComponentHandle, Model, ModelRc, PhysicalPosition, Timer, TimerMode, VecModel};
use std::{
    cell::RefCell,
    path::{Path, PathBuf},
    rc::Rc,
    sync::{atomic::{AtomicU64, Ordering}, Arc},
    time::Duration,
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
    let group_width = (pin_count as i32 * 69) + 145;
    let first_x = dock_x + (DOCK_WIDTH - group_width) / 2;
    let target_x = dock_index
        .map(|i| first_x + i as i32 * 69 + 29)
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
    drawer.set_add_mode(false);
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

fn show_add_panel(drawer: &DrawerWindow, state: &Rc<RefCell<State>>) {
    state.borrow_mut().drawer_open = true;
    drawer.set_add_mode(true);
    drawer.set_as_folder(true);
    drawer.set_status_line("".into());
    if let Err(error) = drawer.show() {
        eprintln!("Failed to open Add panel: {error}");
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

    dock.on_add_requested({
        let dock = dock.as_weak();
        let drawer = drawer.as_weak();
        let state = state.clone();
        move || {
            if let (Some(dock), Some(drawer)) = (dock.upgrade(), drawer.upgrade()) {
                let pins = state.borrow().config.pins.len();
                update_drawer_position(&dock, &drawer, None, pins);
                show_add_panel(&drawer, &state);
            }
        }
    });

    dock.on_exit_requested(|| { let _ = slint::quit_event_loop(); });
    dock.on_remove_requested(|_| {});

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
            if drawer.get_add_mode() { close_drawer(&drawer, &state); return; }
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

    drawer.on_add_entry({
        let state = state.clone();
        let drawer = drawer.as_weak();
        let dock = dock.as_weak();
        move |path, as_folder| {
            let (Some(drawer), Some(dock)) = (drawer.upgrade(), dock.upgrade()) else { return };
            let outcome = state.borrow_mut().config.pin(path.as_str(), as_folder);
            match outcome {
                Ok(()) => {
                    let current = state.borrow();
                    current.save();
                    set_dock_entries(&dock, &current.config);
                    drop(current);
                    close_drawer(&drawer, &state);
                }
                Err(error) => drawer.set_status_line(error.into()),
            }
        }
    });

    drawer.on_remove_last({
        let state = state.clone();
        let dock = dock.as_weak();
        let drawer = drawer.as_weak();
        move || {
            let (Some(dock), Some(drawer)) = (dock.upgrade(), drawer.upgrade()) else { return };
            let mut state = state.borrow_mut();
            if state.config.pins.pop().is_some() {
                state.save();
                set_dock_entries(&dock, &state.config);
                drawer.set_status_line("已移除最后一个固定入口".into());
            } else {
                drawer.set_status_line("Dock 没有固定入口".into());
            }
        }
    });
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
        let should_show = !state.blocked_by_window || state.edge_revealed;
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
    set_dock_entries(&dock, &config);
    let state = Rc::new(RefCell::new(State {
        config, config_path, folder_root: None, current: None,
        drawer_open:false, blocked_by_window:false, edge_revealed:false,
        mouse_down_before:false, scan_version:Arc::new(AtomicU64::new(0)),
    }));
    wire_callbacks(&dock, &drawer, &state);
    update_drawer_position(&dock, &drawer, None, state.borrow().config.pins.len());
    dock.show()?;
    let _timer = hover_controller(&dock, &drawer, &state);
    slint::run_event_loop_until_quit()?;
    Ok(())
}
