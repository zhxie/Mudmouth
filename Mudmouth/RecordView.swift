import SwiftUI

struct RecordView: View {
    var record: Record

    init(record: Record) {
        self.record = record
    }

    var body: some View {
        NavigationView {
            List {
                Section("record") {
                    HStack {
                        Text(LocalizedStringKey("date"))
                        Spacer()
                        Text(record.date!.format())
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    VStack(alignment: .leading) {
                        Text(LocalizedStringKey("url"))
                        Spacer()
                            .frame(height: 8)
                        Text(record.url!)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
                Section("request") {
                    if let method = record.method, !method.isEmpty {
                        HStack {
                            Text(LocalizedStringKey("method"))
                            Spacer()
                            Text(method)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    VStack(alignment: .leading) {
                        Text(LocalizedStringKey("headers"))
                        Spacer()
                            .frame(height: 8)
                        Text(record.requestHeaders!)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
                if let responseHeaders = record.responseHeaders {
                    Section("response") {
                        if record.status > 0 {
                            HStack {
                                Text(LocalizedStringKey("status"))
                                Spacer()
                                Text("\(record.status)")
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        VStack(alignment: .leading) {
                            Text(LocalizedStringKey("headers"))
                            Spacer()
                                .frame(height: 8)
                            Text(responseHeaders)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .navigationTitle("record")
        }
    }
}

struct RecordView_Previews: PreviewProvider {
    static var previews: some View {
        let record = Record(context: PersistenceController.preview.container.viewContext)
        return RecordView(record: record)
    }
}
