//
//  ACCpromAdapterApp.swift
//  ACCpromAdapter
//
//  Created by Christian Strube on 27.02.25.
//

import SwiftUI
import Combine
import os

// Erstelle einen globalen Logger (verfügbar ab macOS 11)
let appLogger = Logger(subsystem: "de.cstrube.ACCpromAdapter", category: "main")

@main
struct ACCpromAdapterApp: App {
    @StateObject private var fetcher = MetricsFetcher()
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        appLogger.log("ACCpromAdapterApp initialisiert")
        // Kein Serverstart hier – das übernimmt AppDelegate, sobald die Datei verfügbar ist.
    }
    
    var body: some Scene {
        MenuBarExtra("ACCpromAdapter", systemImage: "server.rack") {
            ContentView(fetcher: fetcher)
        }
        .menuBarExtraStyle(.window) // oder .automatic
    }
}
