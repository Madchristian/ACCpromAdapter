//
//  ACCpromAdapterApp.swift
//  ACCpromAdapter
//
//  Created by Christian Strube on 27.02.25.
//

import SwiftUI
import Combine


@main
struct ACCpromAdapterApp: App {
    @StateObject private var fetcher = MetricsFetcher()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    init() {
        // Starte den Prometheus-Exporter-Server beim App-Start
         PromExporterServer.shared.start()
    }
    var body: some Scene {
        MenuBarExtra("ACCpromAdapter", systemImage: "server.rack") {
            ContentView(fetcher: fetcher)
        }
    }
}
