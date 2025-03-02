//
//  ContentView.swift
//  ACCpromAdapter
//
//  Created by Christian Strube on 27.02.25.
//
import SwiftUI
import Combine

struct ContentView: View {
    @ObservedObject var fetcher: MetricsFetcher
    @ObservedObject var metricsCache = MetricsCache.shared
    
    private let importantKeys = [
        "acc_zrequestsfromclient",
        "acc_zrepliesfromorigintoclient",
        "acc_zbytesfromcachetoclient",
        "acc_zbytesfromorigintoclient",
        "acc_zbytesdropped",
        "acc_zcreationdate"
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Überschrift und Indikator
            HStack {
                Text("Cache Metrics")
                    .font(.system(size: 18, weight: .bold))
                Spacer()
                // Zeige den Indikator: grün = externer Daemon, rot = lokale DB
                Circle()
                    .fill(fetcher.serverReady ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                    .overlay(
                        Circle().stroke(Color.primary, lineWidth: 0.5)
                    )
                    .help(fetcher.serverReady ? "Externer HTTP-Modus" : "Lokaler DB-Modus")
            }
            .padding(.top, 10)
            
            // Metrikenanzeige
            if fetcher.metrics.isEmpty {
                VStack {
                    ProgressView()
                    Text("Lade Metriken...")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: 160)
            } else {
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
            
            // Anzeige des letzten Update-Datums (optional)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Letztes Update der Metriken:")
                        .font(.footnote)
                    if let creationDateString = fetcher.metrics["acc_zcreationdate"],
                       let formattedDate = formattedCreationDate(from: creationDateString) {
                        Text(formattedDate)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
            }
            
            // Fortschrittsbalken (nur für lokalen DB-Modus sinnvoll)
            if !fetcher.serverReady {
                ProgressView(value: metricsCache.refreshProgress)
                    .progressViewStyle(.linear)
                    .tint(.blue)
                    .frame(height: 4)
                    .padding(.bottom, 6)
            }
            
            Divider()
            
            // Buttons
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Button("In Safari öffnen") {
                        if let url = URL(string: "http://localhost:9200/metrics") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button("URL kopieren") {
                        let pasteboard = NSPasteboard.general
                        pasteboard.clearContents()
                        pasteboard.setString("http://localhost:9200/metrics", forType: .string)
                    }
                    .buttonStyle(.bordered)
                }
                
                HStack(spacing: 12) {
                    Button("Reset Defaults") {
                        resetUserDefaults()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                    
                    Button("Programm beenden") {
                        NSApp.terminate(nil)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            }
            .font(.system(size: 12))
            .padding(.bottom, 10)
        }
        .padding(12)
        .frame(width: 270)
    }
    
    private func formattedMetricName(from key: String) -> String {
        if key.lowercased().hasPrefix("acc_") {
            let trimmed = key.dropFirst(4)
            return trimmed.capitalized
        }
        return key.capitalized
    }
    
    private func formattedCreationDate(from timestampString: String) -> String? {
        guard let timestamp = Double(timestampString) else { return nil }
        // Apple Reference Date: 1. Januar 2001
        let date = Date(timeIntervalSinceReferenceDate: timestamp)
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func resetUserDefaults() {
        UserDefaults.standard.removeObject(forKey: "selectedFileURL")
    }
}

#Preview {
    ContentView(fetcher: MetricsFetcher())
}
