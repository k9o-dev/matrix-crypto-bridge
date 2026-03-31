/**
 * @k9o/react-native-matrix-crypto — public API
 *
 * The old MatrixCrypto class was a handle-based wrapper around NativeModules
 * that expected native initialize() to return an opaque handle, then required
 * passing that handle to every subsequent call. That design was never
 * implemented in the native module — the native module has always been a
 * singleton that stores state internally.
 *
 * The correct API lives in NativeMatrixCrypto.ts. It uses
 * TurboModuleRegistry.getEnforcing and exposes zero-arg / arg-matched methods
 * that exactly match the native Swift implementation.
 *
 * This file re-exports NativeMatrixCrypto so that:
 *   import MatrixCrypto from '@k9o/react-native-matrix-crypto'   → NativeMatrixCrypto
 *   import { NativeMatrixCrypto } from '...'                      → NativeMatrixCrypto
 *   import { MatrixCrypto } from '...'                            → NativeMatrixCrypto (alias)
 */

export type {
  Spec,
  NativeMatrixCryptoInterface,
} from './NativeMatrixCrypto';

export { NativeMatrixCrypto } from './NativeMatrixCrypto';
export { NativeMatrixCrypto as MatrixCrypto } from './NativeMatrixCrypto';
export { NativeMatrixCrypto as default } from './NativeMatrixCrypto';

// ---------------------------------------------------------------------------
// Shared domain types — kept here so CryptoAPI.ts and other consumers can
// import them from the package root without a deep path.
// ---------------------------------------------------------------------------

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
