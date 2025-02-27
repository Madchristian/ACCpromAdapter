//
//  ContentView.swift
//  ACCpromAdapter
//
//  Created by Christian Strube on 27.02.25.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var fetcher = MetricsFetcher()
    
    var body: some View {
        VStack {
            Text("Cache Metrics")
                .font(.headline)
                .padding(.bottom, 5)
            
            if fetcher.metrics.isEmpty {
                Text("Lade Metriken...")
                    .font(.subheadline)
                    .foregroundColor(.gray)
            } else {
                VStack(alignment: .leading) {
                    ForEach(fetcher.metrics.keys.sorted(), id: \.self) { key in
                        if ["bytesfromorigintochild", "repliesfromcachetopeer", "repliesfromcachetoclient","requestsrejectedfornospace"].contains(key.lowercased()) {
                            HStack {
                                Text("\(key.capitalized):")
                                    .bold()
                                Spacer()
                                Text(fetcher.metrics[key] ?? "-")
                            }
                        }
                    }
                }
                .frame(maxWidth: 200)
            }
            
            Divider()
            
            HStack {
                Button(action: {
                    if let url = URL(string: "http://localhost:9200/metrics") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("In Safari öffnen")
                }
                
                Button(action: {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString("http://localhost:9200/metrics", forType: .string)
                }) {
                    Text("URL kopieren")
                }
            }
            .padding(.top, 5)
        }
        .padding()
        .frame(width: 300)
    }
}

#Preview {
    ContentView()
}
