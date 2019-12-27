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

//    var sut: AssetDownloadManager!
//
//    var sessionFactory: MockURLSessionFactory!
//    var session: MockURLSession!
    
    // MARK: - Lifecycle
    
    override func setUp() {
        super.setUp()
//        sessionFactory = MockURLSessionFactory()
//        session = MockURLSession()
//        sessionFactory.defaultSession = session
//
//        sut = AssetDownloadManager(urlSessionFactory: sessionFactory)
    }
    
    override func tearDown() {
//        sessionFactory = nil
//        session = nil
//        
//        sut = nil
    
        super.tearDown()
    }
    
    // MARK: - Tests
    
    // MARK: ScheduleDownload
    
    func test_scheduleDownload_schedules() {
//        let manager = AssetDownloadManager()
//
//        let url = URL(string: "http://test.com")!
//        sut.scheduleDownload(url: url, immediateDownload: false) { _ in }
//
//        XCTAssertTrue(manager.downloading.count == 1)
//        XCTAssertTrue(manager.paused.count == 0)
//        XCTAssertTrue(manager.softCancelled.count == 0)
    }
    
    func test_scheduleDownload_multipleConncurrentDownloads() {
//        let manager = AssetDownloadManager()
//
//        let urlA = URL(string: "http://testA.com")!
//        manager.scheduleDownload(url: urlA, immediateDownload: false) { _ in }
//
//        let urlB = URL(string: "http://testB.com")!
//        manager.scheduleDownload(url: urlB, immediateDownload: false) { _ in }
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
//        manager.scheduleDownload(url: urlA, immediateDownload: false) { _ in }
//
//        let urlB = URL(string: "http://testB.com")!
//        manager.scheduleDownload(url: urlB, immediateDownload: false) { _ in }
//
//        XCTAssertTrue(manager.downloading.count == 1)
//        XCTAssertTrue(manager.paused.count == 1)
//        XCTAssertTrue(manager.softCancelled.count == 0)
    }
    
    func test_scheduleDownload_immediateDownload() {
//        let manager = AssetDownloadManager()
//        let urlA = URL(string: "http://testA.com")!
//        manager.scheduleDownload(url: urlA, immediateDownload: false) { _ in }
//
//        let urlB = URL(string: "http://testB.com")!
//        manager.scheduleDownload(url: urlB, immediateDownload: false) { _ in }
//
//        let urlC = URL(string: "http://testC.com")!
//        manager.scheduleDownload(url: urlC, immediateDownload: true) { _ in }
//
//        XCTAssertTrue(manager.downloading.count == 1)
//        XCTAssertTrue(manager.paused.count == 2)
//        XCTAssertTrue(manager.softCancelled.count == 0)
//
//        let item = manager.downloading.last!
//        XCTAssertEqual(item.url, urlC)
//        XCTAssertTrue(item.immediateDownload)
    }
    
    func test_scheduleDownload_coalesceCurrentlyDownloading() {
//        let manager = AssetDownloadManager()
//
//        let url = URL(string: "http://testA.com")!
//        manager.scheduleDownload(url: url, immediateDownload: false) { _ in }
//        manager.scheduleDownload(url: url, immediateDownload: false) { _ in }
//
//        XCTAssertTrue(manager.downloading.count == 1)
//        XCTAssertTrue(manager.paused.count == 0)
//        XCTAssertTrue(manager.softCancelled.count == 0)
    }
    
    func test_scheduleDownload_coalesceCurrentlyDownloadingAndImmediateDownload() {
//        let manager = AssetDownloadManager()
//
//        let urlA = URL(string: "http://testA.com")!
//        manager.scheduleDownload(url: urlA, immediateDownload: false) { _ in }
//
//        let urlB = URL(string: "http://testB.com")!
//        manager.scheduleDownload(url: urlB, immediateDownload: false) { _ in }
//        manager.scheduleDownload(url: urlB, immediateDownload: true) { _ in }
//
//        XCTAssertTrue(manager.downloading.count == 1)
//        XCTAssertTrue(manager.paused.count == 1)
//        XCTAssertTrue(manager.softCancelled.count == 0)
//
//        let item = manager.downloading.last!
//        XCTAssertEqual(item.url, urlB)
//        XCTAssertTrue(item.immediateDownload)
    }
    
    func test_scheduleDownload_coalesceWaitingDownloading() {
//        let manager = AssetDownloadManager()
//
//        manager.maximumConcurrentDownloads = 1
//        AssetDownloadManager.maximumConcurrentDownloadsResetValue = 1
//
//        let urlA = URL(string: "http://testA.com")!
//        manager.scheduleDownload(url: urlA, immediateDownload: false) { _ in }
//
//        let urlB = URL(string: "http://testB.com")!
//        manager.scheduleDownload(url: urlB, immediateDownload: false) { _ in }
//        manager.scheduleDownload(url: urlB, immediateDownload: false) { _ in }
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
//        manager.scheduleDownload(url: urlA, immediateDownload: false) { _ in }
//
//        let urlB = URL(string: "http://testB.com")!
//        manager.scheduleDownload(url: urlB, immediateDownload: false) { _ in }
//
//        let urlC = URL(string: "http://testC.com")!
//        manager.scheduleDownload(url: urlC, immediateDownload: false) { _ in }
//
//        manager.scheduleDownload(url: urlB, immediateDownload: false) { _ in }
//
//        XCTAssertTrue(manager.downloading.count == 1)
//        XCTAssertTrue(manager.paused.count == 2)
//        XCTAssertTrue(manager.softCancelled.count == 0)
//
//        let item = manager.paused.last
//        XCTAssertEqual(item?.url, urlB)
    }
    
    func test_scheduleDownload_coalesceCurrentlyWaitingAndImmediateDownload() {
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
//        manager.scheduleDownload(url: urlB, immediateDownload: true) { _ in }
//
//        XCTAssertTrue(manager.downloading.count == 1)
//        XCTAssertTrue(manager.paused.count == 1)
//        XCTAssertTrue(manager.softCancelled.count == 0)
//
//        let item = manager.downloading.last!
//        XCTAssertEqual(item.url, urlB)
//        XCTAssertTrue(item.immediateDownload)
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
//        manager.scheduleDownload(url: url, immediateDownload: false) { _ in }
//
//        XCTAssertTrue(manager.downloading.count == 1)
//        XCTAssertTrue(manager.paused.count == 0)
//        XCTAssertTrue(manager.softCancelled.count == 0)
    }
    
    func test_scheduleDownload_resurrectCanceledDownloadAndImmediateDownload() {
//        let manager = AssetDownloadManager()
//        manager.maximumConcurrentDownloads = 1
//        AssetDownloadManager.maximumConcurrentDownloadsResetValue = 1
//
//        let urlA = URL(string: "http://testA.com")!
//        manager.scheduleDownload(url: urlA, immediateDownload: false) { _ in }
//
//        manager.cancelDownload(url: urlA)
//
//        let urlB = URL(string: "http://testB.com")!
//        manager.scheduleDownload(url: urlB, immediateDownload: false) { _ in }
//
//        manager.scheduleDownload(url: urlA, immediateDownload: true) { _ in }
//
//        XCTAssertTrue(manager.downloading.count == 1)
//        XCTAssertTrue(manager.paused.count == 1)
//        XCTAssertTrue(manager.softCancelled.count == 0)
//
//        let item = manager.downloading.last!
//        XCTAssertEqual(item.url, urlA)
//        XCTAssertTrue(item.immediateDownload)
    }
    
    // MARK: Cancel
    
    func test_cancelDownload_cancelDownloadingItem() {
//        let manager = AssetDownloadManager()
//
//        let urlA = URL(string: "http://testA.com")!
//        manager.scheduleDownload(url: urlA, immediateDownload: true) { _ in }
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
//        manager.scheduleDownload(url: urlA, immediateDownload: true) { _ in }
//
//        let urlB = URL(string: "http://testB.com")!
//        manager.scheduleDownload(url: urlB, immediateDownload: true) { _ in }
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
//        manager.scheduleDownload(url: urlA, immediateDownload: true) { _ in }
//        
//        let urlB = URL(string: "http://testB.com")!
//        manager.scheduleDownload(url: urlB, immediateDownload: true) { _ in }
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
