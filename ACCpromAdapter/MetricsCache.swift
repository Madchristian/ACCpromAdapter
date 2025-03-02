//
//  MetricsCache.swift
//  ACCpromAdapter
//
//  Created by Christian Strube on 01.03.25.
//

import Foundation
import os
import Combine

final class MetricsCache: ObservableObject {
    static let shared = MetricsCache()
    
    private let logger = Logger(subsystem: "de.cstrube.ACCpromAdapter", category: "MetricsCache")
    
    /// Vollständiger Prometheus-Output (inklusive # HELP und # TYPE Zeilen).
    @Published private(set) var fullMetrics: String = "Noch keine Metriken verfügbar"
    
    /// Gefilterte Metriken für die UI, basierend auf einer vordefinierten Liste.
    @Published private(set) var filteredMetrics: [String: String] = [:]
    
    private var cancellable: AnyCancellable?
    private let analyzer: AssetCacheAnalyzing
    
    /// Wichtige Schlüssel (im vollständigen Output, inkl. "acc_" Präfix), die in der UI angezeigt werden sollen.
    private let importantKeys: Set<String> = [
        "acc_zrequestsfromclient",
        "acc_zrepliesfromorigintoclient",
        "acc_zbytesfromcachetoclient",
        "acc_zbytesfromorigintoclient",
        "acc_zbytesdropped",
        "acc_zcreationdate"
    ]
    
    // Initialisierung: Sofortiges Update und periodische Aktualisierung alle 30 Sekunden
    private init(analyzer: AssetCacheAnalyzing = AssetCacheAnalyzer()) {
        self.analyzer = analyzer
        forceUpdateMetrics() // Erste Aktualisierung sofort
        startAutoUpdate()    // Danach periodisch alle 30 Sekunden
    }
    
    /// Starte den Timer für regelmäßige Aktualisierungen
    private func startAutoUpdate() {
        logger.log("Starte periodische Metriken-Aktualisierung")
        cancellable = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateMetrics()
            }
    }
    
    /// Aktualisiert den Cache, indem der Analyzer aufgerufen wird.
    private func updateMetrics() {
        logger.log("Hintergrund-Update der Metriken gestartet")
        let result = analyzer.analyzeMetrics()
        switch result {
        case .success(let output):
            // Speichere den vollständigen Output
            DispatchQueue.main.async {
                self.fullMetrics = output
                // Parse den kompletten Output in ein Dictionary
                let allMetrics = self.parseMetrics(output)
                // Filtere die Metriken für die UI basierend auf der wichtigen Key-Liste
                self.filteredMetrics = allMetrics.filter { self.importantKeys.contains($0.key) }
            }
            logger.log("Metriken aktualisiert")
        case .failure(let error):
            logger.error("Fehler beim Aktualisieren der Metriken: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    /// Führt eine synchronisierte Aktualisierung durch und gibt das Result zurück.
    func forceUpdateMetrics() -> Result<String, Error> {
        logger.log("Führe sofortige Metriken-Aktualisierung aus")
        let result = analyzer.analyzeMetrics()
        switch result {
        case .success(let output):
            DispatchQueue.main.async {
                self.fullMetrics = output
                let allMetrics = self.parseMetrics(output)
                self.filteredMetrics = allMetrics.filter { self.importantKeys.contains($0.key) }
            }
            logger.log("Sofortige Metriken-Aktualisierung erfolgreich")
            return .success(output)
        case .failure(let error):
            logger.error("Fehler bei der sofortigen Aktualisierung: \(error.localizedDescription, privacy: .public)")
            return .failure(error)
        }
    }
    
    /// Parser für den vollständigen Prometheus-Output: Erzeugt ein Dictionary, in dem Zeilen, die nicht mit '#' beginnen, als "key value" interpretiert werden.
    private func parseMetrics(_ string: String) -> [String: String] {
        var dict = [String: String]()
        let lines = string.split(separator: "\n")
        for line in lines {
            // Kommentarzeilen überspringen
            if line.trimmingCharacters(in: .whitespaces).hasPrefix("#") { continue }
            let components = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            if components.count == 2 {
                let key = String(components[0]).lowercased()
                let value = String(components[1])
                dict[key] = value
            }
        }
        return dict
    }
    
    deinit {
        cancellable?.cancel()
    }
}
