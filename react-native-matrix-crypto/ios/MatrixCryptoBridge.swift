import Foundation

/**
 * Swift wrapper for the Matrix crypto bridge.
 *
 * Delegates to MatrixCrypto (defined in MatrixCryptoBridgeFFI.swift),
 * which provides the actual crypto implementation backed by the Rust library.
 */
public class MatrixCryptoBridge {
    private let crypto: MatrixCrypto

    public init(userId: String, deviceId: String, pickleKey: String) throws {
        self.crypto = try MatrixCrypto(userId: userId, deviceId: deviceId, pickleKey: pickleKey)
    }

    public func deviceFingerprint() -> String {
        return crypto.deviceFingerprint()
    }

    public func userId() -> String {
        return crypto.userId()
    }

    public func deviceId() -> String {
        return crypto.deviceId()
    }

    public func getUserDevices(userId: String) throws -> [DeviceInfo] {
        return try crypto.getUserDevices(userId: userId)
    }

    public func addDevice(_ device: DeviceInfo) throws {
        try crypto.addDevice(device)
    }

    public func startVerification(otherUserId: String, otherDeviceId: String) throws -> VerificationState {
        return try crypto.startVerification(otherUserId: otherUserId, otherDeviceId: otherDeviceId)
    }

    public func getSASEmojis(verificationId: String) throws -> [EmojiSASPair] {
        return try crypto.getSasEmojis(verificationId: verificationId)
    }

    public func confirmSAS(verificationId: String) throws {
        try crypto.confirmSas(verificationId: verificationId)
    }

    public func completeVerification(verificationId: String) throws {
        try crypto.completeVerification(verificationId: verificationId)
    }

    public func cancelVerification(verificationId: String) throws {
        try crypto.cancelVerification(verificationId: verificationId)
    }

    public func getVerificationState(verificationId: String) throws -> VerificationState {
        return try crypto.getVerificationState(verificationId: verificationId)
    }

    public func enableRoomEncryption(roomId: String, algorithm: String) throws {
        try crypto.enableRoomEncryption(roomId: roomId, algorithm: algorithm)
    }

    public func getRoomEncryptionState(roomId: String) throws -> RoomEncryptionState {
        return try crypto.getRoomEncryptionState(roomId: roomId)
    }

    public func encryptEvent(roomId: String, eventType: String, content: String) throws -> String {
        return try crypto.encryptEvent(roomId: roomId, eventType: eventType, content: content)
    }

    public func decryptEvent(roomId: String, encryptedContent: String) throws -> String {
        return try crypto.decryptEvent(roomId: roomId, encryptedContent: encryptedContent)
    }
}
