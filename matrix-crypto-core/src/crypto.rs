use crate::device::{DeviceInfo, EmojiSASPair, VerificationState, RoomEncryptionState};
use crate::error::CryptoError;
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use uuid::Uuid;
use vodozemac::megolm::{GroupSession, InboundGroupSession, SessionConfig, MegolmMessage};
use vodozemac::olm::{Account, Session as OlmSession, SessionConfig as OlmSessionConfig};
use vodozemac::Curve25519PublicKey;

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
    /// Ed25519 identity key (base64) for signing.
    ed25519_key: String,
    /// Curve25519 identity key (base64) for Olm session establishment.
    curve25519_key: String,
    /// Olm account — holds this device's Ed25519 (signing) and Curve25519
    /// (identity) key pairs.  Wrapped in Mutex so create_inbound_session
    /// (which needs &mut Account) can be called from &self methods.
    olm_account: Arc<Mutex<Account>>,
    /// Megolm session store.
    sessions: Arc<Mutex<MegolmSessions>>,
    /// Olm sessions for to-device message encryption/decryption.
    /// Keyed by "{user_id}:{device_id}" for outbound sessions, and
    /// by session_id for inbound sessions from prekey messages.
    olm_sessions: Arc<Mutex<HashMap<String, OlmSession>>>,
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
        let identity_keys = olm_account.identity_keys();
        let ed25519_key = identity_keys.ed25519.to_base64();
        let curve25519_key = identity_keys.curve25519.to_base64();
        let fingerprint = ed25519_key.clone();

        Ok(MatrixCrypto {
            user_id,
            device_id,
            device_fingerprint: fingerprint,
            ed25519_key,
            curve25519_key,
            olm_account: Arc::new(Mutex::new(olm_account)),
            sessions: Arc::new(Mutex::new(MegolmSessions::new())),
            olm_sessions: Arc::new(Mutex::new(HashMap::new())),
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

    /// Get our Curve25519 identity key (base64) for Olm session establishment.
    pub fn get_identity_key(&self) -> Result<String, CryptoError> {
        Ok(self.curve25519_key.clone())
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
            self.curve25519_key,
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

    // -----------------------------------------------------------------------
    // Megolm session key export / import  (T1-1: cross-device key sharing)
    // -----------------------------------------------------------------------

    /// Export the outbound Megolm session key for a room so it can be shared
    /// with other devices via an Olm-encrypted `m.room_key` to-device message.
    ///
    /// The returned string is the base64-encoded session key that can be
    /// deserialised on the receiving device with `add_inbound_session`.
    pub fn get_outbound_session_key(&self, room_id: String) -> Result<String, CryptoError> {
        let sessions = self.sessions.lock().unwrap();
        let outbound = sessions.outbound.get(&room_id)
            .ok_or_else(|| CryptoError::EncryptionFailed(
                format!("No outbound session for room {room_id}")
            ))?;
        // SessionKey serialises as a base64 JSON string via serde.
        let key_value = serde_json::to_value(outbound.session_key())
            .map_err(|e| CryptoError::EncryptionFailed(e.to_string()))?;
        let key_b64: String = serde_json::from_value(key_value)
            .map_err(|e| CryptoError::EncryptionFailed(e.to_string()))?;
        Ok(key_b64)
    }

    /// Return the session_id of the current outbound session for a room.
    /// Needed so the sender can include session_id in the m.room_key content.
    pub fn get_outbound_session_id(&self, room_id: String) -> Result<String, CryptoError> {
        let sessions = self.sessions.lock().unwrap();
        let outbound = sessions.outbound.get(&room_id)
            .ok_or_else(|| CryptoError::EncryptionFailed(
                format!("No outbound session for room {room_id}")
            ))?;
        Ok(outbound.session_id().to_owned())
    }

    /// Import a Megolm inbound session from a received `m.room_key` to-device
    /// message.  After calling this method the device can decrypt any Megolm
    /// messages in `room_id` that were encrypted with the matching session.
    pub fn add_inbound_session(
        &self,
        room_id: String,
        _sender_key: String,
        session_key_base64: String,
    ) -> Result<(), CryptoError> {
        // SessionKey deserialises from a base64 JSON string.
        let key_value = serde_json::Value::String(session_key_base64);
        let session_key: vodozemac::megolm::SessionKey = serde_json::from_value(key_value)
            .map_err(|e| CryptoError::DecryptionFailed(
                format!("Invalid session key base64: {e}")
            ))?;
        let inbound = InboundGroupSession::new(&session_key, SessionConfig::version_1());
        let session_id = inbound.session_id().to_owned();
        let mut sessions = self.sessions.lock().unwrap();
        sessions.inbound.insert(session_id, inbound);
        Ok(())
    }

    // -----------------------------------------------------------------------
    // Olm to-device encryption / decryption  (T1-1: key transport)
    // -----------------------------------------------------------------------

    /// Create an outbound Olm session with a remote device.
    ///
    /// Must be called once per device before `olm_encrypt`.
    /// `their_identity_key` and `their_one_time_key` are base64-encoded
    /// Curve25519 public keys obtained from the homeserver via `/keys/claim`.
    pub fn create_olm_session(
        &self,
        user_id: String,
        device_id: String,
        their_identity_key: String,
        their_one_time_key: String,
    ) -> Result<(), CryptoError> {
        let identity_key = Curve25519PublicKey::from_base64(&their_identity_key)
            .map_err(|e| CryptoError::EncryptionFailed(
                format!("Invalid identity key: {e}")
            ))?;
        let one_time_key = Curve25519PublicKey::from_base64(&their_one_time_key)
            .map_err(|e| CryptoError::EncryptionFailed(
                format!("Invalid one-time key: {e}")
            ))?;
        let session = {
            let account = self.olm_account.lock().unwrap();
            account.create_outbound_session(
                OlmSessionConfig::version_1(),
                identity_key,
                one_time_key,
            )
        };
        let key = format!("{}:{}", user_id, device_id);
        self.olm_sessions.lock().unwrap().insert(key, session);
        Ok(())
    }

    /// Encrypt a plaintext string for a specific remote device using an
    /// existing Olm session created by `create_olm_session`.
    ///
    /// Returns a JSON object: `{"type":<0|1>,"body":"<base64_ciphertext>"}`
    /// where type 0 = PreKey message (first message), 1 = normal message.
    pub fn olm_encrypt(
        &self,
        user_id: String,
        device_id: String,
        plaintext: String,
    ) -> Result<String, CryptoError> {
        let key = format!("{}:{}", user_id, device_id);
        let mut olm_sessions = self.olm_sessions.lock().unwrap();
        let session = olm_sessions.get_mut(&key)
            .ok_or_else(|| CryptoError::EncryptionFailed(
                format!("No Olm session for {key} — call create_olm_session first")
            ))?;
        let message = session.encrypt(plaintext.as_bytes());
        let (msg_type, body) = match message {
            vodozemac::olm::OlmMessage::Normal(m) => (1usize, m.to_base64()),
            vodozemac::olm::OlmMessage::PreKey(m) => (0usize, m.to_base64()),
        };
        Ok(format!(r#"{{"type":{},"body":"{}"}}"#, msg_type, body))
    }

    /// Decrypt an Olm-encrypted to-device message addressed to this device.
    ///
    /// `sender_identity_key` is the sender's Curve25519 key (base64).
    /// `msg_type` is 0 for PreKey, 1 for Normal.
    /// `ciphertext_b64` is the base64-encoded ciphertext from the `body` field.
    ///
    /// For PreKey messages (type 0) a new inbound Olm session is created from
    /// our account and stored for future normal messages from the same sender.
    ///
    /// Returns the decrypted plaintext string.
    pub fn olm_decrypt(
        &self,
        sender_identity_key: String,
        msg_type: u32,
        ciphertext_b64: String,
    ) -> Result<String, CryptoError> {
        use vodozemac::olm::OlmMessage;

        let sender_key = Curve25519PublicKey::from_base64(&sender_identity_key)
            .map_err(|e| CryptoError::DecryptionFailed(
                format!("Invalid sender identity key: {e}")
            ))?;

        if msg_type == 0 {
            // PreKey message: create a new inbound session from our account.
            let prekey_msg = vodozemac::olm::messages::PreKeyMessage::from_base64(&ciphertext_b64)
                .map_err(|e| CryptoError::DecryptionFailed(
                    format!("Invalid PreKey message: {e}")
                ))?;
            let mut account = self.olm_account.lock().unwrap();
            let result = account
                .create_inbound_session(sender_key, &prekey_msg)
                .map_err(|e| CryptoError::DecryptionFailed(
                    format!("Failed to create inbound Olm session: {e}")
                ))?;
            // Store the new inbound session keyed by the sender identity key
            // so future normal messages from this device can be decrypted.
            drop(account);
            self.olm_sessions.lock().unwrap()
                .insert(sender_identity_key, result.session);
            String::from_utf8(result.plaintext)
                .map_err(|_| CryptoError::DecryptionFailed(
                    "Olm plaintext is not valid UTF-8".to_string()
                ))
        } else {
            // Normal message: look up the existing inbound session by sender key.
            let mut olm_sessions = self.olm_sessions.lock().unwrap();
            let session = olm_sessions.get_mut(&sender_identity_key)
                .ok_or_else(|| CryptoError::DecryptionFailed(
                    format!("No Olm session for sender key {sender_identity_key}")
                ))?;
            let msg = vodozemac::olm::messages::Message::from_base64(&ciphertext_b64)
                .map_err(|e| CryptoError::DecryptionFailed(
                    format!("Invalid Olm Normal message: {e}")
                ))?;
            let plaintext = session
                .decrypt(&OlmMessage::Normal(msg))
                .map_err(|e| CryptoError::DecryptionFailed(
                    format!("Olm decryption error: {e}")
                ))?;
            String::from_utf8(plaintext)
                .map_err(|_| CryptoError::DecryptionFailed(
                    "Olm plaintext is not valid UTF-8".to_string()
                ))
        }
    }
}
