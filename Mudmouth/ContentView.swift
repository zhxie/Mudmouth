//
//  ContentView.swift
//  Mudmouth
//
//  Created by Xie Zhihao on 2023/9/20.
//

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
    @State private var observer: AnyObject?
    @State private var isEnabled: Bool = false
    @State private var status: NEVPNStatus = .invalid
    
    @State private var showNotificationAlert = false
    
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
                                    viewContext.delete(profile)
                                    save()
                                    if profile == selectedProfile {
                                        selectedProfile = nil
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                Button {
                                    profileOperation = UpdateOperation(withExistingObject: profile, in: viewContext)
                                } label: {
                                    Label("Edit", systemImage: "square.and.pencil")
                                }
                                .tint(Color(UIColor.systemOrange))
                            }
                    }
                    Button("New Profile") {
                        profileOperation = CreateOperation(with: viewContext)
                    }
                    .sheet(item: $profileOperation, onDismiss: {
                        save()
                    }) { operation in
                        ProfileView(profile: operation.object)
                            .environment(\.managedObjectContext, operation.context)
                    }
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
                                requestNotification { granted in
                                    if !granted {
                                        showNotificationAlert.toggle()
                                        return
                                    }
                                    let (certificate, privateKey) = loadCertificate()
                                    let serializedCertificate = serializeCertificate(certificate!)
                                    startVpn(manager: manager!, url: selectedProfile!.url!, certificate: serializedCertificate, privateKey: privateKey!.rawRepresentation) {
                                        switch selectedProfile!.preActionEnum {
                                        case .none:
                                            break
                                        case .urlScheme:
                                            UIApplication.shared.open(URL(string: selectedProfile!.preActionUrlScheme!)!)
                                        }
                                    }
                                }
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
            }
            .navigationTitle("Mudmouth")
        }
        .onChange(of: scenePhase) { newValue in
            if newValue == .active {
                loadVpn { manager in
                    self.manager = manager
                    if observer != nil {
                        NotificationCenter.default.removeObserver(observer!)
                        observer = nil
                    }
                    if manager != nil {
                        status = manager!.connection.status
                        os_log(.info, "VPN connection status %d", status.rawValue)
                        observer = NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: manager!.connection, queue: .main) { _ in
                            status = manager!.connection.status
                            os_log(.info, "VPN connection status changed to %d", status.rawValue)
                        }
                    } else {
                        status = .invalid
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
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
