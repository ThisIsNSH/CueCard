use base64::{engine::general_purpose::STANDARD, Engine};
use std::fs;
use std::path::PathBuf;

fn main() {
    let root_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .parent()
        .unwrap()
        .to_path_buf();
    let config_path = root_dir.join("firebase.config");

    let (config_contents, source_path) = if config_path.exists() {
        (
            fs::read_to_string(&config_path)
                .unwrap_or_else(|_| panic!("Failed to read {}", config_path.display())),
            config_path,
        )
    } else {
        panic!(
            "Missing firebase.config. Use firebase.config.example as a template. Provide a config file in {}.",
            root_dir.display()
        );
    };

    let encoded = STANDARD.encode(config_contents);
    println!("cargo:rustc-env=FIREBASE_CONFIG_B64={}", encoded);
    println!("cargo:rerun-if-changed={}", source_path.display());

    tauri_build::build();
}
