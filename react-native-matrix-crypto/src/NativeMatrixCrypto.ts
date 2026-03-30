/**
 * TurboModule spec for RNMatrixCrypto.
 *
 * WHY TurboModuleRegistry AND NOT NativeModules:
 *
 * React Native New Architecture (enabled in Fortress via newArchEnabled: true)
 * routes NativeModules.X calls through ObjCInteropTurboModule. That interop
 * layer explicitly throws when it encounters RCTPromiseResolveBlock as a
 * parameter type (see ObjCInteropTurboModule::setInvocationArg). Methods that
 * have real arguments before the promise blocks (e.g. initialize) happen to
 * succeed because the promise blocks are appended last, but zero-arg methods
 * like getDeviceFingerprint fail immediately — promise block is arg 0.
 *
 * Using TurboModuleRegistry.getEnforcing + codegenConfig causes Expo prebuild
 * to generate a proper spec header. React Native then routes calls through
 * ObjCTurboModule which handles promises via JSI and never calls
 * setInvocationArg with a promise block type.
 */
import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

// ---------------------------------------------------------------------------
// TurboModule spec — must match the ObjC/Swift declarations in RNMatrixCrypto.m
// and RNMatrixCryptoModule.swift exactly.
// ---------------------------------------------------------------------------
export interface Spec extends TurboModule {
  // Initialization
  initialize(userId: string, deviceId: string, pickleKey: string): Promise<Object>;

  // Device Information
  getDeviceFingerprint(): Promise<string>;
  getUserId(): Promise<string>;
  getDeviceId(): Promise<string>;

  // Device Management
  getUserDevices(userId: string): Promise<Object>;
  addDevice(device: Object): Promise<Object>;

  // Device Verification
  startVerification(otherUserId: string, otherDeviceId: string): Promise<Object>;
  getSASEmojis(verificationId: string): Promise<Object>;
  confirmSAS(verificationId: string): Promise<Object>;
  completeVerification(verificationId: string): Promise<Object>;
  cancelVerification(verificationId: string): Promise<Object>;
  getVerificationState(verificationId: string): Promise<Object>;

  // Room Encryption
  enableRoomEncryption(roomId: string, algorithm: string): Promise<Object>;
  getRoomEncryptionState(roomId: string): Promise<Object>;

  // Event Encryption/Decryption
  encryptEvent(roomId: string, eventType: string, content: string): Promise<string>;
  decryptEvent(roomId: string, encryptedContent: string): Promise<string>;

  // Cleanup
  destroy(): Promise<Object>;
}

// getEnforcing throws a descriptive error if the native module is not found,
// which is far more useful than a silent undefined at runtime.
const NativeRNMatrixCrypto = TurboModuleRegistry.getEnforcing<Spec>('RNMatrixCrypto');

// ---------------------------------------------------------------------------
// Public typed interface (keeps callers decoupled from the raw TurboModule spec)
// ---------------------------------------------------------------------------
export interface NativeMatrixCryptoInterface {
  initialize(userId: string, deviceId: string, pickleKey: string): Promise<{ success: boolean }>;
  getDeviceFingerprint(): Promise<string>;
  getUserId(): Promise<string>;
  getDeviceId(): Promise<string>;
  getUserDevices(userId: string): Promise<Array<{
    deviceId: string; userId: string; displayName?: string;
    fingerprint: string; isVerified: boolean; isBlocked: boolean; algorithm: string;
  }>>;
  addDevice(device: {
    deviceId: string; userId: string; displayName?: string;
    fingerprint: string; isVerified: boolean; isBlocked: boolean; algorithm: string;
  }): Promise<{ success: boolean }>;
  startVerification(otherUserId: string, otherDeviceId: string): Promise<{
    verificationId: string; state: string; otherUserId: string; otherDeviceId: string;
    emojis: Array<{ emoji: string; name: string }>; decimals: number[];
  }>;
  getSASEmojis(verificationId: string): Promise<Array<{ emoji: string; name: string }>>;
  confirmSAS(verificationId: string): Promise<{ success: boolean }>;
  completeVerification(verificationId: string): Promise<{ success: boolean }>;
  cancelVerification(verificationId: string): Promise<{ success: boolean }>;
  getVerificationState(verificationId: string): Promise<{
    verificationId: string; state: string; otherUserId: string; otherDeviceId: string;
    emojis: Array<{ emoji: string; name: string }>; decimals: number[];
  }>;
  enableRoomEncryption(roomId: string, algorithm: string): Promise<{ success: boolean }>;
  getRoomEncryptionState(roomId: string): Promise<{
    roomId: string; isEncrypted: boolean; algorithm?: string;
    trustedDevices: string[]; untrustedDevices: string[];
  }>;
  encryptEvent(roomId: string, eventType: string, content: string): Promise<string>;
  decryptEvent(roomId: string, encryptedContent: string): Promise<string>;
  destroy(): Promise<{ success: boolean }>;
}

export const NativeMatrixCrypto: NativeMatrixCryptoInterface = {
  initialize: (u, d, p) => NativeRNMatrixCrypto.initialize(u, d, p) as any,
  getDeviceFingerprint: () => NativeRNMatrixCrypto.getDeviceFingerprint(),
  getUserId: () => NativeRNMatrixCrypto.getUserId(),
  getDeviceId: () => NativeRNMatrixCrypto.getDeviceId(),
  getUserDevices: (userId) => NativeRNMatrixCrypto.getUserDevices(userId) as any,
  addDevice: (device) => NativeRNMatrixCrypto.addDevice(device) as any,
  startVerification: (u, d) => NativeRNMatrixCrypto.startVerification(u, d) as any,
  getSASEmojis: (id) => NativeRNMatrixCrypto.getSASEmojis(id) as any,
  confirmSAS: (id) => NativeRNMatrixCrypto.confirmSAS(id) as any,
  completeVerification: (id) => NativeRNMatrixCrypto.completeVerification(id) as any,
  cancelVerification: (id) => NativeRNMatrixCrypto.cancelVerification(id) as any,
  getVerificationState: (id) => NativeRNMatrixCrypto.getVerificationState(id) as any,
  enableRoomEncryption: (r, a) => NativeRNMatrixCrypto.enableRoomEncryption(r, a) as any,
  getRoomEncryptionState: (r) => NativeRNMatrixCrypto.getRoomEncryptionState(r) as any,
  encryptEvent: (r, t, c) => NativeRNMatrixCrypto.encryptEvent(r, t, c),
  decryptEvent: (r, c) => NativeRNMatrixCrypto.decryptEvent(r, c),
  destroy: () => NativeRNMatrixCrypto.destroy() as any,
};

export default NativeMatrixCrypto;
