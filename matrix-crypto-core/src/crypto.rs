use crate::device::{DeviceInfo, EmojiSASPair, VerificationState, RoomEncryptionState};
use crate::error::CryptoError;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use uuid::Uuid;
use vodozemac::megolm::{GroupSession, InboundGroupSession, SessionConfig, MegolmMessage};
use vodozemac::olm::Account;

// ---------------------------------------------------------------------------
// Combined Megolm session store — one mutex to avoid nested-lock deadlocks.
// ---------------------------------------------------------------------------

struct MegolmSessions {
    /// Room ID → outbound Megolm session (for encrypting messages we send).
    outbound: HashMap<String, GroupSession>,
    /// Session ID → inbound Megolm session (for decrypting).
    /// Populated when we create an outbound session (self-decryption) or
    /// when we receive a room_key to-device message from another device.
    inbound: HashMap<String, InboundGroupSession>,
}

impl MegolmSessions {
    fn new() -> Self {
        Self {
            outbound: HashMap::new(),
            inbound: HashMap::new(),
        }
    }
}

// ---------------------------------------------------------------------------
// Main Matrix crypto machine
// ---------------------------------------------------------------------------

pub struct MatrixCrypto {
    user_id: String,
    device_id: String,
    device_fingerprint: String,
    /// Olm account — holds this device's Ed25519 (signing) and Curve25519
    /// (identity) key pairs.  Used as the signing key when creating inbound
    /// Megolm sessions so that the session is tied to our device.
    olm_account: Account,
    /// Megolm session store.
    sessions: Arc<Mutex<MegolmSessions>>,
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

        // Create a fresh Olm account — gives us real Ed25519 / Curve25519 keys.
        let olm_account = Account::new();
        let fingerprint = olm_account.identity_keys().ed25519.to_base64();

        Ok(MatrixCrypto {
            user_id,
            device_id,
            device_fingerprint: fingerprint,
            olm_account,
            sessions: Arc::new(Mutex::new(MegolmSessions::new())),
            verifications: Arc::new(Mutex::new(HashMap::new())),
            devices: Arc::new(Mutex::new(HashMap::new())),
            rooms: Arc::new(Mutex::new(HashMap::new())),
        })
    }

    /// Get the device fingerprint (Ed25519 public key, base64-encoded)
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

    // -----------------------------------------------------------------------
    // Real Megolm encryption / decryption (vodozemac)
    // -----------------------------------------------------------------------

    /// Encrypt a Matrix event using Megolm (m.megolm.v1.aes-sha2).
    ///
    /// On the first call for a room a new outbound GroupSession is created.
    /// A matching InboundGroupSession is stored at the same time so that
    /// messages we send can be decrypted by this device (self-decryption).
    ///
    /// Returns the JSON content of an `m.room.encrypted` event.
    pub fn encrypt_event(
        &self,
        room_id: String,
        event_type: String,
        content: String,
    ) -> Result<String, CryptoError> {
        let curve25519_key = self.olm_account.identity_keys().curve25519.to_base64();

        let mut sessions = self.sessions.lock().unwrap();

        // Create outbound + inbound session pair on first use for this room.
        if !sessions.outbound.contains_key(&room_id) {
            let outbound = GroupSession::new(SessionConfig::version_1());
            let session_key = outbound.session_key();
            let session_id = outbound.session_id().to_owned();

            // vodozemac 0.7: InboundGroupSession::new(&SessionKey, SessionConfig) -> Self
            let inbound = InboundGroupSession::new(&session_key, SessionConfig::version_1());

            sessions.inbound.insert(session_id, inbound);
            sessions.outbound.insert(room_id.clone(), outbound);
        }

        let outbound = sessions.outbound.get_mut(&room_id).unwrap();

        // Matrix Megolm plaintext: a JSON object with `type` and `content`
        let plaintext = format!(
            r#"{{"type":{},"content":{}}}"#,
            serde_json::to_string(&event_type)
                .map_err(|e| CryptoError::EncryptionFailed(e.to_string()))?,
            content,
        );

        let msg: MegolmMessage = outbound.encrypt(&plaintext);
        let session_id = outbound.session_id().to_owned();

        Ok(format!(
            r#"{{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"{}","device_id":"{}","sender_key":"{}","session_id":"{}"}}"#,
            msg.to_base64(),
            self.device_id,
            curve25519_key,
            session_id,
        ))
    }

    /// Decrypt an `m.room.encrypted` event.
    ///
    /// Succeeds only when an InboundGroupSession for the event's session_id
    /// is present in our store — i.e. messages we sent ourselves, or messages
    /// whose session keys were shared with us via a `m.room_key` to-device
    /// message.  All other messages return `CryptoError::DecryptionFailed`.
    ///
    /// Returns the full plaintext Matrix event JSON:
    ///   `{"type":"m.room.message","content":{…}}`
    pub fn decrypt_event(
        &self,
        _room_id: String,
        encrypted_content: String,
    ) -> Result<String, CryptoError> {
        let parsed: serde_json::Value = serde_json::from_str(&encrypted_content)
            .map_err(|e| CryptoError::DecryptionFailed(
                format!("Invalid encrypted event JSON: {e}")
            ))?;

        let session_id = parsed["session_id"]
            .as_str()
            .ok_or_else(|| CryptoError::DecryptionFailed(
                "Missing session_id field".to_string()
            ))?;

        let ciphertext = parsed["ciphertext"]
            .as_str()
            .ok_or_else(|| CryptoError::DecryptionFailed(
                "Missing ciphertext field".to_string()
            ))?;

        let mut sessions = self.sessions.lock().unwrap();

        let inbound = sessions.inbound.get_mut(session_id)
            .ok_or_else(|| CryptoError::DecryptionFailed(
                format!("No inbound session for session_id {session_id}")
            ))?;

        let msg = MegolmMessage::from_base64(ciphertext)
            .map_err(|e| CryptoError::DecryptionFailed(
                format!("Invalid Megolm ciphertext: {e}")
            ))?;

        let result = inbound.decrypt(&msg)
            .map_err(|e| CryptoError::DecryptionFailed(
                format!("Megolm decryption error: {e}")
            ))?;

        let plaintext = String::from_utf8(result.plaintext)
            .map_err(|_| CryptoError::DecryptionFailed(
                "Decrypted plaintext is not valid UTF-8".to_string()
            ))?;

        // Verify it's a valid JSON object before returning it.
        serde_json::from_str::<serde_json::Value>(&plaintext)
            .map_err(|_| CryptoError::DecryptionFailed(
                "Decrypted plaintext is not valid JSON".to_string()
            ))?;

        Ok(plaintext)
    }
}
