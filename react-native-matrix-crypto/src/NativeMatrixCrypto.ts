import { NativeModules, Platform } from 'react-native';

const LINKING_ERROR =
  `The package 'react-native-matrix-crypto' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

const NativeMatrixCryptoModule = NativeModules.RNMatrixCrypto
  ? NativeModules.RNMatrixCrypto
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

/**
 * Native module interface for Matrix crypto
 * This is the low-level binding to the native iOS/Android modules
 */
export interface NativeMatrixCryptoInterface {
  // Initialization
  initialize(userId: string, deviceId: string, pickleKey: string): Promise<{ success: boolean }>;

  // Device Information
  getDeviceFingerprint(): Promise<string>;
  getUserId(): Promise<string>;
  getDeviceId(): Promise<string>;

  // Device Management
  getUserDevices(userId: string): Promise<Array<{
    deviceId: string;
    userId: string;
    displayName?: string;
    fingerprint: string;
    isVerified: boolean;
    isBlocked: boolean;
    algorithm: string;
  }>>;

  addDevice(device: {
    deviceId: string;
    userId: string;
    displayName?: string;
    fingerprint: string;
    isVerified: boolean;
    isBlocked: boolean;
    algorithm: string;
  }): Promise<{ success: boolean }>;

  // Device Verification
  startVerification(otherUserId: string, otherDeviceId: string): Promise<{
    verificationId: string;
    state: string;
    otherUserId: string;
    otherDeviceId: string;
    emojis: Array<{ emoji: string; name: string }>;
    decimals: number[];
  }>;

  getSASEmojis(verificationId: string): Promise<Array<{ emoji: string; name: string }>>;

  confirmSAS(verificationId: string): Promise<{ success: boolean }>;

  completeVerification(verificationId: string): Promise<{ success: boolean }>;

  cancelVerification(verificationId: string): Promise<{ success: boolean }>;

  getVerificationState(verificationId: string): Promise<{
    verificationId: string;
    state: string;
    otherUserId: string;
    otherDeviceId: string;
    emojis: Array<{ emoji: string; name: string }>;
    decimals: number[];
  }>;

  // Room Encryption
  enableRoomEncryption(roomId: string, algorithm: string): Promise<{ success: boolean }>;

  getRoomEncryptionState(roomId: string): Promise<{
    roomId: string;
    isEncrypted: boolean;
    algorithm?: string;
    trustedDevices: string[];
    untrustedDevices: string[];
  }>;

  // Event Encryption/Decryption
  encryptEvent(roomId: string, eventType: string, content: string): Promise<string>;

  decryptEvent(roomId: string, encryptedContent: string): Promise<string>;

  // Cleanup
  destroy(): Promise<{ success: boolean }>;
}

/**
 * Native module proxy that delegates to the platform-specific implementation
 */
export const NativeMatrixCrypto: NativeMatrixCryptoInterface = {
  initialize: (userId: string, deviceId: string, pickleKey: string) =>
    NativeMatrixCryptoModule.initialize(userId, deviceId, pickleKey),

  getDeviceFingerprint: () =>
    NativeMatrixCryptoModule.getDeviceFingerprint(),

  getUserId: () =>
    NativeMatrixCryptoModule.getUserId(),

  getDeviceId: () =>
    NativeMatrixCryptoModule.getDeviceId(),

  getUserDevices: (userId: string) =>
    NativeMatrixCryptoModule.getUserDevices(userId),

  addDevice: (device) =>
    NativeMatrixCryptoModule.addDevice(device),

  startVerification: (otherUserId: string, otherDeviceId: string) =>
    NativeMatrixCryptoModule.startVerification(otherUserId, otherDeviceId),

  getSASEmojis: (verificationId: string) =>
    NativeMatrixCryptoModule.getSASEmojis(verificationId),

  confirmSAS: (verificationId: string) =>
    NativeMatrixCryptoModule.confirmSAS(verificationId),

  completeVerification: (verificationId: string) =>
    NativeMatrixCryptoModule.completeVerification(verificationId),

  cancelVerification: (verificationId: string) =>
    NativeMatrixCryptoModule.cancelVerification(verificationId),

  getVerificationState: (verificationId: string) =>
    NativeMatrixCryptoModule.getVerificationState(verificationId),

  enableRoomEncryption: (roomId: string, algorithm: string) =>
    NativeMatrixCryptoModule.enableRoomEncryption(roomId, algorithm),

  getRoomEncryptionState: (roomId: string) =>
    NativeMatrixCryptoModule.getRoomEncryptionState(roomId),

  encryptEvent: (roomId: string, eventType: string, content: string) =>
    NativeMatrixCryptoModule.encryptEvent(roomId, eventType, content),

  decryptEvent: (roomId: string, encryptedContent: string) =>
    NativeMatrixCryptoModule.decryptEvent(roomId, encryptedContent),

  destroy: () =>
    NativeMatrixCryptoModule.destroy(),
};

export default NativeMatrixCrypto;
