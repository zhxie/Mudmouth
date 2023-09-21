//
//  ContentView.swift
//  Mudmouth
//
//  Created by Xie Zhihao on 2023/9/20.
//

import SwiftUI
import CoreData

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Profile.name, ascending: true)],
        animation: .default)
    private var profiles: FetchedResults<Profile>
    @State private var selectedProfile: Profile? = nil

    @State private var profileOperation: DataOperation<Profile>?

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
                    Button("Capture Request") {
                        
                    }
                    .disabled(selectedProfile == nil)
                }
            }
            .navigationTitle("Mudmouth")
        }
    }
    
    private func save() {
        do {
            try viewContext.save()
        } catch {
            let nsError = error as NSError
            fatalError("Failed to save view context \(nsError)")
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    }
}
