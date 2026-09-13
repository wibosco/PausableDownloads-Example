//
//  StubDownloadTask.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 13/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation

@testable import PausableDownloads_Example

class StubDownloadTask: DownloadTask {
    enum Event {
        case resume
        case cancelByProducingResumeData((Data?) -> Void)
    }
    
    private(set) var events = [Event]()
    
    var taskIdentifierToReturn: Int!
    
    var taskIdentifier: Int {
        taskIdentifierToReturn
    }
    
    // MARK: - Task
    
    func resume() {
        events.append(.resume)
    }
    
    func cancel(byProducingResumeData completionHandler: @escaping (Data?) -> Void) {
        events.append(.cancelByProducingResumeData(completionHandler))
    }
}
