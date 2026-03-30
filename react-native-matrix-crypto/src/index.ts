import { NativeModules, Platform } from 'react-native';

const LINKING_ERROR =
  `The package 'react-native-matrix-crypto' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

const MatrixCryptoModule = NativeModules.RNMatrixCrypto
  ? NativeModules.RNMatrixCrypto
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

export interface DeviceInfo {
  deviceId: string;
  userId: string;
  displayName?: string;
  fingerprint: string;
  isVerified: boolean;
  isBlocked: boolean;
  algorithm: string;
}

export interface EmojiSASPair {
  emoji: string;
  name: string;
}

export interface VerificationState {
  verificationId: string;
  state: 'pending' | 'sas_ready' | 'confirmed' | 'completed' | 'cancelled';
  otherUserId: string;
  otherDeviceId: string;
  emojis: EmojiSASPair[];
  decimals: number[];
}

export interface RoomEncryptionState {
  roomId: string;
  isEncrypted: boolean;
  algorithm?: string;
  trustedDevices: string[];
  untrustedDevices: string[];
}

export interface EncryptionAlgorithm {
  algorithm: string;
  rotationPeriodMs: number;
  rotationPeriodMsgs: number;
}

export interface UserDevices {
  userId: string;
  devices: DeviceInfo[];
}

export class MatrixCrypto {
  private static instance: MatrixCrypto | null = null;
  private handle: number | null = null;

  private constructor() {}

  /**
   * Get or create singleton instance
   */
  static getInstance(): MatrixCrypto {
    if (!MatrixCrypto.instance) {
      MatrixCrypto.instance = new MatrixCrypto();
    }
    return MatrixCrypto.instance;
  }

  /**
   * Initialize the crypto machine
   */
  async initialize(
    userId: string,
    deviceId: string,
    pickleKey: string
  ): Promise<void> {
    try {
      this.handle = await MatrixCryptoModule.initialize(
        userId,
        deviceId,
        pickleKey
      );
    } catch (error) {
      throw new Error(`Failed to initialize Matrix crypto: ${error}`);
    }
  }

  /**
   * Get the device fingerprint
   */
  async getDeviceFingerprint(): Promise<string> {
    if (!this.handle) {
      throw new Error('Crypto not initialized');
    }
    try {
      return await MatrixCryptoModule.getDeviceFingerprint(this.handle);
    } catch (error) {
      throw new Error(`Failed to get device fingerprint: ${error}`);
    }
  }

  /**
   * Get the user ID
   */
  async getUserId(): Promise<string> {
    if (!this.handle) {
      throw new Error('Crypto not initialized');
    }
    try {
      return await MatrixCryptoModule.getUserId(this.handle);
    } catch (error) {
      throw new Error(`Failed to get user ID: ${error}`);
    }
  }

  /**
   * Get the device ID
   */
  async getDeviceId(): Promise<string> {
    if (!this.handle) {
      throw new Error('Crypto not initialized');
    }
    try {
      return await MatrixCryptoModule.getDeviceId(this.handle);
    } catch (error) {
      throw new Error(`Failed to get device ID: ${error}`);
    }
  }

  /**
   * Get devices for a user
   */
  async getUserDevices(userId: string): Promise<DeviceInfo[]> {
    if (!this.handle) {
      throw new Error('Crypto not initialized');
    }
    try {
      return await MatrixCryptoModule.getUserDevices(this.handle, userId);
    } catch (error) {
      throw new Error(`Failed to get user devices: ${error}`);
    }
  }

  /**
   * Add a device
   */
  async addDevice(device: DeviceInfo): Promise<void> {
    if (!this.handle) {
      throw new Error('Crypto not initialized');
    }
    try {
      await MatrixCryptoModule.addDevice(this.handle, device);
    } catch (error) {
      throw new Error(`Failed to add device: ${error}`);
    }
  }

  /**
   * Start device verification
   */
  async startVerification(
    otherUserId: string,
    otherDeviceId: string
  ): Promise<VerificationState> {
    if (!this.handle) {
      throw new Error('Crypto not initialized');
    }
    try {
      return await MatrixCryptoModule.startVerification(
        this.handle,
        otherUserId,
        otherDeviceId
      );
    } catch (error) {
      throw new Error(`Failed to start verification: ${error}`);
    }
  }

  /**
   * Get SAS emojis
   */
  async getSASEmojis(verificationId: string): Promise<EmojiSASPair[]> {
    if (!this.handle) {
      throw new Error('Crypto not initialized');
    }
    try {
      return await MatrixCryptoModule.getSASEmojis(this.handle, verificationId);
    } catch (error) {
      throw new Error(`Failed to get SAS emojis: ${error}`);
    }
  }

  /**
   * Confirm SAS
   */
  async confirmSAS(verificationId: string): Promise<void> {
    if (!this.handle) {
      throw new Error('Crypto not initialized');
    }
    try {
      await MatrixCryptoModule.confirmSAS(this.handle, verificationId);
    } catch (error) {
      throw new Error(`Failed to confirm SAS: ${error}`);
    }
  }

  /**
   * Complete verification
   */
  async completeVerification(verificationId: string): Promise<void> {
    if (!this.handle) {
      throw new Error('Crypto not initialized');
    }
    try {
      await MatrixCryptoModule.completeVerification(
        this.handle,
        verificationId
      );
    } catch (error) {
      throw new Error(`Failed to complete verification: ${error}`);
    }
  }

  /**
   * Cancel verification
   */
  async cancelVerification(verificationId: string): Promise<void> {
    if (!this.handle) {
      throw new Error('Crypto not initialized');
    }
    try {
      await MatrixCryptoModule.cancelVerification(
        this.handle,
        verificationId
      );
    } catch (error) {
      throw new Error(`Failed to cancel verification: ${error}`);
    }
  }

  /**
   * Get verification state
   */
  async getVerificationState(
    verificationId: string
  ): Promise<VerificationState> {
    if (!this.handle) {
      throw new Error('Crypto not initialized');
    }
    try {
      return await MatrixCryptoModule.getVerificationState(
        this.handle,
        verificationId
      );
    } catch (error) {
      throw new Error(`Failed to get verification state: ${error}`);
    }
  }

  /**
   * Enable room encryption
   */
  async enableRoomEncryption(
    roomId: string,
    algorithm: string
  ): Promise<void> {
    if (!this.handle) {
      throw new Error('Crypto not initialized');
    }
    try {
      await MatrixCryptoModule.enableRoomEncryption(
        this.handle,
        roomId,
        algorithm
      );
    } catch (error) {
      throw new Error(`Failed to enable room encryption: ${error}`);
    }
  }

  /**
   * Get room encryption state
   */
  async getRoomEncryptionState(
    roomId: string
  ): Promise<RoomEncryptionState> {
    if (!this.handle) {
      throw new Error('Crypto not initialized');
    }
    try {
      return await MatrixCryptoModule.getRoomEncryptionState(
        this.handle,
        roomId
      );
    } catch (error) {
      throw new Error(`Failed to get room encryption state: ${error}`);
    }
  }

  /**
   * Encrypt event
   */
  async encryptEvent(
    roomId: string,
    eventType: string,
    content: string
  ): Promise<string> {
    if (!this.handle) {
      throw new Error('Crypto not initialized');
    }
    try {
      return await MatrixCryptoModule.encryptEvent(
        this.handle,
        roomId,
        eventType,
        content
      );
    } catch (error) {
      throw new Error(`Failed to encrypt event: ${error}`);
    }
  }

  /**
   * Decrypt event
   */
  async decryptEvent(
    roomId: string,
    encryptedContent: string
  ): Promise<string> {
    if (!this.handle) {
      throw new Error('Crypto not initialized');
    }
    try {
      return await MatrixCryptoModule.decryptEvent(
        this.handle,
        roomId,
        encryptedContent
      );
    } catch (error) {
      throw new Error(`Failed to decrypt event: ${error}`);
    }
  }

  /**
   * Cleanup
   */
  async destroy(): Promise<void> {
    if (this.handle) {
      try {
        await MatrixCryptoModule.destroy(this.handle);
      } catch (error) {
        console.error(`Failed to destroy crypto: ${error}`);
      }
      this.handle = null;
    }
  }
}

export default MatrixCrypto.getInstance();
