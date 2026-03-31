use crate::device::{DeviceInfo, EmojiSASPair, VerificationState, RoomEncryptionState};
use crate::error::CryptoError;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use uuid::Uuid;
use base64::engine::general_purpose::STANDARD;
use base64::Engine;

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

    /// Get SAS emoji pairs for verification
    pub fn get_sas_emojis(&self, verification_id: String) -> Result<Vec<EmojiSASPair>, CryptoError> {
        let verifications = self.verifications.lock().unwrap();
        let verification = verifications
            .get(&verification_id)
            .ok_or_else(|| CryptoError::VerificationNotFound(verification_id))?;

        Ok(verification.emojis.clone())
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

    /// Get the current state of a verification
    pub fn get_verification_state(&self, verification_id: String) -> Result<VerificationState, CryptoError> {
        let verifications = self.verifications.lock().unwrap();
        let verification = verifications
            .get(&verification_id)
            .ok_or_else(|| CryptoError::VerificationNotFound(verification_id))?;

        Ok(verification.clone())
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

    /// Get encryption state for a room
    pub fn get_room_encryption_state(&self, room_id: String) -> Result<RoomEncryptionState, CryptoError> {
        let rooms = self.rooms.lock().unwrap();
        let state = rooms.get(&room_id).cloned().unwrap_or_else(|| {
            RoomEncryptionState {
                room_id: room_id.clone(),
                is_encrypted: false,
                algorithm: None,
                trusted_devices: vec![],
                untrusted_devices: vec![],
            }
        });
        Ok(state)
    }

    /// Encrypt an event
    pub fn encrypt_event(
        &self,
        _room_id: String,
        _event_type: String,
        content: String,
    ) -> Result<String, CryptoError> {
        // For now, just return a mock encrypted event
        // In production, this would use the actual matrix-sdk-crypto
        Ok(format!(
            r#"{{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"{}","device_id":"{}","sender_key":"{}","session_id":"{}"}}"#,
            STANDARD.encode(&content),
            self.device_id,
            self.device_fingerprint,
            Uuid::new_v4()
        ))
    }

    /// Decrypt an event
    pub fn decrypt_event(
        &self,
        _room_id: String,
        encrypted_content: String,
    ) -> Result<String, CryptoError> {
        // Our mock encrypt_event stores the original content as a base64-encoded
        // ciphertext. Try to round-trip it here so our own sent messages can be
        // displayed. For real Megolm ciphertext from other clients this will fail
        // and we return a proper error instead of malformed JSON.
        let parsed: serde_json::Value = serde_json::from_str(&encrypted_content)
            .map_err(|e| CryptoError::Generic(format!("Invalid event content: {e}")))?;

        let ciphertext = parsed["ciphertext"]
            .as_str()
            .ok_or_else(|| CryptoError::Generic("Missing ciphertext field".to_string()))?;

        let decoded = STANDARD
            .decode(ciphertext)
            .map_err(|_| CryptoError::Generic("Cannot decrypt: no session key for this event".to_string()))?;

        let content_json = String::from_utf8(decoded)
            .map_err(|_| CryptoError::Generic("Decrypted content is not valid UTF-8".to_string()))?;

        // Verify content_json is valid JSON before embedding it
        serde_json::from_str::<serde_json::Value>(&content_json)
            .map_err(|_| CryptoError::Generic("Decrypted content is not valid JSON".to_string()))?;

        Ok(format!(r#"{{"type":"m.room.message","content":{content_json}}}"#))
    }

    /// Generate a random device fingerprint
    fn generate_fingerprint() -> String {
        use rand::Rng;
        let mut rng = rand::thread_rng();
        let bytes: Vec<u8> = (0..32).map(|_| rng.gen()).collect();
        hex::encode(&bytes)
    }
}
