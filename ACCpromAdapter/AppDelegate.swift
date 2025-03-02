import Cocoa
import SwiftUI
import os

let delegateLogger = Logger(subsystem: "de.cstrube.ACCpromAdapter", category: "AppDelegate")

class AppDelegate: NSObject, NSApplicationDelegate {
    static var useExternalDaemon: Bool = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        delegateLogger.log("🚀 Anwendung gestartet – Initialisiere über AppInitializer...")

        AppInitializer.shared.initializeApplication {
            DispatchQueue.main.async {
                delegateLogger.log("✅ App-Initialisierung abgeschlossen – Starte UI.")
                // Erst hier die UI starten oder Hintergrundprozesse aktivieren
                NotificationCenter.default.post(name: Notification.Name("AppInitializationComplete"), object: nil)
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        delegateLogger.log("🛑 Anwendung wird beendet – Stoppe Server falls notwendig.")
        PrometheusServer.shared.stop()
    }
}
