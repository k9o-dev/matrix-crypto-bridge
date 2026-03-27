use uniffi::Error;

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

impl Error for CryptoError {
    fn uniffi_error_code_name(&self) -> String {
        match self {
            CryptoError::InitializationFailed(_) => "InitializationFailed".to_string(),
            CryptoError::EncryptionFailed(_) => "EncryptionFailed".to_string(),
            CryptoError::DecryptionFailed(_) => "DecryptionFailed".to_string(),
            CryptoError::VerificationFailed(_) => "VerificationFailed".to_string(),
            CryptoError::StorageError(_) => "StorageError".to_string(),
            CryptoError::InvalidUserId(_) => "InvalidUserId".to_string(),
            CryptoError::InvalidDeviceId(_) => "InvalidDeviceId".to_string(),
            CryptoError::DeviceNotFound(_) => "DeviceNotFound".to_string(),
            CryptoError::VerificationNotFound(_) => "VerificationNotFound".to_string(),
            CryptoError::InvalidState(_) => "InvalidState".to_string(),
            CryptoError::NetworkError(_) => "NetworkError".to_string(),
            CryptoError::Unknown(_) => "Unknown".to_string(),
        }
    }

    fn uniffi_error_message(&self) -> String {
        self.to_string()
    }
}
