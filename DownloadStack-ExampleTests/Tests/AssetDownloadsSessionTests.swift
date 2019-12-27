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
    
    var sessionFactory: MockURLSessionFactory!
    var session: MockURLSession!
    var notificationCenter: MockNotificationCenter!
    
    let url = URL(string: "http://test.com/example")!
    
    // MARK: - Lifecycle
    
    override func setUp() {
        super.setUp()
        
        sessionFactory = MockURLSessionFactory()
        session = MockURLSession()
        sessionFactory.defaultSession = session
        notificationCenter = MockNotificationCenter()
        
        sut = AssetDownloadsSession(urlSessionFactory: sessionFactory, notificationCenter: notificationCenter)
    }

    override func tearDown() {
        notificationCenter = nil
        sessionFactory = nil
        session = nil
        
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
    
    // MARK: Schedule
    
    func test_scheduleDownload_schedules() {
        sut.scheduleDownload(url: url, immediateDownload: false) { _ in }

        
    }
}
