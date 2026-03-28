// Matrix Crypto Bridge - Android Wrapper
// Re-exports the core library for UniFFI and Android JNI

use matrix_crypto_core::MatrixCrypto;

// Re-export the core library for UniFFI
pub use matrix_crypto_core::{MatrixCrypto, CryptoError};

// UniFFI scaffolding for Android
uniffi::include_scaffolding!("matrix_crypto");

// Optional: Android-specific wrapper functions
#[uniffi::export]
pub fn create_matrix_crypto() -> Result<std::sync::Arc<MatrixCrypto>, CryptoError> {
    Ok(std::sync::Arc::new(MatrixCrypto::new()?))
}
