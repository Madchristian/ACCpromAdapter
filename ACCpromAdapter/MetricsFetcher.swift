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

    /// Verbindet sich mit `MetricsCache`, um automatisch Updates zu erhalten.
    private func bindToMetricsCache() {
        MetricsCache.shared.$metrics
            .receive(on: DispatchQueue.main)
            .sink { [weak self] updatedMetrics in
                self?.metrics = updatedMetrics
                self?.logger.log("Metriken für UI aktualisiert")
            }
            .store(in: &cancellables)
    }
}
