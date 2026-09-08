//
//  StubNotificationCenter.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 14/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation

@testable import PausableDownloads_Example

class StubNotificationCenter: NotificationCenterType {
    enum Event {
        case addObserver(NSNotification.Name?, Any?, OperationQueue?, (Notification) -> Void)
    }
    
    private(set) var events = [Event]()
    
    var objectToReturn: NSObjectProtocol!
    
    func addObserver(forName name: NSNotification.Name?,
                     object obj: Any?,
                     queue: OperationQueue?,
                     using block: @escaping (Notification) -> Void) -> NSObjectProtocol {
        events.append(.addObserver(name,
                                   obj,
                                   queue,
                                   block))
        
        return objectToReturn
    }
}
