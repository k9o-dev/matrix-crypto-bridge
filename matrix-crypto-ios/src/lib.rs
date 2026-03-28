// Matrix Crypto Bridge - iOS Wrapper
// Re-exports the core library for UniFFI and iOS static linking

pub use matrix_crypto_core::{MatrixCrypto, CryptoError};

// UniFFI scaffolding for iOS
uniffi::include_scaffolding!("matrix_crypto");

// iOS-specific wrapper functions for UniFFI
#[uniffi::export]
pub fn create_matrix_crypto(
    user_id: String,
    device_id: String,
    pickle_key: String,
) -> Result<std::sync::Arc<MatrixCrypto>, CryptoError> {
    Ok(std::sync::Arc::new(MatrixCrypto::new(
        user_id,
        device_id,
        pickle_key,
    )?))
}

#[uniffi::export]
pub fn get_device_fingerprint(crypto: std::sync::Arc<MatrixCrypto>) -> String {
    crypto.device_fingerprint()
}
