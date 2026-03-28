import Foundation
import React

/**
 * React Native module for Matrix crypto (iOS)
 * This is the entry point for the React Native module on iOS
 */
@objc(RNMatrixCryptoModule)
class RNMatrixCryptoModule: NSObject {
  
  @objc
  static func moduleName() -> String! {
    return "RNMatrixCrypto"
  }

  @objc
  static func requiresMainQueueSetup() -> Bool {
    return false
  }
}
