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

  # npm package is the source of truth — all files ship inside the package itself.
  s.source = { :git => package["repository"]["url"], :tag => "#{s.version}" }

  # Pre-built universal Rust static library (device arm64 + simulator x86_64/arm64).
  # Compiled by CI and bundled directly in the npm package so no separate CocoaPods
  # pod is required. This makes the package fully self-contained.
  s.vendored_libraries = "ios/libmatrix_crypto_ios.a"

  # UniFFI-generated Swift bindings + React Native bridge files.
  # RNMatrixCryptoTurboModule.mm adds RCTTurboModule conformance (New Architecture).
  s.source_files = [
    "ios/matrix_crypto.swift",
    "ios/matrix_cryptoFFI.h",
    "ios/MatrixCryptoBridge.swift",
    "ios/RNMatrixCryptoModule.swift",
    "ios/RNMatrixCrypto.m",
    "ios/RNMatrixCryptoTurboModule.mm"
  ]

  s.public_header_files = "ios/matrix_cryptoFFI.h"

  # React-Core is always needed.
  # React-NativeModulesApple provides <ReactCommon/RCTTurboModule.h>, which is
  # a transitive dependency of the codegen-generated RNMatrixCryptoSpec.h on
  # New Architecture builds. Without it the pod fails to compile with:
  #   'ReactCommon/RCTTurboModule.h' file not found
  s.dependency "React-Core"
  s.dependency "React-NativeModulesApple"

  s.pod_target_xcconfig = {
    "OTHER_LDFLAGS"  => "-lc++ -lresolv",
    "DEFINES_MODULE" => "YES"
  }
end
