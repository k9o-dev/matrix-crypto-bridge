package com.matrix.crypto

/**
 * Kotlin wrapper for the Matrix crypto bridge
 */
class MatrixCryptoBridge(
    userId: String,
    deviceId: String,
    pickleKey: String
) {
    private val crypto: MatrixCrypto = MatrixCrypto(
        userId = userId,
        deviceId = deviceId,
        pickleKey = pickleKey
    )

    /**
     * Get the device fingerprint
     */
    fun deviceFingerprint(): String = crypto.deviceFingerprint()

    /**
     * Get the user ID
     */
    fun userId(): String = crypto.userId()

    /**
     * Get the device ID
     */
    fun deviceId(): String = crypto.deviceId()

    /**
     * Get devices for a user
     */
    @Throws(CryptoException::class)
    fun getUserDevices(userId: String): List<DeviceInfo> =
        crypto.getUserDevices(userId)

    /**
     * Add a device to the store
     */
    @Throws(CryptoException::class)
    fun addDevice(device: DeviceInfo) {
        crypto.addDevice(device)
    }

    /**
     * Start device verification
     */
    @Throws(CryptoException::class)
    fun startVerification(
        otherUserId: String,
        otherDeviceId: String
    ): VerificationState = crypto.startVerification(
        otherUserId = otherUserId,
        otherDeviceId = otherDeviceId
    )

    /**
     * Get SAS emojis for verification
     */
    @Throws(CryptoException::class)
    fun getSASEmojis(verificationId: String): List<EmojiSASPair> =
        crypto.getSASEmojis(verificationId)

    /**
     * Confirm SAS verification
     */
    @Throws(CryptoException::class)
    fun confirmSAS(verificationId: String) {
        crypto.confirmSAS(verificationId)
    }

    /**
     * Complete device verification
     */
    @Throws(CryptoException::class)
    fun completeVerification(verificationId: String) {
        crypto.completeVerification(verificationId)
    }

    /**
     * Cancel device verification
     */
    @Throws(CryptoException::class)
    fun cancelVerification(verificationId: String) {
        crypto.cancelVerification(verificationId)
    }

    /**
     * Get verification state
     */
    @Throws(CryptoException::class)
    fun getVerificationState(verificationId: String): VerificationState =
        crypto.getVerificationState(verificationId)

    /**
     * Enable encryption for a room
     */
    @Throws(CryptoException::class)
    fun enableRoomEncryption(
        roomId: String,
        algorithm: String
    ) {
        crypto.enableRoomEncryption(roomId, algorithm)
    }

    /**
     * Get room encryption state
     */
    @Throws(CryptoException::class)
    fun getRoomEncryptionState(roomId: String): RoomEncryptionState =
        crypto.getRoomEncryptionState(roomId)

    /**
     * Encrypt event content
     */
    @Throws(CryptoException::class)
    fun encryptEvent(
        roomId: String,
        eventType: String,
        content: String
    ): String = crypto.encryptEvent(
        roomId = roomId,
        eventType = eventType,
        content = content
    )

    /**
     * Decrypt event content
     */
    @Throws(CryptoException::class)
    fun decryptEvent(
        roomId: String,
        encryptedContent: String
    ): String = crypto.decryptEvent(
        roomId = roomId,
        encryptedContent = encryptedContent
    )
}

/**
 * Exception thrown by crypto operations
 */
class CryptoException(message: String, cause: Throwable? = null) :
    Exception(message, cause)

/**
 * Information about a device
 */
data class DeviceInfo(
    val deviceId: String,
    val userId: String,
    val displayName: String? = null,
    val fingerprint: String,
    val isVerified: Boolean = false,
    val isBlocked: Boolean = false,
    val algorithm: String
)

/**
 * A pair of emoji for SAS verification
 */
data class EmojiSASPair(
    val emoji: String,
    val name: String
)

/**
 * The state of a device verification
 */
data class VerificationState(
    val verificationId: String,
    val state: String,
    val otherUserId: String,
    val otherDeviceId: String,
    val emojis: List<EmojiSASPair> = emptyList(),
    val decimals: List<Int> = emptyList()
)

/**
 * Room encryption state
 */
data class RoomEncryptionState(
    val roomId: String,
    val isEncrypted: Boolean,
    val algorithm: String? = null,
    val trustedDevices: List<String> = emptyList(),
    val untrustedDevices: List<String> = emptyList()
)

/**
 * Encryption algorithm information
 */
data class EncryptionAlgorithm(
    val algorithm: String,
    val rotationPeriodMs: Long,
    val rotationPeriodMsgs: Long
)

/**
 * User device list
 */
data class UserDevices(
    val userId: String,
    val devices: List<DeviceInfo>
)
