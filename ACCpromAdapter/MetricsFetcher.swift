//
//  MetricsFetcher.swift
//  ACCpromAdapter
//
//  Created by Christian Strube on 27.02.25.
//
import SwiftUI

class MetricsFetcher: ObservableObject {
    @Published var metrics: [String: String] = [:]
    
    private var timer: Timer?
    
    init() {
        fetchMetrics()
        startAutoRefresh()
    }
    
    func fetchMetrics() {
        guard let url = URL(string: "http://127.0.0.1:9200/metrics") else { return }
        
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 5 // z. B. 15 Sekunden
        let session = URLSession(configuration: config)
        
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            session.dataTask(with: url) { data, response, error in
                guard let data = data, error == nil,
                      let metricsString = String(data: data, encoding: .utf8) else {
                    print("FetchMetrics Error: \(error?.localizedDescription ?? "Unbekannter Fehler")")
                    return
                }
                
                DispatchQueue.main.async {
                    self.metrics = self.parseMetrics(metricsString)
                }
            }.resume()
        }
    }
    
    private func parseMetrics(_ metricsString: String) -> [String: String] {
        var parsedMetrics: [String: String] = [:]
        let lines = metricsString.split(separator: "\n")
        
        for line in lines {
            if line.hasPrefix("#") { continue } // Kommentare überspringen
            let components = line.split(separator: " ")
            if components.count == 2 {
                let key = String(components[0]).replacingOccurrences(of: "acc_", with: "").replacingOccurrences(of: "_", with: " ")
                let value = String(components[1])
                parsedMetrics[key] = value
            }
        }
        
        return parsedMetrics
    }
    
    private func startAutoRefresh() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            self.fetchMetrics()
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}
