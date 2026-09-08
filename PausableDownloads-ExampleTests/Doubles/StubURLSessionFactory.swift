//
//  StubURLSessionFactory.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 14/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation

@testable import PausableDownloads_Example

class StubURLSessionFactory: URLSessionFactoryType {
    enum Event {
        case defaultSession(URLSessionDelegate?, OperationQueue?)
    }
    
    private(set) var events = [Event]()
    
    var sessionToReturn: URLSessionType!
    
    func defaultSession(delegate: URLSessionDelegate?,
                        delegateQueue queue: OperationQueue?) -> URLSessionType {
        events.append(.defaultSession(delegate, queue))
        
        return sessionToReturn
    }
}
