import AlertKit
import CoreData
import NetworkExtension
import OSLog
import SwiftUI

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.scenePhase) private var scenePhase

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Profile.name, ascending: true)],
        animation: .default)
    private var profiles: FetchedResults<Profile>
    @State private var selectedProfile: Profile?
    @State private var profileOperation: DataOperation<Profile>?
    
    @State private var showCertificate = false
    
    @State private var manager: NETunnelProviderManager?
    @State private var vpnObserver: AnyObject?
    @State private var isEnabled: Bool = false
    @State private var status: NEVPNStatus = .invalid
    
    @State private var showVPNAlert = false
    @State private var showNotificationAlert = false
    
    @State private var notificationObserver: AnyObject?
    @State private var requestHeaders = ""
    @State private var requestBody: Data?
    @State private var responseHeaders: String?
    @State private var responseBody: Data?
    
    init() {
        let (certificate, privateKey) = loadCertificate()
        if certificate == nil || privateKey == nil {
            let _ = generateCertificate()
        }
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
            runCertificateServer()
        }
    }

    var body: some View {
        NavigationView {
            List {
                Section("Profile") {
                    ForEach(profiles, id: \.self) { profile in
                        Button {
                            selectedProfile = profile
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
                                Label("Delete", systemImage: "trash")
                            }
                            Button {
                                updateProfile(profile)
                            } label: {
                                Label("Edit", systemImage: "square.and.pencil")
                            }
                            .tint(Color(UIColor.systemOrange))
                        }
                    }
                    Button("New Profile", action: createProfile)
                }
                .sheet(item: $profileOperation, onDismiss: save) { operation in
                    ProfileView(profile: operation.object)
                        .environment(\.managedObjectContext, operation.context)
                }
                Section("Tap") {
                    Button("Configure Root Certificate", action: toggleCertificate)
                    .sheet(isPresented: $showCertificate) {
                        CertificateView()
                    }
                    if manager == nil {
                        Button("Capture Requests", action: install)
                            .disabled(selectedProfile == nil || !selectedProfile!.isValid)
                            .alert(isPresented: $showVPNAlert) {
                                Alert(title: Text("VPN Configuration Not Installed"), message: Text("Mudmouth requires VPN to capture requests."), dismissButton: .default(Text("OK")))
                            }
                    } else {
                        if status == .connected {
                            Button("Stop Capturing Requests", action: stopCapturingRequest)
                        } else {
                            Button("Capture Requests", action: captureRequest)
                            .disabled(selectedProfile == nil || !selectedProfile!.isValid || status != .disconnected)
                            .alert(isPresented: $showNotificationAlert) {
                                Alert(title: Text("Notification Permission Not Granted"), message: Text("Mudmouth requires notification permission to notify completion and perform post-action."), dismissButton: .default(Text("OK")) {
                                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                                })
                            }
                        }
                    }
                }
                if !requestHeaders.isEmpty {
                    Section("Result") {
                        VStack(alignment: .leading) {
                            Text("Request Headers")
                            Spacer()
                                .frame(height: 8)
                            Text(requestHeaders)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                        if requestBody != nil, let requestBody = String(data: requestBody!, encoding: .utf8) {
                            VStack(alignment: .leading) {
                                Text("Request Body")
                                Spacer()
                                    .frame(height: 8)
                                Text(requestBody)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .textSelection(.enabled)
                            }
                        } else {
                            HStack {
                                Text("Request Body")
                                Spacer()
                                Text("\(requestBody?.count ?? 0) Byte\(requestBody?.count ?? 0 > 0 ? "s" : "")")
                                    .foregroundColor(.secondary)
                            }
                        }
                        if let responseHeaders = responseHeaders {
                            VStack(alignment: .leading) {
                                Text("Response Headers")
                                Spacer()
                                    .frame(height: 8)
                                Text(responseHeaders)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                                    .textSelection(.enabled)
                            }
                            if responseBody != nil, let responseBody = String(data: responseBody!, encoding: .utf8) {
                                VStack(alignment: .leading) {
                                    Text("Response Body")
                                    Spacer()
                                        .frame(height: 8)
                                    Text(responseBody)
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .textSelection(.enabled)
                                }
                            } else {
                                HStack {
                                    Text("Response Body")
                                    Spacer()
                                    Text("\(responseBody?.count ?? 0) Byte\(responseBody?.count ?? 0 > 0 ? "s" : "")")
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        if selectedProfile != nil && selectedProfile!.postActionEnum != .none {
                            Button("Continue \"\(selectedProfile!.name!)\"", action: triggerPostAction)
                        }
                    }
                }
                Section {
                    VStack(alignment: .leading) {
                        HStack(alignment: .top) {
                            Image(systemName: "network")
                                .font(.title)
                                .foregroundColor(.secondary)
                            Spacer()
                                .frame(width: 16)
                            Text("Install and trust root certificate of Mudmouth to capture requests.")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                            .frame(height: 16)
                        HStack(alignment: .top) {
                            Image(systemName: "bell.badge")
                                .font(.title)
                                .foregroundColor(.secondary)
                            Spacer()
                                .frame(width: 16)
                            Text("Mudmouth will notify you once the request has been captured.")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                            .frame(height: 16)
                        HStack(alignment: .top) {
                            Image(systemName: "shield.lefthalf.filled")
                                .font(.title)
                                .foregroundColor(.secondary)
                            Spacer()
                                .frame(width: 16)
                            Text("Your connection is always secure and Mudmouth never collects any information.")
                                .font(.system(size: 15, design: .rounded))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .listRowBackground(Color(UIColor.systemGroupedBackground))
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
                        requestHeaders = notification.userInfo!["requestHeaders"] as! String
                        requestBody = notification.userInfo!["requestBody"] as? Data
                        responseHeaders = notification.userInfo!["responseHeaders"] as? String
                        responseBody = notification.userInfo!["responseBody"] as? Data
                        stopCapturingRequest()
                        if selectedProfile != nil {
                            triggerPostAction()
                        }
                    }
                }
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
                            let profile = Profile(context: viewContext)
                            profile.name = queries.first { item in
                                item.name == "name"
                            }?.value
                            profile.url = queries.first { item in
                                item.name == "url"
                            }?.value
                            profile.directionEnum = Direction(rawValue: Int16(queries.first { item in
                                item.name == "direction"
                            }?.value ?? "0") ?? 0) ?? .request
                            profile.preActionEnum = Action(rawValue: Int16(queries.first { item in
                                item.name == "preAction"
                            }?.value ?? "0") ?? 0) ?? .none
                            profile.preActionUrlScheme = queries.first { item in
                                item.name == "preActionUrlScheme"
                            }?.value
                            profile.postActionEnum = Action(rawValue: Int16(queries.first { item in
                                item.name == "postAction"
                            }?.value ?? "0") ?? 0) ?? .none
                            profile.postActionUrlScheme = queries.first { item in
                                item.name == "postActionUrlScheme"
                            }?.value
                            if profile.isValid {
                                save()
                                AlertKitAPI.present(title: "Profile Added", icon: .done, style: .iOS17AppleMusic, haptic: .success)
                            } else {
                                viewContext.delete(profile)
                                save()
                                AlertKitAPI.present(title: "Invalid Profile", icon: .error, style: .iOS17AppleMusic, haptic: .error)
                            }
                        }
                    case "capture":
                        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
                        if let queries = components.queryItems {
                            if let name = queries.first(where: { item in
                                item.name == "name"
                            })?.value {
                                do {
                                    let fetchRequest: NSFetchRequest<Profile> = Profile.fetchRequest()
                                    fetchRequest.predicate = NSPredicate(format: "name == %@", name)
                                    let fetchedResults = try viewContext.fetch(fetchRequest)
                                    if let profile = fetchedResults.first {
                                        selectedProfile = profile
                                        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .seconds(1))) {
                                            captureRequest()
                                        }
                                    } else {
                                        AlertKitAPI.present(title: "Profile Not Found", icon: .error, style: .iOS17AppleMusic, haptic: .error)
                                    }
                                } catch {
                                    fatalError("Failed to find profile: \(error.localizedDescription)")
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
    
    private func save() {
        do {
            try viewContext.save()
        } catch {
            fatalError("Failed to save view context: \(error.localizedDescription)")
        }
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
            let (certificate, privateKey) = loadCertificate()
            let serializedCertificate = serializeCertificate(certificate!)
            startVPN(manager: manager!, profile: selectedProfile!, certificate: serializedCertificate, privateKey: privateKey!.rawRepresentation) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                switch selectedProfile!.preActionEnum {
                case .none:
                    break
                case .urlScheme:
                    DispatchQueue.main.asyncAfter(deadline: DispatchTime.now().advanced(by: .seconds(1))) {
                        UIApplication.shared.open(URL(string: selectedProfile!.preActionUrlScheme!)!)
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
        switch selectedProfile!.postActionEnum {
        case .none:
            break
        case .urlScheme:
            var scheme = URL(string: selectedProfile!.postActionUrlScheme!)!
            let encoded = requestHeaders.data(using: .utf8)!.urlSafeBase64EncodedString()
            var components = URLComponents(url: scheme, resolvingAgainstBaseURL: true)!
            if components.queryItems == nil {
                components.queryItems = []
            }
            components.queryItems!.append(URLQueryItem(name: "requestHeaders", value: encoded))
            if requestBody != nil {
                let encoded = requestBody!.urlSafeBase64EncodedString()
                components.queryItems!.append(URLQueryItem(name: "requestBody", value: encoded))
            }
            if responseHeaders != nil {
                components.queryItems!.append(URLQueryItem(name: "responseHeaders", value: encoded))
            }
            if responseBody != nil {
                let encoded = responseBody!.urlSafeBase64EncodedString()
                components.queryItems!.append(URLQueryItem(name: "responseBody", value: encoded))
            }
            scheme = components.url!
            UIApplication.shared.open(scheme)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
