/// Information about a device
#[derive(Debug, Clone)]
pub struct DeviceInfo {
    /// The device ID
    pub device_id: String,

    /// The user ID that owns this device
    pub user_id: String,

    /// Optional display name for the device
    pub display_name: Option<String>,

    /// The curve25519 fingerprint of the device
    pub fingerprint: String,

    /// Whether this device is verified
    pub is_verified: bool,

    /// Whether this device is blocked
    pub is_blocked: bool,

    /// The algorithm used for encryption
    pub algorithm: String,
}

/// A pair of emoji for SAS verification
#[derive(Debug, Clone)]
pub struct EmojiSASPair {
    /// The emoji character
    pub emoji: String,

    /// The name of the emoji
    pub name: String,
}

/// The state of a device verification
#[derive(Debug, Clone)]
pub struct VerificationState {
    /// Unique identifier for this verification
    pub verification_id: String,

    /// Current state: "pending", "sas_ready", "confirmed", "completed", "cancelled"
    pub state: String,

    /// The user ID being verified
    pub other_user_id: String,

    /// The device ID being verified
    pub other_device_id: String,

    /// The emoji pairs for SAS verification (if in sas_ready state)
    pub emojis: Vec<EmojiSASPair>,

    /// The decimal numbers for SAS verification (if in sas_ready state)
    pub decimals: Vec<u32>,
}

/// Encryption algorithm information
#[derive(Debug, Clone)]
pub struct EncryptionAlgorithm {
    /// The algorithm identifier (e.g., "m.megolm.v1.aes-sha2")
    pub algorithm: String,

    /// Rotation period in milliseconds
    pub rotation_period_ms: u64,

    /// Rotation period in messages
    pub rotation_period_msgs: u64,
}

/// Room encryption state
#[derive(Debug, Clone)]
pub struct RoomEncryptionState {
    /// The room ID
    pub room_id: String,

    /// Whether encryption is enabled
    pub is_encrypted: bool,

    /// The encryption algorithm used
    pub algorithm: Option<String>,

    /// List of devices that can decrypt messages
    pub trusted_devices: Vec<String>,

    /// List of devices that cannot decrypt messages
    pub untrusted_devices: Vec<String>,
}

/// User device list
#[derive(Debug, Clone)]
pub struct UserDevices {
    /// The user ID
    pub user_id: String,

    /// List of devices owned by this user
    pub devices: Vec<DeviceInfo>,
}
