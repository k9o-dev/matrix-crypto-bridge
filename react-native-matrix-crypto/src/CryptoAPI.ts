import { NativeMatrixCrypto } from './NativeMatrixCrypto';
import type {
  DeviceInfo,
  EmojiSASPair,
  VerificationState,
  RoomEncryptionState,
} from './index';

/**
 * High-level API for Matrix crypto operations
 * Provides a clean, easy-to-use interface for encryption, device verification, and key management
 */
export class CryptoAPI {
  private initialized: boolean = false;
  private userId: string = '';
  private deviceId: string = '';

  /**
   * Initialize the crypto API
   */
  async initialize(
    userId: string,
    deviceId: string,
    pickleKey: string
  ): Promise<void> {
    try {
      await NativeMatrixCrypto.initialize(userId, deviceId, pickleKey);
      this.initialized = true;
      this.userId = userId;
      this.deviceId = deviceId;
    } catch (error) {
      throw new Error(`Failed to initialize crypto: ${error}`);
    }
  }

  /**
   * Check if crypto is initialized
   */
  isInitialized(): boolean {
    return this.initialized;
  }

  /**
   * Get device information
   */
  async getDeviceInfo(): Promise<{
    fingerprint: string;
    userId: string;
    deviceId: string;
  }> {
    this.assertInitialized();
    try {
      const [fingerprint, userId, deviceId] = await Promise.all([
        NativeMatrixCrypto.getDeviceFingerprint(),
        NativeMatrixCrypto.getUserId(),
        NativeMatrixCrypto.getDeviceId(),
      ]);
      return { fingerprint, userId, deviceId };
    } catch (error) {
      throw new Error(`Failed to get device info: ${error}`);
    }
  }

  /**
   * Get all devices for a user
   */
  async getUserDevices(userId: string): Promise<DeviceInfo[]> {
    this.assertInitialized();
    try {
      return await NativeMatrixCrypto.getUserDevices(userId);
    } catch (error) {
      throw new Error(`Failed to get user devices: ${error}`);
    }
  }

  /**
   * Add a device to the device store
   */
  async addDevice(device: DeviceInfo): Promise<void> {
    this.assertInitialized();
    try {
      await NativeMatrixCrypto.addDevice(device);
    } catch (error) {
      throw new Error(`Failed to add device: ${error}`);
    }
  }

  /**
   * Start device verification with another device
   */
  async startVerification(
    otherUserId: string,
    otherDeviceId: string
  ): Promise<VerificationState> {
    this.assertInitialized();
    try {
      const result = await NativeMatrixCrypto.startVerification(
        otherUserId,
        otherDeviceId
      );
      return result as VerificationState;
    } catch (error) {
      throw new Error(`Failed to start verification: ${error}`);
    }
  }

  /**
   * Get SAS emoji pairs for verification
   */
  async getSASEmojis(verificationId: string): Promise<EmojiSASPair[]> {
    this.assertInitialized();
    try {
      return await NativeMatrixCrypto.getSASEmojis(verificationId);
    } catch (error) {
      throw new Error(`Failed to get SAS emojis: ${error}`);
    }
  }

  /**
   * Confirm SAS verification
   */
  async confirmSAS(verificationId: string): Promise<void> {
    this.assertInitialized();
    try {
      await NativeMatrixCrypto.confirmSAS(verificationId);
    } catch (error) {
      throw new Error(`Failed to confirm SAS: ${error}`);
    }
  }

  /**
   * Complete device verification
   */
  async completeVerification(verificationId: string): Promise<void> {
    this.assertInitialized();
    try {
      await NativeMatrixCrypto.completeVerification(verificationId);
    } catch (error) {
      throw new Error(`Failed to complete verification: ${error}`);
    }
  }

  /**
   * Cancel device verification
   */
  async cancelVerification(verificationId: string): Promise<void> {
    this.assertInitialized();
    try {
      await NativeMatrixCrypto.cancelVerification(verificationId);
    } catch (error) {
      throw new Error(`Failed to cancel verification: ${error}`);
    }
  }

  /**
   * Get the current state of a verification
   */
  async getVerificationState(
    verificationId: string
  ): Promise<VerificationState> {
    this.assertInitialized();
    try {
      const result = await NativeMatrixCrypto.getVerificationState(verificationId);
      return result as VerificationState;
    } catch (error) {
      throw new Error(`Failed to get verification state: ${error}`);
    }
  }

  /**
   * Enable encryption for a room
   */
  async enableRoomEncryption(
    roomId: string,
    algorithm: string = 'm.megolm.v1.aes-sha2'
  ): Promise<void> {
    this.assertInitialized();
    try {
      await NativeMatrixCrypto.enableRoomEncryption(roomId, algorithm);
    } catch (error) {
      throw new Error(`Failed to enable room encryption: ${error}`);
    }
  }

  /**
   * Get encryption state for a room
   */
  async getRoomEncryptionState(roomId: string): Promise<RoomEncryptionState> {
    this.assertInitialized();
    try {
      return await NativeMatrixCrypto.getRoomEncryptionState(roomId);
    } catch (error) {
      throw new Error(`Failed to get room encryption state: ${error}`);
    }
  }

  /**
   * Encrypt an event
   */
  async encryptEvent(
    roomId: string,
    eventType: string,
    content: string
  ): Promise<string> {
    this.assertInitialized();
    try {
      return await NativeMatrixCrypto.encryptEvent(
        roomId,
        eventType,
        content
      );
    } catch (error) {
      throw new Error(`Failed to encrypt event: ${error}`);
    }
  }

  /**
   * Decrypt an event
   */
  async decryptEvent(
    roomId: string,
    encryptedContent: string
  ): Promise<string> {
    this.assertInitialized();
    try {
      return await NativeMatrixCrypto.decryptEvent(roomId, encryptedContent);
    } catch (error) {
      throw new Error(`Failed to decrypt event: ${error}`);
    }
  }

  /**
   * Cleanup and destroy the crypto instance
   */
  async destroy(): Promise<void> {
    try {
      await NativeMatrixCrypto.destroy();
      this.initialized = false;
    } catch (error) {
      throw new Error(`Failed to destroy crypto: ${error}`);
    }
  }

  /**
   * Helper method to ensure crypto is initialized
   */
  private assertInitialized(): void {
    if (!this.initialized) {
      throw new Error(
        'Crypto not initialized. Call initialize() first.'
      );
    }
  }
}

export default CryptoAPI;
