//
//  ContentView.swift
//  ACCpromAdapter
//
//  Created by Christian Strube on 27.02.25.
//
import SwiftUI

struct ContentView: View {
    @ObservedObject var fetcher: MetricsFetcher
    
    // Die 5 wichtigsten Metriken, die angezeigt werden sollen:
    private let importantKeys = [
        "acc_zrequestsfromclient",
        "acc_zrepliesfromorigintoclient",
        "acc_zbytesfromcachetoclient",
        "acc_zbytesfromorigintoclient",
        "acc_zbytesdropped"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Überschrift
            Text("Cache Metrics")
                .font(.system(size: 22, weight: .bold))
                .padding(.top, 10)
            
            if fetcher.metrics.isEmpty {
                VStack {
                    ProgressView()
                    Text("Lade Metriken...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: 150)
            } else {
                // Zeige nur die wichtigen Metriken in einem ScrollView
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(importantKeys, id: \.self) { key in
                            HStack {
                                Text(formattedMetricName(from: key))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text(fetcher.metrics[key] ?? "-")
                                    .font(.subheadline)
                                    .bold()
                            }
                            Divider()
                        }
                    }
                    .padding(.horizontal)
                }
                .frame(maxHeight: 250)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
                .cornerRadius(8)
            }
            
            Divider()
            
            // UI-Buttons für Aktionen
            VStack(spacing: 10) {
                HStack(spacing: 20) {
                    Button("In Safari öffnen") {
                        if let url = URL(string: "http://localhost:9200/metrics") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(LinkButtonStyle())
                    
                    Button("URL kopieren") {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString("http://localhost:9200/metrics", forType: .string)
                    }
                    .buttonStyle(LinkButtonStyle())
                }
                
                HStack(spacing: 20) {
                    Button("Aktualisieren") {
                        fetcher.fetchMetrics()
                    }
                    .buttonStyle(LinkButtonStyle())
                    
                    Button("Reset Defaults") {
                        resetUserDefaults()
                    }
                    .foregroundColor(.blue)
                    .buttonStyle(LinkButtonStyle())
                    
                    Button("Programm beenden") {
                        NSApp.terminate(nil)
                    }
                    .foregroundColor(.red)
                    .buttonStyle(LinkButtonStyle())
                }
            }
            .font(.system(size: 12))
            .padding(.bottom, 10)
        }
        .padding(12)
        .frame(width: 320)
    }
    
    /// Formatiert den Metrik-Namen, indem der Präfix "acc_" entfernt wird und der Rest schön formatiert wird.
    private func formattedMetricName(from key: String) -> String {
        if key.lowercased().hasPrefix("acc_") {
            let trimmed = key.dropFirst(4)
            return trimmed.capitalized
        }
        return key.capitalized
    }
    /// Löscht den Key "selectedFileURL" aus den UserDefaults
    private func resetUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "selectedFileURL")
    }
}

#Preview {
    ContentView(fetcher: MetricsFetcher())
}
