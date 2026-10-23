use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};

pub const MAX_PINS: usize = 9;

#[derive(Debug, Clone, Copy, Serialize, Deserialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum PinKind {
    Folder,
    Application,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Pin {
    pub title: String,
    pub path: PathBuf,
    pub kind: PinKind,
}

#[derive(Debug, Serialize, Deserialize)]
pub struct Config {
    pub pins: Vec<Pin>,
}

impl Default for Config {
    fn default() -> Self {
        let mut pins = Vec::new();
        if let Some(home) = std::env::var_os("USERPROFILE") {
            let home = PathBuf::from(home);
            for (title, suffix) in [
                ("桌面", "Desktop"),
                ("文档", "Documents"),
                ("下载", "Downloads"),
            ] {
                let path = home.join(suffix);
                if path.is_dir() {
                    pins.push(Pin { title: title.to_owned(), path, kind: PinKind::Folder });
                }
            }
        }
        Self { pins }
    }
}

pub fn config_path() -> PathBuf {
    let base = std::env::var_os("APPDATA")
        .or_else(|| std::env::var_os("HOME"))
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("."));
    base.join("LifeTrace-assets").join("config.json")
}

impl Config {
    pub fn load(path: &Path) -> Self {
        std::fs::read_to_string(path)
            .ok()
            .and_then(|text| serde_json::from_str(&text).ok())
            .unwrap_or_default()
    }

    pub fn save(&self, path: &Path) -> std::io::Result<()> {
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)?;
        }
        let content = serde_json::to_vec_pretty(self).map_err(std::io::Error::other)?;
        let temp = path.with_extension("json.tmp");
        std::fs::write(&temp, content)?;
        if path.exists() {
            let backup = path.with_extension("json.bak");
            let _ = std::fs::copy(path, backup);
            std::fs::remove_file(path)?;
        }
        std::fs::rename(temp, path)
    }

    pub fn pin(&mut self, raw_path: &str, folder: bool) -> Result<(), String> {
        let raw_path = raw_path.trim().trim_matches('"');
        if raw_path.is_empty() {
            return Err("请粘贴完整的文件或文件夹路径".into());
        }
        let input = PathBuf::from(raw_path);
        if !input.exists() {
            return Err("找不到该路径，请检查输入".into());
        }
        if folder && !input.is_dir() {
            return Err("请选择文件夹路径".into());
        }
        if !folder && !input.is_file() {
            return Err("请选择应用程序或文件路径".into());
        }
        if self.pins.len() >= MAX_PINS {
            return Err(format!("首版最多固定 {MAX_PINS} 个入口"));
        }
        let path = input.canonicalize().unwrap_or(input);
        if self.pins.iter().any(|pin| pin.path == path) {
            return Err("这个入口已经固定".into());
        }
        let title = path.file_stem().and_then(|n| n.to_str()).unwrap_or("入口");
        self.pins.push(Pin {
            title: title.chars().take(12).collect(),
            path,
            kind: if folder { PinKind::Folder } else { PinKind::Application },
        });
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_missing_path() {
        let mut config = Config { pins: vec![] };
        assert!(config.pin("", true).is_err());
        assert!(config.pin("a-path-that-cannot-exist-123", true).is_err());
    }

    #[test]
    fn cap_and_duplicate_detection() {
        let mut config = Config { pins: vec![] };
        let folder = std::env::temp_dir();
        let path = folder.to_string_lossy();
        assert!(config.pin(&path, true).is_ok());
        assert!(config.pin(&path, true).is_err());
    }
}
