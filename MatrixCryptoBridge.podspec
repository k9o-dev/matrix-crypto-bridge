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

  # Download pre-built binaries from GitHub Releases
  s.source       = {
    :http => "https://github.com/k9o-dev/matrix-crypto-bridge/releases/download/v#{s.version}/matrix-crypto-bridge-dist.tar.gz",
    :sha256 => "placeholder_sha256_will_be_updated_in_ci"
  }

  s.platform     = :ios, "11.0"
  s.requires_arc = true
  s.swift_version = "5.0"

  # Pre-built static library (universal binary for device + simulator)
  s.vendored_libraries = "ios/libmatrix_crypto_ios.a"

  # UniFFI-generated C header so Swift can call into the Rust library
  s.public_header_files = "ios/matrix_cryptoFFI.h"

  # Source files: the C header, the UniFFI module map, and the generated Swift bindings
  s.source_files = "ios/matrix_cryptoFFI.h", "ios/matrix_crypto.swift"

  # Module map that exposes the C FFI symbols as the `matrix_cryptoFFI` Swift module
  s.module_map = "ios/matrix_cryptoFFI.modulemap"

  # Linker flags needed to resolve Rust runtime symbols in the static library
  s.pod_target_xcconfig = {
    "OTHER_LDFLAGS" => "-lc++ -lresolv",
    "SWIFT_INCLUDE_PATHS" => "$(PODS_TARGET_SRCROOT)/ios",
    "DEFINES_MODULE" => "YES"
  }
end
