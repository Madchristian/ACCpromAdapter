//
//  PrometheusServer.swift
//  ACCpromAdapter
//
//  Created by Christian Strube on 01.03.25.
//

import Foundation
import NIO
import NIOHTTP1
import os
import AppKit

class PrometheusServer {
    static let shared = PrometheusServer(analyzer: AssetCacheAnalyzer())
    
    private let logger: Logger
    private var group: MultiThreadedEventLoopGroup?
    private var channel: Channel?
    private var isRunning = false
    private let analyzer: AssetCacheAnalyzing
    
    init(analyzer: AssetCacheAnalyzing,
         logger: Logger = Logger(subsystem: "de.cstrube.ACCpromAdapter", category: "PrometheusServer")) {
        self.analyzer = analyzer
        self.logger = logger
    }
    
    func start(on port: Int = 9200) {
        guard !isRunning else {
            logger.log("Server läuft bereits.")
            return
        }
        isRunning = true
        logger.log("Starte Prometheus-Server auf Port \(port, privacy: .public)")
        group = MultiThreadedEventLoopGroup(numberOfThreads: System.coreCount)
        
        let bootstrap = ServerBootstrap(group: group!)
            .serverChannelOption(ChannelOptions.backlog, value: 256)
            .serverChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(HTTPHandler(logger: self.logger))
                }
            }
            .childChannelOption(ChannelOptions.socket(SocketOptionLevel(SOL_SOCKET), SO_REUSEADDR), value: 1)
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 16)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())
        
        do {
            channel = try bootstrap.bind(host: "0.0.0.0", port: port).wait()
            logger.log("Prometheus-Server läuft auf: \(String(describing: self.channel?.localAddress), privacy: .public)")
            // Sende Notification, dass der Server gestartet wurde:
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name("PrometheusServerDidStart"), object: nil)
            }
            try channel?.closeFuture.wait()
        } catch {
            logger.error("Fehler beim Starten des Servers: \(error.localizedDescription, privacy: .public)")
        }
    }
    
    func stop() {
        do {
            try channel?.close().wait()
            try group?.syncShutdownGracefully()
            isRunning = false
            logger.log("Prometheus-Server gestoppt.")
        } catch {
            logger.error("Fehler beim Stoppen des Servers: \(error.localizedDescription, privacy: .public)")
        }
    }
}


final class HTTPHandler: ChannelInboundHandler {
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart

    private let logger: Logger
    private var responseSent = false

    init(logger: Logger) {
        self.logger = logger
    }

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = unwrapInboundIn(data)
        switch reqPart {
        case .head(let request):
            // Bei jedem neuen Request-Head das Flag zurücksetzen
            responseSent = false
            // Überprüfe, ob es sich um den gewünschten GET /metrics handelt.
            if request.method != .GET || request.uri != "/metrics" {
                sendNotFound(context: context, request: request)
                responseSent = true
                return
            }
        case .body:
            // Ignoriere den Body
            break
        case .end:
            // Nur antworten, wenn noch keine Antwort gesendet wurde
            guard !responseSent else { return }
            logger.log("Erhalte Anfrage für /metrics")
            let metrics = MetricsCache.shared.fullMetrics
            let status: HTTPResponseStatus = .ok
            var headers = HTTPHeaders()
            headers.add(name: "Content-Type", value: "text/plain; charset=utf-8")
            headers.add(name: "Content-Length", value: "\(metrics.utf8.count)")
            let head = HTTPResponseHead(version: .init(major: 1, minor: 1), status: status, headers: headers)
            
            context.write(wrapOutboundOut(.head(head)), promise: nil)
            var buffer = context.channel.allocator.buffer(capacity: metrics.utf8.count)
            buffer.writeString(metrics)
            context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
            context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
            responseSent = true
        }
    }
    
    private func sendNotFound(context: ChannelHandlerContext, request: HTTPRequestHead) {
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "text/plain; charset=utf-8")
        let head = HTTPResponseHead(version: request.version, status: .notFound, headers: headers)
        context.write(wrapOutboundOut(.head(head)), promise: nil)
        var buffer = context.channel.allocator.buffer(capacity: 9)
        buffer.writeString("Not Found")
        context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
        context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
    }
    
    func errorCaught(context: ChannelHandlerContext, error: Error) {
        logger.error("HTTPHandler error: \(error.localizedDescription, privacy: .public)")
        context.close(promise: nil)
    }
}
