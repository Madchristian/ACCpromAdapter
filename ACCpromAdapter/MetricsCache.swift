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
    @Published private(set) var metrics: [String: String] = [:]
    private var cancellable: AnyCancellable?
    private let analyzer: AssetCacheAnalyzing
    
    // Initialisierung: Automatische Aktualisierung alle 30 Sekunden
    private init(analyzer: AssetCacheAnalyzing = AssetCacheAnalyzer()) {
        self.analyzer = analyzer
        forceUpdateMetrics() // Erste Aktualisierung sofort
        startAutoUpdate()    // Danach periodisch alle 30 Sekunden
    }
    
    /// Starte den Timer für regelmäßige Updates
    private func startAutoUpdate() {
        logger.log("Starte periodische Metriken-Aktualisierung")
        // Nutze den Main-RunLoop; der Timer wird dann in der Sink-Closure asynchronen Code starten.
        cancellable = Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateMetrics()
            }
    }
    
    /// Aktualisiert den Cache im Hintergrund.
    private func updateMetrics() {
        logger.log("Hintergrund-Update der Metriken gestartet")
        let result = analyzer.analyzeMetrics()
        switch result {
        case .success(let output):
            let parsed = self.parseMetrics(output)
            DispatchQueue.main.async {
                self.metrics = parsed
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
            let parsed = parseMetrics(output)
            DispatchQueue.main.async {
                self.metrics = parsed
            }
            logger.log("Sofortige Metriken-Aktualisierung erfolgreich")
            return .success(output)
        case .failure(let error):
            logger.error("Fehler bei der sofortigen Aktualisierung: \(error.localizedDescription, privacy: .public)")
            return .failure(error)
        }
    }
    
    /// Parser für Prometheus-Output (angenommen, die Ausgabe ist flach, ohne verschachtelte Zeilen).
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
