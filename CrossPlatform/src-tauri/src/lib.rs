use serde_json::Value;
use std::fs;
use std::path::PathBuf;
use tauri::{AppHandle, Manager};
use tauri_plugin_window_state::StateFlags;

fn state_path(app: &AppHandle) -> Result<PathBuf, String> {
    app.path()
        .app_data_dir()
        .map(|directory| directory.join("app-state.json"))
        .map_err(|error| error.to_string())
}

#[cfg(target_os = "macos")]
fn legacy_state_path(app: &AppHandle) -> Option<PathBuf> {
    app.path().home_dir().ok().map(|home| {
        home.join("Library")
            .join("Application Support")
            .join("打卡时间")
            .join("work-records.json")
    })
}

#[cfg(target_os = "macos")]
fn read_legacy_state(app: &AppHandle) -> Result<Option<Value>, String> {
    use base64::{engine::general_purpose::STANDARD, Engine as _};
    use serde_json::json;

    let Some(records_path) = legacy_state_path(app).filter(|path| path.exists()) else {
        return Ok(None);
    };
    let bytes = fs::read(records_path).map_err(|error| error.to_string())?;
    let root: Value = serde_json::from_slice(&bytes).map_err(|error| error.to_string())?;
    let records = root.get("records").cloned().unwrap_or_else(|| json!({}));

    let home = app.path().home_dir().map_err(|error| error.to_string())?;
    let preferences_path = home
        .join("Library")
        .join("Preferences")
        .join("local.codex.workday-widget.plist");
    let preferences = plist::Value::from_file(preferences_path)
        .ok()
        .and_then(|value| value.into_dictionary())
        .unwrap_or_default();
    let integer = |key: &str, fallback: i64| {
        preferences
            .get(key)
            .and_then(plist::Value::as_signed_integer)
            .unwrap_or(fallback)
    };
    let real = |key: &str, fallback: f64| {
        preferences
            .get(key)
            .and_then(|value| value.as_real().or_else(|| value.as_signed_integer().map(|n| n as f64)))
            .unwrap_or(fallback)
    };

    let support = home.join("Library").join("Application Support").join("打卡时间");
    let background_data_url = fs::read(support.join("background-original.png"))
        .ok()
        .map(|data| format!("data:image/png;base64,{}", STANDARD.encode(data)));
    let icon_data_url = fs::read(support.join("progress-icon-original")).ok().map(|data| {
        let mime = if data.starts_with(b"GIF8") {
            "image/gif"
        } else if data.starts_with(b"RIFF") && data.get(8..12) == Some(b"WEBP") {
            "image/webp"
        } else if data.starts_with(&[0xFF, 0xD8, 0xFF]) {
            "image/jpeg"
        } else {
            "image/png"
        };
        format!("data:{mime};base64,{}", STANDARD.encode(data))
    });

    let background_mode = match integer("settings.backgroundMode", 2) {
        0 if background_data_url.is_some() => "image",
        1 if background_data_url.is_some() => "blur",
        _ => "glass",
    };
    let progress_icon_mode = match integer("settings.progressIconMode", 0) {
        1 => "builtin",
        2 if icon_data_url.is_some() => "custom",
        _ => "off",
    };
    Ok(Some(json!({
        "schemaVersion": 1,
        "records": records,
        "settings": {
            "durationMinutes": integer("settings.durationMinutes", 510),
            "backgroundMode": background_mode,
            "backgroundDataUrl": background_data_url,
            "backgroundZoom": real("settings.cropZoom", 1.0),
            "backgroundOffsetX": real("settings.cropOffsetX", 0.0),
            "backgroundOffsetY": real("settings.cropOffsetY", 0.0),
            "progressIconMode": progress_icon_mode,
            "progressIconDataUrl": icon_data_url
        }
    })))
}

#[cfg(not(target_os = "macos"))]
fn legacy_state_path(_app: &AppHandle) -> Option<PathBuf> {
    None
}

#[tauri::command]
fn load_app_state(app: AppHandle) -> Result<Option<Value>, String> {
    let current = state_path(&app)?;
    let backup = current
        .parent()
        .map(|directory| directory.join("app-state.backup.json"));
    let candidate = if current.exists() { Some(current) } else { backup.filter(|path| path.exists()) };
    let Some(path) = candidate else {
        #[cfg(target_os = "macos")]
        return read_legacy_state(&app);
        #[cfg(not(target_os = "macos"))]
        return Ok(None);
    };
    let bytes = fs::read(path).map_err(|error| error.to_string())?;
    serde_json::from_slice(&bytes)
        .map(Some)
        .map_err(|error| error.to_string())
}

#[tauri::command]
fn save_app_state(app: AppHandle, state: Value) -> Result<(), String> {
    let path = state_path(&app)?;
    let directory = path.parent().ok_or("Invalid application data path")?;
    fs::create_dir_all(directory).map_err(|error| error.to_string())?;

    let backup = directory.join("app-state.backup.json");
    if path.exists() {
        fs::copy(&path, backup).map_err(|error| error.to_string())?;
    }

    let temporary = directory.join("app-state.tmp");
    let encoded = serde_json::to_vec_pretty(&state).map_err(|error| error.to_string())?;
    fs::write(&temporary, encoded).map_err(|error| error.to_string())?;
    if path.exists() {
        fs::remove_file(&path).map_err(|error| error.to_string())?;
    }
    fs::rename(temporary, path).map_err(|error| error.to_string())
}

fn apply_native_glass(window: &tauri::WebviewWindow) {
    #[cfg(target_os = "macos")]
    {
        let _ = window_vibrancy::apply_vibrancy(
            window,
            window_vibrancy::NSVisualEffectMaterial::HudWindow,
            None,
            Some(16.0),
        );
    }
    #[cfg(target_os = "windows")]
    {
        let _ = window_vibrancy::apply_acrylic(window, Some((21, 59, 75, 190)));
    }
}

// Explorer exposes a WorkerW desktop layer behind normal app windows. Parenting
// the widget there gives Windows the same “on the desktop, never always-on-top”
// behaviour as the macOS desktop-level window.
#[cfg(target_os = "windows")]
fn pin_to_windows_desktop(window: &tauri::WebviewWindow) {
    use std::ptr::{null, null_mut};
    use windows_sys::core::BOOL;
    use windows_sys::Win32::Foundation::{HWND, LPARAM};
    use windows_sys::Win32::UI::WindowsAndMessaging::{
        EnumWindows, FindWindowExW, FindWindowW, SendMessageTimeoutW, SetParent,
        SMTO_NORMAL,
    };

    fn wide(value: &str) -> Vec<u16> {
        value.encode_utf16().chain(Some(0)).collect()
    }

    unsafe extern "system" fn find_worker(top: HWND, state: LPARAM) -> BOOL {
        let shell_view = wide("SHELLDLL_DefView");
        if !FindWindowExW(top, null_mut(), shell_view.as_ptr(), null()).is_null() {
            let worker_class = wide("WorkerW");
            let worker = FindWindowExW(null_mut(), top, worker_class.as_ptr(), null());
            if !worker.is_null() {
                *(state as *mut HWND) = worker;
                return 0;
            }
        }
        1
    }

    let Ok(raw_handle) = window.hwnd() else {
        return;
    };

    unsafe {
        let progman_class = wide("Progman");
        let progman = FindWindowW(progman_class.as_ptr(), null());
        if !progman.is_null() {
            // Ask Explorer to create the background WorkerW when it does not
            // already exist. This message is the mechanism used by wallpaper
            // and desktop-widget applications on Windows 10/11.
            let mut ignored = 0usize;
            let _ = SendMessageTimeoutW(
                progman,
                0x052C,
                0xD,
                0,
                SMTO_NORMAL,
                1000,
                &mut ignored,
            );
        }

        let mut worker: HWND = null_mut();
        let _ = EnumWindows(Some(find_worker), &mut worker as *mut HWND as LPARAM);
        if !worker.is_null() {
            let _ = SetParent(raw_handle.0 as HWND, worker);
        }
    }
}

#[cfg(not(target_os = "windows"))]
fn pin_to_windows_desktop(_window: &tauri::WebviewWindow) {}

#[cfg_attr(mobile, tauri::mobile_entry_point)]
pub fn run() {
    tauri::Builder::default()
        .plugin(tauri_plugin_process::init())
        .plugin(tauri_plugin_updater::Builder::new().build())
        .plugin(
            tauri_plugin_window_state::Builder::default()
                .with_state_flags(StateFlags::POSITION)
                .build(),
        )
        .invoke_handler(tauri::generate_handler![load_app_state, save_app_state])
        .setup(|app| {
            if let Some(window) = app.get_webview_window("main") {
                apply_native_glass(&window);
                pin_to_windows_desktop(&window);
            }
            Ok(())
        })
        .run(tauri::generate_context!())
        .expect("error while running Workday Widget");
}
