//
//  AppleIDCrypto.mm
//  Tetherless
//

#import "AppleIDCrypto.h"

#include <openssl/rsa.h>
#include <openssl/pem.h>
#include <openssl/x509.h>
#include <openssl/pkcs12.h>
#include <openssl/evp.h>
#include <openssl/bio.h>
#include <openssl/err.h>

@implementation AppleIDCrypto

+ (nullable NSString *)generateCSRWithCommonName:(NSString *)commonName
                                           email:(NSString *)email
                                   privateKeyPEM:(NSString * _Nullable * _Nonnull)outPrivateKeyPEM {
    EVP_PKEY *pkey = EVP_PKEY_new();
    RSA *rsa = RSA_new();
    BIGNUM *bn = BN_new();
    X509_REQ *req = NULL;
    NSString *csrResult = nil;

    @try {
        if (!pkey || !rsa || !bn) return nil;
        if (BN_set_word(bn, RSA_F4) != 1) return nil;
        if (RSA_generate_key_ex(rsa, 2048, bn, NULL) != 1) return nil;
        if (EVP_PKEY_assign_RSA(pkey, rsa) != 1) return nil;
        rsa = NULL; // owned by pkey now

        req = X509_REQ_new();
        if (!req) return nil;
        X509_REQ_set_version(req, 0);
        X509_REQ_set_pubkey(req, pkey);

        X509_NAME *name = X509_REQ_get_subject_name(req);
        X509_NAME_add_entry_by_txt(name, "CN", MBSTRING_UTF8,
                                   (const unsigned char *)[commonName UTF8String], -1, -1, 0);
        if (email.length) {
            X509_NAME_add_entry_by_txt(name, "emailAddress", MBSTRING_UTF8,
                                       (const unsigned char *)[email UTF8String], -1, -1, 0);
        }

        if (X509_REQ_sign(req, pkey, EVP_sha256()) == 0) return nil;

        // CSR → PEM
        BIO *csrBio = BIO_new(BIO_s_mem());
        PEM_write_bio_X509_REQ(csrBio, req);
        char *csrPtr = NULL;
        long csrLen = BIO_get_mem_data(csrBio, &csrPtr);
        csrResult = [[NSString alloc] initWithBytes:csrPtr length:csrLen encoding:NSUTF8StringEncoding];
        BIO_free(csrBio);

        // Private key → PEM
        BIO *keyBio = BIO_new(BIO_s_mem());
        PEM_write_bio_PrivateKey(keyBio, pkey, NULL, NULL, 0, NULL, NULL);
        char *keyPtr = NULL;
        long keyLen = BIO_get_mem_data(keyBio, &keyPtr);
        *outPrivateKeyPEM = [[NSString alloc] initWithBytes:keyPtr length:keyLen encoding:NSUTF8StringEncoding];
        BIO_free(keyBio);
    }
    @finally {
        if (req) X509_REQ_free(req);
        if (pkey) EVP_PKEY_free(pkey);
        if (rsa) RSA_free(rsa);
        if (bn) BN_free(bn);
    }
    return csrResult;
}

+ (nullable NSData *)pkcs12WithPrivateKeyPEM:(NSString *)privateKeyPEM
                              certificateDER:(NSData *)certificateDER
                                    password:(NSString *)password {
    EVP_PKEY *pkey = NULL;
    X509 *cert = NULL;
    PKCS12 *p12 = NULL;
    NSData *result = nil;

    @try {
        // Private key from PEM
        const char *keyBytes = [privateKeyPEM UTF8String];
        BIO *keyBio = BIO_new_mem_buf(keyBytes, (int)strlen(keyBytes));
        pkey = PEM_read_bio_PrivateKey(keyBio, NULL, NULL, NULL);
        BIO_free(keyBio);
        if (!pkey) return nil;

        // Certificate from DER
        const unsigned char *certPtr = (const unsigned char *)certificateDER.bytes;
        cert = d2i_X509(NULL, &certPtr, (long)certificateDER.length);
        if (!cert) return nil;

        p12 = PKCS12_create([password UTF8String], "Tetherless", pkey, cert,
                            NULL, 0, 0, 0, 0, 0);
        if (!p12) return nil;

        BIO *outBio = BIO_new(BIO_s_mem());
        i2d_PKCS12_bio(outBio, p12);
        char *outPtr = NULL;
        long outLen = BIO_get_mem_data(outBio, &outPtr);
        result = [NSData dataWithBytes:outPtr length:outLen];
        BIO_free(outBio);
    }
    @finally {
        if (p12) PKCS12_free(p12);
        if (cert) X509_free(cert);
        if (pkey) EVP_PKEY_free(pkey);
    }
    return result;
}

@end
