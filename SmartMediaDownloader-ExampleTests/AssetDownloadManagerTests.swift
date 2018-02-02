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
        var resumeWasCalled = false
        
        init() {
            super.init(task: URLSessionDownloadTask())
        }
        
        override func hardCancel() {
            hardCancelWasCalled = true
        }
        
        override func resume() {
            resumeWasCalled = true
        }
    }
    
    // MARK: - Lifecycle
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        AssetDownloadManager.maximumConcurrentDownloadsResetValue = Int.max
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
    
    // MARK: ScheduleDownload
    
    func test_scheduleDownload_schedules() {
        let manager = AssetDownloadManager()
        let url = URL(string: "http://test.com")!
        manager.scheduleDownload(url: url, forceDownload: false) { _ in }
        
        XCTAssertTrue(manager.downloading.count == 1)
    }
    
    func test_scheduleDownload_multipleConncurrentDownloads() {
        let manager = AssetDownloadManager()
        let urlA = URL(string: "http://testA.com")!
        manager.scheduleDownload(url: urlA, forceDownload: false) { _ in }
        
        let urlB = URL(string: "http://testB.com")!
        manager.scheduleDownload(url: urlB, forceDownload: false) { _ in }
        
        XCTAssertTrue(manager.downloading.count == 2)
    }
    
    func test_scheduleDownload_queuingDownloadsWhenLimitIsMeet() {
        let manager = AssetDownloadManager()
        manager.maximumConcurrentDownloads = 1
        AssetDownloadManager.maximumConcurrentDownloadsResetValue = 1
        let urlA = URL(string: "http://testA.com")!
        manager.scheduleDownload(url: urlA, forceDownload: false) { _ in }
        
        let urlB = URL(string: "http://testB.com")!
        manager.scheduleDownload(url: urlB, forceDownload: false) { _ in }
        
        XCTAssertTrue(manager.downloading.count == 1)
        XCTAssertTrue(manager.waiting.count == 1)
    }
    
    func test_scheduleDownload_forceDownload() {
        let manager = AssetDownloadManager()
        let urlA = URL(string: "http://testA.com")!
        manager.scheduleDownload(url: urlA, forceDownload: false) { _ in }
        
        let urlB = URL(string: "http://testB.com")!
        manager.scheduleDownload(url: urlB, forceDownload: false) { _ in }
        
        let urlC = URL(string: "http://testC.com")!
        manager.scheduleDownload(url: urlC, forceDownload: true) { _ in }
        
        XCTAssertTrue(manager.downloading.count == 1)
        XCTAssertTrue(manager.waiting.count == 2)
        XCTAssertTrue(manager.canceled.count == 0)
        
        let item = manager.downloading.last!
        XCTAssertEqual(item.url, urlC)
        XCTAssertTrue(item.forceDownload)
    }
    
    func test_scheduleDownload_coalesceCurrentlyDownloading() {
        let manager = AssetDownloadManager()
        let url = URL(string: "http://testA.com")!
        manager.scheduleDownload(url: url, forceDownload: false) { _ in }
        manager.scheduleDownload(url: url, forceDownload: false) { _ in }
        
        XCTAssertTrue(manager.downloading.count == 1)
        XCTAssertTrue(manager.waiting.count == 0)
        XCTAssertTrue(manager.canceled.count == 0)
    }
    
    func test_scheduleDownload_coalesceCurrentlyDownloadingAndForceDownload() {
        let manager = AssetDownloadManager()
        let urlA = URL(string: "http://testA.com")!
        manager.scheduleDownload(url: urlA, forceDownload: false) { _ in }
        
        let urlB = URL(string: "http://testB.com")!
        manager.scheduleDownload(url: urlB, forceDownload: false) { _ in }
        manager.scheduleDownload(url: urlB, forceDownload: true) { _ in }
        
        XCTAssertTrue(manager.downloading.count == 1)
        XCTAssertTrue(manager.waiting.count == 1)
        XCTAssertTrue(manager.canceled.count == 0)
        
        let item = manager.downloading.last!
        XCTAssertEqual(item.url, urlB)
        XCTAssertTrue(item.forceDownload)
    }
    
    func test_scheduleDownload_coalesceWaitingDownloading() {
        let manager = AssetDownloadManager()
        manager.maximumConcurrentDownloads = 1
        AssetDownloadManager.maximumConcurrentDownloadsResetValue = 1
        
        let urlA = URL(string: "http://testA.com")!
        manager.scheduleDownload(url: urlA, forceDownload: false) { _ in }
        
        let urlB = URL(string: "http://testB.com")!
        manager.scheduleDownload(url: urlB, forceDownload: false) { _ in }
        manager.scheduleDownload(url: urlB, forceDownload: false) { _ in }
        
        XCTAssertTrue(manager.downloading.count == 1)
        XCTAssertTrue(manager.waiting.count == 1)
        XCTAssertTrue(manager.canceled.count == 0)
    }
    
    func test_scheduleDownload_coalesceWaitingDownloadingAndMoveToFront() {
        let manager = AssetDownloadManager()
        manager.maximumConcurrentDownloads = 1
        AssetDownloadManager.maximumConcurrentDownloadsResetValue = 1
        
        let urlA = URL(string: "http://testA.com")!
        manager.scheduleDownload(url: urlA, forceDownload: false) { _ in }
        
        let urlB = URL(string: "http://testB.com")!
        manager.scheduleDownload(url: urlB, forceDownload: false) { _ in }
        
        let urlC = URL(string: "http://testC.com")!
        manager.scheduleDownload(url: urlC, forceDownload: false) { _ in }
        
        manager.scheduleDownload(url: urlB, forceDownload: false) { _ in }
        
        XCTAssertTrue(manager.downloading.count == 1)
        XCTAssertTrue(manager.waiting.count == 2)
        XCTAssertTrue(manager.canceled.count == 0)
        
        let item = manager.waiting.last
        XCTAssertEqual(item?.url, urlB)
    }
    
    func test_scheduleDownload_coalesceCurrentlyWaitingAndForceDownload() {
        let manager = AssetDownloadManager()
        manager.maximumConcurrentDownloads = 1
        AssetDownloadManager.maximumConcurrentDownloadsResetValue = 1
        
        let urlA = URL(string: "http://testA.com")!
        manager.scheduleDownload(url: urlA, forceDownload: false) { _ in }
        
        let urlB = URL(string: "http://testB.com")!
        manager.scheduleDownload(url: urlB, forceDownload: false) { _ in }
        manager.scheduleDownload(url: urlB, forceDownload: true) { _ in }
        
        XCTAssertTrue(manager.downloading.count == 1)
        XCTAssertTrue(manager.waiting.count == 1)
        XCTAssertTrue(manager.canceled.count == 0)
        
        let item = manager.downloading.last!
        XCTAssertEqual(item.url, urlB)
        XCTAssertTrue(item.forceDownload)
    }
    
    func test_scheduleDownload_resurrectCanceledDownload() {
        let manager = AssetDownloadManager()
        manager.maximumConcurrentDownloads = 1
        AssetDownloadManager.maximumConcurrentDownloadsResetValue = 1
        
        let urlA = URL(string: "http://testA.com")!
        manager.scheduleDownload(url: urlA, forceDownload: false) { _ in }
        
        manager.cancelDownload(url: urlA)
        
        manager.scheduleDownload(url: urlA, forceDownload: false) { _ in }
        
        XCTAssertTrue(manager.downloading.count == 1)
        XCTAssertTrue(manager.waiting.count == 0)
        XCTAssertTrue(manager.canceled.count == 0)
    }
    
    func test_scheduleDownload_resurrectCanceledDownloadAndForceDownload() {
        let manager = AssetDownloadManager()
        manager.maximumConcurrentDownloads = 1
        AssetDownloadManager.maximumConcurrentDownloadsResetValue = 1
        
        let urlA = URL(string: "http://testA.com")!
        manager.scheduleDownload(url: urlA, forceDownload: false) { _ in }
        
        manager.cancelDownload(url: urlA)
        
        let urlB = URL(string: "http://testB.com")!
        manager.scheduleDownload(url: urlB, forceDownload: false) { _ in }
        
        manager.scheduleDownload(url: urlA, forceDownload: true) { _ in }
        
        XCTAssertTrue(manager.downloading.count == 1)
        XCTAssertTrue(manager.waiting.count == 1)
        XCTAssertTrue(manager.canceled.count == 0)
        
        let item = manager.downloading.last!
        XCTAssertEqual(item.url, urlA)
        XCTAssertTrue(item.forceDownload)
    }
    
    // MARK: Cancel
    
    func test_cancelDownload_cancelDownloadingItem() {
        let manager = AssetDownloadManager()
        
        let urlA = URL(string: "http://testA.com")!
        manager.scheduleDownload(url: urlA, forceDownload: true) { _ in }
        
        manager.cancelDownload(url: urlA)
        
        XCTAssertTrue(manager.downloading.count == 0)
        XCTAssertTrue(manager.waiting.count == 0)
        XCTAssertTrue(manager.canceled.count == 1)
    }
    
    func test_cancelDownload_cancelDownloadingItemResumeWaiting() {
        let manager = AssetDownloadManager()
        manager.maximumConcurrentDownloads = 1
        AssetDownloadManager.maximumConcurrentDownloadsResetValue = 1
        
        let urlA = URL(string: "http://testA.com")!
        manager.scheduleDownload(url: urlA, forceDownload: true) { _ in }
        
        let urlB = URL(string: "http://testB.com")!
        manager.scheduleDownload(url: urlB, forceDownload: true) { _ in }
        
        manager.cancelDownload(url: urlA)
        
        XCTAssertTrue(manager.downloading.count == 1)
        XCTAssertTrue(manager.waiting.count == 0)
        XCTAssertTrue(manager.canceled.count == 1)
    }
    
    func test_cancelDownload_cancelWaitingItem() {
        let manager = AssetDownloadManager()
        manager.maximumConcurrentDownloads = 1
        AssetDownloadManager.maximumConcurrentDownloadsResetValue = 1
        
        let urlA = URL(string: "http://testA.com")!
        manager.scheduleDownload(url: urlA, forceDownload: true) { _ in }
        
        let urlB = URL(string: "http://testB.com")!
        manager.scheduleDownload(url: urlB, forceDownload: true) { _ in }
        
        XCTAssertTrue(manager.waiting.count == 1)
        
        manager.cancelDownload(url: urlB)
        
        XCTAssertTrue(manager.downloading.count == 1)
        XCTAssertTrue(manager.waiting.count == 0)
        XCTAssertTrue(manager.canceled.count == 1)
    }
    
}
