require "json"
package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "react-native-matrix-crypto"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = { :type => "Apache-2.0" }
  s.authors      = package["author"]
  s.platforms    = { :ios => "13.0" }
  s.requires_arc = true
  s.swift_version = "5.9"

  # Source files are included directly in the npm package at ios/
  # (not downloaded from GitHub Releases like the CocoaPods-only MatrixCryptoBridge pod)
  s.source = { :git => package["repository"]["url"], :tag => "#{s.version}" }

  # All Swift + ObjC source files needed to compile the React Native module
  s.source_files = [
    "ios/matrix_crypto.swift",
    "ios/matrix_cryptoFFI.h",
    "ios/MatrixCryptoBridge.swift",
    "ios/RNMatrixCryptoModule.swift",
    "ios/RNMatrixCrypto.m"
  ]

  s.public_header_files = "ios/matrix_cryptoFFI.h"
  s.module_map = "ios/matrix_cryptoFFI.modulemap"

  s.dependency "React-Core"

  s.pod_target_xcconfig = {
    "OTHER_LDFLAGS"  => "-lc++ -lresolv",
    "DEFINES_MODULE" => "YES"
  }
end
