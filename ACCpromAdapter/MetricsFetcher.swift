//
//  MetricsFetcher.swift
//  ACCpromAdapter
//
//  Created by Christian Strube on 27.02.25.
//
import Foundation
import Combine
import os

class MetricsFetcher: ObservableObject {
    @Published var metrics: [String: String] = [:]
    @Published var serverReady: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "de.cstrube.ACCpromAdapter", category: "MetricsFetcher")

    init() {
        // Beobachte, ob der Server gestartet wurde.
        NotificationCenter.default.publisher(for: Notification.Name("PrometheusServerDidStart"))
            .sink { [weak self] _ in
                self?.logger.log("Server Ready Notification erhalten")
                self?.serverReady = true
                self?.bindToMetricsCache()
            }
            .store(in: &cancellables)
    }

    /// Abonniert den gefilterten Metrik-Output aus MetricsCache.
    private func bindToMetricsCache() {
        MetricsCache.shared.$filteredMetrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedMetrics in
                self?.metrics = updatedMetrics
                self?.logger.log("UI-Metriken aktualisiert")
            }
            .store(in: &cancellables)
    }
}
