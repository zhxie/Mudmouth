import AlertKit
import Crypto
import SwiftASN1
import SwiftUI
import X509

struct CertificateView: View {
    @State var certificate: Certificate
    @State var privateKey: P256.Signing.PrivateKey

    @State var showRegenerateCertificateAlert = false
    @State var showImportCertificateAlert = false
    @State var showImporter = false
    @State var showExporter = false

    init() {
        let (certificate, privateKey) = loadCertificate()
        _certificate = State(initialValue: certificate!)
        _privateKey = State(initialValue: privateKey!)
    }
    init(certificate: Certificate, privateKey: P256.Signing.PrivateKey) {
        _certificate = State(initialValue: certificate)
        _privateKey = State(initialValue: privateKey)
    }

    var body: some View {
        NavigationView {
            List {
                Section("Certificate") {
                    HStack {
                        Text("Organization")
                        Spacer()
                        Text(certificate.orgnization)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text("Common Name")
                        Spacer()
                        Text(certificate.commonName)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
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
                    Button("Generate a New Certificate", action: regenerateCertificate)
                        .alert(isPresented: $showRegenerateCertificateAlert) {
                            Alert(title: Text("Your current certificate will become invalid in Mudmouth, do you want to generate a new certificate?"), primaryButton: .destructive(Text("OK"), action: continueRegeneratingCertificate), secondaryButton: .cancel())
                        }
                    Button("Import Certificate", action: importCertificate)
                        .alert(isPresented: $showImportCertificateAlert) {
                            Alert(title: Text("Your current certificate will become invalid in Mudmouth, do you want to import certificate?"), primaryButton: .destructive(Text("OK"), action: continueImportingCertificate), secondaryButton: .cancel())
                        }
                        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.x509Certificate]) { result in
                            switch result {
                            case .success(let url):
                                let (certificate, privateKey) = Mudmouth.importCertificate(url: url)
                                if let certificate = certificate, let privateKey = privateKey {
                                    self.certificate = certificate
                                    self.privateKey = privateKey
                                } else {
                                    AlertKitAPI.present(title: "Invalid Certificate", icon: .error, style: .iOS17AppleMusic, haptic: .error)
                                }
                                break
                            case .failure:
                                AlertKitAPI.present(title: "Failed to Import", icon: .error, style: .iOS17AppleMusic, haptic: .error)
                            }
                        }
                    Button("Export Certificate", action: exportCertificate)
                        .fileExporter(isPresented: $showExporter, document: PEMFile(certificate: certificate, privateKey: privateKey), contentType: .x509Certificate, defaultFilename: certificate.commonName) { _ in }
                }
                Section {
                    Button("Install Certificate", action: installCertificate)
                } footer: {
                    Text(isCertificateInstalled ? "You have installed the certificate." : "You should install the certificate manually after downloading in Settings > General > VPN & Device Management > Downloaded Profile.")
                }
                Section {
                    Button("Trust Certificate", action: trustCertificate)
                } footer: {
                    Text(isCertificateTrusted ? "You have trusted the certificate." : "You should trust the certificate manually after installation in Settings > General > About > Certificate Trust Settings > Enable Full Trust For Root Certificates.")
                }
            }
            .navigationTitle("Root Certificate")
        }
    }

    var isCertificateInstalled: Bool {
        verifyCertificate(certificate: certificate)
    }
    var isCertificateTrusted: Bool {
        let (certificate, _) = generateSiteCertificate(url: "https://mudmouth.local", caCertificate: certificate, caPrivateKey: privateKey)
        return verifyCertificateForTLS(certificate: certificate, url: "mudmouth.local")
    }

    private func regenerateCertificate() {
        showRegenerateCertificateAlert.toggle()
    }
    private func continueRegeneratingCertificate() {
        (certificate, privateKey) = generateCertificate()
    }

    private func importCertificate() {
        showImportCertificateAlert.toggle()
    }
    private func continueImportingCertificate() {
        showImporter.toggle()
    }

    private func exportCertificate() {
        showExporter.toggle()
    }

    private func installCertificate() {
        UIApplication.shared.open(URL(string: "http://127.0.0.1:\(CertificateServerPort)")!)
    }

    private func trustCertificate() {
        UIApplication.shared.open(URL(string: "App-prefs:General&path=About/CERT_TRUST_SETTINGS")!)
    }
}

struct CertificateView_Previews: PreviewProvider {
    static var previews: some View {
        let (certificate, privateKey) = generateCertificate()
        CertificateView(certificate: certificate, privateKey: privateKey)
    }
}
