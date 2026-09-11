//
//  MemoryPressureMonitor.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 11/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import Foundation

protocol MemoryPressureMonitor {
    func startMonitoring(handler: @escaping () -> Void)
}

final class DefaultMemoryPressureMonitor: MemoryPressureMonitor {
    private var source: DispatchSourceMemoryPressure
    private let queue: DispatchQueue
    
    // MARK: - Init
    
    init() {
        let queue = DispatchQueue(label: "com.williamboles.memorypressure")
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical],
                                                             queue: queue)
        self.queue = queue
        self.source = source
    }
    
    // MARK: - Monitoring
    
    func startMonitoring(handler: @escaping () -> Void) {
        source.setEventHandler(handler: handler)
        source.resume()
    }
    
    // MARK: - Deinit
    
    deinit {
        source.cancel()
    }
}
