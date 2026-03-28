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
  s.source       = { :git => "https://github.com/k9o-dev/matrix-crypto-bridge.git", :tag => "v#{s.version}" }
  
  s.platform     = :ios, "11.0"
  s.requires_arc = true
  
  # Pre-built static libraries
  # The build process creates universal binaries for both device and simulator
  s.vendored_libraries = "dist/ios/libmatrix_crypto_ios.a"
  
  # Public headers (if any)
  s.public_header_files = "matrix-crypto-ios/include/**/*.h"
  s.header_mappings_dir = "matrix-crypto-ios/include"
  
  # Module map for Swift interop
  s.module_map = "matrix-crypto-ios/MatrixCryptoBridge.modulemap"
  
  # Compiler flags for linking
  s.xcconfig = {
    "OTHER_LDFLAGS" => "-lmatrix_crypto_ios",
    "LIBRARY_SEARCH_PATHS" => "$(PODS_ROOT)/MatrixCryptoBridge/dist/ios",
    "HEADER_SEARCH_PATHS" => "$(PODS_ROOT)/MatrixCryptoBridge/matrix-crypto-ios/include"
  }
end
