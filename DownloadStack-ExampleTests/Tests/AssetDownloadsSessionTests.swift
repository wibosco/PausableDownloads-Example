//
//  AssetDownloadsSessionTests.swift
//  DownloadStack-ExampleTests
//
//  Created by William Boles on 15/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import XCTest

@testable import DownloadStack_Example

class AssetDownloadsSessionTests: XCTestCase {
    
    var sut: AssetDownloadsSession!
    
    var notificationCenter: MockNotificationCenter!
    
    // MARK: - Lifecycle
    
    override func setUp() {
        super.setUp()
        
        notificationCenter = MockNotificationCenter()
        
        sut = AssetDownloadsSession(notificationCenter: notificationCenter)
    }

    override func tearDown() {
        notificationCenter = nil
        
        sut = nil
        
        super.tearDown()
    }
    
    // MARK: - Tests
    
    // MARK: Notification
    
    func test_init_notificationRegistration() {
        let notificationCenter = MockNotificationCenter()
        let addObserverExpectation = expectation(description: "addObserverExpectation")
        notificationCenter.addObserverClosure = { (name, object, queue, block) in
            XCTAssertEqual(name, UIApplication.didReceiveMemoryWarningNotification)
            
            addObserverExpectation.fulfill()
        }
        
        _ = AssetDownloadsSession(notificationCenter: notificationCenter)
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func test_init_notificationTriggeredClearsCanceledItems() {
//        let notificationCenter = MockNotificationCenter()
//        let addObserverExpectation = expectation(description: "addObserverExpectation")
//        notificationCenter.addObserverClosure = { (name, object, queue, block) in
//            XCTAssertEqual(name, UIApplication.didReceiveMemoryWarningNotification)
//            
//            addObserverExpectation.fulfill()
//        }
//        
//        let sut = AssetDownloadsSession(notificationCenter: notificationCenter)
//        
//        waitForExpectations(timeout: 3, handler: nil)
    }
}
