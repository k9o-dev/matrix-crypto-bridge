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

  # Download the pre-built binary archive from GitHub Releases.
  # The archive contains:
  #   ios/libmatrix_crypto_ios.a            <- universal static library (device + sim)
  #   ios/bindings/matrix_crypto.swift      <- UniFFI-generated Swift bindings
  #   ios/bindings/matrix_cryptoFFI.h       <- UniFFI-generated C header
  #   ios/bindings/matrix_cryptoFFI.modulemap
  #   ios/bridge/MatrixCryptoBridge.swift   <- Swift singleton wrapper
  #   ios/bridge/RNMatrixCryptoModule.swift <- React Native module implementation
  #   ios/bridge/RNMatrixCrypto.m           <- Objective-C RCT_EXTERN_MODULE registration
  s.source = {
    :http => "https://github.com/k9o-dev/matrix-crypto-bridge/releases/download/v#{s.version}/matrix-crypto-bridge-dist.tar.gz",
    :sha256 => "cfec051bb2254ffb028cdf658d4639a25256733d12362719749c73b00dc2beec"
  }

  # Pre-built universal static library (Rust)
  s.vendored_libraries = "ios/libmatrix_crypto_ios.a"

  # All Swift + ObjC source files needed to compile the React Native module
  s.source_files = [
    "ios/bindings/matrix_crypto.swift",
    "ios/bindings/matrix_cryptoFFI.h",
    "ios/bridge/MatrixCryptoBridge.swift",
    "ios/bridge/RNMatrixCryptoModule.swift",
    "ios/bridge/RNMatrixCrypto.m"
  ]

  s.public_header_files = "ios/bindings/matrix_cryptoFFI.h"
  s.module_map = "ios/bindings/matrix_cryptoFFI.modulemap"

  s.dependency "React-Core"

  s.pod_target_xcconfig = {
    "OTHER_LDFLAGS"        => "-lc++ -lresolv",
    "SWIFT_INCLUDE_PATHS"  => "$(PODS_TARGET_SRCROOT)/ios/bindings",
    "DEFINES_MODULE"       => "YES"
  }
end
