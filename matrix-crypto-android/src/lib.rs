// Matrix Crypto Bridge - Android Wrapper
// This crate packages matrix-crypto-core as a cdylib (.so) for Android JNI.
//
// IMPORTANT: Do NOT call uniffi::include_scaffolding!() or generate_scaffolding() here.
// matrix-crypto-core already owns the UDL and generates all UniFFI scaffolding.
// Duplicating it here causes duplicate symbol linker errors.

// Re-export everything from core so the .so exposes all required symbols.
pub use matrix_crypto_core::*;
