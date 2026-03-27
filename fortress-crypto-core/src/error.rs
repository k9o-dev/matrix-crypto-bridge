/// Error types for the Matrix crypto bridge
#[derive(Debug, thiserror::Error)]
pub enum CryptoError {
    #[error("Initialization failed: {0}")]
    InitializationFailed(String),

    #[error("Encryption failed: {0}")]
    EncryptionFailed(String),

    #[error("Decryption failed: {0}")]
    DecryptionFailed(String),

    #[error("Device verification failed: {0}")]
    VerificationFailed(String),

    #[error("Storage error: {0}")]
    StorageError(String),

    #[error("Invalid user ID: {0}")]
    InvalidUserId(String),

    #[error("Invalid device ID: {0}")]
    InvalidDeviceId(String),

    #[error("Device not found: {0}")]
    DeviceNotFound(String),

    #[error("Verification not found: {0}")]
    VerificationNotFound(String),

    #[error("Invalid state: {0}")]
    InvalidState(String),

    #[error("Network error: {0}")]
    NetworkError(String),

    #[error("Unknown error: {0}")]
    Unknown(String),
}
