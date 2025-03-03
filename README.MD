# ACCpromAdapter

**Version:** 1.0  
**Author:** Christian Strube  
**License:** MIT

---

## 📝 Description

ACCPromAdapter is a macOS menu bar application that monitors the Apple Content Cache and provides metrics in Prometheus format. The app reads the Metrics.db file from the system directory and serves the data through an integrated HTTP server, making it easy to integrate with Grafana or other monitoring tools.

Additionally, we offer the **ACCPromAdapterDaemon** for headless installations—ideal for servers and headless Mac Minis where the service runs automatically at system startup and collects metrics without requiring a user to log in.

---

## 🎯 Features

- **Prometheus-Compatible Metrics:** All data is output in a standard format that can be directly scraped by Prometheus.
- **Lightweight HTTP Server:** Runs on port 9200 and serves metrics either via an external daemon or, as a fallback, through an internal server.
- **Security-Scoped Bookmarks:** Enables access to protected files such as Metrics.db.
- **Menu Bar Only (No Dock Icon):** The app runs discreetly in the menu bar.
- **Simple Configuration:** The app saves your file selection once, so you won’t need to choose the file repeatedly.
- **Automatic Updates:** Metrics are automatically refreshed every 30 seconds using Combine, with a progress indicator showing the update cycle.
- **Headless Installation:** The ACCPromAdapterDaemon allows administrators to install the service system-wide, ensuring continuous metrics collection even without user login.

---

## 🏗️ Architecture

The project is written in **Swift** and utilizes:
- **SwiftUI** for the menu bar interface
- **SwiftNIO** for the HTTP server
- **Combine** for automatic updates
- **SQLite3** for reading the Metrics.db file

**Core Components:**

1. **AppDelegate.swift**  
   - Initializes the app and checks if port 9200 is available.
   - Manages access to the Metrics.db using Security-Scoped Bookmarks.
   - Opens a file dialog if no file has been saved yet.

2. **AppInitializer.swift**  
   - Handles the centralized initialization of the app, deciding whether to use external HTTP metrics or fall back to the local database, and only starts the UI after this process is complete.

3. **PrometheusServer.swift**  
   - Starts an HTTP server with SwiftNIO on port 9200 that returns metrics from MetricsCache.

4. **AssetCacheAnalyzer.swift**  
   - Reads the Metrics.db using SQLite and converts the data into Prometheus-compatible output.
   - Parses numeric values and units (e.g., MB, GB) appropriately.

5. **MetricsCache.swift**  
   - Periodically updates metrics from the local database (if no external daemon is available) and provides them to the UI.

6. **MetricsFetcher.swift**  
   - Uses Combine to observe and fetch metrics via HTTP when an external daemon is active.

7. **ContentView.swift**  
   - The menu bar interface displaying key metrics.
   - Includes buttons for opening the metrics URL in Safari, copying the URL, resetting defaults, and quitting the app.

---

## 🚀 Installation

1. **Clone the Project:**
   ```bash
   git clone https://github.com/your-github/ACCpromAdapter.git
   cd ACCpromAdapter

    2.    Open in Xcode:

open ACCpromAdapter.xcodeproj


    3.    Set Up Code Signing:
    •    In Xcode, navigate to “Signing & Capabilities” and enter your Developer ID as needed.
    4.    Run the App:
    •    Press Cmd + R to build and run the app.
    5.    ACCPromAdapterDaemon:
    •    The installation package ACCPromAdapterDaemon.pkg is available via GitHub Releases or as a direct download on the blog. Install the daemon to use it system-wide.

🔧 Troubleshooting
    •    No Access to Metrics.db:
Make sure the app is granted Full Disk Access in System Preferences → Security & Privacy.
    •    Port 9200 is Blocked:
Check with:

lsof -i :9200

If another process is using the port, terminate it with:

kill -9 <PID>


    •    No Metrics in Grafana:
Verify that the Prometheus URL is correct:

http://localhost:9200/metrics

📌 License

This software is provided under the MIT License.

MIT License:

MIT License

Copyright (c) [Year] Christian Strube

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Usage Restrictions:
    •    The software must be used in its original, unmodified form. Modifications or derivative works are not permitted without explicit authorization.

📌 Planned Features
    •    XPC Service for Sandbox Mode
    •    More Detailed Metrics with Units (MB, GB, KB)
    •    Automatic Installation as a LaunchDaemon
    •    Notifications for Critical Cache Levels

Deployment

The current version of the ACCpromAdapter App and the daemon are available as a release. Visit the Releases Page to download the installation package.

For any questions or feedback, please contact me via GitHub or email.
