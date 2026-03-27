use crate::device::{DeviceInfo, EmojiSASPair, VerificationState, RoomEncryptionState};
use crate::error::CryptoError;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use uuid::Uuid;

/// Main Matrix crypto machine
pub struct MatrixCrypto {
    user_id: String,
    device_id: String,
    device_fingerprint: String,
    /// Storage for device verifications
    verifications: Arc<Mutex<HashMap<String, VerificationState>>>,
    /// Storage for device info
    devices: Arc<Mutex<HashMap<String, DeviceInfo>>>,
    /// Storage for room encryption state
    rooms: Arc<Mutex<HashMap<String, RoomEncryptionState>>>,
}

impl MatrixCrypto {
    /// Create a new Matrix crypto machine
    pub fn new(
        user_id: String,
        device_id: String,
        _pickle_key: String,
    ) -> Result<Self, CryptoError> {
        // Validate user ID format
        if !user_id.starts_with('@') || !user_id.contains(':') {
            return Err(CryptoError::InvalidUserId(user_id));
        }

        // Generate a fingerprint for this device
        let fingerprint = Self::generate_fingerprint();

        Ok(MatrixCrypto {
            user_id,
            device_id,
            device_fingerprint: fingerprint,
            verifications: Arc::new(Mutex::new(HashMap::new())),
            devices: Arc::new(Mutex::new(HashMap::new())),
            rooms: Arc::new(Mutex::new(HashMap::new())),
        })
    }

    /// Get the device fingerprint
    pub fn device_fingerprint(&self) -> String {
        self.device_fingerprint.clone()
    }

    /// Get the user ID
    pub fn user_id(&self) -> String {
        self.user_id.clone()
    }

    /// Get the device ID
    pub fn device_id(&self) -> String {
        self.device_id.clone()
    }

    /// Get devices for a user
    pub fn get_user_devices(&self, user_id: String) -> Result<Vec<DeviceInfo>, CryptoError> {
        let devices = self.devices.lock().unwrap();
        let user_devices: Vec<DeviceInfo> = devices
            .values()
            .filter(|d| d.user_id == user_id)
            .cloned()
            .collect();
        Ok(user_devices)
    }

    /// Add a device to the store
    pub fn add_device(&self, device: DeviceInfo) -> Result<(), CryptoError> {
        let mut devices = self.devices.lock().unwrap();
        devices.insert(format!("{}:{}", device.user_id, device.device_id), device);
        Ok(())
    }

    /// Start device verification with another device
    pub fn start_verification(
        &self,
        other_user_id: String,
        other_device_id: String,
    ) -> Result<VerificationState, CryptoError> {
        // Validate other user ID
        if !other_user_id.starts_with('@') || !other_user_id.contains(':') {
            return Err(CryptoError::InvalidUserId(other_user_id));
        }

        let verification_id = Uuid::new_v4().to_string();
        let state = VerificationState {
            verification_id: verification_id.clone(),
            state: "pending".to_string(),
            other_user_id: other_user_id.clone(),
            other_device_id: other_device_id.clone(),
            emojis: vec![],
            decimals: vec![],
        };

        let mut verifications = self.verifications.lock().unwrap();
        verifications.insert(verification_id, state.clone());

        Ok(state)
    }

    /// Get SAS emojis for a verification
    pub fn get_sas_emojis(&self, verification_id: String) -> Result<Vec<EmojiSASPair>, CryptoError> {
        let mut verifications = self.verifications.lock().unwrap();
        let verification = verifications
            .get_mut(&verification_id)
            .ok_or_else(|| CryptoError::VerificationNotFound(verification_id.clone()))?;

        // Generate emoji pairs for SAS
        let emojis = vec![
            EmojiSASPair {
                emoji: "🎯".to_string(),
                name: "Target".to_string(),
            },
            EmojiSASPair {
                emoji: "🎮".to_string(),
                name: "Game Controller".to_string(),
            },
            EmojiSASPair {
                emoji: "🎨".to_string(),
                name: "Artist Palette".to_string(),
            },
            EmojiSASPair {
                emoji: "🎭".to_string(),
                name: "Performing Arts".to_string(),
            },
            EmojiSASPair {
                emoji: "🎪".to_string(),
                name: "Circus Tent".to_string(),
            },
            EmojiSASPair {
                emoji: "🎬".to_string(),
                name: "Clapper Board".to_string(),
            },
            EmojiSASPair {
                emoji: "🎤".to_string(),
                name: "Microphone".to_string(),
            },
            EmojiSASPair {
                emoji: "🎧".to_string(),
                name: "Headphones".to_string(),
            },
        ];

        verification.emojis = emojis.clone();
        verification.state = "sas_ready".to_string();

        Ok(emojis)
    }

    /// Confirm SAS verification
    pub fn confirm_sas(&self, verification_id: String) -> Result<(), CryptoError> {
        let mut verifications = self.verifications.lock().unwrap();
        let verification = verifications
            .get_mut(&verification_id)
            .ok_or_else(|| CryptoError::VerificationNotFound(verification_id.clone()))?;

        verification.state = "confirmed".to_string();
        Ok(())
    }

    /// Complete device verification
    pub fn complete_verification(&self, verification_id: String) -> Result<(), CryptoError> {
        let mut verifications = self.verifications.lock().unwrap();
        let verification = verifications
            .get_mut(&verification_id)
            .ok_or_else(|| CryptoError::VerificationNotFound(verification_id.clone()))?;

        verification.state = "completed".to_string();

        // Mark the device as verified
        let mut devices = self.devices.lock().unwrap();
        let key = format!("{}:{}", verification.other_user_id, verification.other_device_id);
        if let Some(device) = devices.get_mut(&key) {
            device.is_verified = true;
        }

        Ok(())
    }

    /// Cancel device verification
    pub fn cancel_verification(&self, verification_id: String) -> Result<(), CryptoError> {
        let mut verifications = self.verifications.lock().unwrap();
        let verification = verifications
            .get_mut(&verification_id)
            .ok_or_else(|| CryptoError::VerificationNotFound(verification_id.clone()))?;

        verification.state = "cancelled".to_string();
        Ok(())
    }

    /// Get verification state
    pub fn get_verification_state(&self, verification_id: String) -> Result<VerificationState, CryptoError> {
        let verifications = self.verifications.lock().unwrap();
        verifications
            .get(&verification_id)
            .cloned()
            .ok_or_else(|| CryptoError::VerificationNotFound(verification_id))
    }

    /// Enable encryption for a room
    pub fn enable_room_encryption(
        &self,
        room_id: String,
        algorithm: String,
    ) -> Result<(), CryptoError> {
        let mut rooms = self.rooms.lock().unwrap();
        let state = RoomEncryptionState {
            room_id: room_id.clone(),
            is_encrypted: true,
            algorithm: Some(algorithm),
            trusted_devices: vec![],
            untrusted_devices: vec![],
        };
        rooms.insert(room_id, state);
        Ok(())
    }

    /// Get room encryption state
    pub fn get_room_encryption_state(&self, room_id: String) -> Result<RoomEncryptionState, CryptoError> {
        let rooms = self.rooms.lock().unwrap();
        rooms
            .get(&room_id)
            .cloned()
            .ok_or_else(|| CryptoError::StorageError(format!("Room {} not found", room_id)))
    }

    /// Encrypt event content
    pub fn encrypt_event(
        &self,
        room_id: String,
        event_type: String,
        content: String,
    ) -> Result<String, CryptoError> {
        // Verify room is encrypted
        let rooms = self.rooms.lock().unwrap();
        let _room = rooms
            .get(&room_id)
            .ok_or_else(|| CryptoError::StorageError(format!("Room {} not found", room_id)))?;

        // In a real implementation, this would use matrix-sdk-crypto to encrypt
        // For now, we'll just return a mock encrypted content
        let encrypted = format!(
            r#"{{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"{}","device_id":"{}","sender_key":"{}","session_id":"{}"}}"#,
            base64::encode(&content),
            self.device_id,
            self.device_fingerprint,
            Uuid::new_v4()
        );

        Ok(encrypted)
    }

    /// Decrypt event content
    pub fn decrypt_event(
        &self,
        _room_id: String,
        encrypted_content: String,
    ) -> Result<String, CryptoError> {
        // In a real implementation, this would use matrix-sdk-crypto to decrypt
        // For now, we'll just return a mock decrypted content
        if encrypted_content.contains("ciphertext") {
            Ok("Decrypted message content".to_string())
        } else {
            Err(CryptoError::DecryptionFailed(
                "Invalid encrypted content format".to_string(),
            ))
        }
    }

    /// Generate a mock fingerprint
    fn generate_fingerprint() -> String {
        let uuid = Uuid::new_v4();
        format!("{:X}", uuid.as_u128())
    }
}
