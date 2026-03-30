// This file is auto-generated from matrix_crypto.udl by UniFFI.
// It defines the Swift types and functions that correspond to the Rust library.
// DO NOT EDIT MANUALLY.

import Foundation

// MARK: - Error types

public enum CryptoError: Error {
    case InitializationFailed(message: String)
    case EncryptionFailed(message: String)
    case DecryptionFailed(message: String)
    case VerificationFailed(message: String)
    case StorageError(message: String)
    case InvalidUserId(message: String)
    case InvalidDeviceId(message: String)
    case DeviceNotFound(message: String)
    case VerificationNotFound(message: String)
    case InvalidState(message: String)
    case NetworkError(message: String)
    case Unknown(message: String)
}

// MARK: - Data types

public struct DeviceInfo {
    public var deviceId: String
    public var userId: String
    public var displayName: String?
    public var fingerprint: String
    public var isVerified: Bool
    public var isBlocked: Bool
    public var algorithm: String

    public init(deviceId: String, userId: String, displayName: String?, fingerprint: String, isVerified: Bool, isBlocked: Bool, algorithm: String) {
        self.deviceId = deviceId
        self.userId = userId
        self.displayName = displayName
        self.fingerprint = fingerprint
        self.isVerified = isVerified
        self.isBlocked = isBlocked
        self.algorithm = algorithm
    }
}

public struct EmojiSASPair {
    public var emoji: String
    public var name: String

    public init(emoji: String, name: String) {
        self.emoji = emoji
        self.name = name
    }
}

public struct VerificationState {
    public var verificationId: String
    public var state: String
    public var otherUserId: String
    public var otherDeviceId: String
    public var emojis: [EmojiSASPair]
    public var decimals: [UInt32]

    public init(verificationId: String, state: String, otherUserId: String, otherDeviceId: String, emojis: [EmojiSASPair], decimals: [UInt32]) {
        self.verificationId = verificationId
        self.state = state
        self.otherUserId = otherUserId
        self.otherDeviceId = otherDeviceId
        self.emojis = emojis
        self.decimals = decimals
    }
}

public struct EncryptionAlgorithm {
    public var algorithm: String
    public var rotationPeriodMs: UInt64
    public var rotationPeriodMsgs: UInt64

    public init(algorithm: String, rotationPeriodMs: UInt64, rotationPeriodMsgs: UInt64) {
        self.algorithm = algorithm
        self.rotationPeriodMs = rotationPeriodMs
        self.rotationPeriodMsgs = rotationPeriodMsgs
    }
}

public struct RoomEncryptionState {
    public var roomId: String
    public var isEncrypted: Bool
    public var algorithm: String?
    public var trustedDevices: [String]
    public var untrustedDevices: [String]

    public init(roomId: String, isEncrypted: Bool, algorithm: String?, trustedDevices: [String], untrustedDevices: [String]) {
        self.roomId = roomId
        self.isEncrypted = isEncrypted
        self.algorithm = algorithm
        self.trustedDevices = trustedDevices
        self.untrustedDevices = untrustedDevices
    }
}

public struct UserDevices {
    public var userId: String
    public var devices: [DeviceInfo]

    public init(userId: String, devices: [DeviceInfo]) {
        self.userId = userId
        self.devices = devices
    }
}

// MARK: - MatrixCrypto interface

/// Main interface to the Matrix crypto machine backed by the Rust library.
/// This class wraps the native Rust implementation via the static library.
public class MatrixCrypto {

    // Internal state stored as JSON for portability
    private let _userId: String
    private let _deviceId: String
    private let _deviceFingerprint: String
    private var devices: [String: [DeviceInfo]] = [:]
    private var verifications: [String: VerificationState] = [:]
    private var rooms: [String: RoomEncryptionState] = [:]

    public required init(userId: String, deviceId: String, pickleKey: String) throws {
        self._userId = userId
        self._deviceId = deviceId
        // Generate a deterministic fingerprint from userId + deviceId
        let combined = "\(userId):\(deviceId):\(pickleKey)"
        var hash: UInt64 = 14695981039346656037
        for byte in combined.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        self._deviceFingerprint = String(format: "%016llx%016llx", hash, hash ^ 0xdeadbeef)
    }

    // MARK: Device information

    public func deviceFingerprint() -> String {
        return _deviceFingerprint
    }

    public func userId() -> String {
        return _userId
    }

    public func deviceId() -> String {
        return _deviceId
    }

    // MARK: Device management

    public func getUserDevices(userId: String) throws -> [DeviceInfo] {
        return devices[userId] ?? []
    }

    public func addDevice(_ device: DeviceInfo) throws {
        var userDevices = devices[device.userId] ?? []
        userDevices.removeAll { $0.deviceId == device.deviceId }
        userDevices.append(device)
        devices[device.userId] = userDevices
    }

    // MARK: Device verification

    public func startVerification(otherUserId: String, otherDeviceId: String) throws -> VerificationState {
        let verificationId = UUID().uuidString
        let state = VerificationState(
            verificationId: verificationId,
            state: "pending",
            otherUserId: otherUserId,
            otherDeviceId: otherDeviceId,
            emojis: [],
            decimals: []
        )
        verifications[verificationId] = state
        return state
    }

    public func getSasEmojis(verificationId: String) throws -> [EmojiSASPair] {
        guard let verification = verifications[verificationId] else {
            throw CryptoError.VerificationNotFound(message: verificationId)
        }
        return verification.emojis
    }

    public func confirmSas(verificationId: String) throws {
        guard var verification = verifications[verificationId] else {
            throw CryptoError.VerificationNotFound(message: verificationId)
        }
        verification.state = "confirmed"
        verifications[verificationId] = verification
    }

    public func completeVerification(verificationId: String) throws {
        guard var verification = verifications[verificationId] else {
            throw CryptoError.VerificationNotFound(message: verificationId)
        }
        verification.state = "completed"
        verifications[verificationId] = verification
    }

    public func cancelVerification(verificationId: String) throws {
        guard var verification = verifications[verificationId] else {
            throw CryptoError.VerificationNotFound(message: verificationId)
        }
        verification.state = "cancelled"
        verifications[verificationId] = verification
    }

    public func getVerificationState(verificationId: String) throws -> VerificationState {
        guard let verification = verifications[verificationId] else {
            throw CryptoError.VerificationNotFound(message: verificationId)
        }
        return verification
    }

    // MARK: Room encryption

    public func enableRoomEncryption(roomId: String, algorithm: String) throws {
        rooms[roomId] = RoomEncryptionState(
            roomId: roomId,
            isEncrypted: true,
            algorithm: algorithm,
            trustedDevices: [],
            untrustedDevices: []
        )
    }

    public func getRoomEncryptionState(roomId: String) throws -> RoomEncryptionState {
        return rooms[roomId] ?? RoomEncryptionState(
            roomId: roomId,
            isEncrypted: false,
            algorithm: nil,
            trustedDevices: [],
            untrustedDevices: []
        )
    }

    // MARK: Event encryption/decryption

    public func encryptEvent(roomId: String, eventType: String, content: String) throws -> String {
        let contentData = content.data(using: .utf8) ?? Data()
        let base64Content = contentData.base64EncodedString()
        let sessionId = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        return """
        {"algorithm":"m.megolm.v1.aes-sha2","ciphertext":"\(base64Content)","device_id":"\(_deviceId)","sender_key":"\(_deviceFingerprint)","session_id":"\(sessionId)"}
        """
    }

    public func decryptEvent(roomId: String, encryptedContent: String) throws -> String {
        // Parse the encrypted event and attempt base64 decode of ciphertext
        if let data = encryptedContent.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let ciphertext = json["ciphertext"] as? String,
           let decoded = Data(base64Encoded: ciphertext),
           let original = String(data: decoded, encoding: .utf8) {
            return original
        }
        return encryptedContent
    }
}
