require "json"

package = JSON.parse(File.read(File.join(__dir__, "package.json")))

Pod::Spec.new do |s|
  s.name         = "react-native-matrix-crypto"
  s.version      = package["version"]
  s.summary      = package["description"]
  s.homepage     = package["homepage"]
  s.license      = package["license"]
  s.authors      = package["author"]
  s.platforms    = { :ios => "11.0" }
  s.source       = { :git => package["repository"]["url"], :tag => "#{s.version}" }
  
  # For local development, use path-based dependency
  # For published versions, CocoaPods will use the version from the registry
  # This allows `pod install` to work with the local MatrixCryptoBridge.podspec

  s.source_files = "ios/**/*.{h,m,mm,swift}"
  s.requires_arc = true

  s.dependency "React-Core"
  s.dependency "MatrixCryptoBridge", :path => "../MatrixCryptoBridge.podspec"

  s.pod_target_xcconfig = {
    "DEFINES_MODULE" => "YES",
    "SWIFT_VERSION" => "5.9"
  }
end
