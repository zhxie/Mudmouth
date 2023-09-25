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
    
    @State private var manager: NETunnelProviderManager?
    @State private var observer: AnyObject?
    @State private var isEnabled: Bool = false
    @State private var status: NEVPNStatus = .invalid

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
                    Button("Generate and Trust Root CA") {
                        
                    }
                    if manager == nil {
                        Button("Install VPN") {
                            let manager = NETunnelProviderManager()
                            manager.localizedDescription = "Mudmouth"
                            let proto = NETunnelProviderProtocol()
                            proto.providerBundleIdentifier = "name.sketch.Mudmouth.PacketTunnel"
                            proto.serverAddress = "Mudmouth"
                            manager.protocolConfiguration = proto
                            manager.isEnabled = true
                            manager.saveToPreferences { error in
                                if let error = error {
                                    fatalError("Failed to add VPN profile: \(error.localizedDescription)")
                                }
                            }
                        }
                    } else {
                        if status == .connected {
                            Button("Stop Capturing Request") {
                                manager!.connection.stopVPNTunnel()
                            }
                        } else {
                            Button("Capture Request") {
                                manager!.isEnabled = true
                                manager!.saveToPreferences { error in
                                    if let error = error {
                                        fatalError("Failed to enable VPN: \(error.localizedDescription)")
                                    }
                                    do {
                                        try manager!.connection.startVPNTunnel(options: [
                                            NEVPNConnectionStartOptionUsername: selectedProfile!.url! as NSObject
                                        ])
                                    } catch {
                                        fatalError("Failed to start VPN: \(error.localizedDescription)")
                                    }
                                    switch selectedProfile!.preActionEnum {
                                    case .none:
                                        break
                                    case .urlScheme:
                                        UIApplication.shared.open(URL(string: selectedProfile!.preActionUrlScheme!)!)
                                        break
                                    }
                                }
                            }
                            .disabled(selectedProfile == nil || !selectedProfile!.isValid || status != .disconnected)
                        }
                    }
                }
            }
            .navigationTitle("Mudmouth")
        }
        .onChange(of: scenePhase) { newValue in
            if newValue == .active {
                NETunnelProviderManager.loadAllFromPreferences { managers, error in
                    os_log(.info, "Load %d VPN profile", managers?.count ?? 0)
                    manager = managers?.first
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
                    if let error = error {
                        fatalError("Failed to load VPN profile: \(error.localizedDescription)")
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
