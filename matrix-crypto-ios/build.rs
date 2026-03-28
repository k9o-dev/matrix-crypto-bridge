fn main() {
    // Generate UniFFI scaffolding for iOS
    uniffi::generate_scaffolding("../matrix-crypto-core/src/matrix_crypto.udl")
        .expect("Failed to generate UniFFI scaffolding");
    
    println!("cargo:rustc-cfg=ios_target");
}
