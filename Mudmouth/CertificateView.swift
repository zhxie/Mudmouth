import Crypto
import SwiftASN1
import SwiftUI
import X509

struct CertificateView: View {
    @State var certificate: Certificate
    @State var privateKey: P256.Signing.PrivateKey
    @State var showRegenerateCertificateAlert: Bool = false
    
    init() {
        let (certificate, privateKey) = loadCertificate()
        _certificate = State(initialValue: certificate!)
        _privateKey = State(initialValue: privateKey!)
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
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Common Name")
                        Spacer()
                        Text(certificate.subject.first(where: { name in
                            name.description.starts(with: "CN=")
                        })?.description.replacingOccurrences(of: "CN=", with: "") ?? "")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
                Section("Validity Period") {
                    HStack {
                        Text("Not Valid Before")
                        Spacer()
                        Text(certificate.notValidBefore.formatted())
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Not Valid After")
                        Spacer()
                        Text(certificate.notValidAfter.formatted())
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
                Section("Key Info") {
                    HStack {
                        Text("Algorithm")
                        Spacer()
                        Text("\(certificate.signature.description) Encryption")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    VStack(alignment: .leading) {
                        Text("Public Key Data")
                        Spacer()
                            .frame(height: 8)
                        Text(privateKey.publicKey.rawRepresentation.hex())
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                    }
                    VStack(alignment: .leading) {
                        Text("Private Key Data")
                        Spacer()
                            .frame(height: 8)
                        Text(privateKey.rawRepresentation.hex())
                        .font(.system(.footnote, design: .monospaced))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                    }
                }
                Section {
                    Button("Generate a New Certificate", action: requestGeneratingCertificate)
                    .alert(isPresented: $showRegenerateCertificateAlert) {
                        Alert(title: Text("Your current certificate will become invalid in Mudmouth, do you want to generate a new certificate?"), primaryButton: .destructive(Text("OK"), action: ContinueGeneratingCertificate), secondaryButton: .cancel())
                    }
                    Button("Install Certificate", action: installCertificate)
                } footer: {
                    Text("You should trust the certificate manually after installation in Settings > General > About > Certificate Trust Settings.")
                }
            }
            .navigationTitle("Root Certificate")
        }
    }
    
    private func requestGeneratingCertificate() {
        showRegenerateCertificateAlert.toggle()
    }
    
    private func ContinueGeneratingCertificate() {
        (certificate, privateKey) = generateCertificate()
    }
    
    private func installCertificate() {
        UIApplication.shared.open(URL(string: "http://127.0.0.1:16836")!)
    }
}

struct CertificateView_Previews: PreviewProvider {
    static var previews: some View {
        CertificateView()
    }
}
