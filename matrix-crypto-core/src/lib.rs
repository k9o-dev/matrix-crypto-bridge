mod crypto;
mod device;
mod error;

pub use crypto::MatrixCrypto;
pub use device::{DeviceInfo, EmojiSASPair, VerificationState, RoomEncryptionState, UserDevices, EncryptionAlgorithm};
pub use error::CryptoError;

uniffi::include_scaffolding!("matrix_crypto");
