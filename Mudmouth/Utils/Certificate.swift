import Crypto
import Foundation
import SwiftASN1
import SwiftUI
import UniformTypeIdentifiers
import X509

extension Certificate {
    var orgnization: String {
        self.issuer.first(where: { name in
            name.description.starts(with: "O=")
        })?.description.replacingOccurrences(of: "O=", with: "") ?? ""
    }

    var commonName: String {
        self.subject.first(where: { name in
            name.description.starts(with: "CN=")
        })?.description.replacingOccurrences(of: "CN=", with: "") ?? ""
    }

    var derRepresentation: [UInt8] {
        var serializer = DER.Serializer()
        try! serializer.serialize(self)
        let derEncodedCertificate = serializer.serializedBytes
        return derEncodedCertificate
    }
}

func generateCertificate() -> (Certificate, P256.Signing.PrivateKey) {
    let privateKey = P256.Signing.PrivateKey()
    let certificatePrivateKey = Certificate.PrivateKey(privateKey)
    let now = Date()
    let publicKeyString = privateKey.publicKey.rawRepresentation.map { char in
        String(format: "%02hhX", char)
    }.joined()
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
    let certificate = try! Certificate(
        version: .v3, serialNumber: Certificate.SerialNumber(), publicKey: certificatePrivateKey.publicKey,
        notValidBefore: now, notValidAfter: now.addingTimeInterval(60 * 60 * 24 * 365 * 5), issuer: name, subject: name,
        signatureAlgorithm: .ecdsaWithSHA256, extensions: extensions, issuerPrivateKey: certificatePrivateKey)
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
    let privateKey = try! P256.Signing.PrivateKey(rawRepresentation: privateKeyData)
    let der = try! DER.parse(certificateData as! [UInt8])
    let certificate = try! Certificate(derEncoded: der)
    return (certificate, privateKey)
}

func generateSiteCertificate(url: String, caCertificate: Certificate?, caPrivateKey: P256.Signing.PrivateKey?) -> (
    Certificate?, P256.Signing.PrivateKey?
) {
    guard let caCertificate = caCertificate, let caPrivateKey = caPrivateKey else {
        return (nil, nil)
    }
    let privateKey = P256.Signing.PrivateKey()
    let certificatePrivateKey = Certificate.PrivateKey(privateKey)
    let now = Date()
    let publicKeyString = privateKey.publicKey.rawRepresentation.map { char in
        String(format: "%02hhX", char)
    }.joined()
    let subject = try! DistinguishedName {
        CommonName("Mudmouth Signed \(publicKeyString.prefix(8))")
        OrganizationName("Mudmouth")
    }
    let url = URL(string: url)!
    let extensions = try! Certificate.Extensions {
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
    let certificateCaPrivateKey = Certificate.PrivateKey(caPrivateKey)
    let certificate = try! Certificate(
        version: .v3, serialNumber: Certificate.SerialNumber(), publicKey: certificatePrivateKey.publicKey,
        notValidBefore: now.addingTimeInterval(-60), notValidAfter: now.addingTimeInterval(60 * 60 * 24 * 365),
        issuer: caCertificate.issuer, subject: subject, signatureAlgorithm: .ecdsaWithSHA256, extensions: extensions,
        issuerPrivateKey: certificateCaPrivateKey)
    return (certificate, privateKey)
}

enum PEMFileError: Error {
    case invalidPEMFile
}

// Referenced from https://www.hackingwithswift.com/quick-start/swiftui/how-to-export-files-using-fileexporter.
struct PEMFile: FileDocument {
    static var readableContentTypes = [UTType.x509Certificate]

    var certificate: Certificate
    var privateKey: P256.Signing.PrivateKey

    init(certificate: Certificate, privateKey: P256.Signing.PrivateKey) {
        self.certificate = certificate
        self.privateKey = privateKey
    }

    init(data: Data) throws {
        let text = String(decoding: data, as: UTF8.self)
        let certificateBegin = text.ranges(of: "-----BEGIN CERTIFICATE-----").first!.lowerBound
        let certificateEnd = text.ranges(of: "-----END CERTIFICATE-----").first!.upperBound
        certificate = try Certificate(pemEncoded: String(text[certificateBegin..<certificateEnd]))
        let privateKeyBegin = text.ranges(of: "-----BEGIN PRIVATE KEY-----").first!.lowerBound
        let privateKeyEnd = text.ranges(of: "-----END PRIVATE KEY-----").first!.upperBound
        privateKey = try P256.Signing.PrivateKey(pemRepresentation: String(text[privateKeyBegin..<privateKeyEnd]))
    }

    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            try self.init(data: data)
        } else {
            throw PEMFileError.invalidPEMFile
        }
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(readable.utf8)
        return FileWrapper(regularFileWithContents: data)
    }

    var readable: String {
        String(format: "%@\n\n%@", try! certificate.serializeAsPEM().pemString, privateKey.pemRepresentation)
    }
}

func importCertificate(url: URL) -> (Certificate?, P256.Signing.PrivateKey?) {
    do {
        if url.startAccessingSecurityScopedResource() {
            let data = try Data(contentsOf: url)
            let pemFile = try PEMFile(data: data)
            var serializer = DER.Serializer()
            try serializer.serialize(pemFile.certificate)
            let derEncodedCertificate = serializer.serializedBytes
            UserDefaults.standard.set(pemFile.privateKey.rawRepresentation, forKey: "privateKey")
            UserDefaults.standard.set(derEncodedCertificate, forKey: "certificate")
            return (pemFile.certificate, pemFile.privateKey)
        } else {
            return (nil, nil)
        }
    } catch {
        return (nil, nil)
    }
}

func verifyCertificate(certificate: Certificate?) -> Bool {
    guard let certificate = certificate else {
        return false
    }
    let der = certificate.derRepresentation
    let data = der.withUnsafeBufferPointer { bufferPointer in
        CFDataCreate(nil, bufferPointer.baseAddress, der.count)
    }!
    let secCertificate = SecCertificateCreateWithData(nil, data)!
    let policy = SecPolicyCreateBasicX509()
    var trust: SecTrust?
    let status = SecTrustCreateWithCertificates(secCertificate, policy, &trust)
    guard status == errSecSuccess, let trust = trust else {
        return false
    }
    var error: CFError?
    return SecTrustEvaluateWithError(trust, &error)
}

func verifyCertificateForTLS(certificate: Certificate?, url: String) -> Bool {
    guard let certificate = certificate else {
        return false
    }
    let der = certificate.derRepresentation
    let data = der.withUnsafeBufferPointer { bufferPointer in
        CFDataCreate(nil, bufferPointer.baseAddress, der.count)
    }!
    let secCertificate = SecCertificateCreateWithData(nil, data)!
    let policy = SecPolicyCreateSSL(true, url as NSString)
    var trust: SecTrust?
    let status = SecTrustCreateWithCertificates(secCertificate, policy, &trust)
    guard status == errSecSuccess, let trust = trust else {
        return false
    }
    var error: CFError?
    return SecTrustEvaluateWithError(trust, &error)
}
