//
//  ContentView.swift
//  Mudmouth
//
//  Created by Xie Zhihao on 2023/9/20.
//

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
    @State private var selectedProfile: Profile? = nil
    @State private var profileOperation: DataOperation<Profile>?
    
    @State private var showCertificate = false
    
    @State private var manager: NETunnelProviderManager?
    @State private var vpnObserver: AnyObject?
    @State private var isEnabled: Bool = false
    @State private var status: NEVPNStatus = .invalid
    
    @State private var showNotificationAlert = false
    
    @State private var notificationObserver: AnyObject?
    @State private var headers = ""
    @State private var body_: Data?
    
    init() {
        let (certificate, privateKey) = loadCertificate()
        if certificate == nil || privateKey == nil {
            let _ = generateCertificate()
        }
        runCertificateServer()
    }

    var body: some View {
        NavigationView {
            List(selection: $selectedProfile) {
                Section("Profile") {
                    ForEach(profiles, id: \.self) { profile in
                        Text(profile.name!)
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
                            .contextMenu {
                                Button {
                                    updateProfile(profile)
                                } label: {
                                    Label("Edit", systemImage: "square.and.pencil")
                                }
                                Button(role: .destructive) {
                                    deleteProfile(profile)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    Button("New Profile") {
                        profileOperation = CreateOperation(with: viewContext)
                    }
                }
                .sheet(item: $profileOperation, onDismiss: {
                    save()
                }) { operation in
                    ProfileView(profile: operation.object)
                        .environment(\.managedObjectContext, operation.context)
                }
                Section("Tap") {
                    Button("Configure Root Certificate") {
                        showCertificate.toggle()
                    }
                    .sheet(isPresented: $showCertificate) {
                        CertificateView()
                    }
                    if manager == nil {
                        Button("Install VPN") {
                            installVpn()
                        }
                    } else {
                        if status == .connected {
                            Button("Stop Capturing Request") {
                                manager!.connection.stopVPNTunnel()
                            }
                        } else {
                            Button("Capture Request") {
                                captureRequest()
                            }
                            .disabled(selectedProfile == nil || !selectedProfile!.isValid || status != .disconnected)
                            .alert(isPresented: $showNotificationAlert) {
                                Alert(title: Text("Notification Permission Not Granted"), message: Text("Mudmouth requires notification permission to notify completion and perform post-action."), dismissButton: .default(Text("OK")) {
                                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                                })
                            }
                        }
                    }
                }
                if !headers.isEmpty {
                    Section("Result") {
                        VStack(alignment: .leading) {
                            Text("Headers")
                            Spacer()
                                .frame(height: 8)
                            Text(headers)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                        .contextMenu {
                            Button {
                                UIPasteboard.general.string = headers
                            } label: {
                                Label("Copy", systemImage: "doc.on.doc")
                            }
                        }
                        if bodyString != nil {
                            VStack(alignment: .leading) {
                                Text("Body")
                                Spacer()
                                    .frame(height: 8)
                                Text(bodyString!)
                                    .font(.footnote)
                                    .foregroundColor(.secondary)
                            }
                            .contextMenu {
                                Button {
                                    UIPasteboard.general.string = bodyString!
                                } label: {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                            }
                        } else {
                            HStack {
                                Text("Body")
                                Spacer()
                                Text("\(body_?.count ?? 0) Byte(s)")
                                    .foregroundColor(.secondary)
                            }
                        }
                        if selectedProfile != nil && selectedProfile!.postActionEnum != .none {
                            Button("Continue \"\(selectedProfile!.name!)\"") {
                                switch selectedProfile!.postActionEnum {
                                case .none:
                                    break
                                case .urlScheme:
                                    var scheme = URL(string: selectedProfile!.postActionUrlScheme!)!
                                    let encoded = headers.data(using: .utf8)!.urlSafeBase64EncodedString()
                                    scheme.append(queryItems: [URLQueryItem(name: "headers", value: encoded)])
                                    if body_ != nil {
                                        let encoded = body_!.urlSafeBase64EncodedString()
                                        scheme.append(queryItems: [URLQueryItem(name: "body", value: encoded)])
                                    }
                                    UIApplication.shared.open(scheme)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Mudmouth")
        }
        .onChange(of: scenePhase) { newValue in
            if newValue == .active {
                loadVpn { manager in
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
                if notificationObserver == nil {
                    notificationObserver = NotificationCenter.default.addObserver(forName: Notification.Name("notification"), object: nil, queue: .main) { notification in
                        headers = notification.userInfo!["headers"] as! String
                        body_ = notification.userInfo!["body"] as? Data
                        manager?.connection.stopVPNTunnel()
                        if selectedProfile != nil {
                            switch selectedProfile!.postActionEnum {
                            case .none:
                                break
                            case .urlScheme:
                                var scheme = URL(string: selectedProfile!.postActionUrlScheme!)!
                                let encoded = headers.data(using: .utf8)!.urlSafeBase64EncodedString()
                                scheme.append(queryItems: [URLQueryItem(name: "headers", value: encoded)])
                                if body_ != nil {
                                    let encoded = body_!.urlSafeBase64EncodedString()
                                    scheme.append(queryItems: [URLQueryItem(name: "body", value: encoded)])
                                }
                                UIApplication.shared.open(scheme)
                                AlertKitAPI.present(title: "Post-Action Triggered", icon: .done, style: .iOS17AppleMusic, haptic: .success)
                            }
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
    
    var bodyString: String? {
        guard let body = body_ else {
            return nil
        }
        return String(data: body, encoding: .utf8)
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
    
    private func captureRequest() {
        requestNotification { granted in
            if !granted {
                showNotificationAlert.toggle()
                return
            }
            let (certificate, privateKey) = loadCertificate()
            let serializedCertificate = serializeCertificate(certificate!)
            startVpn(manager: manager!, profile: selectedProfile!, certificate: serializedCertificate, privateKey: privateKey!.rawRepresentation) {
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
