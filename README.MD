Hier ist eine ausführliche README.md für dein Git-Repository, die dokumentiert, was der ACCpromAdapter macht, welche Technologien verwendet wurden und wie das Projekt strukturiert ist. Die README enthält auch Anweisungen zur Einrichtung und Nutzung.

ACCpromAdapter

Version: 1.0
Autor: Christian Strube
Lizenz: MIT

📝 Beschreibung

ACCpromAdapter ist eine macOS-Menüleisten-App, die den Apple Content Cache überwacht und die Metriken im Prometheus-Format bereitstellt. Die App liest die Metrics.db aus dem Systemverzeichnis aus und stellt sie über einen integrierten HTTP-Server zur Verfügung. So können die Daten direkt in Grafana oder andere Monitoring-Tools integriert werden.

🎯 Features

✅ Prometheus-kompatible Metriken
✅ Leichtgewichtiger HTTP-Server auf Port 9200
✅ Security-Scoped Bookmarks für Zugriff auf geschützte Dateien
✅ Menüleisten-App ohne Dock-Icon
✅ Einfache Konfiguration und automatische Speicherung der Dateiauswahl
✅ Automatische Aktualisierung der Metriken über Combine
✅ Option zur Rücksetzung der Einstellungen

🏗️ Architektur

Das Projekt ist in Swift geschrieben und verwendet SwiftUI für die Menüleiste sowie SwiftNIO für den HTTP-Server.

🔹 Komponenten:
    1.    AppDelegate.swift
    •    Initialisiert die App und prüft, ob der Port 9200 verfügbar ist.
    •    Verwaltet den Zugriff auf die Metrics.db mithilfe von Security-Scoped Bookmarks.
    •    Falls keine Datei gespeichert ist, öffnet es einen Dateiauswahldialog.
    2.    PrometheusServer.swift
    •    Startet einen HTTP-Server mit SwiftNIO auf Port 9200.
    •    Liefert Metriken aus dem MetricsCache zurück.
    •    Verhindert, dass der Server blockiert, indem Metriken im Hintergrund aktualisiert werden.
    3.    AssetCacheAnalyzer.swift
    •    Liest die Metrics.db mit SQLite aus.
    •    Parst die Z-Werte aus der Datenbank und konvertiert sie in ein Prometheus-kompatibles Format.
    •    Zerlegt Werte mit Einheiten (z. B. MB, GB) in numerische Werte.
    4.    MetricsFetcher.swift
    •    Observables mit Combine, um UI-Updates nur auszuführen, wenn Metriken aktualisiert wurden.
    •    Kümmert sich um das Abrufen und Verarbeiten der Daten für die UI.
    5.    ContentView.swift
    •    Die Menüleisten-Oberfläche zur Anzeige der wichtigsten Metriken.
    •    Enthält Buttons für Safari, Kopieren der URL und Neustarten der Metriken.
    •    Reset-Funktion für UserDefaults (zum Testen nützlich).

🚀 Installation
    1.    Projekt klonen

git clone https://github.com/dein-github/ACCpromAdapter.git
cd ACCpromAdapter


    2.    Xcode öffnen

open ACCpromAdapter.xcodeproj


    3.    Signatur einrichten (falls nötig)
    •    In den Xcode Signing & Capabilities die Entwickler-ID eintragen.
    4.    App starten
    •    Drücke Cmd + R, um die App zu starten.

🔧 Troubleshooting

❌ Kein Zugriff auf die Metrics.db
    •    Stelle sicher, dass die App in den Systemeinstellungen → Datenschutz & Sicherheit → Festplattenvollzugriff eingetragen ist.

❌ Port 9200 ist blockiert
    •    Prüfe mit:

lsof -i :9200

Falls ein anderer Prozess den Port belegt:

kill -9 <PID>



❌ Keine Metriken in Grafana
    •    Prüfe, ob die Prometheus-URL korrekt ist:

http://localhost:9200/metrics

📌 Geplante Features

✅ XPC-Service für Sandbox-Modus
✅ Detailliertere Metriken mit Einheiten (MB, GB, KB)
🔜 Automatische Installation als LaunchDaemon
🔜 Benachrichtigungen bei kritischen Cache-Werten

⚖️ Lizenz

Dieses Projekt steht unter der MIT-Lizenz – du kannst es frei verwenden, modifizieren und verteilen.
