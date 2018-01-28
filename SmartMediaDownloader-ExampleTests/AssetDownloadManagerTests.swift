//
//  AssetDownloadManagerTests.swift
//  SmartMediaDownloader-ExampleTests
//
//  Created by William Boles on 28/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import XCTest

@testable import SmartMediaDownloader_Example

class AssetDownloadManagerTests: XCTestCase {
    
    class NotificationCenterSpy: NotificationCenter {
        
        var addObserverWasCalled = false
        var forNamePassedIn: NSNotification.Name?
        var closurePassedIn: ((Notification) -> Void)?
        
        override func addObserver(forName name: NSNotification.Name?, object obj: Any?, queue: OperationQueue?, using block: @escaping (Notification) -> Void) -> NSObjectProtocol {
            addObserverWasCalled = true
            forNamePassedIn = name
            closurePassedIn = block
            
            return NSObject()
        }
    }
    
    class AssetDownloadItemSpy: AssetDownloadItem {
        
        var hardCancelWasCalled = false
        
        init() {
            super.init(task: URLSessionDownloadTask())
        }
        
        override func hardCancel() {
            hardCancelWasCalled = true
        }
    }
    
    // MARK: - Lifecycle
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    // MARK: - Tests
    
    // MARK: Notification
    
    func test_init_notificationRegistration() {
        let notificationCenterSpy = NotificationCenterSpy()
        _ = AssetDownloadManager(notificationCenter: notificationCenterSpy)
        
        XCTAssertTrue(notificationCenterSpy.addObserverWasCalled)
        XCTAssertEqual(notificationCenterSpy.forNamePassedIn, NSNotification.Name.UIApplicationDidReceiveMemoryWarning)
        XCTAssertNotNil(notificationCenterSpy.closurePassedIn)
    }
    
    func test_init_notificationTriggeredClearsCanceledItems() {
        let manager = AssetDownloadManager()
        
        let itemA = AssetDownloadItemSpy()
        manager.canceled.append(itemA)
        
        let itemB = AssetDownloadItemSpy()
        manager.canceled.append(itemB)
        
        let itemC = AssetDownloadItemSpy()
        manager.canceled.append(itemC)
        
        NotificationCenter.default.post(name: NSNotification.Name.UIApplicationDidReceiveMemoryWarning, object: nil)
        
        XCTAssertTrue(manager.canceled.count == 0)
        XCTAssertTrue(itemA.hardCancelWasCalled)
        XCTAssertTrue(itemB.hardCancelWasCalled)
        XCTAssertTrue(itemC.hardCancelWasCalled)
    }
}
