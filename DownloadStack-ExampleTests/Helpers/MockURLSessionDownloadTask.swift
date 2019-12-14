//
//  MockURLSessionDownloadTask.swift
//  DownloadStack-ExampleTests
//
//  Created by William Boles on 13/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation

@testable import DownloadStack_Example

class MockURLSessionDownloadTask: URLSessionDownloadTaskType {
    
    var suspendClosure: (() -> ())?
    var resumeClosure: (() -> ())?
    var cancelClosure: (() -> ())?
    
    var currentRequest: URLRequest?
    
    func suspend() {
        suspendClosure?()
    }
    
    func resume() {
        resumeClosure?()
    }
    
    func cancel() {
        cancelClosure?()
    }
}
