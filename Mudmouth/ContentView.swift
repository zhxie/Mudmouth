//
//  ContentView.swift
//  Mudmouth
//
//  Created by Xie Zhihao on 2023/9/20.
//

import CoreData
import NetworkExtension
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
                    }
                    if manager != nil {
                        Button("Capture Request") {
                            
                        }
                        .disabled(selectedProfile == nil)
                    }
                }
            }
            .navigationTitle("Mudmouth")
        }
        .onChange(of: scenePhase) { newValue in
            if newValue == .active {
                NETunnelProviderManager.loadAllFromPreferences { managers, error in
                    manager = managers?.first
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
