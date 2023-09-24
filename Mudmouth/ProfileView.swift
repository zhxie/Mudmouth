//
//  ProfileView.swift
//  Mudmouth
//
//  Created by Xie Zhihao on 2023/9/21.
//

import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var childContext

    @ObservedObject var profile: Profile
    var title: String
    
    init(profile: Profile) {
        self.profile = profile
        title = profile.name ?? ""
    }
    
    var isValid: Bool {
        if (profile.name ?? "").isEmpty {
            return false
        }
        if URL(string: profile.url ?? "") == nil {
            return false
        }
        switch profile.preActionEnum {
        case .none:
            break
        case .urlScheme:
            if URL(string: profile.preActionUrlScheme ?? "") == nil {
                return false
            }
            break
        }
        switch profile.postActionEnum {
        case .none:
            break
        case .urlScheme:
            if URL(string: profile.postActionUrlScheme ?? "") == nil {
                return false
            }
            break
        }
        return true
    }
    
    var body: some View {
        NavigationView {
            ZStack {
                Color(UIColor.secondarySystemBackground)
                    .ignoresSafeArea(edges: .all)

                Form {
                    Section("Profile") {
                        TextField("Name", text: $profile.name.defaultValue(""))
                        TextField("URL", text: $profile.url.defaultValue(""))
                    }
                    Section("Pre-Action") {
                        Picker("Action", selection: $profile.preActionEnum) {
                            ForEach(Action.allCases, id: \.self) {
                                Text($0.name).tag($0)
                            }
                        }
                        .animation(.none, value: profile.preActionEnum)
                        if profile.preActionEnum == .urlScheme {
                            TextField("URL Scheme", text: $profile.preActionUrlScheme.defaultValue(""))
                        }
                    }
                    Section {
                        Picker("Action", selection: $profile.postActionEnum) {
                            ForEach(Action.allCases, id: \.self) {
                                Text($0.name).tag($0)
                            }
                        }
                        .animation(.none, value: profile.postActionEnum)
                        if profile.postActionEnum == .urlScheme {
                            TextField("URL Scheme", text: $profile.postActionUrlScheme.defaultValue(""))
                        }
                    } header: {
                        Text("Post-Action")
                    } footer: {
                        if profile.postActionEnum == .urlScheme {
                            Text("MudMouth will trigger the URL Scheme in the form of <URL_SCHEME>?[HEADER=VALUE] on completion.")
                        }
                    }
                    Button(title.isEmpty ? "Add" : "Save") {
                        withAnimation {
                            try? childContext.save()
                            dismiss()
                        }
                    }
                    .disabled(!isValid)
                }
                .animation(Animation.easeInOut, value: profile.preActionEnum)
                .animation(Animation.easeInOut, value: profile.postActionEnum)
                .navigationTitle(title.isEmpty ? "New Profile" : title)
            }
        }
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        let profile = Profile(context: PersistenceController.preview.container.viewContext)
        return ProfileView(profile: profile)
    }
}