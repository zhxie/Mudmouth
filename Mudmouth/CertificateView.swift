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
                Section("certificate") {
                    HStack {
                        Text(LocalizedStringKey("organization"))
                        Spacer()
                        Text(certificate.orgnization)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text(LocalizedStringKey("common_name"))
                        Spacer()
                        Text(certificate.commonName)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text(LocalizedStringKey("not_valid_before"))
                        Spacer()
                        Text(certificate.notValidBefore.formatted())
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    HStack {
                        Text(LocalizedStringKey("not_valid_after"))
                        Spacer()
                        Text(certificate.notValidAfter.formatted())
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                }
                Section("key_info") {
                    HStack {
                        Text(LocalizedStringKey("algorithm"))
                        Spacer()
                        Text(certificate.signature.description)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    VStack(alignment: .leading) {
                        Text(LocalizedStringKey("public_key_data"))
                        Spacer()
                            .frame(height: 8)
                        Text(privateKey.publicKey.rawRepresentation.hex())
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                    VStack(alignment: .leading) {
                        Text(LocalizedStringKey("private_key_data"))
                        Spacer()
                            .frame(height: 8)
                        Text(privateKey.rawRepresentation.hex())
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
                Section {
                    Button("generate_a_new_certificate", action: regenerateCertificate)
                        .alert(isPresented: $showRegenerateCertificateAlert) {
                            Alert(title: Text(LocalizedStringKey("generate_a_new_certificate_alert")), primaryButton: .destructive(Text("OK"), action: continueRegeneratingCertificate), secondaryButton: .cancel())
                        }
                    Button("import_certificate", action: importCertificate)
                        .alert(isPresented: $showImportCertificateAlert) {
                            Alert(title: Text(LocalizedStringKey("import_certificate_alert")), primaryButton: .destructive(Text("OK"), action: continueImportingCertificate), secondaryButton: .cancel())
                        }
                        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.x509Certificate]) { result in
                            switch result {
                            case .success(let url):
                                let (certificate, privateKey) = Mudmouth.importCertificate(url: url)
                                if let certificate = certificate, let privateKey = privateKey {
                                    self.certificate = certificate
                                    self.privateKey = privateKey
                                } else {
                                    AlertKitAPI.present(title: "invalid_certificate".localizedString, icon: .error, style: .iOS17AppleMusic, haptic: .error)
                                }
                                break
                            case .failure:
                                AlertKitAPI.present(title: "failed_to_import".localizedString, icon: .error, style: .iOS17AppleMusic, haptic: .error)
                            }
                        }
                    Button("export_certificate", action: exportCertificate)
                        .fileExporter(isPresented: $showExporter, document: PEMFile(certificate: certificate, privateKey: privateKey), contentType: .x509Certificate, defaultFilename: certificate.commonName) { _ in }
                }
                Section {
                    Button("install_certificate", action: installCertificate)
                } footer: {
                    Text(LocalizedStringKey(isCertificateInstalled ? "certificate_installed" : "certificate_not_installed"))
                }
                Section {
                    Button("trust_certificate", action: trustCertificate)
                } footer: {
                    Text(isCertificateTrusted ? "certificate_trusted" : "certificate_not_trusted")
                }
            }
            .navigationTitle("root_certificate")
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
