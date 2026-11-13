//
//  AppleIDCrypto.h
//  Tetherless
//
//  OpenSSL-backed CSR + PKCS#12 helpers for the free Apple ID signing path.
//  Reuses the same OpenSSL that zsign links.
//

#ifndef AppleIDCrypto_h
#define AppleIDCrypto_h

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AppleIDCrypto : NSObject

/// Generates a fresh RSA-2048 private key (PEM) and a PKCS#10 CSR (PEM) for the
/// given common name / email. Returns nil on failure.
/// On success, `outPrivateKeyPEM` receives the private key PEM.
+ (nullable NSString *)generateCSRWithCommonName:(NSString *)commonName
                                           email:(NSString *)email
                                   privateKeyPEM:(NSString * _Nullable * _Nonnull)outPrivateKeyPEM;

/// Assembles a PKCS#12 (.p12) blob from a private key PEM and the DER-encoded
/// certificate Apple issued, protected with `password`. Returns nil on failure.
+ (nullable NSData *)pkcs12WithPrivateKeyPEM:(NSString *)privateKeyPEM
                              certificateDER:(NSData *)certificateDER
                                    password:(NSString *)password;

@end

NS_ASSUME_NONNULL_END

#endif /* AppleIDCrypto_h */
