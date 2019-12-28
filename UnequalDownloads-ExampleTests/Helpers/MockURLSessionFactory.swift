//
//  MockURLSessionFactory.swift
//  UnequalDownloads-ExampleTests
//
//  Created by William Boles on 14/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import Foundation

@testable import UnequalDownloads_Example

class MockURLSessionFactory: URLSessionFactoryType {
    
    var defaultSession: URLSessionType = MockURLSession()
    var downloadTaskClosure: ((_ delegate: URLSessionDelegate?, _ delegateQueue: OperationQueue?) -> ())?
    
    func defaultSession(delegate: URLSessionDelegate?, delegateQueue queue: OperationQueue?) -> URLSessionType {
        downloadTaskClosure?(delegate, queue)
        
        return defaultSession
    }
}
