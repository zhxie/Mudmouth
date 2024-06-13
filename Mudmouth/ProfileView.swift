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

    var body: some View {
        NavigationView {
            List {
                Section {
                    TextField("Name", text: $profile.name.defaultValue(""))
                    TextField("URL", text: $profile.url.defaultValue(""))
                        .textContentType(.URL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Profile")
                } footer: {
                    Text("Mudmouth only supports tapping on HTTP and HTTPS requests.")
                }
                Section("Match") {
                    Picker("Direction", selection: $profile.directionEnum) {
                        ForEach(Direction.allCases, id: \.self) { direction in
                            Text(direction.name)
                                .tag(direction)
                        }
                    }
                }
                Section("Pre-Action") {
                    Picker("Action", selection: $profile.preActionEnum) {
                        ForEach(Action.allCases, id: \.self) { action in
                            Text(action.name)
                                .tag(action)
                        }
                    }
                    .animation(.none, value: profile.preActionEnum)
                    if profile.preActionEnum == .urlScheme {
                        TextField("URL Scheme", text: $profile.preActionUrlScheme.defaultValue(""))
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                    }
                }
                Section {
                    Picker("Action", selection: $profile.postActionEnum) {
                        ForEach(Action.allCases, id: \.self) { action in
                            Text(action.name)
                                .tag(action)
                        }
                    }
                    .animation(.none, value: profile.postActionEnum)
                    if profile.postActionEnum == .urlScheme {
                        TextField("URL Scheme", text: $profile.postActionUrlScheme.defaultValue(""))
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                    }
                } header: {
                    Text("Post-Action")
                } footer: {
                    if profile.postActionEnum == .urlScheme {
                        Text(
                            "MudMouth will trigger the URL Scheme with additional parameters on completion. Both headers and body will be encoded in the URL-safe Base64 format."
                        )
                    }
                }
                Section {
                    Button(title.isEmpty ? "Add" : "Save", action: save)
                        .disabled(!profile.isValid)
                }
            }
            .animation(Animation.easeInOut, value: profile.preActionEnum)
            .animation(Animation.easeInOut, value: profile.postActionEnum)
            .navigationTitle(title.isEmpty ? "New Profile" : title)
        }
    }

    private func save() {
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
