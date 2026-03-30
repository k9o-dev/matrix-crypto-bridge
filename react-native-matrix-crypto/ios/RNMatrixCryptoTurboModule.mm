/**
 * RNMatrixCryptoTurboModule.mm
 *
 * Adds RCTTurboModule conformance to the RNMatrixCrypto Swift class so that
 * React Native's New Architecture routes method calls through ObjCTurboModule
 * (JSI-based, handles RCTPromiseResolveBlock correctly) instead of
 * ObjCInteropTurboModule (which crashes on promise-block arguments).
 *
 * How the routing works:
 *   RCTTurboModuleManager checks [module conformsToProtocol:@protocol(RCTTurboModule)]
 *   at module-lookup time. When YES, calls go through ObjCTurboModule::invokeObjCMethod
 *   with PromiseKind — promises are resolved via JSI, setInvocationArg is never
 *   called with a promise block type.
 *
 *   Without this file RNMatrixCrypto only conforms to NSObject + RCTBridgeModule
 *   (added by RCT_EXTERN_MODULE), so the runtime falls through to
 *   ObjCInteropTurboModule which crashes on any zero-real-arg promise method.
 *
 * Header location: React Native / Expo place the codegen-generated spec header
 * in different pod paths depending on the build system:
 *
 *   Expo managed / RN 0.73+:
 *     Pods/Headers/Public/ReactCodegen/RNMatrixCryptoSpec/RNMatrixCryptoSpec.h
 *
 *   React Native CLI bare workflow (older RN):
 *     Pods/Headers/Public/RNMatrixCryptoSpec/RNMatrixCryptoSpec.h
 *
 * Both are tried via __has_include.  If neither is present (e.g. old arch or
 * prebuild not yet run) the entire file compiles to nothing.
 */

#ifdef RCT_NEW_ARCH_ENABLED

#import <Foundation/Foundation.h>

// Resolve spec header — try Expo/ReactCodegen path first, then bare RN path.
#if __has_include(<ReactCodegen/RNMatrixCryptoSpec/RNMatrixCryptoSpec.h>)
  #import <ReactCodegen/RNMatrixCryptoSpec/RNMatrixCryptoSpec.h>
  #define RN_MATRIX_CRYPTO_SPEC_FOUND 1
#elif __has_include(<RNMatrixCryptoSpec/RNMatrixCryptoSpec.h>)
  #import <RNMatrixCryptoSpec/RNMatrixCryptoSpec.h>
  #define RN_MATRIX_CRYPTO_SPEC_FOUND 1
#endif

#ifdef RN_MATRIX_CRYPTO_SPEC_FOUND

using namespace facebook::react;

// Extend RNMatrixCrypto (defined in RNMatrixCryptoModule.swift via
// RCT_EXTERN_MODULE) with NativeMatrixCryptoSpec conformance.
// NativeMatrixCryptoSpec extends RCTTurboModule, so after this category is
// loaded, conformsToProtocol:@protocol(RCTTurboModule) returns YES and the
// module is routed through ObjCTurboModule.
@interface RNMatrixCrypto (TurboModule) <NativeMatrixCryptoSpec>
@end

@implementation RNMatrixCrypto (TurboModule)

/**
 * Returns NativeMatrixCryptoSpecJSI which carries the full methodMap_ generated
 * by codegen (one entry per JS-callable method, each with PromiseKind and the
 * exact ObjC selector to invoke).  ObjCTurboModule::invokeObjCMethod uses this
 * map to dispatch calls — promise blocks never pass through setInvocationArg.
 */
- (std::shared_ptr<TurboModule>)getTurboModule:(const ObjCTurboModule::InitParams &)params {
  return std::make_shared<NativeMatrixCryptoSpecJSI>(params);
}

@end

#endif  // RN_MATRIX_CRYPTO_SPEC_FOUND
#endif  // RCT_NEW_ARCH_ENABLED
