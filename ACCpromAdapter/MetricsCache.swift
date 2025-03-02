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
    
    /// Vollständiger Prometheus-Output (als String).
    @Published private(set) var fullMetrics: String = "Noch keine Metriken verfügbar"
    /// Gefilterte Metriken (Dictionary) für die UI.
    @Published private(set) var filteredMetrics: [String: String] = [:]
    /// Fortschrittswert von 0.0 bis 1.0, der anzeigt, wie weit der 30-Sekunden-Zyklus fortgeschritten ist.
    @Published var refreshProgress: Double = 0.0
    
    private var cancellable: AnyCancellable?
    private let analyzer: AssetCacheAnalyzing
    
    /// 30-Sekunden Intervall für die Aktualisierung
    private let refreshInterval: TimeInterval = 30.0
    /// Startzeit des aktuellen Zyklus
    private var startTime: Date = Date()
    
    // Kein automatischer Start – wird explizit über startLocalUpdates() angestoßen
    private init(analyzer: AssetCacheAnalyzing = AssetCacheAnalyzer()) {
        self.analyzer = analyzer
    }
    
    /// Startet die lokale Aktualisierung, falls kein externer Daemon verfügbar ist.
    func startLocalUpdates() {
        // Führe initial ein Update durch
        _ = forceUpdateMetrics()
        // Starte den Timer für kontinuierliche Updates
        startAutoUpdate()
    }
    
    /// Führt eine sofortige Aktualisierung der Metriken aus.
    func forceUpdateMetrics() -> Result<String, Error> {
        logger.log("Führe forceUpdateMetrics aus")
        let result = analyzer.analyzeMetrics()
        switch result {
        case .success(let output):
            DispatchQueue.main.async {
                self.fullMetrics = output
                let allMetrics = self.parseMetrics(output)
                self.filteredMetrics = allMetrics.filter { key, _ in
                    ["acc_zrequestsfromclient",
                     "acc_zrepliesfromorigintoclient",
                     "acc_zbytesfromcachetoclient",
                     "acc_zbytesfromorigintoclient",
                     "acc_zbytesdropped",
                     "acc_zcreationdate"].contains(key)
                }
            }
            logger.log("forceUpdateMetrics erfolgreich")
            return .success(output)
        case .failure(let error):
            logger.error("forceUpdateMetrics Fehler: \(error.localizedDescription, privacy: .public)")
            return .failure(error)
        }
    }
    
    private func startAutoUpdate() {
        logger.log("Starte kontinuierlichen Timer für Metriken-Aktualisierung und Fortschritt")
        startTime = Date()
        cancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] currentTime in
                guard let self = self else { return }
                let elapsed = currentTime.timeIntervalSince(self.startTime)
                self.refreshProgress = min(elapsed / self.refreshInterval, 1.0)
                if elapsed >= self.refreshInterval {
                    _ = self.forceUpdateMetrics()
                    self.startTime = currentTime
                }
            }
    }
    
    /// Parser für den vollständigen Prometheus-Output.
    private func parseMetrics(_ string: String) -> [String: String] {
        var dict = [String: String]()
        let lines = string.split(separator: "\n")
        for line in lines {
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
