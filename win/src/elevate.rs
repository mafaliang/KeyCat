//! Running as administrator. Windows keeps a normal program's input hook from seeing keys and
//! clicks that go to an elevated window, and many games (anti-cheat ones above all) run elevated,
//! so the cat goes still while one has focus. An elevated KeyCat sees them again.

#[cfg(windows)]
mod imp {
    use std::ffi::OsStr;
    use std::os::windows::ffi::OsStrExt;

    use windows::core::{w, PCWSTR};
    use windows::Win32::Foundation::{CloseHandle, HANDLE};
    use windows::Win32::Security::{GetTokenInformation, TokenElevation, TOKEN_ELEVATION, TOKEN_QUERY};
    use windows::Win32::System::Threading::{
        GetCurrentProcess, OpenProcess, OpenProcessToken, WaitForSingleObject, PROCESS_SYNCHRONIZE,
    };
    use windows::Win32::UI::Shell::ShellExecuteW;
    use windows::Win32::UI::WindowsAndMessaging::SW_SHOWNORMAL;

    pub fn is_elevated() -> bool {
        unsafe {
            let mut token = HANDLE::default();
            if OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &mut token).is_err() {
                return false;
            }
            let mut elevation = TOKEN_ELEVATION::default();
            let mut size = 0u32;
            let read = GetTokenInformation(
                token,
                TokenElevation,
                Some((&mut elevation as *mut TOKEN_ELEVATION).cast()),
                std::mem::size_of::<TOKEN_ELEVATION>() as u32,
                &mut size,
            );
            let _ = CloseHandle(token);
            read.is_ok() && elevation.TokenIsElevated != 0
        }
    }

    fn wide(text: &OsStr) -> Vec<u16> {
        text.encode_wide().chain(Some(0)).collect()
    }

    /// Starts this program again, elevated, behind the UAC prompt. Fails if the user declines.
    pub fn relaunch(args: &str) -> Result<(), String> {
        let exe = std::env::current_exe().map_err(|error| error.to_string())?;
        let (exe, args) = (wide(exe.as_os_str()), wide(OsStr::new(args)));
        let result = unsafe {
            ShellExecuteW(None, w!("runas"), PCWSTR(exe.as_ptr()), PCWSTR(args.as_ptr()), PCWSTR::null(), SW_SHOWNORMAL)
        };
        // Anything above 32 means the program started.
        match result.0 as usize {
            code if code > 32 => Ok(()),
            code => Err(format!("ShellExecute runas returned {code}")),
        }
    }

    /// Waits up to 10 s for process `pid` to end.
    pub fn wait_for_exit(pid: u32) {
        unsafe {
            if let Ok(process) = OpenProcess(PROCESS_SYNCHRONIZE, false, pid) {
                let _ = WaitForSingleObject(process, 10_000);
                let _ = CloseHandle(process);
            }
        }
    }
}

#[cfg(not(windows))]
mod imp {
    pub fn is_elevated() -> bool {
        false
    }

    pub fn relaunch(_args: &str) -> Result<(), String> {
        Err("elevation is Windows-only".into())
    }

    pub fn wait_for_exit(_pid: u32) {}
}

pub use imp::{is_elevated, relaunch, wait_for_exit};
