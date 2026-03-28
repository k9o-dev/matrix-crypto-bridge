fn main() {
    // Generate UniFFI scaffolding for Android
    uniffi::generate_scaffolding("../matrix-crypto-core/src/matrix_crypto.udl")
        .expect("Failed to generate UniFFI scaffolding");
    
    println!("cargo:rustc-cfg=android_target");
}
