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
    private let source: DispatchSourceMemoryPressure
    
    // MARK: - Init
    
    init() {
        source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical],
                                                         queue: DispatchQueue(label: "com.williamboles.memorypressure"))
        source.activate()
    }
    
    // MARK: - Monitoring
    
    func startMonitoring(handler: @escaping () -> Void) {
        source.setEventHandler(handler: handler)
    }
    
    // MARK: - Deinit
    
    deinit {
        source.cancel()
    }
}
