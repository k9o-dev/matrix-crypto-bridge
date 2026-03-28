// Matrix Crypto Bridge - iOS Wrapper
// Re-exports the core library for UniFFI and iOS static linking

use matrix_crypto_core::MatrixCrypto;

// Re-export the core library for UniFFI
pub use matrix_crypto_core::{MatrixCrypto, CryptoError};

// UniFFI scaffolding for iOS
uniffi::include_scaffolding!("matrix_crypto");

// Optional: iOS-specific wrapper functions
#[uniffi::export]
pub fn create_matrix_crypto() -> Result<std::sync::Arc<MatrixCrypto>, CryptoError> {
    Ok(std::sync::Arc::new(MatrixCrypto::new()?))
}
