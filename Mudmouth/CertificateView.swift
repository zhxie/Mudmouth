//
//  CertificateView.swift
//  Mudmouth
//
//  Created by Xie Zhihao on 2023/9/28.
//

import Crypto
import SwiftASN1
import SwiftUI
import X509

struct CertificateView: View {
    @State var certificate: Certificate
    @State var privateKey: P256.Signing.PrivateKey
    
    init() {
        let (certificate, privateKey) = loadCertificate()
        if certificate != nil && privateKey != nil {
            _certificate = State(initialValue: certificate!)
            _privateKey = State(initialValue: privateKey!)
        } else {
            let (certificate, privateKey) = generateCertificate()
            _certificate = State(initialValue: certificate)
            _privateKey = State(initialValue: privateKey)
        }
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("Basics") {
                    HStack {
                        Text("Organization")
                        Spacer()
                        Text(certificate.issuer.first(where: { name in
                            name.description.starts(with: "O=")
                        })?.description.replacingOccurrences(of: "O=", with: "") ?? "")
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Common Name")
                        Spacer()
                        Text(certificate.subject.first(where: { name in
                            name.description.starts(with: "CN=")
                        })?.description.replacingOccurrences(of: "CN=", with: "") ?? "")
                            .foregroundColor(.secondary)
                    }
                }
                Section("Validity Period") {
                    HStack {
                        Text("Not Valid Before")
                        Spacer()
                        Text(certificate.notValidBefore.formatted())
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Not Valid After")
                        Spacer()
                        Text(certificate.notValidAfter.formatted())
                            .foregroundColor(.secondary)
                    }
                }
                Section("Key Info") {
                    HStack {
                        Text("Algorithm")
                        Spacer()
                        Text("\(certificate.signature.description) Encryption")
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading) {
                        Text("Public Key Data")
                        Spacer()
                            .frame(height: 8)
                        Text(privateKey.publicKey.rawRepresentation.map({ char in
                            String(format: "%02hhX", char)
                        }).joined())
                            .font(.footnote)
                            .fontDesign(.monospaced)
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading) {
                        Text("Private Key Data")
                        Spacer()
                            .frame(height: 8)
                        Text(privateKey.rawRepresentation.map({ char in
                            String(format: "%02hhX", char)
                        }).joined())
                            .font(.footnote)
                            .fontDesign(.monospaced)
                            .foregroundColor(.secondary)
                    }
                }
                Section {
                    Button("Generate a New Certificate") {
                        (certificate, privateKey) = generateCertificate()
                    }
                    Button("Install Certificate") {
                        UIApplication.shared.open(URL(string: "http://127.0.0.1:16836")!)
                    }
                } footer: {
                    Text("You should install and trust the certificate manually in Settings > General > About > Certificate Trust Settings.")
                }
            }
            .navigationTitle("Root Certificate")
        }
    }
}

struct CertificateView_Previews: PreviewProvider {
    static var previews: some View {
        CertificateView()
    }
}
