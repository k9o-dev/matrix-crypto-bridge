package com.matrix.crypto

import com.facebook.react.bridge.*
import com.facebook.react.module.annotations.ReactModule

/**
 * React Native bridge for Matrix crypto on Android
 */
@ReactModule(name = "RNMatrixCrypto")
class RNMatrixCrypto(reactContext: ReactApplicationContext) :
    ReactContextBaseJavaModule(reactContext) {

    companion object {
        private var cryptoInstance: MatrixCryptoBridge? = null
    }

    override fun getName(): String = "RNMatrixCrypto"

    // MARK: - Initialization

    @ReactMethod
    fun initialize(userId: String, deviceId: String, pickleKey: String, promise: Promise) {
        try {
            cryptoInstance = MatrixCryptoBridge(userId, deviceId, pickleKey)
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
            val emojis = crypto.getSASEmojis(verificationId)
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
            crypto.confirmSAS(verificationId)
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
                decimalsArray.pushInt(decimal)
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

    // MARK: - Cleanup

    @ReactMethod
    fun destroy(promise: Promise) {
        cryptoInstance = null
        val result = WritableNativeMap()
        result.putBoolean("success", true)
        promise.resolve(result)
    }
}
