use std::path::{Path, PathBuf};

pub const LIST_LIMIT: usize = 450;

#[derive(Debug, Clone)]
pub struct FileItem {
    pub name: String,
    pub path: PathBuf,
    pub is_dir: bool,
    pub glyph: &'static str,
}

#[derive(Debug)]
pub struct FolderContents {
    pub items: Vec<FileItem>,
    pub truncated: bool,
    pub error: Option<String>,
}

pub fn inspect(path: &Path) -> FolderContents {
    let entries = match std::fs::read_dir(path) {
        Ok(entries) => entries,
        Err(error) => {
            return FolderContents { items: vec![], truncated: false, error: Some(error.to_string()) };
        }
    };
    let mut items = Vec::new();
    let mut truncated = false;
    for entry in entries {
        if items.len() == LIST_LIMIT {
            truncated = true;
            break;
        }
        let Ok(entry) = entry else { continue };
        let path = entry.path();
        let is_dir = path.is_dir();
        let name = entry.file_name().to_string_lossy().into_owned();
        let glyph = if is_dir { "▣" } else { glyph_for(&path) };
        items.push(FileItem { name, path, is_dir, glyph });
    }
    items.sort_by(|a, b| {
        (!a.is_dir, a.name.to_lowercase()).cmp(&(!b.is_dir, b.name.to_lowercase()))
    });
    FolderContents { items, truncated, error: None }
}

fn glyph_for(path: &Path) -> &'static str {
    match path.extension().and_then(|x| x.to_str()).unwrap_or("").to_lowercase().as_str() {
        "png" | "jpg" | "jpeg" | "webp" | "svg" | "gif" => "▧",
        "mp3" | "flac" | "wav" => "♫",
        "mp4" | "mov" | "mkv" => "▶",
        "exe" | "lnk" => "◆",
        "zip" | "7z" | "rar" => "▤",
        "rs" | "py" | "js" | "ts" | "json" => "</>",
        _ => "▤",
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn inspect_missing_folder_reports_error() {
        let dir = inspect(Path::new("/unlikely-missing-asset-dir-012345"));
        assert!(dir.error.is_some());
    }

    #[test]
    fn file_extension_glyph() {
        assert_eq!(glyph_for(Path::new("photo.png")), "▧");
    }
}
