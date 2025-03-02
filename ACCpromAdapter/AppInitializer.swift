//
//  AppInitializer.swift
//  ACCpromAdapter
//
//  Created by Christian Strube on 02.03.25.
//

import Foundation
import os
import AppKit
import UniformTypeIdentifiers

class AppInitializer {
    static let shared = AppInitializer()
    private let logger = Logger(subsystem: "de.cstrube.ACCpromAdapter", category: "AppInitializer")

    private(set) var useExternalDaemon: Bool = false

    private init() {}

    func initializeApplication(completion: @escaping () -> Void) {
        Task {
            await performInitialization()
            DispatchQueue.main.async {
                self.logger.log("✅ App-Initialisierung abgeschlossen – Starte UI.")
                NotificationCenter.default.post(name: Notification.Name("AppInitializationComplete"), object: nil)
                completion()
            }
        }
    }

    private func performInitialization() async {
        logger.log("🚀 App-Initialisierung gestartet – Prüfe Umgebung...")
        
        // 1 Sekunde warten, um Netzwerkanfragen Zeit zu geben
        do {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 Sekunde Verzögerung
        } catch {
            logger.error("⚠️ Fehler beim Warten: \(error.localizedDescription, privacy: .public)")
        }
        
        let daemonRunning = await checkIfDaemonIsAvailable()
        self.useExternalDaemon = daemonRunning

        if daemonRunning {
            logger.log("🟢 Externer Daemon erkannt – Nutze HTTP statt lokale DB.")
        } else {
            logger.log("🔴 Kein externer Daemon gefunden – Nutze lokale Datenbank.")
            
            let dbAvailable = await checkFileURLAndUpdateMetrics()
            if !dbAvailable {
                await openFileDialog()
            }
            
            // Starte den internen HTTP‑Server, weil kein externer Daemon verfügbar ist.
            DispatchQueue.global(qos: .background).async {
                self.logger.log("Starte internen HTTP-Server, da kein externer Dienst verfügbar ist.")
                PrometheusServer.shared.start(on: 9200)
            }
        }
    }

    private func checkIfDaemonIsAvailable() async -> Bool {
        let url = URL(string: "http://localhost:9200/metrics")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 2.0

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                return true
            }
        } catch {
            logger.error("⛔ Fehler beim Prüfen des Daemons: \(error.localizedDescription, privacy: .public)")
        }
        return false
    }

    private func checkFileURLAndUpdateMetrics() async -> Bool {
        guard let savedURLString = UserDefaults.standard.string(forKey: "selectedFileURL"),
              let url = URL(string: savedURLString) else {
            logger.log("⚠️ Keine gespeicherte Datei-URL gefunden.")
            return false
        }

        logger.log("📂 Gespeicherte Datei-URL: \(url.path, privacy: .public)")
        if FileManager.default.isReadableFile(atPath: url.path) {
            logger.log("✅ Datei \(url.path, privacy: .public) ist lesbar.")
            let result = MetricsCache.shared.forceUpdateMetrics()
            switch result {
            case .success(_):
                logger.log("✅ Initiale Metriken erfolgreich aktualisiert.")
                return true
            case .failure(let error):
                logger.error("⚠️ Fehler beim Laden der lokalen DB: \(error.localizedDescription, privacy: .public)")
            }
        } else {
            logger.error("⛔ Datei \(url.path, privacy: .public) NICHT lesbar.")
        }
        return false
    }

    @MainActor
    private func openFileDialog() async {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false

        if #available(macOS 12.0, *) {
            panel.allowedContentTypes = [UTType(filenameExtension: "db")!]
        } else {
            panel.allowedFileTypes = ["db"]
        }
        panel.directoryURL = URL(fileURLWithPath: "/Library/Application Support/Apple/AssetCache/Metrics")
        panel.title = "Bitte wählen Sie die Metrics-Datenbank (.db) aus"
        panel.message = "Wählen Sie die Datei aus, die Ihre AssetCache-Metriken enthält."

        if panel.runModal() == .OK, let url = panel.url {
            UserDefaults.standard.set(url.absoluteString, forKey: "selectedFileURL")
            logger.log("✅ Datei ausgewählt: \(url.path, privacy: .public)")
            _ = MetricsCache.shared.forceUpdateMetrics()
        } else {
            logger.log("⚠️ Kein File ausgewählt – App kann keine Metriken laden.")
        }
    }
}
