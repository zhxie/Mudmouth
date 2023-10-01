import Crypto
import Foundation
import SwiftASN1
import X509

func generateCertificate() -> (Certificate, P256.Signing.PrivateKey) {
    let privateKey = P256.Signing.PrivateKey()
    let certificatePrivateKey = Certificate.PrivateKey(privateKey)
    let now = Date()
    let publicKeyString = privateKey.publicKey.rawRepresentation.map({ char in
        String(format: "%02hhX", char)
    }).joined()
    let name = try! DistinguishedName {
        CommonName("Mudmouth Generated \(publicKeyString.prefix(8))")
        OrganizationName("Mudmouth")
    }
    let extensions = try! Certificate.Extensions {
        Critical(
            BasicConstraints.isCertificateAuthority(maxPathLength: nil)
        )
        Critical(
            KeyUsage(digitalSignature: true, keyCertSign: true)
        )
    }
    let certificate = try! Certificate(version: .v3, serialNumber: Certificate.SerialNumber(), publicKey: certificatePrivateKey.publicKey, notValidBefore: now, notValidAfter: now.addingTimeInterval(60 * 60 * 24 * 365 * 5), issuer: name, subject: name, signatureAlgorithm: .ecdsaWithSHA256, extensions: extensions, issuerPrivateKey: certificatePrivateKey)
    var serializer = DER.Serializer()
    try! serializer.serialize(certificate)
    let derEncodedCertificate = serializer.serializedBytes
    UserDefaults.standard.set(privateKey.rawRepresentation, forKey: "privateKey")
    UserDefaults.standard.set(derEncodedCertificate, forKey: "certificate")
    return (certificate, privateKey)
}

func loadCertificate() -> (Certificate?, P256.Signing.PrivateKey?) {
    let privateKeyData = UserDefaults.standard.data(forKey: "privateKey")
    let certificateData = UserDefaults.standard.array(forKey: "certificate")
    guard let privateKeyData = privateKeyData else {
        return (nil, nil)
    }
    guard let certificateData = certificateData else {
        return (nil, nil)
    }
    do {
        let privateKey = try P256.Signing.PrivateKey(rawRepresentation: privateKeyData)
        let der = try DER.parse(certificateData as! [UInt8])
        let certificate = try Certificate(derEncoded: der)
        return (certificate, privateKey)
    } catch {
        fatalError("Failed to load certificate: \(error.localizedDescription)")
    }
}

func serializeCertificate(_ certificate: Certificate) -> [UInt8] {
    var serializer = DER.Serializer()
    do {
        try serializer.serialize(certificate)
        let derEncodedCertificate = serializer.serializedBytes
        return derEncodedCertificate
    } catch {
        fatalError("Failed to install certificate: \(error.localizedDescription)")
    }
}

func generateSiteCertificate(url: String, caCertificateData: [UInt8], caPrivateKeyData: Data) -> ([UInt8], Data) {
    let privateKey = P256.Signing.PrivateKey()
    let certificatePrivateKey = Certificate.PrivateKey(privateKey)
    let now = Date()
    let publicKeyString = privateKey.publicKey.rawRepresentation.map({ char in
        String(format: "%02hhX", char)
    }).joined()
    do {
        let caCertificate = try Certificate(derEncoded: caCertificateData)
        let subject = try DistinguishedName {
            CommonName("Mudmouth Signed \(publicKeyString.prefix(8))")
            OrganizationName("Mudmouth")
        }
        let url = URL(string: url)!
        let extensions = try Certificate.Extensions {
            Critical(
                BasicConstraints.notCertificateAuthority
            )
            Critical(
                KeyUsage(digitalSignature: true)
            )
            try! ExtendedKeyUsage([ExtendedKeyUsage.Usage.serverAuth, ExtendedKeyUsage.Usage.ocspSigning])
            SubjectKeyIdentifier(hash: certificatePrivateKey.publicKey)
            SubjectAlternativeNames([.dnsName(url.host!)])
        }
        let caPriavteKey = try P256.Signing.PrivateKey(rawRepresentation: caPrivateKeyData)
        let certificateCaPrivateKey = Certificate.PrivateKey(caPriavteKey)
        let certificate = try Certificate(version: .v3, serialNumber: Certificate.SerialNumber(), publicKey: certificatePrivateKey.publicKey, notValidBefore: now, notValidAfter: now.addingTimeInterval(60 * 60 * 24 * 365), issuer: caCertificate.issuer, subject: subject, signatureAlgorithm: .ecdsaWithSHA256, extensions: extensions, issuerPrivateKey: certificateCaPrivateKey)
        return (serializeCertificate(certificate), privateKey.derRepresentation)
    } catch {
        fatalError("Failed to generate site certificate: \(error.localizedDescription)")
    }
}
