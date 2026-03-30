require "json"

# Read version from react-native-matrix-crypto package.json to keep both podspecs in sync
package = JSON.parse(File.read(File.join(__dir__, "react-native-matrix-crypto/package.json")))

Pod::Spec.new do |s|
  s.name         = "MatrixCryptoBridge"
  s.version      = package["version"]
  s.summary      = "Native Rust cryptography bridge for Matrix End-to-End Encryption"
  s.description  = <<-DESC
    MatrixCryptoBridge provides high-performance Rust-based cryptography for Matrix clients
    on iOS. It includes pre-built static libraries for device and simulator architectures.

    Features:
    - OlmMachine for cryptographic operations
    - Device verification and key management
    - Megolm session handling for group encryption
    - 10x faster than WebAssembly implementations
  DESC

  s.homepage     = "https://github.com/k9o-dev/matrix-crypto-bridge"
  s.license      = { :type => "Apache-2.0", :file => "LICENSE" }
  s.author       = { "k9o" => "support@pmglobaltechnology.com" }

  # Download pre-built binaries from GitHub Releases.
  # The archive extracts to:
  #   ios/libmatrix_crypto_ios.a               <- universal static library
  #   ios/bindings/matrix_crypto.swift         <- UniFFI-generated Swift bindings
  #   ios/bindings/matrix_cryptoFFI.h          <- UniFFI-generated C header
  #   ios/bindings/matrix_cryptoFFI.modulemap  <- module map
  #   ios/bridge/MatrixCryptoBridge.swift      <- Swift singleton wrapper
  #   ios/bridge/RNMatrixCryptoModule.swift    <- React Native module implementation
  #   ios/bridge/RNMatrixCrypto.m              <- ObjC RCT_EXTERN_MODULE registration
  #   LICENSE
  s.source       = {
    :http => "https://github.com/k9o-dev/matrix-crypto-bridge/releases/download/v#{s.version}/matrix-crypto-bridge-dist.tar.gz",
    :sha256 => "278935dec9708a7c7f92438f9f5fa0606d688cc609b018c6501bcb2b22f9e350"
  }

  s.platform     = :ios, "13.0"
  s.requires_arc = true
  s.swift_version = "5.9"

  # Pre-built universal static library
  s.vendored_libraries = "ios/libmatrix_crypto_ios.a"

  # UniFFI-generated Swift bindings + React Native bridge files
  s.source_files = [
    "ios/bindings/matrix_crypto.swift",
    "ios/bindings/matrix_cryptoFFI.h",
    "ios/bridge/MatrixCryptoBridge.swift",
    "ios/bridge/RNMatrixCryptoModule.swift",
    "ios/bridge/RNMatrixCrypto.m"
  ]

  # C header for the Rust FFI symbols
  s.public_header_files = "ios/bindings/matrix_cryptoFFI.h"

  # Module map that exposes the C FFI symbols as the `matrix_cryptoFFI` Swift module
  s.module_map = "ios/bindings/matrix_cryptoFFI.modulemap"

  s.dependency "React-Core"

  # Linker flags needed to resolve Rust runtime symbols in the static library
  s.pod_target_xcconfig = {
    "OTHER_LDFLAGS"       => "-lc++ -lresolv",
    "SWIFT_INCLUDE_PATHS" => "$(PODS_TARGET_SRCROOT)/ios/bindings",
    "DEFINES_MODULE"      => "YES"
  }
end
