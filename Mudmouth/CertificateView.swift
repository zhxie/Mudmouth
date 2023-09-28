//
//  CertificateView.swift
//  Mudmouth
//
//  Created by Xie Zhihao on 2023/9/28.
//

import SwiftUI

struct CertificateView: View {
    @State var organization: String
    @State var commonName: String
    @State var publicKey: String
    @State var privateKey: String
    
    init() {
        organization = "Mudmouth"
        commonName = "Mudmouth Generated 00000000"
        publicKey = "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
        privateKey = "00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00"
    }
    
    var body: some View {
        NavigationView {
            List {
                Section("Basics") {
                    HStack {
                        Text("Organization")
                        Spacer()
                        Text(organization)
                            .foregroundColor(.secondary)
                    }
                    HStack {
                        Text("Common Name")
                        Spacer()
                        Text(commonName)
                            .foregroundColor(.secondary)
                    }
                }
                Section("Key Info") {
                    VStack(alignment: .leading) {
                        Text("Public Key Data")
                        Spacer()
                            .frame(height: 8)
                        Text(publicKey)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading) {
                        Text("Private Key Data")
                        Spacer()
                            .frame(height: 8)
                        Text(publicKey)
                            .font(.caption)
                            .fontDesign(.monospaced)
                            .foregroundColor(.secondary)
                    }
                }
                Section {
                    Button("Generate a New Certificate") {
                        
                    }
                    Button("Install Certificate") {
                        
                    }
                }
            }
            .navigationTitle("Certificate")
        }
    }
}

struct CertificateView_Previews: PreviewProvider {
    static var previews: some View {
        CertificateView()
    }
}
