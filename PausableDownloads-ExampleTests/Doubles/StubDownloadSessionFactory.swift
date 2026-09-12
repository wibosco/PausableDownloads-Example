//
//  StubDownloadSessionFactory.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 14/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation

@testable import PausableDownloads_Example

class StubDownloadSessionFactory: DownloadSessionFactory {
    enum Event {
        case makeSession(URLSessionDelegate)
    }
    
    private(set) var events = [Event]()
    
    var sessionToReturn: DownloadSession!
    
    func makeSession(delegate: URLSessionDelegate) -> DownloadSession {
        events.append(.makeSession(delegate))
        
        return sessionToReturn
    }
}
