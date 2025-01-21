import SwiftUI

struct ProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) var childContext

    @ObservedObject var profile: Profile
    var title: String

    init(profile: Profile) {
        self.profile = profile
        title = profile.name ?? ""
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    TextField("name", text: $profile.name.defaultValue(""))
                    TextField("url", text: $profile.url.defaultValue(""))
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text(LocalizedStringKey("profile"))
                } footer: {
                    Text(LocalizedStringKey("profile_notice"))
                }
                Section("match") {
                    Picker("direction", selection: $profile.directionEnum) {
                        ForEach(Direction.allCases, id: \.self) { direction in
                            Text(direction.name)
                                .tag(direction)
                        }
                    }
                }
                Section("pre_action") {
                    Picker("action", selection: $profile.preActionEnum) {
                        ForEach(Action.allCases, id: \.self) { action in
                            Text(action.name)
                                .tag(action)
                        }
                    }
                    .animation(.none, value: profile.preActionEnum)
                    if profile.preActionEnum == .urlScheme {
                        TextField("url_scheme", text: $profile.preActionUrlScheme.defaultValue(""))
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                    } else if profile.preActionEnum == .shortcut {
                        TextField("shortcut", text: $profile.preActionShortcut.defaultValue(""))
                    }
                }
                Section {
                    Picker("action", selection: $profile.postActionEnum) {
                        ForEach(Action.allCases, id: \.self) { action in
                            Text(action.name)
                                .tag(action)
                        }
                    }
                    .animation(.none, value: profile.postActionEnum)
                    if profile.postActionEnum == .urlScheme {
                        TextField("url_scheme", text: $profile.postActionUrlScheme.defaultValue(""))
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                    } else if profile.postActionEnum == .shortcut {
                        TextField("shortcut", text: $profile.postActionShortcut.defaultValue(""))
                    }
                } header: {
                    Text(LocalizedStringKey("post_action"))
                } footer: {
                    if profile.postActionEnum == .urlScheme {
                        Text("post_action_url_scheme_notice")
                    } else if profile.postActionEnum == .shortcut {
                        Text("post_action_shortcut_notice")
                    }
                }
                Section {
                    Button(title.isEmpty ? "add" : "save", action: save)
                        .disabled(!profile.isValid)
                }
            }
            .animation(Animation.easeInOut, value: profile.preActionEnum)
            .animation(Animation.easeInOut, value: profile.postActionEnum)
            .navigationTitle(title.isEmpty ? "new_profile".localizedString : title)
        }
    }

    func save() {
        try? childContext.save()
        dismiss()
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        let profile = Profile(context: PersistenceController.preview.container.viewContext)
        return ProfileView(profile: profile)
    }
}
