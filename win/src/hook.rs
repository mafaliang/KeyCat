//! Global keyboard and mouse input. Low-level hooks see every key and button system-wide
//! without the app having focus; they run on their own thread with a message loop and only
//! forward what happened, so the callbacks return at once and never slow input down.
use std::sync::mpsc::Sender;

#[derive(Clone, Copy, PartialEq, Eq)]
pub enum Button {
    Left,
    Right,
    Other,
}

pub enum Input {
    /// `id` names the physical key (scan code, plus 0x100 for E0 keys) so autorepeat can be
    /// told apart from a new press; `code` is `None` for keys the scene has no name for.
    Key { id: u32, code: Option<&'static str>, down: bool },
    Button { button: Button, down: bool },
    /// Wheel notches, positive away from the user.
    Wheel(f64),
}

#[cfg(windows)]
mod imp {
    use std::sync::mpsc::{self, Sender};
    use std::sync::OnceLock;
    use std::thread;

    use windows::Win32::Foundation::{HINSTANCE, LPARAM, LRESULT, WPARAM};
    use windows::Win32::System::LibraryLoader::GetModuleHandleW;
    use windows::Win32::UI::Input::KeyboardAndMouse::{MapVirtualKeyW, MAPVK_VK_TO_VSC_EX};
    use windows::Win32::UI::WindowsAndMessaging::{
        CallNextHookEx, DispatchMessageW, GetMessageW, SetWindowsHookExW, HC_ACTION, KBDLLHOOKSTRUCT,
        LLKHF_EXTENDED, MSG, MSLLHOOKSTRUCT, WH_KEYBOARD_LL, WH_MOUSE_LL, WM_KEYDOWN, WM_LBUTTONDOWN,
        WM_LBUTTONUP, WM_MBUTTONDOWN, WM_MBUTTONUP, WM_MOUSEWHEEL, WM_RBUTTONDOWN, WM_RBUTTONUP,
        WM_SYSKEYDOWN, WM_XBUTTONDOWN, WM_XBUTTONUP,
    };

    use super::{Button, Input};
    use crate::keymap;

    static SINK: OnceLock<Sender<Input>> = OnceLock::new();

    fn send(input: Input) {
        if let Some(sink) = SINK.get() {
            let _ = sink.send(input);
        }
    }

    unsafe extern "system" fn keyboard_proc(code: i32, wparam: WPARAM, lparam: LPARAM) -> LRESULT {
        if code == HC_ACTION as i32 {
            let info = unsafe { &*(lparam.0 as *const KBDLLHOOKSTRUCT) };
            let down = matches!(wparam.0 as u32, WM_KEYDOWN | WM_SYSKEYDOWN);
            let mut scan = info.scanCode;
            let mut extended = info.flags.0 & LLKHF_EXTENDED.0 != 0;
            if scan == 0 {
                // Injected input (remote desktop, macro tools) may carry only the virtual key.
                let mapped = unsafe { MapVirtualKeyW(info.vkCode, MAPVK_VK_TO_VSC_EX) };
                scan = mapped & 0xff;
                extended = mapped & 0xff00 != 0;
            }
            send(Input::Key {
                id: scan | if extended { 0x100 } else { 0 },
                code: keymap::code(scan, extended, info.vkCode),
                down,
            });
        }
        unsafe { CallNextHookEx(None, code, wparam, lparam) }
    }

    unsafe extern "system" fn mouse_proc(code: i32, wparam: WPARAM, lparam: LPARAM) -> LRESULT {
        if code == HC_ACTION as i32 {
            let button = |button, down| Some(Input::Button { button, down });
            let input = match wparam.0 as u32 {
                WM_LBUTTONDOWN => button(Button::Left, true),
                WM_LBUTTONUP => button(Button::Left, false),
                WM_RBUTTONDOWN => button(Button::Right, true),
                WM_RBUTTONUP => button(Button::Right, false),
                WM_MBUTTONDOWN | WM_XBUTTONDOWN => button(Button::Other, true),
                WM_MBUTTONUP | WM_XBUTTONUP => button(Button::Other, false),
                WM_MOUSEWHEEL => {
                    let info = unsafe { &*(lparam.0 as *const MSLLHOOKSTRUCT) };
                    let delta = (info.mouseData >> 16) as u16 as i16;
                    Some(Input::Wheel(f64::from(delta) / 120.0))
                }
                _ => None,
            };
            if let Some(input) = input {
                send(input);
            }
        }
        unsafe { CallNextHookEx(None, code, wparam, lparam) }
    }

    pub fn start(sink: Sender<Input>) -> Result<(), String> {
        SINK.set(sink).map_err(|_| "input hook already started".to_string())?;
        let (ready, started) = mpsc::channel();
        thread::Builder::new()
            .name("input-hook".into())
            .spawn(move || unsafe {
                let module = GetModuleHandleW(None).ok().map(|module| HINSTANCE(module.0));
                let keyboard = SetWindowsHookExW(WH_KEYBOARD_LL, Some(keyboard_proc), module, 0);
                let mouse = SetWindowsHookExW(WH_MOUSE_LL, Some(mouse_proc), module, 0);
                if let Err(error) = keyboard.and(mouse) {
                    let _ = ready.send(Err(error.to_string()));
                    return;
                }
                let _ = ready.send(Ok(()));
                // Hooks are called through this thread's message queue.
                let mut msg = MSG::default();
                while GetMessageW(&mut msg, None, 0, 0).as_bool() {
                    DispatchMessageW(&msg);
                }
            })
            .map_err(|error| error.to_string())?;
        started.recv().map_err(|error| error.to_string())?
    }
}

#[cfg(not(windows))]
mod imp {
    use std::sync::mpsc::Sender;

    use super::Input;

    pub fn start(_sink: Sender<Input>) -> Result<(), String> {
        Err("global input is only implemented for Windows".into())
    }
}

pub fn start(sink: Sender<Input>) -> Result<(), String> {
    imp::start(sink)
}
