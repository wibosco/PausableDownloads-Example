//
//  MockNotificationCenter.swift
//  DownloadStack-ExampleTests
//
//  Created by William Boles on 14/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation

@testable import DownloadStack_Example

class MockNotificationCenter: NotificationCenterType {
    
    var addObserverClosure: ((_ name: NSNotification.Name?, _ obj: Any?, _ queue: OperationQueue?, _ block: ((Notification) -> Void)) -> ())?
    
    func addObserver(forName name: NSNotification.Name?, object obj: Any?, queue: OperationQueue?, using block: @escaping (Notification) -> Void) -> NSObjectProtocol {
        addObserverClosure?(name, obj, queue, block)
        
        return NSObject()
    }
}
