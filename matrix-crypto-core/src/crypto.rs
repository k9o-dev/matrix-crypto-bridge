use crate::device::{DeviceInfo, EmojiSASPair, VerificationState, RoomEncryptionState};
use crate::error::CryptoError;
use serde::{Serialize, Deserialize};
use std::collections::HashMap;
use std::sync::{Arc, Mutex};
use uuid::Uuid;
use vodozemac::megolm::{ExportedSessionKey, GroupSession, InboundGroupSession, SessionConfig, MegolmMessage};
use vodozemac::olm::{Account, Session as OlmSession, SessionConfig as OlmSessionConfig};
use vodozemac::Curve25519PublicKey;

// ---------------------------------------------------------------------------
// Serialisable snapshot of crypto state for persistence across app restarts.
// ---------------------------------------------------------------------------

#[derive(Serialize, Deserialize)]
struct PersistedCryptoState {
    /// Pickled Olm account (preserves identity keys + OTK state).
    account: vodozemac::olm::AccountPickle,
    /// Olm sessions keyed by remote Curve25519 identity key.
    olm_sessions: HashMap<String, vodozemac::olm::SessionPickle>,
    /// Maps "userId:deviceId" → Curve25519 identity key.
    device_to_idkey: HashMap<String, String>,
    /// Outbound Megolm sessions keyed by room ID.
    megolm_outbound: HashMap<String, vodozemac::megolm::GroupSessionPickle>,
    /// Inbound Megolm sessions keyed by session ID.
    megolm_inbound: HashMap<String, vodozemac::megolm::InboundGroupSessionPickle>,
}

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
    device_fingerprint: Mutex<String>,
    /// Ed25519 identity key (base64) for signing.
    ed25519_key: Mutex<String>,
    /// Curve25519 identity key (base64) for Olm session establishment.
    curve25519_key: Mutex<String>,
    /// Olm account — holds this device's Ed25519 (signing) and Curve25519
    /// (identity) key pairs.  Wrapped in Mutex so create_inbound_session
    /// (which needs &mut Account) can be called from &self methods.
    olm_account: Arc<Mutex<Account>>,
    /// Megolm session store.
    sessions: Arc<Mutex<MegolmSessions>>,
    /// Olm sessions for to-device message encryption/decryption.
    /// All sessions are keyed by the remote device's Curve25519 identity key
    /// (base64).  This allows both encrypt (after lookup via device_to_idkey)
    /// and decrypt (direct lookup by sender_identity_key) to find the session.
    olm_sessions: Arc<Mutex<HashMap<String, OlmSession>>>,
    /// Maps "userId:deviceId" → identity key (base64) so olm_encrypt can
    /// locate the session stored by identity key.
    device_to_idkey: Arc<Mutex<HashMap<String, String>>>,
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
            device_fingerprint: Mutex::new(fingerprint),
            ed25519_key: Mutex::new(ed25519_key),
            curve25519_key: Mutex::new(curve25519_key),
            olm_account: Arc::new(Mutex::new(olm_account)),
            sessions: Arc::new(Mutex::new(MegolmSessions::new())),
            olm_sessions: Arc::new(Mutex::new(HashMap::new())),
            device_to_idkey: Arc::new(Mutex::new(HashMap::new())),
            verifications: Arc::new(Mutex::new(HashMap::new())),
            devices: Arc::new(Mutex::new(HashMap::new())),
            rooms: Arc::new(Mutex::new(HashMap::new())),
        })
    }

    /// Get the device fingerprint (Ed25519 public key, base64-encoded)
    pub fn device_fingerprint(&self) -> String {
        self.device_fingerprint.lock().unwrap().clone()
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
        Ok(self.curve25519_key.lock().unwrap().clone())
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
    /// Create the outbound Megolm session for a room if it doesn't exist yet.
    ///
    /// Call this BEFORE `get_outbound_session_key` / `get_outbound_session_id`
    /// when you need to export the session key at ratchet index 0 (before any
    /// message is encrypted).  This lets the caller share the key with other
    /// devices and guarantees they can decrypt every message from index 0.
    ///
    /// If the session already exists this is a no-op.
    pub fn ensure_outbound_session(&self, room_id: String) -> Result<(), CryptoError> {
        let mut sessions = self.sessions.lock().unwrap();
        if !sessions.outbound.contains_key(&room_id) {
            let outbound = GroupSession::new(SessionConfig::version_1());
            let session_key = outbound.session_key();
            let session_id = outbound.session_id().to_owned();

            let inbound = InboundGroupSession::new(&session_key, SessionConfig::version_1());

            sessions.inbound.insert(session_id, inbound);
            sessions.outbound.insert(room_id, outbound);
        }
        Ok(())
    }

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
        // Ensure the outbound session exists (creates it if needed).
        self.ensure_outbound_session(room_id.clone())?;

        let mut sessions = self.sessions.lock().unwrap();

        let outbound = sessions.outbound.get_mut(&room_id).unwrap();

        // Matrix Megolm plaintext: a JSON object with `type`, `content`, and
        // `room_id`.  The spec requires `room_id` in the plaintext so the
        // recipient can verify the message belongs to the claimed room.
        let plaintext = format!(
            r#"{{"type":{},"content":{},"room_id":{}}}"#,
            serde_json::to_string(&event_type)
                .map_err(|e| CryptoError::EncryptionFailed(e.to_string()))?,
            content,
            serde_json::to_string(&room_id)
                .map_err(|e| CryptoError::EncryptionFailed(e.to_string()))?,
        );

        let msg: MegolmMessage = outbound.encrypt(&plaintext);
        let session_id = outbound.session_id().to_owned();

        Ok(format!(
            r#"{{"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"{}","device_id":"{}","sender_key":"{}","session_id":"{}"}}"#,
            msg.to_base64(),
            self.device_id,
            self.curve25519_key.lock().unwrap(),
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

        // Collect diagnostic info before the mutable borrow from get_mut
        let stored_ids: Vec<String> = sessions.inbound.keys()
            .map(|s| s.chars().take(12).collect::<String>())
            .collect();

        let inbound = sessions.inbound.get_mut(session_id)
            .ok_or_else(|| {
                eprintln!(
                    "[RUST:decrypt] No session for {} (have {} sessions: {:?})",
                    &session_id[..std::cmp::min(12, session_id.len())],
                    stored_ids.len(),
                    stored_ids,
                );
                CryptoError::DecryptionFailed(
                    format!("No inbound session for session_id {} (have {} sessions: {:?})",
                        session_id, stored_ids.len(), stored_ids)
                )
            })?;

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
        let key_value = serde_json::Value::String(session_key_base64.clone());
        let session_key: vodozemac::megolm::SessionKey = serde_json::from_value(key_value)
            .map_err(|e| CryptoError::DecryptionFailed(
                format!("Invalid session key base64: {e}")
            ))?;
        let inbound = InboundGroupSession::new(&session_key, SessionConfig::version_1());
        let session_id = inbound.session_id().to_owned();
        eprintln!("[RUST:addInbound] Created session, id={}, room={}, keyLen={}", session_id, room_id, session_key_base64.len());
        let mut sessions = self.sessions.lock().unwrap();
        sessions.inbound.insert(session_id.clone(), inbound);
        eprintln!("[RUST:addInbound] Stored. Total inbound sessions: {}", sessions.inbound.len());
        Ok(())
    }

    /// Import an inbound Megolm session from a forwarded/exported session key.
    ///
    /// Unlike `add_inbound_session` which takes a `SessionKey` (from the
    /// original `m.room_key`), this takes an `ExportedSessionKey` (from
    /// `m.forwarded_room_key` or key backup). The exported format uses a
    /// different binary prefix and may start at a ratchet index > 0.
    pub fn import_inbound_session(
        &self,
        room_id: String,
        _sender_key: String,
        exported_key_base64: String,
    ) -> Result<(), CryptoError> {
        let key_value = serde_json::Value::String(exported_key_base64);
        let exported_key: ExportedSessionKey = serde_json::from_value(key_value)
            .map_err(|e| CryptoError::DecryptionFailed(
                format!("Invalid exported session key base64: {e}")
            ))?;
        let inbound = InboundGroupSession::import(&exported_key, SessionConfig::version_1());
        let session_id = inbound.session_id().to_owned();
        tracing::info!(
            room_id = %room_id,
            session_id = %session_id,
            "Imported forwarded/exported inbound Megolm session"
        );
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
        // DEBUG: log the exact key we're storing the session under
        eprintln!(
            "[OLM-DEBUG] create_olm_session: storing session for {}:{} under idkey='{}'",
            user_id, device_id, their_identity_key
        );
        // Store session by identity key so olmDecrypt can find it
        self.olm_sessions.lock().unwrap().insert(their_identity_key.clone(), session);
        // Map userId:deviceId → identity key so olmEncrypt can find it
        let device_key = format!("{}:{}", user_id, device_id);
        self.device_to_idkey.lock().unwrap().insert(device_key.clone(), their_identity_key.clone());
        // DEBUG: dump all session keys after insert
        let all_keys: Vec<String> = self.olm_sessions.lock().unwrap().keys().cloned().collect();
        eprintln!(
            "[OLM-DEBUG] create_olm_session: all session keys after insert: {:?}",
            all_keys
        );
        eprintln!(
            "[OLM-DEBUG] create_olm_session: device_to_idkey[{}] = {}",
            device_key, their_identity_key
        );
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
        let device_key = format!("{}:{}", user_id, device_id);
        let idkey = self.device_to_idkey.lock().unwrap()
            .get(&device_key)
            .cloned()
            .ok_or_else(|| CryptoError::EncryptionFailed(
                format!("No Olm session for {device_key} — call create_olm_session first")
            ))?;
        let mut olm_sessions = self.olm_sessions.lock().unwrap();
        let session = olm_sessions.get_mut(&idkey)
            .ok_or_else(|| CryptoError::EncryptionFailed(
                format!("No Olm session for identity key {idkey}")
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

        // DEBUG: log what we're looking up and what keys exist
        let all_keys: Vec<String> = self.olm_sessions.lock().unwrap().keys().cloned().collect();
        eprintln!(
            "[OLM-DEBUG] olm_decrypt: looking for sender_identity_key='{}', msg_type={}, all session keys: {:?}",
            sender_identity_key, msg_type, all_keys
        );

        let sender_key = Curve25519PublicKey::from_base64(&sender_identity_key)
            .map_err(|e| CryptoError::DecryptionFailed(
                format!("Invalid sender identity key: {e}")
            ))?;

        if msg_type == 0 {
            // PreKey message: try to create a new inbound session from our account.
            let prekey_msg = vodozemac::olm::PreKeyMessage::from_base64(&ciphertext_b64)
                .map_err(|e| CryptoError::DecryptionFailed(
                    format!("Invalid PreKey message: {e}")
                ))?;
            let mut account = self.olm_account.lock().unwrap();
            match account.create_inbound_session(sender_key, &prekey_msg) {
                Ok(result) => {
                    // Store the new inbound session keyed by the sender identity key
                    // so future normal messages from this device can be decrypted.
                    drop(account);
                    eprintln!(
                        "[OLM-DEBUG] olm_decrypt type 0: created inbound session, storing under idkey='{}'",
                        sender_identity_key
                    );
                    self.olm_sessions.lock().unwrap()
                        .insert(sender_identity_key, result.session);
                    String::from_utf8(result.plaintext)
                        .map_err(|_| CryptoError::DecryptionFailed(
                            "Olm plaintext is not valid UTF-8".to_string()
                        ))
                }
                Err(e) => {
                    // Unknown OTK — the sender may have created a new session
                    // using a stale OTK.  Fallback: try decrypting with our
                    // existing session for this sender (vodozemac's Session::decrypt
                    // extracts the inner Normal message from a PreKey envelope).
                    drop(account);
                    let mut olm_sessions = self.olm_sessions.lock().unwrap();
                    if let Some(session) = olm_sessions.get_mut(&sender_identity_key) {
                        let olm_msg = OlmMessage::PreKey(prekey_msg);
                        match session.decrypt(&olm_msg) {
                            Ok(plaintext) => {
                                String::from_utf8(plaintext)
                                    .map_err(|_| CryptoError::DecryptionFailed(
                                        "Olm plaintext is not valid UTF-8".to_string()
                                    ))
                            }
                            Err(e2) => Err(CryptoError::DecryptionFailed(
                                format!("New session failed ({e}); existing session also failed ({e2})")
                            ))
                        }
                    } else {
                        Err(CryptoError::DecryptionFailed(
                            format!("Failed to create inbound Olm session: {e} (no existing session to fall back on)")
                        ))
                    }
                }
            }
        } else {
            // Normal message: look up the existing inbound session by sender key.
            let mut olm_sessions = self.olm_sessions.lock().unwrap();
            let session = olm_sessions.get_mut(&sender_identity_key)
                .ok_or_else(|| CryptoError::DecryptionFailed(
                    format!("No Olm session for sender key {sender_identity_key}")
                ))?;
            let msg = vodozemac::olm::Message::from_base64(&ciphertext_b64)
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

    // -----------------------------------------------------------------------
    // Device key and one-time key upload helpers  (needed for T1-1: other
    // devices can only Olm-encrypt to-device messages for us after we upload
    // our Curve25519 identity key and signed one-time keys to the homeserver)
    // -----------------------------------------------------------------------

    /// Return the signed device keys JSON body for `POST /keys/upload`.
    ///
    /// The returned string is a JSON object with `algorithms`, `device_id`,
    /// `keys` (curve25519 + ed25519) and a `signatures` dict signed with the
    /// account's Ed25519 key — ready to embed in the `device_keys` field of
    /// the `/keys/upload` request body.
    pub fn get_device_keys_json(&self) -> Result<String, CryptoError> {
        let account = self.olm_account.lock().unwrap();
        let identity_keys = account.identity_keys();
        let curve25519_b64 = identity_keys.curve25519.to_base64();
        let ed25519_b64 = identity_keys.ed25519.to_base64();

        // Build the to-be-signed object using BTreeMap so keys are sorted
        // (canonical JSON for Matrix signatures requires sorted keys).
        let mut unsigned: std::collections::BTreeMap<&str, serde_json::Value> = std::collections::BTreeMap::new();
        unsigned.insert("algorithms", serde_json::json!([
            "m.olm.v1.curve25519-aes-sha2",
            "m.megolm.v1.aes-sha2"
        ]));
        unsigned.insert("device_id", serde_json::Value::String(self.device_id.clone()));
        unsigned.insert("keys", serde_json::json!({
            format!("curve25519:{}", self.device_id): &curve25519_b64,
            format!("ed25519:{}", self.device_id): &ed25519_b64,
        }));
        unsigned.insert("user_id", serde_json::Value::String(self.user_id.clone()));

        let to_sign = serde_json::to_string(&unsigned)
            .map_err(|e| CryptoError::Unknown(e.to_string()))?;
        let signature = account.sign(&to_sign);
        // Ed25519Signature does not implement serde::Serialize — use to_base64() directly.
        let sig_b64 = signature.to_base64();

        let device_keys = serde_json::json!({
            "algorithms": ["m.olm.v1.curve25519-aes-sha2", "m.megolm.v1.aes-sha2"],
            "device_id": &self.device_id,
            "keys": {
                format!("curve25519:{}", self.device_id): &curve25519_b64,
                format!("ed25519:{}", self.device_id): &ed25519_b64,
            },
            "user_id": &self.user_id,
            "signatures": {
                &self.user_id: {
                    format!("ed25519:{}", self.device_id): sig_b64
                }
            }
        });

        serde_json::to_string(&device_keys)
            .map_err(|e| CryptoError::Unknown(e.to_string()))
    }

    /// Generate `count` new one-time keys and return them as the signed JSON
    /// object expected by the `one_time_keys` field of `POST /keys/upload`.
    ///
    /// Each key is of type `signed_curve25519` and has a signature created by
    /// the account's Ed25519 signing key.
    ///
    /// Call `mark_keys_as_published()` after a successful upload so vodozemac
    /// stops returning the same keys on subsequent calls.
    pub fn generate_one_time_keys_json(&self, count: u32) -> Result<String, CryptoError> {
        let mut account = self.olm_account.lock().unwrap();
        account.generate_one_time_keys(count as usize);

        let otks = account.one_time_keys();
        let mut result: std::collections::BTreeMap<String, serde_json::Value> = std::collections::BTreeMap::new();

        // Use vodozemac's KeyId (a monotonically-increasing u64, base64-encoded)
        // as the OTK identifier.  Previously we used the enumerate() index which
        // restarted at 0001 for every batch, causing "already exists" errors on
        // the homeserver when uploading a second batch.
        for (key_id, curve25519_key) in otks.iter() {
            let key_b64 = curve25519_key.to_base64();

            // Canonical JSON for the key object (sorted single-key object)
            let to_sign = format!(r#"{{"key":"{}"}}"#, key_b64);
            let signature = account.sign(&to_sign);
            // Ed25519Signature does not implement serde::Serialize — use to_base64() directly.
            let sig_b64 = signature.to_base64();

            let signed_key = serde_json::json!({
                "key": key_b64,
                "signatures": {
                    &self.user_id: {
                        format!("ed25519:{}", self.device_id): sig_b64
                    }
                }
            });

            // The homeserver treats OTK IDs as opaque strings.  Using vodozemac's
            // internal KeyId guarantees uniqueness across the account's lifetime.
            result.insert(format!("signed_curve25519:{}", key_id.to_base64()), signed_key);
        }

        serde_json::to_string(&result)
            .map_err(|e| CryptoError::Unknown(e.to_string()))
    }

    /// Mark the current batch of one-time keys as published.
    ///
    /// Must be called after a successful `POST /keys/upload` so vodozemac
    /// rotates to a fresh set and doesn't re-serve the same OTKs.
    pub fn mark_keys_as_published(&self) -> Result<(), CryptoError> {
        let mut account = self.olm_account.lock().unwrap();
        account.mark_keys_as_published();
        Ok(())
    }

    // -----------------------------------------------------------------------
    // State persistence — export / import
    // -----------------------------------------------------------------------

    /// Serialise the full crypto state to a JSON string so it can be persisted
    /// by the host application (e.g. AsyncStorage, filesystem).
    ///
    /// Includes: Olm account, Olm sessions, device→idkey map,
    /// Megolm outbound + inbound sessions.
    pub fn export_state(&self) -> Result<String, CryptoError> {
        let account = self.olm_account.lock().unwrap();
        let olm_sessions_guard = self.olm_sessions.lock().unwrap();
        let device_map = self.device_to_idkey.lock().unwrap();
        let megolm = self.sessions.lock().unwrap();

        let mut olm_pickles: HashMap<String, vodozemac::olm::SessionPickle> = HashMap::new();
        for (key, session) in olm_sessions_guard.iter() {
            olm_pickles.insert(key.clone(), session.pickle());
        }

        let mut outbound_pickles: HashMap<String, vodozemac::megolm::GroupSessionPickle> = HashMap::new();
        for (room_id, session) in megolm.outbound.iter() {
            outbound_pickles.insert(room_id.clone(), session.pickle());
        }

        let mut inbound_pickles: HashMap<String, vodozemac::megolm::InboundGroupSessionPickle> = HashMap::new();
        for (session_id, session) in megolm.inbound.iter() {
            inbound_pickles.insert(session_id.clone(), session.pickle());
        }

        let state = PersistedCryptoState {
            account: account.pickle(),
            olm_sessions: olm_pickles,
            device_to_idkey: device_map.clone(),
            megolm_outbound: outbound_pickles,
            megolm_inbound: inbound_pickles,
        };

        serde_json::to_string(&state)
            .map_err(|e| CryptoError::StorageError(e.to_string()))
    }

    /// Restore crypto state from a previously exported JSON string.
    ///
    /// Replaces the current Olm account, all Olm sessions, device→idkey map,
    /// and all Megolm sessions.  Also updates the derived identity keys so
    /// subsequent calls to `get_identity_key()` / `device_fingerprint()` are
    /// consistent with the restored account.
    ///
    /// Returns `true` if the state was restored, `false` if `state_json` is
    /// empty (caller should proceed with the fresh account created by `new()`).
    pub fn import_state(&self, state_json: String) -> Result<bool, CryptoError> {
        if state_json.is_empty() {
            return Ok(false);
        }

        let state: PersistedCryptoState = serde_json::from_str(&state_json)
            .map_err(|e| CryptoError::StorageError(
                format!("Failed to parse persisted state: {e}")
            ))?;

        // Restore the Olm account and update derived identity keys.
        let restored_account = Account::from_pickle(state.account);
        let identity_keys = restored_account.identity_keys();
        let ed25519_b64 = identity_keys.ed25519.to_base64();
        let curve25519_b64 = identity_keys.curve25519.to_base64();

        *self.ed25519_key.lock().unwrap() = ed25519_b64.clone();
        *self.curve25519_key.lock().unwrap() = curve25519_b64.clone();
        *self.device_fingerprint.lock().unwrap() = ed25519_b64.clone();

        *self.olm_account.lock().unwrap() = restored_account;

        tracing::info!(
            "[STATE] Restored Olm account — ed25519={}, curve25519={}",
            &ed25519_b64[..12], &curve25519_b64[..12]
        );

        // Restore Olm sessions.
        let mut olm_sessions = self.olm_sessions.lock().unwrap();
        olm_sessions.clear();
        for (key, pickle) in state.olm_sessions {
            let session = OlmSession::from_pickle(pickle);
            olm_sessions.insert(key, session);
        }
        tracing::info!("[STATE] Restored {} Olm session(s)", olm_sessions.len());

        // Restore device→idkey mapping.
        let mut device_map = self.device_to_idkey.lock().unwrap();
        *device_map = state.device_to_idkey;

        // Restore Megolm sessions.
        let mut megolm = self.sessions.lock().unwrap();
        megolm.outbound.clear();
        for (room_id, pickle) in state.megolm_outbound {
            let session = GroupSession::from_pickle(pickle);
            megolm.outbound.insert(room_id, session);
        }
        megolm.inbound.clear();
        for (session_id, pickle) in state.megolm_inbound {
            let session = InboundGroupSession::from_pickle(pickle);
            megolm.inbound.insert(session_id, session);
        }
        tracing::info!(
            "[STATE] Restored {} outbound + {} inbound Megolm session(s)",
            megolm.outbound.len(), megolm.inbound.len()
        );

        Ok(true)
    }
}
