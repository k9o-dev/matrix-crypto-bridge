import Foundation
import React

/// React Native bridge for Matrix crypto on iOS
@objc(RNMatrixCrypto)
class RNMatrixCrypto: NSObject {
    private static var cryptoInstance: MatrixCryptoBridge?
    
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
            RNMatrixCrypto.cryptoInstance = try MatrixCryptoBridge(
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
        guard let crypto = RNMatrixCrypto.cryptoInstance else {
            reject("NOT_INITIALIZED", "Crypto not initialized", nil)
            return
        }
        
        resolve(crypto.deviceFingerprint())
    }
    
    @objc(getUserId:withRejecter:)
    func getUserId(
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        guard let crypto = RNMatrixCrypto.cryptoInstance else {
            reject("NOT_INITIALIZED", "Crypto not initialized", nil)
            return
        }
        
        resolve(crypto.userId())
    }
    
    @objc(getDeviceId:withRejecter:)
    func getDeviceId(
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        guard let crypto = RNMatrixCrypto.cryptoInstance else {
            reject("NOT_INITIALIZED", "Crypto not initialized", nil)
            return
        }
        
        resolve(crypto.deviceId())
    }
    
    // MARK: - Device Management
    
    @objc(getUserDevices:withResolver:withRejecter:)
    func getUserDevices(
        userId: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        guard let crypto = RNMatrixCrypto.cryptoInstance else {
            reject("NOT_INITIALIZED", "Crypto not initialized", nil)
            return
        }
        
        do {
            let devices = try crypto.getUserDevices(userId: userId)
            let deviceDicts = devices.map { device -> [String: Any] in
                [
                    "deviceId": device.deviceId,
                    "userId": device.userId,
                    "displayName": device.displayName as Any,
                    "fingerprint": device.fingerprint,
                    "isVerified": device.isVerified,
                    "isBlocked": device.isBlocked,
                    "algorithm": device.algorithm
                ]
            }
            resolve(deviceDicts)
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
        guard let crypto = RNMatrixCrypto.cryptoInstance else {
            reject("NOT_INITIALIZED", "Crypto not initialized", nil)
            return
        }
        
        do {
            let deviceInfo = DeviceInfo(
                deviceId: device["deviceId"] as? String ?? "",
                userId: device["userId"] as? String ?? "",
                displayName: device["displayName"] as? String,
                fingerprint: device["fingerprint"] as? String ?? "",
                isVerified: device["isVerified"] as? Bool ?? false,
                isBlocked: device["isBlocked"] as? Bool ?? false,
                algorithm: device["algorithm"] as? String ?? ""
            )
            try crypto.addDevice(deviceInfo)
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
        guard let crypto = RNMatrixCrypto.cryptoInstance else {
            reject("NOT_INITIALIZED", "Crypto not initialized", nil)
            return
        }
        
        do {
            let state = try crypto.startVerification(
                otherUserId: otherUserId,
                otherDeviceId: otherDeviceId
            )
            resolve([
                "verificationId": state.verificationId,
                "state": state.state,
                "otherUserId": state.otherUserId,
                "otherDeviceId": state.otherDeviceId,
                "emojis": [],
                "decimals": []
            ])
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
        guard let crypto = RNMatrixCrypto.cryptoInstance else {
            reject("NOT_INITIALIZED", "Crypto not initialized", nil)
            return
        }
        
        do {
            let emojis = try crypto.getSASEmojis(verificationId: verificationId)
            let emojiDicts = emojis.map { emoji -> [String: String] in
                [
                    "emoji": emoji.emoji,
                    "name": emoji.name
                ]
            }
            resolve(emojiDicts)
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
        guard let crypto = RNMatrixCrypto.cryptoInstance else {
            reject("NOT_INITIALIZED", "Crypto not initialized", nil)
            return
        }
        
        do {
            try crypto.confirmSAS(verificationId: verificationId)
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
        guard let crypto = RNMatrixCrypto.cryptoInstance else {
            reject("NOT_INITIALIZED", "Crypto not initialized", nil)
            return
        }
        
        do {
            try crypto.completeVerification(verificationId: verificationId)
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
        guard let crypto = RNMatrixCrypto.cryptoInstance else {
            reject("NOT_INITIALIZED", "Crypto not initialized", nil)
            return
        }
        
        do {
            try crypto.cancelVerification(verificationId: verificationId)
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
        guard let crypto = RNMatrixCrypto.cryptoInstance else {
            reject("NOT_INITIALIZED", "Crypto not initialized", nil)
            return
        }
        
        do {
            let state = try crypto.getVerificationState(verificationId: verificationId)
            resolve([
                "verificationId": state.verificationId,
                "state": state.state,
                "otherUserId": state.otherUserId,
                "otherDeviceId": state.otherDeviceId,
                "emojis": state.emojis.map { ["emoji": $0.emoji, "name": $0.name] },
                "decimals": state.decimals
            ])
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
        guard let crypto = RNMatrixCrypto.cryptoInstance else {
            reject("NOT_INITIALIZED", "Crypto not initialized", nil)
            return
        }
        
        do {
            try crypto.enableRoomEncryption(roomId: roomId, algorithm: algorithm)
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
        guard let crypto = RNMatrixCrypto.cryptoInstance else {
            reject("NOT_INITIALIZED", "Crypto not initialized", nil)
            return
        }
        
        do {
            let state = try crypto.getRoomEncryptionState(roomId: roomId)
            resolve([
                "roomId": state.roomId,
                "isEncrypted": state.isEncrypted,
                "algorithm": state.algorithm as Any,
                "trustedDevices": state.trustedDevices,
                "untrustedDevices": state.untrustedDevices
            ])
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
        guard let crypto = RNMatrixCrypto.cryptoInstance else {
            reject("NOT_INITIALIZED", "Crypto not initialized", nil)
            return
        }
        
        do {
            let encrypted = try crypto.encryptEvent(
                roomId: roomId,
                eventType: eventType,
                content: content
            )
            resolve(encrypted)
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
        guard let crypto = RNMatrixCrypto.cryptoInstance else {
            reject("NOT_INITIALIZED", "Crypto not initialized", nil)
            return
        }
        
        do {
            let decrypted = try crypto.decryptEvent(
                roomId: roomId,
                encryptedContent: encryptedContent
            )
            resolve(decrypted)
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
        RNMatrixCrypto.cryptoInstance = nil
        resolve(["success": true])
    }
    
    // MARK: - Module Setup
    
    @objc
    static func requiresMainQueueSetup() -> Bool {
        return false
    }
}
