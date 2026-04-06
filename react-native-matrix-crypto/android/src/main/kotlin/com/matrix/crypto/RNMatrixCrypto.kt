package com.matrix.crypto

import com.facebook.react.bridge.*
import com.facebook.react.module.annotations.ReactModule

/**
 * React Native bridge for Matrix crypto on Android.
 * Uses the UniFFI-generated MatrixCrypto class backed by Rust.
 */
@ReactModule(name = "RNMatrixCrypto")
class RNMatrixCrypto(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    companion object {
        private var cryptoInstance: MatrixCrypto? = null
    }

    override fun getName(): String = "RNMatrixCrypto"

    // MARK: - Initialization

    @ReactMethod
    fun initialize(userId: String, deviceId: String, pickleKey: String, promise: Promise) {
        try {
            cryptoInstance = MatrixCrypto(userId, deviceId, pickleKey)
            val result = WritableNativeMap()
            result.putBoolean("success", true)
            promise.resolve(result)
        } catch (e: Exception) {
            promise.reject("INIT_ERROR", "Failed to initialize crypto: ${e.message}", e)
        }
    }

    // MARK: - Device Information

    @ReactMethod
    fun getDeviceFingerprint(promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            promise.resolve(crypto.deviceFingerprint())
        } catch (e: Exception) {
            promise.reject("GET_FINGERPRINT_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun getUserId(promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            promise.resolve(crypto.userId())
        } catch (e: Exception) {
            promise.reject("GET_USER_ID_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun getDeviceId(promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            promise.resolve(crypto.deviceId())
        } catch (e: Exception) {
            promise.reject("GET_DEVICE_ID_ERROR", e.message, e)
        }
    }

    // MARK: - Device Management

    @ReactMethod
    fun getUserDevices(userId: String, promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            val devices = crypto.getUserDevices(userId)
            val deviceArray = WritableNativeArray()

            for (device in devices) {
                val deviceMap = WritableNativeMap()
                deviceMap.putString("deviceId", device.deviceId)
                deviceMap.putString("userId", device.userId)
                deviceMap.putString("displayName", device.displayName)
                deviceMap.putString("fingerprint", device.fingerprint)
                deviceMap.putBoolean("isVerified", device.isVerified)
                deviceMap.putBoolean("isBlocked", device.isBlocked)
                deviceMap.putString("algorithm", device.algorithm)
                deviceArray.pushMap(deviceMap)
            }

            promise.resolve(deviceArray)
        } catch (e: Exception) {
            promise.reject("GET_DEVICES_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun addDevice(device: ReadableMap, promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            val deviceInfo = DeviceInfo(
                deviceId = device.getString("deviceId") ?: "",
                userId = device.getString("userId") ?: "",
                displayName = device.getString("displayName"),
                fingerprint = device.getString("fingerprint") ?: "",
                isVerified = device.getBoolean("isVerified"),
                isBlocked = device.getBoolean("isBlocked"),
                algorithm = device.getString("algorithm") ?: ""
            )
            crypto.addDevice(deviceInfo)
            val result = WritableNativeMap()
            result.putBoolean("success", true)
            promise.resolve(result)
        } catch (e: Exception) {
            promise.reject("ADD_DEVICE_ERROR", e.message, e)
        }
    }

    // MARK: - Device Verification

    @ReactMethod
    fun startVerification(otherUserId: String, otherDeviceId: String, promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            val state = crypto.startVerification(otherUserId, otherDeviceId)

            val result = WritableNativeMap()
            result.putString("verificationId", state.verificationId)
            result.putString("state", state.state)
            result.putString("otherUserId", state.otherUserId)
            result.putString("otherDeviceId", state.otherDeviceId)
            result.putArray("emojis", WritableNativeArray())
            result.putArray("decimals", WritableNativeArray())

            promise.resolve(result)
        } catch (e: Exception) {
            promise.reject("START_VERIFICATION_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun getSASEmojis(verificationId: String, promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            val emojis = crypto.getSasEmojis(verificationId)
            val emojiArray = WritableNativeArray()

            for (emoji in emojis) {
                val emojiMap = WritableNativeMap()
                emojiMap.putString("emoji", emoji.emoji)
                emojiMap.putString("name", emoji.name)
                emojiArray.pushMap(emojiMap)
            }

            promise.resolve(emojiArray)
        } catch (e: Exception) {
            promise.reject("GET_EMOJIS_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun confirmSAS(verificationId: String, promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            crypto.confirmSas(verificationId)
            val result = WritableNativeMap()
            result.putBoolean("success", true)
            promise.resolve(result)
        } catch (e: Exception) {
            promise.reject("CONFIRM_SAS_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun completeVerification(verificationId: String, promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            crypto.completeVerification(verificationId)
            val result = WritableNativeMap()
            result.putBoolean("success", true)
            promise.resolve(result)
        } catch (e: Exception) {
            promise.reject("COMPLETE_VERIFICATION_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun cancelVerification(verificationId: String, promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            crypto.cancelVerification(verificationId)
            val result = WritableNativeMap()
            result.putBoolean("success", true)
            promise.resolve(result)
        } catch (e: Exception) {
            promise.reject("CANCEL_VERIFICATION_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun getVerificationState(verificationId: String, promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            val state = crypto.getVerificationState(verificationId)

            val emojiArray = WritableNativeArray()
            for (emoji in state.emojis) {
                val emojiMap = WritableNativeMap()
                emojiMap.putString("emoji", emoji.emoji)
                emojiMap.putString("name", emoji.name)
                emojiArray.pushMap(emojiMap)
            }

            val decimalsArray = WritableNativeArray()
            for (decimal in state.decimals) {
                decimalsArray.pushInt(decimal.toInt())
            }

            val result = WritableNativeMap()
            result.putString("verificationId", state.verificationId)
            result.putString("state", state.state)
            result.putString("otherUserId", state.otherUserId)
            result.putString("otherDeviceId", state.otherDeviceId)
            result.putArray("emojis", emojiArray)
            result.putArray("decimals", decimalsArray)

            promise.resolve(result)
        } catch (e: Exception) {
            promise.reject("GET_VERIFICATION_STATE_ERROR", e.message, e)
        }
    }

    // MARK: - Room Encryption

    @ReactMethod
    fun enableRoomEncryption(roomId: String, algorithm: String, promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            crypto.enableRoomEncryption(roomId, algorithm)
            val result = WritableNativeMap()
            result.putBoolean("success", true)
            promise.resolve(result)
        } catch (e: Exception) {
            promise.reject("ENABLE_ENCRYPTION_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun getRoomEncryptionState(roomId: String, promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            val state = crypto.getRoomEncryptionState(roomId)

            val trustedArray = WritableNativeArray()
            for (device in state.trustedDevices) {
                trustedArray.pushString(device)
            }

            val untrustedArray = WritableNativeArray()
            for (device in state.untrustedDevices) {
                untrustedArray.pushString(device)
            }

            val result = WritableNativeMap()
            result.putString("roomId", state.roomId)
            result.putBoolean("isEncrypted", state.isEncrypted)
            result.putString("algorithm", state.algorithm)
            result.putArray("trustedDevices", trustedArray)
            result.putArray("untrustedDevices", untrustedArray)

            promise.resolve(result)
        } catch (e: Exception) {
            promise.reject("GET_ENCRYPTION_STATE_ERROR", e.message, e)
        }
    }

    // MARK: - Event Encryption/Decryption

    @ReactMethod
    fun encryptEvent(roomId: String, eventType: String, content: String, promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            val encrypted = crypto.encryptEvent(roomId, eventType, content)
            promise.resolve(encrypted)
        } catch (e: Exception) {
            promise.reject("ENCRYPT_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun decryptEvent(roomId: String, encryptedContent: String, promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            val decrypted = crypto.decryptEvent(roomId, encryptedContent)
            promise.resolve(decrypted)
        } catch (e: Exception) {
            promise.reject("DECRYPT_ERROR", e.message, e)
        }
    }

    // MARK: - Key Management

    @ReactMethod
    fun getIdentityKey(promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            promise.resolve(crypto.getIdentityKey())
        } catch (e: Exception) {
            promise.reject("GET_IDENTITY_KEY_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun getOutboundSessionKey(roomId: String, promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            promise.resolve(crypto.getOutboundSessionKey(roomId))
        } catch (e: Exception) {
            promise.reject("GET_SESSION_KEY_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun getOutboundSessionId(roomId: String, promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            promise.resolve(crypto.getOutboundSessionId(roomId))
        } catch (e: Exception) {
            promise.reject("GET_SESSION_ID_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun addInboundSession(roomId: String, senderKey: String, sessionKeyBase64: String, promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            crypto.addInboundSession(roomId, senderKey, sessionKeyBase64)
            val result = WritableNativeMap()
            result.putBoolean("success", true)
            promise.resolve(result)
        } catch (e: Exception) {
            promise.reject("ADD_INBOUND_SESSION_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun importInboundSession(roomId: String, senderKey: String, exportedKeyBase64: String, promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            crypto.importInboundSession(roomId, senderKey, exportedKeyBase64)
            val result = WritableNativeMap()
            result.putBoolean("success", true)
            promise.resolve(result)
        } catch (e: Exception) {
            promise.reject("IMPORT_INBOUND_SESSION_ERROR", e.message, e)
        }
    }

    // MARK: - Olm

    @ReactMethod
    fun createOlmSession(userId: String, deviceId: String, theirIdentityKey: String, theirOneTimeKey: String, promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            crypto.createOlmSession(userId, deviceId, theirIdentityKey, theirOneTimeKey)
            val result = WritableNativeMap()
            result.putBoolean("success", true)
            promise.resolve(result)
        } catch (e: Exception) {
            promise.reject("CREATE_OLM_SESSION_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun olmEncrypt(userId: String, deviceId: String, plaintext: String, promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            promise.resolve(crypto.olmEncrypt(userId, deviceId, plaintext))
        } catch (e: Exception) {
            promise.reject("OLM_ENCRYPT_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun olmDecrypt(senderIdentityKey: String, msgType: Int, ciphertextB64: String, promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            promise.resolve(crypto.olmDecrypt(senderIdentityKey, msgType.toUInt(), ciphertextB64))
        } catch (e: Exception) {
            promise.reject("OLM_DECRYPT_ERROR", e.message, e)
        }
    }

    // MARK: - Device Keys

    @ReactMethod
    fun getDeviceKeysJson(promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            promise.resolve(crypto.getDeviceKeysJson())
        } catch (e: Exception) {
            promise.reject("GET_DEVICE_KEYS_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun generateOneTimeKeysJson(count: Int, promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            promise.resolve(crypto.generateOneTimeKeysJson(count.toUInt()))
        } catch (e: Exception) {
            promise.reject("GENERATE_OTK_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun markKeysAsPublished(promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            crypto.markKeysAsPublished()
            val result = WritableNativeMap()
            result.putBoolean("success", true)
            promise.resolve(result)
        } catch (e: Exception) {
            promise.reject("MARK_PUBLISHED_ERROR", e.message, e)
        }
    }

    // MARK: - State Persistence

    @ReactMethod
    fun exportState(promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            promise.resolve(crypto.exportState())
        } catch (e: Exception) {
            promise.reject("EXPORT_STATE_ERROR", e.message, e)
        }
    }

    @ReactMethod
    fun importState(stateJson: String, promise: Promise) {
        try {
            val crypto = cryptoInstance ?: throw Exception("Crypto not initialized")
            val success = crypto.importState(stateJson)
            promise.resolve(success)
        } catch (e: Exception) {
            promise.reject("IMPORT_STATE_ERROR", e.message, e)
        }
    }

    // MARK: - Cleanup

    @ReactMethod
    fun destroy(promise: Promise) {
        cryptoInstance?.close()
        cryptoInstance = null
        val result = WritableNativeMap()
        result.putBoolean("success", true)
        promise.resolve(result)
    }
}
