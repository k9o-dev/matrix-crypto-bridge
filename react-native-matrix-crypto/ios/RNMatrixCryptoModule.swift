import Foundation
import React

/// React Native bridge for Matrix crypto on iOS.
/// Delegates to MatrixCryptoBridge static methods — no instance needed.
@objc(RNMatrixCrypto)
class RNMatrixCrypto: NSObject {

    // MARK: - Initialization

    @objc(initialize:deviceId:pickleKey:withResolver:withRejecter:)
    func initialize(
        userId: String,
        deviceId: String,
        pickleKey: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            try MatrixCryptoBridge.initialize(
                userId: userId,
                deviceId: deviceId,
                pickleKey: pickleKey
            )
            resolve(["success": true])
        } catch {
            reject("INIT_ERROR", "Failed to initialize crypto: \(error.localizedDescription)", error)
        }
    }

    // MARK: - Device Information

    @objc(getDeviceFingerprint:withRejecter:)
    func getDeviceFingerprint(
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            resolve(try MatrixCryptoBridge.getDeviceFingerprint())
        } catch {
            reject("GET_FINGERPRINT_ERROR", "Failed to get device fingerprint: \(error.localizedDescription)", error)
        }
    }

    @objc(getUserId:withRejecter:)
    func getUserId(
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            resolve(try MatrixCryptoBridge.getUserId())
        } catch {
            reject("GET_USERID_ERROR", "Failed to get user ID: \(error.localizedDescription)", error)
        }
    }

    @objc(getDeviceId:withRejecter:)
    func getDeviceId(
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            resolve(try MatrixCryptoBridge.getDeviceId())
        } catch {
            reject("GET_DEVICEID_ERROR", "Failed to get device ID: \(error.localizedDescription)", error)
        }
    }

    // MARK: - Device Management

    @objc(getUserDevices:withResolver:withRejecter:)
    func getUserDevices(
        userId: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            resolve(try MatrixCryptoBridge.getUserDevices(userId: userId))
        } catch {
            reject("GET_DEVICES_ERROR", "Failed to get user devices: \(error.localizedDescription)", error)
        }
    }

    @objc(addDevice:withResolver:withRejecter:)
    func addDevice(
        device: [String: Any],
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            try MatrixCryptoBridge.addDevice(device: device)
            resolve(["success": true])
        } catch {
            reject("ADD_DEVICE_ERROR", "Failed to add device: \(error.localizedDescription)", error)
        }
    }

    // MARK: - Device Verification

    @objc(startVerification:otherDeviceId:withResolver:withRejecter:)
    func startVerification(
        otherUserId: String,
        otherDeviceId: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            resolve(try MatrixCryptoBridge.startVerification(
                otherUserId: otherUserId,
                otherDeviceId: otherDeviceId
            ))
        } catch {
            reject("START_VERIFICATION_ERROR", "Failed to start verification: \(error.localizedDescription)", error)
        }
    }

    @objc(getSASEmojis:withResolver:withRejecter:)
    func getSASEmojis(
        verificationId: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            // MatrixCryptoBridge uses camelCase: getSasEmojis
            resolve(try MatrixCryptoBridge.getSasEmojis(verificationId: verificationId))
        } catch {
            reject("GET_EMOJIS_ERROR", "Failed to get SAS emojis: \(error.localizedDescription)", error)
        }
    }

    @objc(confirmSAS:withResolver:withRejecter:)
    func confirmSAS(
        verificationId: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            // MatrixCryptoBridge uses camelCase: confirmSas
            try MatrixCryptoBridge.confirmSas(verificationId: verificationId)
            resolve(["success": true])
        } catch {
            reject("CONFIRM_SAS_ERROR", "Failed to confirm SAS: \(error.localizedDescription)", error)
        }
    }

    @objc(completeVerification:withResolver:withRejecter:)
    func completeVerification(
        verificationId: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            try MatrixCryptoBridge.completeVerification(verificationId: verificationId)
            resolve(["success": true])
        } catch {
            reject("COMPLETE_VERIFICATION_ERROR", "Failed to complete verification: \(error.localizedDescription)", error)
        }
    }

    @objc(cancelVerification:withResolver:withRejecter:)
    func cancelVerification(
        verificationId: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            try MatrixCryptoBridge.cancelVerification(verificationId: verificationId)
            resolve(["success": true])
        } catch {
            reject("CANCEL_VERIFICATION_ERROR", "Failed to cancel verification: \(error.localizedDescription)", error)
        }
    }

    @objc(getVerificationState:withResolver:withRejecter:)
    func getVerificationState(
        verificationId: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            resolve(try MatrixCryptoBridge.getVerificationState(verificationId: verificationId))
        } catch {
            reject("GET_VERIFICATION_STATE_ERROR", "Failed to get verification state: \(error.localizedDescription)", error)
        }
    }

    // MARK: - Room Encryption

    @objc(enableRoomEncryption:algorithm:withResolver:withRejecter:)
    func enableRoomEncryption(
        roomId: String,
        algorithm: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            try MatrixCryptoBridge.enableRoomEncryption(roomId: roomId, algorithm: algorithm)
            resolve(["success": true])
        } catch {
            reject("ENABLE_ENCRYPTION_ERROR", "Failed to enable room encryption: \(error.localizedDescription)", error)
        }
    }

    @objc(getRoomEncryptionState:withResolver:withRejecter:)
    func getRoomEncryptionState(
        roomId: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            resolve(try MatrixCryptoBridge.getRoomEncryptionState(roomId: roomId))
        } catch {
            reject("GET_ENCRYPTION_STATE_ERROR", "Failed to get room encryption state: \(error.localizedDescription)", error)
        }
    }

    // MARK: - Event Encryption/Decryption

    @objc(encryptEvent:eventType:content:withResolver:withRejecter:)
    func encryptEvent(
        roomId: String,
        eventType: String,
        content: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            resolve(try MatrixCryptoBridge.encryptEvent(
                roomId: roomId,
                eventType: eventType,
                content: content
            ))
        } catch {
            reject("ENCRYPT_ERROR", "Failed to encrypt event: \(error.localizedDescription)", error)
        }
    }

    @objc(decryptEvent:encryptedContent:withResolver:withRejecter:)
    func decryptEvent(
        roomId: String,
        encryptedContent: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            resolve(try MatrixCryptoBridge.decryptEvent(
                roomId: roomId,
                encryptedContent: encryptedContent
            ))
        } catch {
            reject("DECRYPT_ERROR", "Failed to decrypt event: \(error.localizedDescription)", error)
        }
    }

    // MARK: - Cleanup

    @objc(destroy:withRejecter:)
    func destroy(
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        MatrixCryptoBridge.destroy()
        resolve(["success": true])
    }

    // MARK: - Module Setup

    @objc
    static func requiresMainQueueSetup() -> Bool {
        return false
    }
}
