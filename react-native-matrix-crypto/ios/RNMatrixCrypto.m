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
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

// Device Information
RCT_EXTERN_METHOD(getDeviceFingerprint:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getUserId:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getDeviceId:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

// Device Management
RCT_EXTERN_METHOD(getUserDevices:(NSString *)userId
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(addDevice:(NSDictionary *)device
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

// Device Verification
RCT_EXTERN_METHOD(startVerification:(NSString *)otherUserId
                  otherDeviceId:(NSString *)otherDeviceId
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getSASEmojis:(NSString *)verificationId
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(confirmSAS:(NSString *)verificationId
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(completeVerification:(NSString *)verificationId
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(cancelVerification:(NSString *)verificationId
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getVerificationState:(NSString *)verificationId
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

// Room Encryption
RCT_EXTERN_METHOD(enableRoomEncryption:(NSString *)roomId
                  algorithm:(NSString *)algorithm
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(getRoomEncryptionState:(NSString *)roomId
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

// Event Encryption/Decryption
RCT_EXTERN_METHOD(encryptEvent:(NSString *)roomId
                  eventType:(NSString *)eventType
                  content:(NSString *)content
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

RCT_EXTERN_METHOD(decryptEvent:(NSString *)roomId
                  encryptedContent:(NSString *)encryptedContent
                  withResolver:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

// Cleanup
RCT_EXTERN_METHOD(destroy:(RCTPromiseResolveBlock)resolve
                  withRejecter:(RCTPromiseRejectBlock)reject)

@end
