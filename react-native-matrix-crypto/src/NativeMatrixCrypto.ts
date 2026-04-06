/**
 * Native module binding for RNMatrixCrypto.
 *
 * Uses NativeModules (Old Architecture bridge) instead of TurboModuleRegistry.
 * On Old Architecture the classic bridge routes NativeModules.X through
 * RCT_EXTERN_MODULE registrations in RNMatrixCrypto.m, which works correctly
 * for all method signatures including zero-arg promise methods.
 *
 * The TurboModuleRegistry path was needed only when New Architecture was
 * enabled (ObjCInteropTurboModule crashes on zero-real-arg promise methods).
 * With Old Architecture this is not an issue.
 */
import { NativeModules, Platform } from 'react-native';

const LINKING_ERROR =
  `The package '@k9o/react-native-matrix-crypto' doesn't seem to be linked. Make sure:\n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo Go\n';

const NativeRNMatrixCrypto = NativeModules.RNMatrixCrypto
  ? NativeModules.RNMatrixCrypto
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      },
    );

// ---------------------------------------------------------------------------
// Public typed interface (keeps callers decoupled from the raw native module)
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
  getIdentityKey(): Promise<string>;
  getOutboundSessionKey(roomId: string): Promise<string>;
  getOutboundSessionId(roomId: string): Promise<string>;
  addInboundSession(roomId: string, senderKey: string, sessionKeyBase64: string): Promise<{ success: boolean }>;
  importInboundSession(roomId: string, senderKey: string, exportedKeyBase64: string): Promise<{ success: boolean }>;
  createOlmSession(userId: string, deviceId: string, theirIdentityKey: string, theirOneTimeKey: string): Promise<{ success: boolean }>;
  olmEncrypt(userId: string, deviceId: string, plaintext: string): Promise<string>;
  olmDecrypt(senderIdentityKey: string, msgType: number, ciphertextB64: string): Promise<string>;
  getDeviceKeysJson(): Promise<string>;
  generateOneTimeKeysJson(count: number): Promise<string>;
  markKeysAsPublished(): Promise<{ success: boolean }>;
  exportState(): Promise<string>;
  importState(stateJson: string): Promise<boolean>;
  destroy(): Promise<{ success: boolean }>;
}

export const NativeMatrixCrypto: NativeMatrixCryptoInterface = NativeRNMatrixCrypto;

export default NativeMatrixCrypto;
