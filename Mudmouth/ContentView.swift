import AlertKit
import CoreData
import Crypto
import NetworkExtension
import OSLog
import SwiftUI
import X509

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Profile.name, ascending: true)], animation: .default)
    private var profiles: FetchedResults<Profile>
    @State private var selectedProfile: Profile?
    @State private var profileOperation: DataOperation<Profile>?

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \Record.date, ascending: false)], animation: .default)
    private var records: FetchedResults<Record>
    @State private var selectedRecord: Record?

    @State private var showCertificate = false

    @State private var manager: NETunnelProviderManager?
    @State private var vpnObserver: AnyObject?
    @State private var isEnabled: Bool = false
    @State private var status: NEVPNStatus = .invalid

    @State private var showVPNAlert = false
    @State private var showNotificationAlert = false
    @State private var showRootCertificateAlert = false

    @State private var notificationObserver: AnyObject?
    @State private var requestHeaders = ""
    @State private var responseHeaders: String?

    init() {
        let (certificate, privateKey) = loadCertificate()
        if certificate == nil || privateKey == nil {
            let _ = generateCertificate()
        }
        // HACK: Stop running certificate server in previews to prevent crash.
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
            runCertificateServer()
        }
    }

    var body: some View {
        NavigationView {
            List {
                Section("profile") {
                    ForEach(profiles, id: \.self) { profile in
                        Button {
                            withAnimation {
                                selectedProfile = profile
                            }
                        } label: {
                            HStack {
                                Text(profile.name!)
                                    .foregroundColor(Color.primary)
                                Spacer()
                                if selectedProfile == profile {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Color.accentColor)
                                }
                            }
                        }
                        .swipeActions(allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                deleteProfile(profile)
                            } label: {
                                Label("delete", systemImage: "trash")
                            }
                            Button {
                                updateProfile(profile)
                            } label: {
                                Label("edit", systemImage: "square.and.pencil")
                            }
                            .tint(Color(UIColor.systemOrange))
                        }
                        .contextMenu {
                            Button {
                                updateProfile(profile)
                            } label: {
                                Label("edit", systemImage: "square.and.pencil")
                            }
                            Button(role: .destructive) {
                                deleteProfile(profile)
                            } label: {
                                Label("delete", systemImage: "trash")
                            }
                        }
                    }

                    Button("new_profile", action: createProfile)
                }
                .animation(.none, value: selectedProfile)
                Section {
                    if isHTTPS {
                        Button("configure_root_certificate", action: toggleCertificate)
                            .sheet(isPresented: $showCertificate) {
                                CertificateView()
                            }
                    }
                    if manager == nil {
                        Button("install_vpn", action: install)
                            .alert(isPresented: $showVPNAlert) {
                                Alert(title: Text(LocalizedStringKey("vpn_configuration_not_installed")), message: Text(LocalizedStringKey("vpn_configuration_not_installed_message")), dismissButton: .default(Text("OK")))
                            }
                    } else {
                        if status == .connected {
                            Button("stop_capturing_requests", action: stopCapturingRequest)
                        } else {
                            Button("capture_requests", action: captureRequest)
                                .disabled(
                                    selectedProfile == nil || !selectedProfile!.isValid || status != .disconnected
                                )
                                .alert(isPresented: $showNotificationAlert) {
                                    Alert(
                                        title: Text(LocalizedStringKey("notification_permission_not_granted")), message: Text(LocalizedStringKey("notification_permission_not_granted_message")),
                                        dismissButton: .default(Text("OK")) {
                                            if #available(iOS 16, *) {
                                                UIApplication.shared.open(URL(string: UIApplication.openNotificationSettingsURLString)!)
                                            } else {
                                                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                                            }
                                        })
                                }
                                .alert(isPresented: $showRootCertificateAlert) {
                                    Alert(
                                        title: Text(LocalizedStringKey("root_certificate_not_installed_or_trusted")), message: Text(LocalizedStringKey("root_certificate_not_installed_or_trusted_message")),
                                        dismissButton: .default(Text("OK")) {
                                            toggleCertificate()
                                        })
                                }
                        }
                    }
                }
                if !records.isEmpty {
                    Section("record") {
                        ForEach(records, id: \.self) { record in
                            Button {
                                showRecord(record)
                            } label: {
                                VStack(alignment: .leading) {
                                    HStack {
                                        Text(record.date!.format())
                                            .font(.footnote)
                                            .foregroundColor(.secondary)
                                        if let method = record.method, !method.isEmpty {
                                            Text(method)
                                                .font(.caption2)
                                                .bold()
                                                .foregroundColor(Color(UIColor.systemBackground))
                                                .padding(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
                                                .background {
                                                    Rectangle()
                                                        .fill(Color.accentColor)
                                                        .cornerRadius(4)
                                                }
                                        }
                                        if record.status > 0 {
                                            Text("\(record.status)")
                                                .font(.caption2)
                                                .bold()
                                                .foregroundColor(Color(UIColor.systemBackground))
                                                .padding(EdgeInsets(top: 2, leading: 4, bottom: 2, trailing: 4))
                                                .background {
                                                    Rectangle()
                                                        .fill(statusColor(record.status))
                                                        .cornerRadius(4)
                                                }
                                        }
                                    }
                                    Text(record.url!)
                                        .foregroundColor(.primary)
                                }
                            }
                        }
                    }
                }
                Section {
                    VStack(alignment: .leading) {
                        HStack(alignment: .center) {
                            Image(systemName: "network")
                                .font(.title)
                                .foregroundColor(.secondary)
                            Spacer()
                                .frame(width: 16)
                            Text(LocalizedStringKey("instruction_vpn"))
                                .font(.system(size: 15, design: .rounded))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                            .frame(height: 16)
                        HStack(alignment: .center) {
                            Image(systemName: "bell.badge")
                                .font(.title)
                                .foregroundColor(.secondary)
                            Spacer()
                                .frame(width: 16)
                            Text(LocalizedStringKey("instruction_notification"))
                                .font(.system(size: 15, design: .rounded))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                            .frame(height: 16)
                        HStack(alignment: .center) {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.title)
                                .foregroundColor(.secondary)
                            Spacer()
                                .frame(width: 16)
                            Text(LocalizedStringKey("instruction_privacy"))
                                .font(.system(size: 15, design: .rounded))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .listRowBackground(Color(UIColor.systemGroupedBackground))
            }
            .sheet(item: $profileOperation, onDismiss: save) { operation in
                ProfileView(profile: operation.object)
                    .environment(\.managedObjectContext, operation.context)
            }
            .sheet(item: $selectedRecord) { record in
                RecordView(record: record)
            }
            .navigationTitle("Mudmouth")
        }
        .onChange(of: scenePhase) { newValue in
            if newValue == .active {
                // Observes VPN connection status.
                loadVPN { manager in
                    self.manager = manager
                    if vpnObserver != nil {
                        NotificationCenter.default.removeObserver(vpnObserver!)
                        vpnObserver = nil
                    }
                    if manager != nil {
                        status = manager!.connection.status
                        os_log(.info, "VPN connection status %d", status.rawValue)
                        vpnObserver = NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: manager!.connection, queue: .main) { _ in
                            status = manager!.connection.status
                            os_log(.info, "VPN connection status changed to %d", status.rawValue)
                        }
                    } else {
                        status = .invalid
                    }
                }
                // Observes notification callback from app delegate.
                if notificationObserver == nil {
                    notificationObserver = NotificationCenter.default.addObserver(forName: Notification.Name("notification"), object: nil, queue: .main) { notification in
                        requestHeaders = notification.userInfo![RequestHeaders] as! String
                        responseHeaders = notification.userInfo![ResponseHeaders] as? String
                        stopCapturingRequest()
                        if selectedProfile != nil {
                            triggerPostAction()
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSPersistentStoreRemoteChange).receive(on: DispatchQueue.main)) { _ in
            // HACK: Update fetch request forcly.
            if records.nsPredicate == nil {
                records.nsPredicate = NSPredicate(value: true)
            } else {
                records.nsPredicate = nil
            }
        }
        .onOpenURL { url in
            os_log(.info, "Open from URL Scheme: %{public}@", url.absoluteString)
            if url.scheme == "mudmouth" {
                if let host = url.host {
                    switch host {
                    case "add":
                        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
                        if let queries = components.queryItems {
                            let profile = Profile(context: viewContext, queries: queries)
                            if profile.isValid {
                                save()
                                AlertKitAPI.present(title: "profile_added".localizedString, icon: .done, style: .iOS17AppleMusic, haptic: .success)
                            } else {
                                viewContext.delete(profile)
                                save()
                                AlertKitAPI.present(title: "invalid_profile".localizedString, icon: .error, style: .iOS17AppleMusic, haptic: .error)
                            }
                        }
                    case "capture":
                        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
                        if let queries = components.queryItems {
                            if let name = queries.first(where: { item in
                                item.name == "name"
                            })?.value {
                                let fetchRequest: NSFetchRequest<Profile> = Profile.fetchRequest()
                                fetchRequest.predicate = NSPredicate(format: "name == %@", name)
                                let fetchedResults = try? viewContext.fetch(fetchRequest)
                                if let profiles = fetchedResults {
                                    if profiles.count > 1 {
                                        AlertKitAPI.present(title: "duplicate_profiles_found".localizedString, icon: .error, style: .iOS17AppleMusic, haptic: .error)
                                    } else if let profile = profiles.first {
                                        selectedProfile = profile
                                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .seconds(1))) {
                                            captureRequest()
                                        }
                                    } else {
                                        AlertKitAPI.present(title: "profile_not_found".localizedString, icon: .error, style: .iOS17AppleMusic, haptic: .error)
                                    }
                                }
                            }
                        }
                    default:
                        break
                    }
                }
            }
        }
    }

    var isHTTPS: Bool {
        if let url = selectedProfile?.url {
            if let url = URL(string: url) {
                return url.scheme == "https"
            }
        }
        return false
    }

    private func save() {
        try! viewContext.save()
    }

    private func deleteProfile(_ profile: Profile) {
        viewContext.delete(profile)
        save()
        if profile == selectedProfile {
            selectedProfile = nil
        }
    }
    private func updateProfile(_ profile: Profile) {
        profileOperation = UpdateOperation(withExistingObject: profile, in: viewContext)
    }
    private func createProfile() {
        profileOperation = CreateOperation(with: viewContext)
    }

    private func showRecord(_ record: Record) {
        selectedRecord = record
    }

    private func statusColor(_ status: Int16) -> Color {
        switch status {
        case 100..<200:
            .blue
        case 200..<300:
            .green
        case 300..<400:
            .yellow
        case 400..<599:
            .red
        default:
            .accentColor
        }
    }

    private func toggleCertificate() {
        showCertificate.toggle()
    }

    private func install() {
        installVPN { error in
            if error != nil {
                showVPNAlert.toggle()
            }
        }
    }

    private func captureRequest() {
        requestNotification { granted in
            if !granted {
                showNotificationAlert.toggle()
                return
            }
            var certificate: Certificate? = nil
            var privateKey: P256.Signing.PrivateKey? = nil
            let url = URL(string: selectedProfile!.url!)!
            switch url.scheme! {
            case "http":
                break
            case "https":
                let (caCertificate, caPrivateKey) = loadCertificate()
                (certificate, privateKey) = generateSiteCertificate(url: selectedProfile!.url!, caCertificate: caCertificate, caPrivateKey: caPrivateKey)
            default:
                fatalError("Unexpected scheme: \(url.scheme!)")
            }
            if let certificate = certificate {
                let url = URL(string: selectedProfile!.url!)!
                if !verifyCertificateForTLS(certificate: certificate, url: url.host!) {
                    showRootCertificateAlert.toggle()
                    return
                }
            }
            startVPN(manager: manager!, profile: selectedProfile!, certificate: certificate, privateKey: privateKey) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                switch selectedProfile!.preActionEnum {
                case .none:
                    break
                case .urlScheme:
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .seconds(1))) {
                        UIApplication.shared.open(URL(string: selectedProfile!.preActionUrlScheme!)!)
                    }
                case .shortcut:
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .seconds(1))) {
                        UIApplication.shared.open(URL(string: "shortcuts://run-shortcut?name=\(selectedProfile!.preActionShortcut!)")!)
                    }
                }
            }
        }
    }
    private func stopCapturingRequest() {
        manager?.connection.stopVPNTunnel()
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }

    private func triggerPostAction() {
        if let selectedProfile = selectedProfile {
            switch selectedProfile.postActionEnum {
            case .none:
                break
            case .urlScheme:
                let scheme = URL(string: selectedProfile.postActionUrlScheme!)!
                let encoded = requestHeaders.data(using: .utf8)!.urlSafeBase64EncodedString()
                var components = URLComponents(url: scheme, resolvingAgainstBaseURL: true)!
                if components.queryItems == nil {
                    components.queryItems = []
                }
                components.queryItems!.append(URLQueryItem(name: "requestHeaders", value: encoded))
                if let responseHeaders = responseHeaders {
                    let encoded = responseHeaders.data(using: .utf8)!.urlSafeBase64EncodedString()
                    components.queryItems!.append(URLQueryItem(name: "responseHeaders", value: encoded))
                }
                UIApplication.shared.open(components.url!)
            case .shortcut:
                var json = ["requestHeaders": requestHeaders]
                if let responseHeaders = responseHeaders {
                    json.updateValue(responseHeaders, forKey: "responseHeaders")
                }
                let data = try! JSONSerialization.data(withJSONObject: json)
                let text = String(data: data, encoding: .utf8)!
                UIApplication.shared.open(URL(string: "shortcuts://run-shortcut?name=\(selectedProfile.postActionShortcut!)&input=text&text=\(text)")!)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
