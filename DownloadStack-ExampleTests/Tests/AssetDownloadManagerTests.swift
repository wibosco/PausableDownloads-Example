//
//  AssetDownloadManagerTests.swift
//  DownloadStack-ExampleTests
//
//  Created by William Boles on 28/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import XCTest

@testable import DownloadStack_Example

class AssetDownloadManagerTests: XCTestCase {

    var sut: AssetDownloadManager!
    
    var sessionFactory: MockURLSessionFactory!
    var session: MockURLSession!
    var notificationCenter: MockNotificationCenter!
    
    // MARK: - Lifecycle
    
    override func setUp() {
        super.setUp()
        sessionFactory = MockURLSessionFactory()
        session = MockURLSession()
        sessionFactory.defaultSession = session
        notificationCenter = MockNotificationCenter()
        
        sut = AssetDownloadManager(urlSessionFactory: sessionFactory, notificationCenter: notificationCenter)
    }
    
    override func tearDown() {
        sessionFactory = nil
        session = nil
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
        
        _ = AssetDownloadManager(notificationCenter: notificationCenter)
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func test_init_notificationTriggeredClearsCanceledItems() {
        //TODO: Implement
    }
    
    // MARK: ScheduleDownload
    
    func test_scheduleDownload_schedules() {
//        let manager = AssetDownloadManager()
//
//        let url = URL(string: "http://test.com")!
//        sut.scheduleDownload(url: url, forceDownload: false) { _ in }
//
//        XCTAssertTrue(manager.downloading.count == 1)
//        XCTAssertTrue(manager.paused.count == 0)
//        XCTAssertTrue(manager.softCancelled.count == 0)
    }
    
    func test_scheduleDownload_multipleConncurrentDownloads() {
//        let manager = AssetDownloadManager()
//
//        let urlA = URL(string: "http://testA.com")!
//        manager.scheduleDownload(url: urlA, forceDownload: false) { _ in }
//
//        let urlB = URL(string: "http://testB.com")!
//        manager.scheduleDownload(url: urlB, forceDownload: false) { _ in }
//
//        XCTAssertTrue(manager.downloading.count == 2)
//        XCTAssertTrue(manager.paused.count == 0)
//        XCTAssertTrue(manager.softCancelled.count == 0)
    }
    
    func test_scheduleDownload_queuingDownloadsWhenLimitIsMeet() {
//        let manager = AssetDownloadManager()
//        manager.maximumConcurrentDownloads = 1
//        AssetDownloadManager.maximumConcurrentDownloadsResetValue = 1
//
//        let urlA = URL(string: "http://testA.com")!
//        manager.scheduleDownload(url: urlA, forceDownload: false) { _ in }
//
//        let urlB = URL(string: "http://testB.com")!
//        manager.scheduleDownload(url: urlB, forceDownload: false) { _ in }
//
//        XCTAssertTrue(manager.downloading.count == 1)
//        XCTAssertTrue(manager.paused.count == 1)
//        XCTAssertTrue(manager.softCancelled.count == 0)
    }
    
    func test_scheduleDownload_forceDownload() {
//        let manager = AssetDownloadManager()
//        let urlA = URL(string: "http://testA.com")!
//        manager.scheduleDownload(url: urlA, forceDownload: false) { _ in }
//
//        let urlB = URL(string: "http://testB.com")!
//        manager.scheduleDownload(url: urlB, forceDownload: false) { _ in }
//
//        let urlC = URL(string: "http://testC.com")!
//        manager.scheduleDownload(url: urlC, forceDownload: true) { _ in }
//
//        XCTAssertTrue(manager.downloading.count == 1)
//        XCTAssertTrue(manager.paused.count == 2)
//        XCTAssertTrue(manager.softCancelled.count == 0)
//
//        let item = manager.downloading.last!
//        XCTAssertEqual(item.url, urlC)
//        XCTAssertTrue(item.forceDownload)
    }
    
    func test_scheduleDownload_coalesceCurrentlyDownloading() {
//        let manager = AssetDownloadManager()
//
//        let url = URL(string: "http://testA.com")!
//        manager.scheduleDownload(url: url, forceDownload: false) { _ in }
//        manager.scheduleDownload(url: url, forceDownload: false) { _ in }
//
//        XCTAssertTrue(manager.downloading.count == 1)
//        XCTAssertTrue(manager.paused.count == 0)
//        XCTAssertTrue(manager.softCancelled.count == 0)
    }
    
    func test_scheduleDownload_coalesceCurrentlyDownloadingAndForceDownload() {
//        let manager = AssetDownloadManager()
//
//        let urlA = URL(string: "http://testA.com")!
//        manager.scheduleDownload(url: urlA, forceDownload: false) { _ in }
//
//        let urlB = URL(string: "http://testB.com")!
//        manager.scheduleDownload(url: urlB, forceDownload: false) { _ in }
//        manager.scheduleDownload(url: urlB, forceDownload: true) { _ in }
//
//        XCTAssertTrue(manager.downloading.count == 1)
//        XCTAssertTrue(manager.paused.count == 1)
//        XCTAssertTrue(manager.softCancelled.count == 0)
//
//        let item = manager.downloading.last!
//        XCTAssertEqual(item.url, urlB)
//        XCTAssertTrue(item.forceDownload)
    }
    
    func test_scheduleDownload_coalesceWaitingDownloading() {
//        let manager = AssetDownloadManager()
//
//        manager.maximumConcurrentDownloads = 1
//        AssetDownloadManager.maximumConcurrentDownloadsResetValue = 1
//
//        let urlA = URL(string: "http://testA.com")!
//        manager.scheduleDownload(url: urlA, forceDownload: false) { _ in }
//
//        let urlB = URL(string: "http://testB.com")!
//        manager.scheduleDownload(url: urlB, forceDownload: false) { _ in }
//        manager.scheduleDownload(url: urlB, forceDownload: false) { _ in }
//
//        XCTAssertTrue(manager.downloading.count == 1)
//        XCTAssertTrue(manager.paused.count == 1)
//        XCTAssertTrue(manager.softCancelled.count == 0)
    }
    
    func test_scheduleDownload_coalesceWaitingDownloadingAndMoveToFront() {
//        let manager = AssetDownloadManager()
//
//        manager.maximumConcurrentDownloads = 1
//        AssetDownloadManager.maximumConcurrentDownloadsResetValue = 1
//
//        let urlA = URL(string: "http://testA.com")!
//        manager.scheduleDownload(url: urlA, forceDownload: false) { _ in }
//
//        let urlB = URL(string: "http://testB.com")!
//        manager.scheduleDownload(url: urlB, forceDownload: false) { _ in }
//
//        let urlC = URL(string: "http://testC.com")!
//        manager.scheduleDownload(url: urlC, forceDownload: false) { _ in }
//
//        manager.scheduleDownload(url: urlB, forceDownload: false) { _ in }
//
//        XCTAssertTrue(manager.downloading.count == 1)
//        XCTAssertTrue(manager.paused.count == 2)
//        XCTAssertTrue(manager.softCancelled.count == 0)
//
//        let item = manager.paused.last
//        XCTAssertEqual(item?.url, urlB)
    }
    
    func test_scheduleDownload_coalesceCurrentlyWaitingAndForceDownload() {
//        let manager = AssetDownloadManager()
//
//        manager.maximumConcurrentDownloads = 1
//        AssetDownloadManager.maximumConcurrentDownloadsResetValue = 1
//
//        let itemA = assetDownloadItem(forURL: URL(string: "http://testA.com")!)
//        manager.downloading.append(itemA)
//
//        let urlB = URL(string: "http://testB.com")!
//        let itemB = assetDownloadItem(forURL: urlB)
//        manager.paused.append(itemB)
//
//        manager.scheduleDownload(url: urlB, forceDownload: true) { _ in }
//
//        XCTAssertTrue(manager.downloading.count == 1)
//        XCTAssertTrue(manager.paused.count == 1)
//        XCTAssertTrue(manager.softCancelled.count == 0)
//
//        let item = manager.downloading.last!
//        XCTAssertEqual(item.url, urlB)
//        XCTAssertTrue(item.forceDownload)
    }
    
    func test_scheduleDownload_resurrectCanceledDownload() {
//        let manager = AssetDownloadManager()
//
//        let url = URL(string: "http://testA.com")!
//
//        let urlRequest = URLRequest(url: url)
//        urlSessionDownloadTaskSpy.currentRequestToBeReturned = urlRequest
//        let item = AssetDownloadItem(task: urlSessionDownloadTaskSpy)
//        manager.softCancelled.append(item)
//
//        manager.scheduleDownload(url: url, forceDownload: false) { _ in }
//
//        XCTAssertTrue(manager.downloading.count == 1)
//        XCTAssertTrue(manager.paused.count == 0)
//        XCTAssertTrue(manager.softCancelled.count == 0)
    }
    
    func test_scheduleDownload_resurrectCanceledDownloadAndForceDownload() {
//        let manager = AssetDownloadManager()
//        manager.maximumConcurrentDownloads = 1
//        AssetDownloadManager.maximumConcurrentDownloadsResetValue = 1
//
//        let urlA = URL(string: "http://testA.com")!
//        manager.scheduleDownload(url: urlA, forceDownload: false) { _ in }
//
//        manager.cancelDownload(url: urlA)
//
//        let urlB = URL(string: "http://testB.com")!
//        manager.scheduleDownload(url: urlB, forceDownload: false) { _ in }
//
//        manager.scheduleDownload(url: urlA, forceDownload: true) { _ in }
//
//        XCTAssertTrue(manager.downloading.count == 1)
//        XCTAssertTrue(manager.paused.count == 1)
//        XCTAssertTrue(manager.softCancelled.count == 0)
//
//        let item = manager.downloading.last!
//        XCTAssertEqual(item.url, urlA)
//        XCTAssertTrue(item.forceDownload)
    }
    
    // MARK: Cancel
    
    func test_cancelDownload_cancelDownloadingItem() {
//        let manager = AssetDownloadManager()
//
//        let urlA = URL(string: "http://testA.com")!
//        manager.scheduleDownload(url: urlA, forceDownload: true) { _ in }
//
//        manager.cancelDownload(url: urlA)
//
//        XCTAssertTrue(manager.downloading.count == 0)
//        XCTAssertTrue(manager.paused.count == 0)
//        XCTAssertTrue(manager.softCancelled.count == 1)
    }
    
    func test_cancelDownload_cancelDownloadingItemResumeWaiting() {
//        let manager = AssetDownloadManager()
//        manager.maximumConcurrentDownloads = 1
//        AssetDownloadManager.maximumConcurrentDownloadsResetValue = 1
//
//        let urlA = URL(string: "http://testA.com")!
//        manager.scheduleDownload(url: urlA, forceDownload: true) { _ in }
//
//        let urlB = URL(string: "http://testB.com")!
//        manager.scheduleDownload(url: urlB, forceDownload: true) { _ in }
//
//        manager.cancelDownload(url: urlA)
//
//        XCTAssertTrue(manager.downloading.count == 1)
//        XCTAssertTrue(manager.paused.count == 0)
//        XCTAssertTrue(manager.softCancelled.count == 1)
    }
    
    func test_cancelDownload_cancelWaitingItem() {
//        let manager = AssetDownloadManager()
//        manager.maximumConcurrentDownloads = 1
//        AssetDownloadManager.maximumConcurrentDownloadsResetValue = 1
//        
//        let urlA = URL(string: "http://testA.com")!
//        manager.scheduleDownload(url: urlA, forceDownload: true) { _ in }
//        
//        let urlB = URL(string: "http://testB.com")!
//        manager.scheduleDownload(url: urlB, forceDownload: true) { _ in }
//        
//        XCTAssertTrue(manager.paused.count == 1)
//        
//        manager.cancelDownload(url: urlB)
//        
//        XCTAssertTrue(manager.downloading.count == 1)
//        XCTAssertTrue(manager.paused.count == 0)
//        XCTAssertTrue(manager.softCancelled.count == 1)
    }
    
}
