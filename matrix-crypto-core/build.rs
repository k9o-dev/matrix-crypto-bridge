fn main() {
    // Generate UniFFI scaffolding
    uniffi::generate_scaffolding("src/matrix_crypto.udl")
        .expect("Failed to generate UniFFI scaffolding");
    
    // Determine the target platform
    let target = std::env::var("TARGET").unwrap_or_default();
    
    if target.contains("android") {
        // Android: Use cdylib to generate .so files for JNI
        println!("cargo:rustc-cfg=android_target");
    } else if target.contains("apple") && target.contains("ios") {
        // iOS: Use staticlib to generate .a files for static linking
        println!("cargo:rustc-cfg=ios_target");
    }
}
