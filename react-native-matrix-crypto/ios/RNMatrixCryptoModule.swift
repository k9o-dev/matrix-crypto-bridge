import Foundation
import React

/// React Native bridge for Matrix crypto on iOS.
/// Delegates to MatrixCryptoBridge static methods — no instance needed.
///
/// IMPORTANT: This module uses TurboModule-style promises (implicit JSI handling)
/// rather than explicit RCTPromiseResolveBlock/RCTPromiseRejectBlock parameters.
/// This ensures compatibility with React Native New Architecture codegen.
@objc(RNMatrixCrypto)
class RNMatrixCrypto: NSObject {

    // MARK: - Initialization

    @objc(initialize:deviceId:pickleKey:withResolver:withRejecter:)
    func initialize(
        userId: String,
        deviceId: String,
        pickleKey: String,
        withResolver resolve: @escaping RCTPromiseResolveBlock,
        withRejecter reject: @escaping RCTPromiseRejectBlock
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
        withResolver resolve: @escaping RCTPromiseResolveBlock,
        withRejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            resolve(try MatrixCryptoBridge.getDeviceFingerprint())
        } catch {
            reject("GET_FINGERPRINT_ERROR", "Failed to get device fingerprint: \(error.localizedDescription)", error)
        }
    }

    @objc(getUserId:withRejecter:)
    func getUserId(
        withResolver resolve: @escaping RCTPromiseResolveBlock,
        withRejecter reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            resolve(try MatrixCryptoBridge.getUserId())
        } catch {
            reject("GET_USERID_ERROR", "Failed to get user ID: \(error.localizedDescription)", error)
        }
    }

    @objc(getDeviceId:withRejecter:)
    func getDeviceId(
        withResolver resolve: @escaping RCTPromiseResolveBlock,
        withRejecter reject: @escaping RCTPromiseRejectBlock
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
        withResolver resolve: @escaping RCTPromiseResolveBlock,
        withRejecter reject: @escaping RCTPromiseRejectBlock
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
        withResolver resolve: @escaping RCTPromiseResolveBlock,
        withRejecter reject: @escaping RCTPromiseRejectBlock
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
        withResolver resolve: @escaping RCTPromiseResolveBlock,
        withRejecter reject: @escaping RCTPromiseRejectBlock
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
        withResolver resolve: @escaping RCTPromiseResolveBlock,
        withRejecter reject: @escaping RCTPromiseRejectBlock
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
        withResolver resolve: @escaping RCTPromiseResolveBlock,
        withRejecter reject: @escaping RCTPromiseRejectBlock
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
        withResolver resolve: @escaping RCTPromiseResolveBlock,
        withRejecter reject: @escaping RCTPromiseRejectBlock
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
        withResolver resolve: @escaping RCTPromiseResolveBlock,
        withRejecter reject: @escaping RCTPromiseRejectBlock
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
        withResolver resolve: @escaping RCTPromiseResolveBlock,
        withRejecter reject: @escaping RCTPromiseRejectBlock
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
        withResolver resolve: @escaping RCTPromiseResolveBlock,
        withRejecter reject: @escaping RCTPromiseRejectBlock
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
        withResolver resolve: @escaping RCTPromiseResolveBlock,
        withRejecter reject: @escaping RCTPromiseRejectBlock
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
        withResolver resolve: @escaping RCTPromiseResolveBlock,
        withRejecter reject: @escaping RCTPromiseRejectBlock
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
        withResolver resolve: @escaping RCTPromiseResolveBlock,
        withRejecter reject: @escaping RCTPromiseRejectBlock
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

    // MARK: - Key Exchange (T1-1)

    @objc(getIdentityKey:withRejecter:)
    func getIdentityKey(withResolver resolve: @escaping RCTPromiseResolveBlock, withRejecter reject: @escaping RCTPromiseRejectBlock) {
        do { resolve(try MatrixCryptoBridge.getIdentityKey()) }
        catch { reject("GET_IDENTITY_KEY_ERROR", "Failed to get identity key: \(error.localizedDescription)", error) }
    }

    @objc(getOutboundSessionKey:withResolver:withRejecter:)
    func getOutboundSessionKey(roomId: String, withResolver resolve: @escaping RCTPromiseResolveBlock, withRejecter reject: @escaping RCTPromiseRejectBlock) {
        do { resolve(try MatrixCryptoBridge.getOutboundSessionKey(roomId: roomId)) }
        catch { reject("GET_SESSION_KEY_ERROR", "Failed to get outbound session key: \(error.localizedDescription)", error) }
    }

    @objc(getOutboundSessionId:withResolver:withRejecter:)
    func getOutboundSessionId(roomId: String, withResolver resolve: @escaping RCTPromiseResolveBlock, withRejecter reject: @escaping RCTPromiseRejectBlock) {
        do { resolve(try MatrixCryptoBridge.getOutboundSessionId(roomId: roomId)) }
        catch { reject("GET_SESSION_ID_ERROR", "Failed to get outbound session id: \(error.localizedDescription)", error) }
    }

    @objc(addInboundSession:senderKey:sessionKeyBase64:withResolver:withRejecter:)
    func addInboundSession(roomId: String, senderKey: String, sessionKeyBase64: String, withResolver resolve: @escaping RCTPromiseResolveBlock, withRejecter reject: @escaping RCTPromiseRejectBlock) {
        do {
            try MatrixCryptoBridge.addInboundSession(roomId: roomId, senderKey: senderKey, sessionKeyBase64: sessionKeyBase64)
            resolve(["success": true])
        } catch { reject("ADD_INBOUND_SESSION_ERROR", "Failed to add inbound session: \(error.localizedDescription)", error) }
    }

    @objc(createOlmSession:deviceId:theirIdentityKey:theirOneTimeKey:withResolver:withRejecter:)
    func createOlmSession(userId: String, deviceId: String, theirIdentityKey: String, theirOneTimeKey: String, withResolver resolve: @escaping RCTPromiseResolveBlock, withRejecter reject: @escaping RCTPromiseRejectBlock) {
        do {
            try MatrixCryptoBridge.createOlmSession(userId: userId, deviceId: deviceId, theirIdentityKey: theirIdentityKey, theirOneTimeKey: theirOneTimeKey)
            resolve(["success": true])
        } catch { reject("CREATE_OLM_SESSION_ERROR", "Failed to create Olm session: \(error.localizedDescription)", error) }
    }

    @objc(olmEncrypt:deviceId:plaintext:withResolver:withRejecter:)
    func olmEncrypt(userId: String, deviceId: String, plaintext: String, withResolver resolve: @escaping RCTPromiseResolveBlock, withRejecter reject: @escaping RCTPromiseRejectBlock) {
        do { resolve(try MatrixCryptoBridge.olmEncrypt(userId: userId, deviceId: deviceId, plaintext: plaintext)) }
        catch { reject("OLM_ENCRYPT_ERROR", "Failed to Olm encrypt: \(error.localizedDescription)", error) }
    }

    @objc(olmDecrypt:msgType:ciphertextB64:withResolver:withRejecter:)
    func olmDecrypt(senderIdentityKey: String, msgType: UInt32, ciphertextB64: String, withResolver resolve: @escaping RCTPromiseResolveBlock, withRejecter reject: @escaping RCTPromiseRejectBlock) {
        do { resolve(try MatrixCryptoBridge.olmDecrypt(senderIdentityKey: senderIdentityKey, msgType: msgType, ciphertextB64: ciphertextB64)) }
        catch { reject("OLM_DECRYPT_ERROR", "Failed to Olm decrypt: \(error.localizedDescription)", error) }
    }

    // MARK: - Key Upload (T1-1)

    @objc(getDeviceKeysJson:withRejecter:)
    func getDeviceKeysJson(withResolver resolve: @escaping RCTPromiseResolveBlock, withRejecter reject: @escaping RCTPromiseRejectBlock) {
        do { resolve(try MatrixCryptoBridge.getDeviceKeysJson()) }
        catch { reject("GET_DEVICE_KEYS_ERROR", "Failed to get device keys: \(error.localizedDescription)", error) }
    }

    @objc(generateOneTimeKeysJson:withResolver:withRejecter:)
    func generateOneTimeKeysJson(count: UInt32, withResolver resolve: @escaping RCTPromiseResolveBlock, withRejecter reject: @escaping RCTPromiseRejectBlock) {
        do { resolve(try MatrixCryptoBridge.generateOneTimeKeysJson(count: count)) }
        catch { reject("GEN_OTK_ERROR", "Failed to generate one-time keys: \(error.localizedDescription)", error) }
    }

    @objc(markKeysAsPublished:withRejecter:)
    func markKeysAsPublished(withResolver resolve: @escaping RCTPromiseResolveBlock, withRejecter reject: @escaping RCTPromiseRejectBlock) {
        do { try MatrixCryptoBridge.markKeysAsPublished(); resolve(["success": true]) }
        catch { reject("MARK_PUBLISHED_ERROR", "Failed to mark keys as published: \(error.localizedDescription)", error) }
    }

    // MARK: - Cleanup

    @objc(destroy:withRejecter:)
    func destroy(
        withResolver resolve: @escaping RCTPromiseResolveBlock,
        withRejecter reject: @escaping RCTPromiseRejectBlock
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
