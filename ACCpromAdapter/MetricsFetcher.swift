//
//  MetricsFetcher.swift
//  ACCpromAdapter
//
//  Created by Christian Strube on 27.03.25.
//

import Foundation
import Combine
import os

class MetricsFetcher: ObservableObject {
    @Published var metrics: [String: String] = [:]
    @Published var serverReady: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "de.cstrube.ACCpromAdapter", category: "MetricsFetcher")
    
    private let metricsURL = URL(string: "http://localhost:9200/metrics")!
    private let refreshInterval: TimeInterval = 30.0
    private var timer: AnyCancellable?

    init() {
        NotificationCenter.default.publisher(for: Notification.Name("AppInitializationComplete"))
            .sink { [weak self] _ in
                self?.logger.log("📡 App-Initialisierung abgeschlossen – Starte periodischen Abruf.")
                self?.startFetching()
            }
            .store(in: &cancellables)
    }

    private func startFetching() {
        if AppInitializer.shared.useExternalDaemon {
            logger.log("🟢 Verwende externen Daemon für Metriken.")
            startFetchingMetrics()
        } else {
            logger.log("📂 Verwende lokale Datenbank für Metriken. (Kein periodischer Abruf erforderlich)")
            startFetchingMetrics()
        }
    }
    
    private func startFetchingMetrics() {
        fetchMetrics()
        
        timer = Timer.publish(every: refreshInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchMetrics()
            }
    }

    private func fetchMetrics() {
        logger.log("Starte Abruf von \(self.metricsURL.absoluteString, privacy: .public)")
        
        URLSession.shared.dataTaskPublisher(for: metricsURL)
            .timeout(.seconds(5), scheduler: DispatchQueue.global(qos: .background))
            .map { (data, response) -> [String: String]? in
                guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                    return nil
                }
                return self.parseMetrics(data)
            }
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure = completion {
                    self.logger.error("Daemon nicht erreichbar.")
                    self.serverReady = false
                }
            }, receiveValue: { [weak self] metrics in
                guard let self = self, let metrics = metrics else {
                    self?.serverReady = false
                    return
                }
                self.metrics = metrics
                self.serverReady = true
                self.logger.log("Metriken erfolgreich aktualisiert.")
            })
            .store(in: &cancellables)
    }

    private func parseMetrics(_ data: Data) -> [String: String] {
        guard let rawText = String(data: data, encoding: .utf8) else { return [:] }
        var parsedMetrics: [String: String] = [:]
        
        rawText.split(separator: "\n").forEach { line in
            if line.hasPrefix("#") { return }
            let components = line.split(separator: " ", maxSplits: 1)
            if components.count == 2 {
                let key = String(components[0])
                let value = String(components[1])
                parsedMetrics[key] = value
            }
        }
        return parsedMetrics
    }
}
