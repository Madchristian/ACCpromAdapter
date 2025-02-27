//
//  PromExporterServer.swift
//  ACCpromAdapter
//
//  Created by Christian Strube on 27.02.25.
//

import Foundation
import NIO
import NIOHTTP1
import SQLite3

class PromExporterServer {
    static let shared = PromExporterServer()
    
    private var group: MultiThreadedEventLoopGroup?
    private var channel: Channel?
    private var isRunning = false
    
    /// Startet den HTTP-Server auf Port 9200 im Hintergrund
    func start() {
        // Falls der Server bereits läuft, nicht nochmal starten
        guard !isRunning else {
            print("PromExporterServer bereits gestartet.")
            return
        }
        isRunning = true
        print("Starte PromExporterServer...")
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self else { return }
            self.group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
            
            let bootstrap = ServerBootstrap(group: self.group!)
                .serverChannelOption(ChannelOptions.backlog, value: 256)
                .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
                .childChannelInitializer { channel in
                    channel.pipeline.configureHTTPServerPipeline().flatMap {
                        channel.pipeline.addHandler(HTTPHandler())
                    }
                }
                .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
                .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
                .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
            
            do {
                self.channel = try bootstrap.bind(host: "0.0.0.0", port: 9200).wait()
                print("PromExporterServer läuft auf: \(self.channel?.localAddress?.description ?? "Unbekannt")")
                try self.channel?.closeFuture.wait()
            } catch {
                print("Fehler beim Starten des PromExporterServer: \(error)")
            }
        }
    }
    
    func stop() {
        do {
            try channel?.close().wait()
            try group?.syncShutdownGracefully()
            isRunning = false
        } catch {
            print("Fehler beim Stoppen des Servers: \(error)")
        }
    }
}


/// Liest den neuesten Eintrag aus der Metrics‑Datenbank und gibt für jede Spalte (außer creationDate)
/// eine Prometheus-konforme Ausgabe zurück. Falls creationDate vorhanden ist, wird er als Label hinzugefügt.
func readLatestMetrics() -> (output: String, error: String?) {
    let dbPath = "/Library/Application Support/Apple/AssetCache/Metrics/Metrics.db"
    var output = ""
    var db: OpaquePointer?
    
    // Öffne die Datenbank
    guard sqlite3_open(dbPath, &db) == SQLITE_OK else {
        let errMsg = db != nil ? String(cString: sqlite3_errmsg(db)) : "Unknown error"
        return ("", "Fehler beim Öffnen der Datenbank: \(errMsg)")
    }
    
    // Ermittele alle Spaltennamen aus der Tabelle "metrics" per PRAGMA
    var pragmaStatement: OpaquePointer?
    let pragmaQuery = "PRAGMA table_info(ZMETRIC)"
    if sqlite3_prepare_v2(db, pragmaQuery, -1, &pragmaStatement, nil) != SQLITE_OK {
        let errMsg = String(cString: sqlite3_errmsg(db))
        sqlite3_close(db)
        return ("", "Fehler beim Vorbereiten des PRAGMA: \(errMsg)")
    }
    
    var columns = [String]()
    while sqlite3_step(pragmaStatement) == SQLITE_ROW {
        if let cString = sqlite3_column_text(pragmaStatement, 1) {
            let colName = String(cString: cString)
            columns.append(colName)
        }
    }
    sqlite3_finalize(pragmaStatement)
    
    if columns.isEmpty {
        sqlite3_close(db)
        return ("", "Keine Spalten in der Tabelle gefunden.")
    }
    
    // Wähle den neuesten Datensatz (ORDER BY creationDate DESC LIMIT 1)
    let query = "SELECT " + columns.joined(separator: ", ") + " FROM ZMETRIC ORDER BY ZCREATIONDATE DESC LIMIT 1"
    var statement: OpaquePointer?
    if sqlite3_prepare_v2(db, query, -1, &statement, nil) != SQLITE_OK {
        let errMsg = String(cString: sqlite3_errmsg(db))
        sqlite3_close(db)
        return ("", "Fehler beim Vorbereiten des SELECT-Statements: \(errMsg)")
    }
    
    guard sqlite3_step(statement) == SQLITE_ROW else {
        sqlite3_finalize(statement)
        sqlite3_close(db)
        return ("", "Keine Daten in der Tabelle gefunden.")
    }
    
    // Erstelle die Prometheus-Ausgabe: Für jede Spalte (außer creationDate) einen eigenen Metrik-Eintrag.
    var creationDateValue: String = ""
    var metricLines = [String]()
    for (index, colName) in columns.enumerated() {
        let colType = sqlite3_column_type(statement, Int32(index))
        var valueString = ""
        switch colType {
        case SQLITE_INTEGER:
            let intValue = sqlite3_column_int64(statement, Int32(index))
            valueString = "\(intValue)"
        case SQLITE_FLOAT:
            let doubleValue = sqlite3_column_double(statement, Int32(index))
            valueString = "\(doubleValue)"
        case SQLITE_TEXT:
            if let text = sqlite3_column_text(statement, Int32(index)) {
                valueString = String(cString: text)
            }
        case SQLITE_NULL:
            valueString = "NaN"
        default:
            valueString = "NaN"
        }
        
        // Entferne das führende "Z" für einen sauberen Metriknamen
        let baseName = colName.hasPrefix("Z") ? String(colName.dropFirst()) : colName
        
        // Falls es sich um REQUESTSREJECTEDFORNOSPACE handelt, entferne alle "%" im Wert
        if baseName.uppercased() == "REQUESTSREJECTEDFORNOSPACE" {
            valueString = valueString.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)
        }
        
        // Falls die Spalte CREATIONDATE ist, speichern wir den Wert separat.
        if baseName.uppercased() == "CREATIONDATE" {
            creationDateValue = valueString
            continue
        }
        
        let metricName = "acc_\(baseName.lowercased())"
        
        metricLines.append("# HELP \(metricName) Metrik \(baseName)")
        metricLines.append("# TYPE \(metricName) gauge")
        if !creationDateValue.isEmpty {
            metricLines.append("\(metricName){creationDate=\"\(creationDateValue)\"} \(valueString)")
        } else {
            metricLines.append("\(metricName) \(valueString)")
        }
    }
    
    sqlite3_finalize(statement)
    sqlite3_close(db)
    
    output = metricLines.joined(separator: "\n")
    return (output, nil)
}

/// HTTPHandler, der Anfragen verarbeitet und bei GET /metrics den Prometheus-Output liefert.
final class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    
    private var hasResponded = false
    
    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        // Falls bereits geantwortet wurde, ignoriere weitere Teile
        if hasResponded { return }
        
        let reqPart = self.unwrapInboundIn(data)
        switch reqPart {
        case .head(let request):
            // Wir reagieren nur auf GET /metrics
            if !(request.method == .GET && request.uri == "/metrics") {
                sendNotFound(context: context, request: request)
                hasResponded = true
                return
            }
        case .body:
            break
        case .end:
            let result = readLatestMetrics()
            let (status, responseString): (HTTPResponseStatus, String) = {
                if let errorMessage = result.error {
                    return (.internalServerError, "Internal Server Error:\n\(errorMessage)")
                } else {
                    return (.ok, result.output)
                }
            }()
            
            var headers = HTTPHeaders()
            headers.add(name: "Content-Type", value: "text/plain; charset=utf-8")
            headers.add(name: "Content-Length", value: "\(responseString.utf8.count)")
            let responseHead = HTTPResponseHead(version: .init(major: 1, minor: 1), status: status, headers: headers)
            
            // Schreibe alle Teile der Antwort
            context.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
            var buffer = context.channel.allocator.buffer(capacity: responseString.utf8.count)
            buffer.writeString(responseString)
            context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            // Nur einmal flushen – schließe damit die Antwort ab:
            context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: nil)
            hasResponded = true
        }
    }
    
    private func sendNotFound(context: ChannelHandlerContext, request: HTTPRequestHead) {
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/plain; charset=utf-8")
        let responseHead = HTTPResponseHead(version: request.version, status: .notFound, headers: headers)
        
        var buffer = context.channel.allocator.buffer(capacity: 9)
        buffer.writeString("Not Found")
        
        // Erstelle einen Promise für Void
        let promise = context.eventLoop.makePromise(of: Void.self)
        
        // Schreibe die Antwort und übergebe den Promise
        context.write(self.wrapOutboundOut(.head(responseHead)), promise: nil)
        context.write(self.wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        context.writeAndFlush(self.wrapOutboundOut(.end(nil)), promise: promise)
        
        // Wenn das Schreiben abgeschlossen ist, schließe den Kanal
        promise.futureResult.whenComplete { _ in
            context.close(promise: nil)
        }
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        print("HTTPHandler Fehler: \(error)")
        context.close(promise: nil)
    }
}
