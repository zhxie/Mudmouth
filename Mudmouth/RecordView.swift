import SwiftUI

struct RecordView: View {
    var record: Record

    init(record: Record) {
        self.record = record
    }

    var body: some View {
        NavigationView {
            List {
                Section("Record") {
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(record.date!.format())
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.trailing)
                    }
                    VStack(alignment: .leading) {
                        Text("URL")
                        Spacer()
                            .frame(height: 8)
                        Text(record.url!)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
                Section("Request") {
                    if let method = record.method, !method.isEmpty {
                        HStack {
                            Text("Method")
                            Spacer()
                            Text(method)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                    VStack(alignment: .leading) {
                        Text("Headers")
                        Spacer()
                            .frame(height: 8)
                        Text(record.requestHeaders!)
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                    }
                }
                if let responseHeaders = record.responseHeaders {
                    Section("Response") {
                        if record.status > 0 {
                            HStack {
                                Text("Status")
                                Spacer()
                                Text("\(record.status)")
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                        VStack(alignment: .leading) {
                            Text("Headers")
                            Spacer()
                                .frame(height: 8)
                            Text(responseHeaders)
                                .foregroundColor(.secondary)
                                .textSelection(.enabled)
                        }
                    }
                }
            }
            .navigationTitle("Record")
        }
    }
}

struct RecordView_Previews: PreviewProvider {
    static var previews: some View {
        let record = Record(context: PersistenceController.preview.container.viewContext)
        return RecordView(record: record)
    }
}
