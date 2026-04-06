import Foundation
import React

/// React Native bridge for Matrix crypto on iOS.
/// Delegates to MatrixCryptoBridge static methods — no instance needed.
///
/// WHY resolve:reject: (NOT withResolver:withRejecter:)?
///
/// This module uses the RCT_EXTERN_MODULE + RCT_EXTERN_METHOD pattern, where
/// RNMatrixCrypto.m registers each ObjC selector by name and bridges it to
/// Swift.  The ObjC selectors declared in the .m file use "resolve:reject:"
/// as the last two labels, e.g.:
///   initialize:deviceId:pickleKey:resolve:reject:
///
/// The codegen-generated NativeMatrixCryptoSpecJSI (built from
/// NativeMatrixCrypto.ts) also constructs the methodMap_ using "resolve:reject:"
/// labels — it is hardcoded in the RN codegen template.
///
/// "withResolver:withRejecter:" is the naming convention for a completely
/// different module pattern (auto-generated .mm modules with @ReactMethod
/// annotations in the New Architecture).  Using it here breaks both:
///   1. The RCT_EXTERN_METHOD selector registration in .m → crash on invoke
///   2. The codegen methodMap_ lookup → Promise hangs / NSException in TurboModule
///
/// Always keep @objc labels in this file in sync with RNMatrixCrypto.m.
///
/// NUMERIC PARAMETERS: RCT_EXTERN_METHOD always passes numbers as NSNumber
/// objects (boxed pointers).  If a Swift parameter is declared as a value type
/// (UInt32, Int, etc.), the ObjC runtime reinterprets the pointer as the
/// primitive — yielding a garbage value (the pointer address truncated to the
/// primitive's width).  Always declare numeric parameters as NSNumber and call
/// `.uint32Value` / `.intValue` etc. explicitly.
@objc(RNMatrixCrypto)
class RNMatrixCrypto: NSObject {

    // MARK: - Initialization

    @objc(initialize:deviceId:pickleKey:resolve:reject:)
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
            reject("INIT_ERROR", "Failed to initialize crypto: \(String(describing: error))", error)
        }
    }

    // MARK: - Device Information

    @objc(getDeviceFingerprint:reject:)
    func getDeviceFingerprint(
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            resolve(try MatrixCryptoBridge.getDeviceFingerprint())
        } catch {
            reject("GET_FINGERPRINT_ERROR", "Failed to get device fingerprint: \(String(describing: error))", error)
        }
    }

    @objc(getUserId:reject:)
    func getUserId(
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            resolve(try MatrixCryptoBridge.getUserId())
        } catch {
            reject("GET_USERID_ERROR", "Failed to get user ID: \(String(describing: error))", error)
        }
    }

    @objc(getDeviceId:reject:)
    func getDeviceId(
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            resolve(try MatrixCryptoBridge.getDeviceId())
        } catch {
            reject("GET_DEVICEID_ERROR", "Failed to get device ID: \(String(describing: error))", error)
        }
    }

    // MARK: - Device Management

    @objc(getUserDevices:resolve:reject:)
    func getUserDevices(
        userId: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            resolve(try MatrixCryptoBridge.getUserDevices(userId: userId))
        } catch {
            reject("GET_DEVICES_ERROR", "Failed to get user devices: \(String(describing: error))", error)
        }
    }

    @objc(addDevice:resolve:reject:)
    func addDevice(
        device: [String: Any],
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            try MatrixCryptoBridge.addDevice(device: device)
            resolve(["success": true])
        } catch {
            reject("ADD_DEVICE_ERROR", "Failed to add device: \(String(describing: error))", error)
        }
    }

    // MARK: - Device Verification

    @objc(startVerification:otherDeviceId:resolve:reject:)
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
            reject("START_VERIFICATION_ERROR", "Failed to start verification: \(String(describing: error))", error)
        }
    }

    @objc(getSASEmojis:resolve:reject:)
    func getSASEmojis(
        verificationId: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            // MatrixCryptoBridge uses camelCase: getSasEmojis
            resolve(try MatrixCryptoBridge.getSasEmojis(verificationId: verificationId))
        } catch {
            reject("GET_EMOJIS_ERROR", "Failed to get SAS emojis: \(String(describing: error))", error)
        }
    }

    @objc(confirmSAS:resolve:reject:)
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
            reject("CONFIRM_SAS_ERROR", "Failed to confirm SAS: \(String(describing: error))", error)
        }
    }

    @objc(completeVerification:resolve:reject:)
    func completeVerification(
        verificationId: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            try MatrixCryptoBridge.completeVerification(verificationId: verificationId)
            resolve(["success": true])
        } catch {
            reject("COMPLETE_VERIFICATION_ERROR", "Failed to complete verification: \(String(describing: error))", error)
        }
    }

    @objc(cancelVerification:resolve:reject:)
    func cancelVerification(
        verificationId: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            try MatrixCryptoBridge.cancelVerification(verificationId: verificationId)
            resolve(["success": true])
        } catch {
            reject("CANCEL_VERIFICATION_ERROR", "Failed to cancel verification: \(String(describing: error))", error)
        }
    }

    @objc(getVerificationState:resolve:reject:)
    func getVerificationState(
        verificationId: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            resolve(try MatrixCryptoBridge.getVerificationState(verificationId: verificationId))
        } catch {
            reject("GET_VERIFICATION_STATE_ERROR", "Failed to get verification state: \(String(describing: error))", error)
        }
    }

    // MARK: - Room Encryption

    @objc(enableRoomEncryption:algorithm:resolve:reject:)
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
            reject("ENABLE_ENCRYPTION_ERROR", "Failed to enable room encryption: \(String(describing: error))", error)
        }
    }

    @objc(getRoomEncryptionState:resolve:reject:)
    func getRoomEncryptionState(
        roomId: String,
        resolve: @escaping RCTPromiseResolveBlock,
        reject: @escaping RCTPromiseRejectBlock
    ) {
        do {
            resolve(try MatrixCryptoBridge.getRoomEncryptionState(roomId: roomId))
        } catch {
            reject("GET_ENCRYPTION_STATE_ERROR", "Failed to get room encryption state: \(String(describing: error))", error)
        }
    }

    // MARK: - Event Encryption/Decryption

    @objc(encryptEvent:eventType:content:resolve:reject:)
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
            reject("ENCRYPT_ERROR", "Failed to encrypt event: \(String(describing: error))", error)
        }
    }

    @objc(decryptEvent:encryptedContent:resolve:reject:)
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
            reject("DECRYPT_ERROR", "Failed to decrypt event: \(String(describing: error))", error)
        }
    }

    // MARK: - Key Exchange (T1-1)

    @objc(getIdentityKey:reject:)
    func getIdentityKey(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        do { resolve(try MatrixCryptoBridge.getIdentityKey()) }
        catch { reject("GET_IDENTITY_KEY_ERROR", "Failed to get identity key: \(String(describing: error))", error) }
    }

    @objc(getOutboundSessionKey:resolve:reject:)
    func getOutboundSessionKey(roomId: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        do { resolve(try MatrixCryptoBridge.getOutboundSessionKey(roomId: roomId)) }
        catch { reject("GET_SESSION_KEY_ERROR", "Failed to get outbound session key: \(String(describing: error))", error) }
    }

    @objc(getOutboundSessionId:resolve:reject:)
    func getOutboundSessionId(roomId: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        do { resolve(try MatrixCryptoBridge.getOutboundSessionId(roomId: roomId)) }
        catch { reject("GET_SESSION_ID_ERROR", "Failed to get outbound session id: \(String(describing: error))", error) }
    }

    @objc(addInboundSession:senderKey:sessionKeyBase64:resolve:reject:)
    func addInboundSession(roomId: String, senderKey: String, sessionKeyBase64: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        do {
            try MatrixCryptoBridge.addInboundSession(roomId: roomId, senderKey: senderKey, sessionKeyBase64: sessionKeyBase64)
            resolve(["success": true])
        } catch { reject("ADD_INBOUND_SESSION_ERROR", "Failed to add inbound session: \(String(describing: error))", error) }
    }

    @objc(importInboundSession:senderKey:exportedKeyBase64:resolve:reject:)
    func importInboundSession(roomId: String, senderKey: String, exportedKeyBase64: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        do {
            try MatrixCryptoBridge.importInboundSession(roomId: roomId, senderKey: senderKey, exportedKeyBase64: exportedKeyBase64)
            resolve(["success": true])
        } catch { reject("IMPORT_INBOUND_SESSION_ERROR", "Failed to import inbound session: \(String(describing: error))", error) }
    }

    @objc(createOlmSession:deviceId:theirIdentityKey:theirOneTimeKey:resolve:reject:)
    func createOlmSession(userId: String, deviceId: String, theirIdentityKey: String, theirOneTimeKey: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        do {
            try MatrixCryptoBridge.createOlmSession(userId: userId, deviceId: deviceId, theirIdentityKey: theirIdentityKey, theirOneTimeKey: theirOneTimeKey)
            resolve(["success": true])
        } catch { reject("CREATE_OLM_SESSION_ERROR", "Failed to create Olm session: \(String(describing: error))", error) }
    }

    @objc(olmEncrypt:deviceId:plaintext:resolve:reject:)
    func olmEncrypt(userId: String, deviceId: String, plaintext: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        do { resolve(try MatrixCryptoBridge.olmEncrypt(userId: userId, deviceId: deviceId, plaintext: plaintext)) }
        catch { reject("OLM_ENCRYPT_ERROR", "Failed to Olm encrypt: \(String(describing: error))", error) }
    }

    @objc(olmDecrypt:msgType:ciphertextB64:resolve:reject:)
    func olmDecrypt(senderIdentityKey: String, msgType: NSNumber, ciphertextB64: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        // Accept NSNumber from the ObjC bridge and convert explicitly — same
        // pointer-reinterpretation fix as generateOneTimeKeysJson above.
        let msgTypeValue = msgType.uint32Value
        NSLog("[OlmDecrypt] senderKey=%@... msgType=%d bodyLen=%d",
              String(senderIdentityKey.prefix(12)), msgTypeValue, ciphertextB64.count)
        do {
            let result = try MatrixCryptoBridge.olmDecrypt(senderIdentityKey: senderIdentityKey, msgType: msgTypeValue, ciphertextB64: ciphertextB64)
            NSLog("[OlmDecrypt] Success, plaintext length=%d", result.count)
            resolve(result)
        } catch {
            // Use String(describing:) to get the full Rust error message,
            // not just the generic NSError localizedDescription.
            let errorDetail = String(describing: error)
            NSLog("[OlmDecrypt] FAILED: %@", errorDetail)
            reject("OLM_DECRYPT_ERROR", "Olm decrypt failed: \(errorDetail)", error)
        }
    }

    // MARK: - Key Upload (T1-1)

    @objc(getDeviceKeysJson:reject:)
    func getDeviceKeysJson(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        do { resolve(try MatrixCryptoBridge.getDeviceKeysJson()) }
        catch { reject("GET_DEVICE_KEYS_ERROR", "Failed to get device keys: \(String(describing: error))", error) }
    }

    @objc(generateOneTimeKeysJson:resolve:reject:)
    func generateOneTimeKeysJson(count: NSNumber, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        // IMPORTANT: The ObjC bridge (RCT_EXTERN_METHOD) passes `count` as an
        // NSNumber object.  Previously the Swift parameter was declared as UInt32,
        // which caused the ObjC runtime to reinterpret the 64-bit NSNumber pointer
        // as a 32-bit unsigned int — yielding a garbage count in the billions and
        // making the Rust key-generation loop hang forever.  Always accept NSNumber
        // and convert explicitly.
        let countValue = count.uint32Value
        NSLog("[OTK] Starting SYNC generation of %d keys on bridge queue", countValue)
        let start = CFAbsoluteTimeGetCurrent()
        do {
            let json = try MatrixCryptoBridge.generateOneTimeKeysJson(count: countValue)
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            NSLog("[OTK] Generation of %d keys completed in %.2fs", countValue, elapsed)
            resolve(json)
        } catch {
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            NSLog("[OTK] Generation failed after %.2fs: %@", elapsed, String(describing: error))
            reject("GEN_OTK_ERROR", "Failed to generate one-time keys: \(String(describing: error))", error)
        }
    }

    @objc(markKeysAsPublished:reject:)
    func markKeysAsPublished(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        do { try MatrixCryptoBridge.markKeysAsPublished(); resolve(["success": true]) }
        catch { reject("MARK_PUBLISHED_ERROR", "Failed to mark keys as published: \(String(describing: error))", error) }
    }

    // MARK: - State Persistence

    @objc(exportState:reject:)
    func exportState(resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        do { resolve(try MatrixCryptoBridge.exportState()) }
        catch { reject("EXPORT_STATE_ERROR", "Failed to export crypto state: \(String(describing: error))", error) }
    }

    @objc(importState:resolve:reject:)
    func importState(stateJson: String, resolve: @escaping RCTPromiseResolveBlock, reject: @escaping RCTPromiseRejectBlock) {
        do { resolve(try MatrixCryptoBridge.importState(stateJson: stateJson)) }
        catch { reject("IMPORT_STATE_ERROR", "Failed to import crypto state: \(String(describing: error))", error) }
    }

    // MARK: - Cleanup

    @objc(destroy:reject:)
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
