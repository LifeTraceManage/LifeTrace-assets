use std::path::Path;

#[derive(Clone, Copy)]
pub struct Rect { pub left:i32, pub top:i32, pub right:i32, pub bottom:i32 }
impl Rect {
    pub fn width(self)->i32 { self.right-self.left }
    pub fn contains(self,x:i32,y:i32,pad:i32)->bool {
        x>=self.left-pad && x<self.right+pad && y>=self.top-pad && y<self.bottom+pad
    }
}

#[cfg(windows)]
mod native {
    use super::Rect;
    use std::{os::windows::ffi::OsStrExt,path::Path};
    use windows_sys::Win32::{
        Foundation::{POINT,RECT},
        Graphics::Gdi::{
            GetMonitorInfoW,MonitorFromPoint,MonitorFromWindow,
            HMONITOR,MONITORINFO,MONITOR_DEFAULTTOPRIMARY,MONITOR_DEFAULTTONEAREST
        },
        System::Threading::GetCurrentProcessId,
        UI::{
            Input::KeyboardAndMouse::{GetAsyncKeyState,VK_LBUTTON},
            Shell::ShellExecuteW,
            WindowsAndMessaging::{GetClassNameW,GetCursorPos,GetForegroundWindow,
                GetWindowRect,GetWindowThreadProcessId,IsZoomed,SW_SHOWNORMAL}
        }
    };
    fn monitor_rect(handle:HMONITOR,work:bool)->Option<Rect> {
        let mut mi:MONITORINFO=unsafe{std::mem::zeroed()};
        mi.cbSize=std::mem::size_of::<MONITORINFO>() as u32;
        if unsafe{GetMonitorInfoW(handle,&mut mi)}==0 {return None}
        let r=if work{mi.rcWork}else{mi.rcMonitor};
        Some(Rect{left:r.left,top:r.top,right:r.right,bottom:r.bottom})
    }
    pub fn work_area()->Rect {
        let h=unsafe{MonitorFromPoint(POINT{x:0,y:0},MONITOR_DEFAULTTOPRIMARY)};
        monitor_rect(h,true).unwrap_or(Rect{left:0,top:0,right:1920,bottom:1040})
    }
    pub fn cursor()->Option<(i32,i32)> {
        let mut p=POINT{x:0,y:0};
        (unsafe{GetCursorPos(&mut p)}!=0).then_some((p.x,p.y))
    }
    pub fn left_mouse_down()->bool {
        unsafe{(GetAsyncKeyState(VK_LBUTTON as i32) as u16&0x8000)!=0}
    }
    pub fn foreground_blocks_dock()->Option<bool>{
        let hwnd=unsafe{GetForegroundWindow()};
        if hwnd.is_null(){return None}
        let mut pid=0u32;
        unsafe{GetWindowThreadProcessId(hwnd,&mut pid)};
        if pid==unsafe{GetCurrentProcessId()}{return None}
        let mut name=[0u16;128];
        let n=unsafe{GetClassNameW(hwnd,name.as_mut_ptr(),name.len() as i32)};
        let class=String::from_utf16_lossy(&name[..n.max(0) as usize]);
        if class=="Progman"||class=="WorkerW"{return Some(false)}
        if unsafe{IsZoomed(hwnd)}!=0{return Some(true)}
        let mut r:RECT=unsafe{std::mem::zeroed()};
        if unsafe{GetWindowRect(hwnd,&mut r)}==0{return Some(false)}
        let h=unsafe{MonitorFromWindow(hwnd,MONITOR_DEFAULTTONEAREST)};
        let Some(m)=monitor_rect(h,false) else{return Some(false)};
        Some(r.left<=m.left+3 && r.top<=m.top+3 &&
            r.right>=m.right-3 && r.bottom>=m.bottom-3)
    }
    pub fn open_path(path:&Path)->Result<(),String>{
        let path_w:Vec<u16>=path.as_os_str().encode_wide().chain(Some(0)).collect();
        let result=unsafe{ShellExecuteW(std::ptr::null_mut(),std::ptr::null(),
            path_w.as_ptr(),std::ptr::null(),std::ptr::null(),SW_SHOWNORMAL)};
        if (result as isize)<=32{Err(format!("Windows 无法打开 {} (code {})",path.display(),result as isize))}
        else{Ok(())}
    }
}

#[cfg(not(windows))]
mod native {
    use super::Rect;
    use std::path::Path;
    pub fn work_area()->Rect{Rect{left:0,top:0,right:1600,bottom:900}}
    pub fn cursor()->Option<(i32,i32)>{None}
    pub fn left_mouse_down()->bool{false}
    pub fn foreground_blocks_dock()->Option<bool>{Some(false)}
    pub fn open_path(path:&Path)->Result<(),String>{Err(format!("Windows only: {}",path.display()))}
}
pub use native::*;
