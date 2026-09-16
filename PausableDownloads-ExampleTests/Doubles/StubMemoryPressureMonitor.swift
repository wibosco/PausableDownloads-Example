//
//  StubMemoryPressureMonitor.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 11/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import Foundation

@testable import PausableDownloads_Example

class StubMemoryPressureMonitor: MemoryPressureMonitor {
    enum Event {
        case startMonitoring(() -> Void)
    }
    
    private(set) var events = [Event]()
    
    func startMonitoring(handler: @escaping () -> Void) {
        events.append(.startMonitoring(handler))
    }
}
