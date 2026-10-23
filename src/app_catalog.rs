//! On-demand enumeration of Start Menu shortcuts and packaged Windows apps.
//! No registry crawls, package installation changes, or whole-disk scans.
use std::{collections::HashSet, path::{Path, PathBuf}};

#[derive(Debug, Clone)]
pub struct InstalledApp {
    pub title: String,
    pub target: String,
}

pub fn discover_apps() -> Vec<InstalledApp> {
    let mut apps = Vec::new();
    let mut roots = Vec::new();
    if let Some(roaming) = std::env::var_os("APPDATA") {
        roots.push(PathBuf::from(roaming).join("Microsoft/Windows/Start Menu/Programs"));
    }
    if let Some(common) = std::env::var_os("ProgramData") {
        roots.push(PathBuf::from(common).join("Microsoft/Windows/Start Menu/Programs"));
    }
    for root in &roots {
        visit_shortcuts(root, 0, &mut apps);
    }
    // Only packaged apps are added here; regular Win32 shortcuts are found above.
    #[cfg(windows)]
    discover_packaged_apps(&mut apps);

    let mut seen_targets = HashSet::new();
    let mut seen_names = HashSet::new();
    apps.retain(|app| {
        seen_targets.insert(app.target.to_lowercase()) &&
        seen_names.insert(app.title.to_lowercase())
    });
    apps.sort_by_key(|app| app.title.to_lowercase());
    apps
}

fn visit_shortcuts(root: &Path, depth: usize, apps: &mut Vec<InstalledApp>) {
    if depth > 8 || apps.len() >= 3000 { return; }
    let Ok(iter) = std::fs::read_dir(root) else { return; };
    for entry in iter.flatten() {
        let path = entry.path();
        if path.is_dir() {
            visit_shortcuts(&path, depth + 1, apps);
            continue;
        }
        let ext = path.extension().and_then(|x| x.to_str()).unwrap_or("").to_ascii_lowercase();
        if !matches!(ext.as_str(), "lnk" | "url" | "appref-ms" | "exe") { continue; }
        let title = path.file_stem().and_then(|x| x.to_str()).unwrap_or("").trim();
        if title.is_empty() || title.to_lowercase().contains("uninstall") || title.contains("卸载") { continue; }
        apps.push(InstalledApp { title: title.to_owned(), target: path.to_string_lossy().to_string() });
        if apps.len() >= 3000 { return; }
    }
}

#[cfg(windows)]
fn discover_packaged_apps(apps: &mut Vec<InstalledApp>) {
    use std::os::windows::process::CommandExt;
    // The command is fixed, not constructed from file paths or user input.
    let command = "[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false); @(Get-StartApps | Where-Object { $_.AppID -like '*!*' } | Select-Object Name, AppID) | ConvertTo-Json -Compress";
    let result = std::process::Command::new("powershell.exe")
        .args(["-NoProfile", "-NonInteractive", "-Command", command])
        .creation_flags(0x08000000) // CREATE_NO_WINDOW
        .output();
    let Ok(output) = result else { return; };
    if !output.status.success() { return; }
    let Ok(value) = serde_json::from_slice::<serde_json::Value>(&output.stdout) else { return; };
    let entries: Vec<_> = match value {
        serde_json::Value::Array(items) => items,
        serde_json::Value::Object(_) => vec![value],
        _ => vec![],
    };
    for item in entries {
        let (Some(title), Some(id)) = (item["Name"].as_str(), item["AppID"].as_str()) else { continue; };
        if id.trim().is_empty() || title.trim().is_empty() || id.contains('\n') || id.contains('\r') { continue; }
        apps.push(InstalledApp { title: title.to_owned(), target: format!("shell:AppsFolder\\{id}") });
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn missing_shortcut_dir_returns_empty() {
        let mut apps = vec![];
        visit_shortcuts(Path::new("/missing-lifetrace-app-folder"), 0, &mut apps);
        assert!(apps.is_empty());
    }
}
