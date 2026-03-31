#import <React/RCTBridgeModule.h>

/**
 * Objective-C bridge file required to register the Swift RNMatrixCrypto module
 * with React Native's native module system.
 *
 * Without this file, NativeModules.RNMatrixCrypto will be undefined in JavaScript
 * because React Native's bridge only discovers modules registered via RCT_EXTERN_MODULE.
 *
 * The actual implementation lives in RNMatrixCryptoModule.swift.
 */
@interface RCT_EXTERN_MODULE(RNMatrixCrypto, NSObject)

// Initialization
RCT_EXTERN_METHOD(initialize:(NSString *)userId
                  deviceId:(NSString *)deviceId
                  pickleKey:(NSString *)pickleKey
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// Device Information
RCT_EXTERN_METHOD(getDeviceFingerprint:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getUserId:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getDeviceId:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// Device Management
RCT_EXTERN_METHOD(getUserDevices:(NSString *)userId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(addDevice:(NSDictionary *)device
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// Device Verification
RCT_EXTERN_METHOD(startVerification:(NSString *)otherUserId
                  otherDeviceId:(NSString *)otherDeviceId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getSASEmojis:(NSString *)verificationId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(confirmSAS:(NSString *)verificationId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(completeVerification:(NSString *)verificationId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(cancelVerification:(NSString *)verificationId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getVerificationState:(NSString *)verificationId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// Room Encryption
RCT_EXTERN_METHOD(enableRoomEncryption:(NSString *)roomId
                  algorithm:(NSString *)algorithm
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getRoomEncryptionState:(NSString *)roomId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// Event Encryption/Decryption
RCT_EXTERN_METHOD(encryptEvent:(NSString *)roomId
                  eventType:(NSString *)eventType
                  content:(NSString *)content
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(decryptEvent:(NSString *)roomId
                  encryptedContent:(NSString *)encryptedContent
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// Key Exchange (T1-1)
RCT_EXTERN_METHOD(getIdentityKey:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getOutboundSessionKey:(NSString *)roomId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getOutboundSessionId:(NSString *)roomId
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(addInboundSession:(NSString *)roomId
                  senderKey:(NSString *)senderKey
                  sessionKeyBase64:(NSString *)sessionKeyBase64
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(createOlmSession:(NSString *)userId
                  deviceId:(NSString *)deviceId
                  theirIdentityKey:(NSString *)theirIdentityKey
                  theirOneTimeKey:(NSString *)theirOneTimeKey
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(olmEncrypt:(NSString *)userId
                  deviceId:(NSString *)deviceId
                  plaintext:(NSString *)plaintext
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(olmDecrypt:(NSString *)senderIdentityKey
                  msgType:(nonnull NSNumber *)msgType
                  ciphertextB64:(NSString *)ciphertextB64
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// Cleanup
RCT_EXTERN_METHOD(destroy:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

// Key Upload (T1-1)
RCT_EXTERN_METHOD(getDeviceKeysJson:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(generateOneTimeKeysJson:(nonnull NSNumber *)count
                  resolve:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(markKeysAsPublished:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)

@end
