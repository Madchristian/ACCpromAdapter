import Cocoa
import SwiftUI
import ServiceManagement
import os
import UniformTypeIdentifiers
import Network

let delegateLogger = Logger(subsystem: "de.cstrube.ACCpromAdapter", category: "AppDelegate")

class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        delegateLogger.log("applicationDidFinishLaunching gestartet")
        
        // Prüfe, ob Port 9200 frei ist.
        if !isPortAvailable(9200) {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Port 9200 nicht verfügbar"
                alert.informativeText = "Der Port 9200 wird bereits verwendet. Die Anwendung kann nicht gestartet werden."
                alert.alertStyle = .critical
                alert.addButton(withTitle: "OK")
                alert.runModal()
                NSApp.terminate(nil)
            }
            return
        }
        
        // Verzögere die Prüfung um 1 Sekunde, damit sich das UI stabilisieren kann.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.checkFileURLAndUpdateMetrics { success in
                if success {
                    self.startServer()
                } else {
                    self.openFileDialog()
                }
            }
        }
    }
    
    private func isPortAvailable(_ port: UInt16) -> Bool {
        do {
            let listener = try NWListener(using: .tcp, on: NWEndpoint.Port(integerLiteral: port))
            listener.cancel()
            delegateLogger.log("Port \(port) ist verfügbar.")
            return true
        } catch {
            delegateLogger.error("Port \(port) nicht verfügbar: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
    
    private func checkFileURLAndUpdateMetrics(completion: @escaping (Bool) -> Void) {
        if let savedURLString = UserDefaults.standard.string(forKey: "selectedFileURL"),
           let url = URL(string: savedURLString) {
            delegateLogger.log("Gespeicherte Datei-URL: \(url.path, privacy: .public)")
            if FileManager.default.isReadableFile(atPath: url.path) {
                delegateLogger.log("Datei \(url.path, privacy: .public) ist lesbar.")
                // Führe forceUpdateMetrics nur einmalig aus und logge kompakt
                let result = MetricsCache.shared.forceUpdateMetrics()
                switch result {
                case .success(_):
                    delegateLogger.log("Initiale Metriken aktualisiert.")
                    completion(true)
                case .failure(let error):
                    delegateLogger.error("Initiales Update fehlgeschlagen: \(error.localizedDescription, privacy: .public)")
                    completion(false)
                }
            } else {
                delegateLogger.error("Datei \(url.path, privacy: .public) NICHT lesbar.")
                completion(false)
            }
        } else {
            delegateLogger.log("Keine gespeicherte Datei-URL gefunden.")
            completion(false)
        }
    }
    
    func openFileDialog() {
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
            delegateLogger.log("Datei ausgewählt: \(url.path, privacy: .public)")
            _ = MetricsCache.shared.forceUpdateMetrics()
            self.startServer()
        }
    }
    
    private func startServer() {
        DispatchQueue.global(qos: .background).async {
            delegateLogger.log("Starte Prometheus-Server...")
            PrometheusServer.shared.start(on: 9200)
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        delegateLogger.log("Cleanup: Anwendung wird beendet.")
        PrometheusServer.shared.stop()
    }
}
