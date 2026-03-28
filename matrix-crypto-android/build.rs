fn main() {
    // NOTE: Do NOT call uniffi::generate_scaffolding() here.
    // matrix-crypto-core already generates the UniFFI scaffolding.
    // Calling it again here causes duplicate symbol errors at link time.
    println!("cargo:rustc-cfg=android_target");
}
