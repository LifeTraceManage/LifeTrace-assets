use std::path::Path;

#[derive(Clone, Copy, Debug)]
pub struct Rect {
    pub left: i32,
    pub top: i32,
    pub right: i32,
    pub bottom: i32,
}
impl Rect {
    pub fn contains(self, x: i32, y: i32, margin: i32) -> bool {
        x >= self.left - margin && x < self.right + margin &&
        y >= self.top - margin && y < self.bottom + margin
    }
    pub fn width(self) -> i32 { self.right - self.left }
}

#[cfg(windows)]
mod native {
    use super::Rect;
    use std::{ffi::OsStr, os::windows::ffi::OsStrExt, path::Path};
    use windows_sys::Win32::{
        Foundation::{POINT, RECT},
        Graphics::Gdi::{GetMonitorInfoW, MONITORINFO, MonitorFromPoint, MonitorFromWindow, HMONITOR, MONITOR_DEFAULTTOPRIMARY, MONITOR_DEFAULTTONEAREST},
        System::Threading::GetCurrentProcessId,
        UI::{
            Input::KeyboardAndMouse::{GetAsyncKeyState, VK_LBUTTON},
            Shell::ShellExecuteW,
            WindowsAndMessaging::{
                GetClassNameW, GetCursorPos, GetForegroundWindow,
                GetWindowRect, GetWindowThreadProcessId, IsZoomed, SW_SHOWNORMAL,
            },
        },
    };

    fn monitor_area(monitor: windows_sys::Win32::Graphics::Gdi::HMONITOR, work: bool) -> Option<Rect> {
        let mut info: MONITORINFO = unsafe { std::mem::zeroed() };
        info.cbSize = std::mem::size_of::<MONITORINFO>() as u32;
        if unsafe { GetMonitorInfoW(monitor, &mut info) } == 0 { return None; }
        let r = if work { info.rcWork } else { info.rcMonitor };
        Some(Rect { left:r.left, top:r.top, right:r.right, bottom:r.bottom })
    }

    pub fn work_area() -> Rect {
        let monitor = unsafe { MonitorFromPoint(POINT { x:0, y:0 }, MONITOR_DEFAULTTOPRIMARY) };
        monitor_area(monitor, true).unwrap_or(Rect { left:0, top:0, right:1920, bottom:1040 })
    }

    pub fn cursor() -> Option<(i32,i32)> {
        let mut point = POINT { x:0, y:0 };
        (unsafe { GetCursorPos(&mut point) } != 0).then_some((point.x,point.y))
    }

    pub fn left_mouse_down() -> bool {
        unsafe { (GetAsyncKeyState(VK_LBUTTON as i32) as u16 & 0x8000) != 0 }
    }

    // None means the foreground is one of our own windows or temporarily unknown.
    // The controller retains its previous external-window state in this case.
    pub fn foreground_blocks_dock() -> Option<bool> {
        let hwnd = unsafe { GetForegroundWindow() };
        if hwnd.is_null() { return None; }
        let mut pid: u32 = 0;
        unsafe { GetWindowThreadProcessId(hwnd, &mut pid) };
        if pid == unsafe { GetCurrentProcessId() } { return None; }
        let mut class = [0u16;128];
        let length = unsafe { GetClassNameW(hwnd, class.as_mut_ptr(), class.len() as i32) };
        let name = String::from_utf16_lossy(&class[..length.max(0) as usize]);
        if name == "Progman" || name == "WorkerW" { return Some(false); }
        if unsafe { IsZoomed(hwnd) } != 0 { return Some(true); }
        let mut rect: RECT = unsafe { std::mem::zeroed() };
        if unsafe { GetWindowRect(hwnd, &mut rect) } == 0 { return Some(false); }
        let monitor = unsafe { MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST) };
        let Some(m) = monitor_area(monitor, false) else { return Some(false); };
        let covers = rect.left <= m.left + 3 && rect.top <= m.top + 3 &&
            rect.right >= m.right - 3 && rect.bottom >= m.bottom - 3;
        Some(covers)
    }

    pub fn open_path(path: &Path) -> Result<(), String> {
        let wide: Vec<u16> = path.as_os_str().encode_wide().chain(Some(0)).collect();
        let virtual_target = path.to_string_lossy();
        let explorer: Vec<u16> = "explorer.exe".encode_utf16().chain(Some(0)).collect();
        let result = if virtual_target.starts_with("shell:AppsFolder\\") {
            // Packaged Windows app: pass the AUMID to Explorer's AppsFolder handler.
            unsafe { ShellExecuteW(std::ptr::null_mut(), std::ptr::null(), explorer.as_ptr(),
                wide.as_ptr(), std::ptr::null(), SW_SHOWNORMAL) }
        } else {
            unsafe { ShellExecuteW(std::ptr::null_mut(), std::ptr::null(), wide.as_ptr(),
                std::ptr::null(), std::ptr::null(), SW_SHOWNORMAL) }
        };
        if result as isize <= 32 {
            Err(format!("Windows 无法打开 {} (错误码 {})", path.display(), result as isize))
        } else { Ok(()) }
    }
}

#[cfg(not(windows))]
mod native {
    use super::Rect;
    use std::path::Path;
    pub fn work_area() -> Rect { Rect { left:0, top:0, right:1600, bottom:900 } }
    pub fn cursor() -> Option<(i32,i32)> { None }
    pub fn left_mouse_down() -> bool { false }
    pub fn foreground_blocks_dock() -> Option<bool> { Some(false) }
    pub fn open_path(path: &Path) -> Result<(), String> { Err(format!("Windows only: {}", path.display())) }
}
pub use native::*;
