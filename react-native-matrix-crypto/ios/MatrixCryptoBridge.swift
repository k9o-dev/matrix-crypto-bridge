import Foundation

/// Swift wrapper for the Matrix crypto bridge
public class MatrixCryptoBridge {
    private let crypto: MatrixCrypto
    
    /// Initialize the crypto bridge
    /// - Parameters:
    ///   - userId: The user ID (e.g., @user:example.com)
    ///   - deviceId: The device ID
    ///   - pickleKey: The encryption key for storage
    public init(userId: String, deviceId: String, pickleKey: String) throws {
        self.crypto = try MatrixCrypto(
            userId: userId,
            deviceId: deviceId,
            pickleKey: pickleKey
        )
    }
    
    /// Get the device fingerprint
    public func deviceFingerprint() -> String {
        return crypto.deviceFingerprint()
    }
    
    /// Get the user ID
    public func userId() -> String {
        return crypto.userId()
    }
    
    /// Get the device ID
    public func deviceId() -> String {
        return crypto.deviceId()
    }
    
    /// Get devices for a user
    public func getUserDevices(userId: String) throws -> [DeviceInfo] {
        return try crypto.getUserDevices(userId: userId)
    }
    
    /// Add a device to the store
    public func addDevice(_ device: DeviceInfo) throws {
        try crypto.addDevice(device)
    }
    
    /// Start device verification
    public func startVerification(
        otherUserId: String,
        otherDeviceId: String
    ) throws -> VerificationState {
        return try crypto.startVerification(
            otherUserId: otherUserId,
            otherDeviceId: otherDeviceId
        )
    }
    
    /// Get SAS emojis for verification
    public func getSASEmojis(verificationId: String) throws -> [EmojiSASPair] {
        return try crypto.getSASEmojis(verificationId: verificationId)
    }
    
    /// Confirm SAS verification
    public func confirmSAS(verificationId: String) throws {
        try crypto.confirmSAS(verificationId: verificationId)
    }
    
    /// Complete device verification
    public func completeVerification(verificationId: String) throws {
        try crypto.completeVerification(verificationId: verificationId)
    }
    
    /// Cancel device verification
    public func cancelVerification(verificationId: String) throws {
        try crypto.cancelVerification(verificationId: verificationId)
    }
    
    /// Get verification state
    public func getVerificationState(verificationId: String) throws -> VerificationState {
        return try crypto.getVerificationState(verificationId: verificationId)
    }
    
    /// Enable encryption for a room
    public func enableRoomEncryption(
        roomId: String,
        algorithm: String
    ) throws {
        try crypto.enableRoomEncryption(roomId: roomId, algorithm: algorithm)
    }
    
    /// Get room encryption state
    public func getRoomEncryptionState(roomId: String) throws -> RoomEncryptionState {
        return try crypto.getRoomEncryptionState(roomId: roomId)
    }
    
    /// Encrypt event content
    public func encryptEvent(
        roomId: String,
        eventType: String,
        content: String
    ) throws -> String {
        return try crypto.encryptEvent(
            roomId: roomId,
            eventType: eventType,
            content: content
        )
    }
    
    /// Decrypt event content
    public func decryptEvent(
        roomId: String,
        encryptedContent: String
    ) throws -> String {
        return try crypto.decryptEvent(
            roomId: roomId,
            encryptedContent: encryptedContent
        )
    }
}
