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
  s.source = { :git => package["repository"]["url"], :tag => "#{s.version}" }

  # React Native bridge files (Swift + ObjC) that wrap the Rust crypto library
  s.source_files = [
    "ios/matrix_crypto.swift",
    "ios/matrix_cryptoFFI.h",
    "ios/MatrixCryptoBridge.swift",
    "ios/RNMatrixCryptoModule.swift",
    "ios/RNMatrixCrypto.m"
  ]

  s.public_header_files = "ios/matrix_cryptoFFI.h"

  # Dependencies
  s.dependency "React-Core"
  # MatrixCryptoBridge provides the pre-built Rust static library (libmatrix_crypto_ios.a)
  # and the UniFFI-generated Swift bindings.
  # Note: The Podfile can override this with a :git source if needed (e.g., during development)
  s.dependency "MatrixCryptoBridge", "~> #{s.version}"

  s.pod_target_xcconfig = {
    "OTHER_LDFLAGS"  => "-lc++ -lresolv",
    "DEFINES_MODULE" => "YES"
  }
end
