fn main() {
    uniffi::generate_scaffolding("src/matrix_crypto.udl")
        .expect("Failed to generate UniFFI scaffolding");
}
