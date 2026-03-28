fn main() {
    // Generate UniFFI scaffolding
    uniffi::generate_scaffolding("src/matrix_crypto.udl")
        .expect("Failed to generate UniFFI scaffolding");
    
    // For Android targets, we need to use staticlib instead of cdylib
    // because Rust doesn't support cdylib for cross-compilation targets.
    // The Android build system will handle the dynamic linking through JNI.
    let target = std::env::var("TARGET").unwrap_or_default();
    
    if target.contains("android") {
        // Tell cargo to use staticlib for Android
        // The build script will copy the .a files and the Android build system
        // will handle creating the .so files through the NDK.
        println!("cargo:rustc-cfg=android_target");
    }
}
