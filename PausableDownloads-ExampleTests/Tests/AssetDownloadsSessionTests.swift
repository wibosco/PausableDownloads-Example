//
//  AssetDownloadsSessionTests.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 15/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import XCTest

@testable import PausableDownloads_Example

class AssetDownloadsSessionTests: XCTestCase {
    
    // MARK: - Tests
    
    // MARK: Init
    
    func test_givenURLSessionFactory_whenInitialised_thenDefaultSessionIsCreatedWithSelfAsDelegateAndNoQueue() {
        let sessionFactory = StubURLSessionFactory()
        sessionFactory.sessionToReturn = StubURLSession()
        
        let sut = createSUT(urlSessionFactory: sessionFactory)
        
        XCTAssertEqual(sessionFactory.events.count, 1)
        
        guard case let .defaultSession(delegate, queue) = sessionFactory.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertTrue(delegate === sut)
        XCTAssertNil(queue)
    }
    
    // MARK: MemoryPressure
    
    func test_givenMemoryPressureMonitor_whenInitialised_thenMonitoringIsStarted() {
        let memoryPressureMonitor = StubMemoryPressureMonitor()
        
        _ = createSUT(memoryPressureMonitor: memoryPressureMonitor)
        
        XCTAssertEqual(memoryPressureMonitor.events.count, 1)
        
        guard case .startMonitoring = memoryPressureMonitor.events.first else {
            XCTFail("Unexpected event")
            return
        }
    }
    
    func test_givenPausedDownload_whenMemoryPressureIsReceived_thenTheDownloadIsDiscarded() {
        let url = URL(string: "http://test.com/example")!
        
        let memoryPressureMonitor = StubMemoryPressureMonitor()
        
        let session = StubURLSession()
        let sut = createSUT(session: session, memoryPressureMonitor: memoryPressureMonitor)
        
        guard case let .startMonitoring(memoryPressureHandler) = memoryPressureMonitor.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        let downloadTask = StubURLSessionDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        let downloadID = sut.scheduleDownload(for: url) { _ in }
        
        XCTAssertEqual(session.events.count, 1)
        
        sut.pauseDownload(downloadID)
        
        XCTAssertEqual(downloadTask.events.count, 2)
        
        guard case let .cancelByProducingResumeData(resumeDataHandler) = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        resumeDataHandler(Data("resumption".utf8))
        
        memoryPressureHandler()
        
        //the purged item took its resumption data with it, so the next schedule starts over
        session.downloadTaskWithResumeDataToReturn = StubURLSessionDownloadTask()
        
        sut.scheduleDownload(for: url) { _ in }
        
        XCTAssertEqual(session.events.count, 2)
        
        guard case .downloadTask = session.events.last else {
            XCTFail("Expected a new download task rather than a resumed one")
            return
        }
    }
    
    func test_givenActiveDownload_whenMemoryPressureIsReceived_thenTheDownloadTaskIsNotCancelled() {
        let url = URL(string: "http://test.com/example")!
        
        let memoryPressureMonitor = StubMemoryPressureMonitor()
        
        let session = StubURLSession()
        let sut = createSUT(session: session, memoryPressureMonitor: memoryPressureMonitor)
        
        let downloadTask = StubURLSessionDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        guard case let .startMonitoring(memoryPressureHandler) = memoryPressureMonitor.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        sut.scheduleDownload(for: url) { _ in }
        
        XCTAssertEqual(downloadTask.events.count, 1)
        
        memoryPressureHandler()
        
        XCTAssertEqual(downloadTask.events.count, 1)
        
        guard case .resume = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
    }
    
    // MARK: Schedule
    
    func test_givenNoExistingDownload_whenScheduleDownloadIsCalled_thenDownloadTaskIsCreatedForURLAndResumed() {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubURLSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubURLSessionDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        sut.scheduleDownload(for: url) { _ in }
        
        XCTAssertEqual(downloadTask.events.count, 1)
        
        guard case .resume = downloadTask.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(session.events.count, 1)
        
        guard case let .downloadTask(downloadTaskURL) = session.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(downloadTaskURL, url)
    }
    
    func test_givenNoExistingDownloads_whenScheduleDownloadIsCalledForTwoDifferentURLs_thenBothDownloadTasksAreResumed() {
        let session = StubURLSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubURLSessionDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        let urlA = URL(string: "http://example.com/resourceA")!
        let urlB = URL(string: "http://example.com/resourceB")!
        
        sut.scheduleDownload(for: urlA) { _ in }
        sut.scheduleDownload(for: urlB) { _ in }
        
        XCTAssertEqual(downloadTask.events.count, 2)
        
        guard case .resume = downloadTask.events.first,
              case .resume = downloadTask.events.last else {
            XCTFail("Unexpected events")
            return
        }
    }
    
    func test_givenInFlightDownload_whenScheduleDownloadIsCalledForTheSameURL_thenOneDownloadIsSharedAndBothCompletionHandlersAreCalled() {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubURLSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubURLSessionDownloadTask()
        downloadTask.taskIdentifierToReturn = 1
        session.downloadTaskToReturn = downloadTask
        
        var firstResults = [Result<Data, Error>]()
        sut.scheduleDownload(for: url) { firstResults.append($0) }
        
        var secondResults = [Result<Data, Error>]()
        sut.scheduleDownload(for: url) { secondResults.append($0) }
        
        //a second caller coalesces onto the download that's already running
        XCTAssertEqual(session.events.count, 1)
        XCTAssertEqual(downloadTask.events.count, 1)
        
        sut.handleFailedDownloading(for: url, taskIdentifier: downloadTask.taskIdentifier, error: TestError.test)
        
        XCTAssertEqual(firstResults.count, 1)
        XCTAssertEqual(secondResults.count, 1)
    }
    
    func test_givenTwoCallersForTheSameURL_whenOneIsPaused_thenTheSharedTaskIsNotCancelledAndTheOtherIsStillAnswered() {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubURLSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubURLSessionDownloadTask()
        downloadTask.taskIdentifierToReturn = 1
        session.downloadTaskToReturn = downloadTask
        
        var firstResults = [Result<Data, Error>]()
        let firstDownloadToken = sut.scheduleDownload(for: url) { firstResults.append($0) }
        
        var secondResults = [Result<Data, Error>]()
        sut.scheduleDownload(for: url) { secondResults.append($0) }
        
        sut.pauseDownload(firstDownloadToken)
        
        //the second caller still wants this URL, so the shared task keeps running
        XCTAssertEqual(downloadTask.events.count, 1)
        
        guard case .resume = downloadTask.events.last else {
            XCTFail("Expected the shared download not to be cancelled")
            return
        }
        
        sut.handleFailedDownloading(for: url, taskIdentifier: downloadTask.taskIdentifier, error: TestError.test)
        
        XCTAssertEqual(secondResults.count, 1)
        XCTAssertTrue(firstResults.isEmpty)
    }
    
    func test_givenPausedDownloadThatProducedNoResumptionData_whenScheduleDownloadIsCalledForTheSameURL_thenTheDownloadRestarts() {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubURLSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubURLSessionDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        let downloadID = sut.scheduleDownload(for: url) { _ in }
        sut.pauseDownload(downloadID)
        
        XCTAssertEqual(downloadTask.events.count, 2)
        
        guard case let .cancelByProducingResumeData(resumeDataHandler) = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        //a server that can't resume hands back no data, so starting over is all that's left
        resumeDataHandler(nil)
        
        sut.scheduleDownload(for: url) { _ in }
        
        XCTAssertEqual(session.events.count, 2)
        
        guard case .downloadTask = session.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(downloadTask.events.count, 3)
        
        guard case .resume = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
    }
    
    func test_givenPauseStillProducingResumptionData_whenScheduleDownloadIsCalledForTheSameURL_thenTheResumeWaitsForTheResumptionData() {
        let url = URL(string: "http://test.com/example")!
        let resumptionData = Data("resumption".utf8)
        
        let session = StubURLSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubURLSessionDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        let downloadID = sut.scheduleDownload(for: url) { _ in }
        sut.pauseDownload(downloadID)
        
        guard case let .cancelByProducingResumeData(resumeDataHandler) = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        let resumedDownloadTask = StubURLSessionDownloadTask()
        session.downloadTaskWithResumeDataToReturn = resumedDownloadTask
        
        //rescheduling whilst the resumption data is still in flight - the fast swipe back
        sut.scheduleDownload(for: url) { _ in }
        
        XCTAssertEqual(session.events.count, 1)
        
        resumeDataHandler(resumptionData)
        
        XCTAssertEqual(session.events.count, 2)
        
        guard case let .downloadTaskWithResumeData(data) = session.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(data, resumptionData)
        
        XCTAssertEqual(resumedDownloadTask.events.count, 1)
        
        guard case .resume = resumedDownloadTask.events.first else {
            XCTFail("Unexpected event")
            return
        }
    }
    
    func test_givenACallerThatJoinedAPauseInFlight_whenItPausesBeforeTheResumptionDataLands_thenNoTaskIsEverStarted() {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubURLSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubURLSessionDownloadTask()
        session.downloadTaskToReturn = downloadTask
        session.downloadTaskWithResumeDataToReturn = StubURLSessionDownloadTask()
        
        let firstDownloadID = sut.scheduleDownload(for: url) { _ in }
        sut.pauseDownload(firstDownloadID)
        
        guard case let .cancelByProducingResumeData(resumeDataHandler) = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        //scheduled whilst the pause is still in flight, so it joins rather than starting a task
        let joinedDownloadToken = sut.scheduleDownload(for: url) { _ in }
        
        XCTAssertEqual(session.events.count, 1)
        
        sut.pauseDownload(joinedDownloadToken)
        
        resumeDataHandler(Data("resumption".utf8))
        
        //nothing was waiting on the data by the time it landed
        XCTAssertEqual(session.events.count, 1)
    }
    
    func test_givenPausedDownload_whenTheCancelledDownloadTaskCompletes_thenTheCompletionHandlerIsNotCalled() {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubURLSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubURLSessionDownloadTask()
        downloadTask.taskIdentifierToReturn = 1
        session.downloadTaskToReturn = downloadTask
        
        var results = [Result<Data, Error>]()
        let downloadID = sut.scheduleDownload(for: url) { results.append($0) }
        
        guard case .downloadTask = session.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        sut.pauseDownload(downloadID)
        
        //pausing cancels the underlying task, which reports back as a cancellation error
        sut.handleFailedDownloading(for: url, taskIdentifier: downloadTask.taskIdentifier, error: URLError(.cancelled))
        
        XCTAssertTrue(results.isEmpty)
    }
    
    func test_givenCompletedDownload_whenScheduleDownloadIsCalledForTheSameURL_thenANewDownloadTaskIsCreated() throws {
        let url = URL(string: "http://test.com/example")!
        let fileURL = try XCTUnwrap(Bundle(for: type(of: self)).url(forResource: "square", withExtension: "pdf"))
        
        let session = StubURLSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubURLSessionDownloadTask()
        downloadTask.taskIdentifierToReturn = 1
        session.downloadTaskToReturn = downloadTask
        
        sut.scheduleDownload(for: url) { _ in }
        
        XCTAssertEqual(session.events.count, 1)
        
        guard case .downloadTask = session.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        sut.handleFinishedDownloading(for: url, taskIdentifier: downloadTask.taskIdentifier, to: fileURL)
        
        sut.scheduleDownload(for: url) { _ in }
        
        XCTAssertEqual(session.events.count, 2)
    }
    
    func test_givenScheduledDownload_whenTheDownloadTaskFails_thenTheCompletionHandlerIsCalled() {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubURLSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubURLSessionDownloadTask()
        downloadTask.taskIdentifierToReturn = 1
        session.downloadTaskToReturn = downloadTask
        
        let completionExpectation = expectation(description: "completionExpectation")
        sut.scheduleDownload(for: url) { _ in
            completionExpectation.fulfill()
        }
        
        guard case .downloadTask = session.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        sut.handleFailedDownloading(for: url, taskIdentifier: downloadTask.taskIdentifier, error: TestError.test)
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func test_givenPausedDownloadWithResumptionData_whenScheduleDownloadIsCalledForTheSameURL_thenDownloadTaskIsCreatedFromResumeData() {
        let url = URL(string: "http://test.com/example")!
        let resumptionData = Data("resumption".utf8)
        
        let session = StubURLSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubURLSessionDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        let downloadID = sut.scheduleDownload(for: url) { _ in }
        sut.pauseDownload(downloadID)
        
        guard case let .cancelByProducingResumeData(resumeDataHandler) = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        resumeDataHandler(resumptionData)
        
        let resumedDownloadTask = StubURLSessionDownloadTask()
        session.downloadTaskWithResumeDataToReturn = resumedDownloadTask
        
        sut.scheduleDownload(for: url) { _ in }
        
        XCTAssertEqual(session.events.count, 2)
        
        guard case let .downloadTaskWithResumeData(data) = session.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(data, resumptionData)
        XCTAssertEqual(resumedDownloadTask.events.count, 1)
        
        guard case .resume = resumedDownloadTask.events.first else {
            XCTFail("Unexpected event")
            return
        }
    }
    
    func test_givenScheduledDownload_whenTheDownloadTaskCompletesWithAFileURL_thenTheCompletionHandlerReceivesTheFileContents() throws {
        let url = URL(string: "http://test.com/example")!
        let fileURL = try XCTUnwrap(Bundle(for: type(of: self)).url(forResource: "square", withExtension: "pdf"))
        let expectedData = try Data(contentsOf: fileURL)
        
        XCTAssertFalse(expectedData.isEmpty)
        
        let session = StubURLSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubURLSessionDownloadTask()
        downloadTask.taskIdentifierToReturn = 1
        session.downloadTaskToReturn = downloadTask
        
        var receivedResult: Result<Data, Error>?
        let completionExpectation = expectation(description: "completionExpectation")
        sut.scheduleDownload(for: url) { (result) in
            receivedResult = result
            completionExpectation.fulfill()
        }
        
        guard case .downloadTask = session.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        sut.handleFinishedDownloading(for: url, taskIdentifier: downloadTask.taskIdentifier, to: fileURL)
        
        waitForExpectations(timeout: 3, handler: nil)
        
        guard case let .success(data) = try XCTUnwrap(receivedResult) else {
            XCTFail("Expected a success result")
            return
        }
        
        XCTAssertEqual(data, expectedData)
    }
    
    func test_givenScheduledDownload_whenTheDownloadTaskCompletesWithAnError_thenTheCompletionHandlerReceivesARetrievalFailure() throws {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubURLSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubURLSessionDownloadTask()
        downloadTask.taskIdentifierToReturn = 1
        session.downloadTaskToReturn = downloadTask
        
        var receivedResult: Result<Data, Error>?
        let completionExpectation = expectation(description: "completionExpectation")
        sut.scheduleDownload(for: url) { (result) in
            receivedResult = result
            completionExpectation.fulfill()
        }
        
        guard case .downloadTask = session.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        sut.handleFailedDownloading(for: url, taskIdentifier: downloadTask.taskIdentifier, error: TestError.test)
        
        waitForExpectations(timeout: 3, handler: nil)
        
        guard case let .failure(error) = try XCTUnwrap(receivedResult),
              case let NetworkingError.retrieval(underlyingError) = error else {
            XCTFail("Expected a retrieval failure")
            return
        }
        
        XCTAssertEqual(underlyingError as? TestError, .test)
    }
    
    func test_givenScheduledDownload_whenTheDownloadTaskCompletesWithAnUnreadableFileURL_thenTheCompletionHandlerReceivesAnInvalidDataFailure() throws {
        let url = URL(string: "http://test.com/example")!
        let unreadableFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("does-not-exist-\(UUID().uuidString)")
        
        let session = StubURLSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubURLSessionDownloadTask()
        downloadTask.taskIdentifierToReturn = 1
        session.downloadTaskToReturn = downloadTask
        
        var receivedResult: Result<Data, Error>?
        let completionExpectation = expectation(description: "completionExpectation")
        sut.scheduleDownload(for: url) { (result) in
            receivedResult = result
            completionExpectation.fulfill()
        }
        
        guard case .downloadTask = session.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        sut.handleFinishedDownloading(for: url, taskIdentifier: downloadTask.taskIdentifier, to: unreadableFileURL)
        
        waitForExpectations(timeout: 3, handler: nil)
        
        guard case let .failure(error) = try XCTUnwrap(receivedResult),
              case NetworkingError.invalidData = error else {
            XCTFail("Expected an invalid data failure")
            return
        }
    }
    
    func test_givenPauseThenResume_whenTheCancelledDownloadTaskCompletes_thenItIsIgnoredAndTheResumedTaskStillCompletes() {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubURLSession()
        let sut = createSUT(session: session)
        
        let retiredDownloadTask = StubURLSessionDownloadTask()
        retiredDownloadTask.taskIdentifierToReturn = 1
        session.downloadTaskToReturn = retiredDownloadTask
        
        let downloadID = sut.scheduleDownload(for: url) { _ in }
        sut.pauseDownload(downloadID)
        
        guard case let .cancelByProducingResumeData(resumeDataHandler) = retiredDownloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        resumeDataHandler(Data("resumption".utf8))
        
        let resumedDownloadTask = StubURLSessionDownloadTask()
        resumedDownloadTask.taskIdentifierToReturn = 2
        session.downloadTaskWithResumeDataToReturn = resumedDownloadTask
        
        var results = [Result<Data, Error>]()
        sut.scheduleDownload(for: url) { results.append($0) }
        
        //the task the pause retired winds down late and must not be mistaken for this download
        sut.handleFailedDownloading(for: url, taskIdentifier: retiredDownloadTask.taskIdentifier, error: URLError(.cancelled))
        
        XCTAssertTrue(results.isEmpty)
        
        sut.handleFailedDownloading(for: url, taskIdentifier: resumedDownloadTask.taskIdentifier, error: TestError.test)
        
        XCTAssertEqual(results.count, 1)
    }
    
    func test_givenNoMatchingDownload_whenAnEventForAnUnknownTaskIsReceived_thenItIsIgnored() {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubURLSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubURLSessionDownloadTask()
        downloadTask.taskIdentifierToReturn = 1
        session.downloadTaskToReturn = downloadTask
        
        var results = [Result<Data, Error>]()
        sut.scheduleDownload(for: url) { results.append($0) }
        
        let unknownURL = URL(string: "http://test.com/unknown")!
        let unknownTaskIdentifier = 2
        
        sut.handleProgress(for: unknownURL, totalBytesWritten: 50, expectedTotalBytes: 100)
        sut.handleResumption(for: unknownURL, fileOffset: 50, expectedTotalBytes: 100)
        sut.handleFinishedDownloading(for: unknownURL, taskIdentifier: unknownTaskIdentifier, to: URL(fileURLWithPath: "/dev/null"))
        sut.handleFailedDownloading(for: unknownURL, taskIdentifier: unknownTaskIdentifier, error: TestError.test)
        
        XCTAssertTrue(results.isEmpty)
    }
    
    // MARK: Cancel
    
    func test_givenScheduledDownload_whenCancelDownloadIsCalled_thenDownloadTaskIsCancelledByProducingResumeData() {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubURLSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubURLSessionDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        let downloadID = sut.scheduleDownload(for: url) { _ in }
        sut.pauseDownload(downloadID)
        
        XCTAssertEqual(downloadTask.events.count, 2)
        
        guard case .cancelByProducingResumeData = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
    }
    
    func test_givenNoScheduledDownloads_whenCancelDownloadIsCalledForAnUnknownID_thenNoDownloadTaskEventsAreRecorded() {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubURLSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubURLSessionDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        sut.pauseDownload(DownloadToken(url: url))
        
        XCTAssertTrue(session.events.isEmpty)
        XCTAssertTrue(downloadTask.events.isEmpty)
    }
    
    // MARK: - Coalescing
    
    func test_givenTwoCoalescedDownloads_whenTheDownloadTaskCompletes_thenBothCompletionHandlersReceiveTheSameData() throws {
        let url = URL(string: "http://test.com/example")!
        let fileURL = try XCTUnwrap(Bundle(for: type(of: self)).url(forResource: "square", withExtension: "pdf"))
        let expectedData = try Data(contentsOf: fileURL)
        
        XCTAssertFalse(expectedData.isEmpty)
        
        let session = StubURLSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubURLSessionDownloadTask()
        downloadTask.taskIdentifierToReturn = 1
        session.downloadTaskToReturn = downloadTask
        
        var firstResult: Result<Data, Error>?
        sut.scheduleDownload(for: url) { firstResult = $0 }
        
        var secondResult: Result<Data, Error>?
        sut.scheduleDownload(for: url) { secondResult = $0 }
        
        XCTAssertEqual(session.events.count, 1)
        
        sut.handleFinishedDownloading(for: url, taskIdentifier: downloadTask.taskIdentifier, to: fileURL)
        
        //one read of the file, handed to everybody who coalesced onto the download
        guard case let .success(firstData) = try XCTUnwrap(firstResult),
              case let .success(secondData) = try XCTUnwrap(secondResult) else {
            XCTFail("Expected both callers to receive a success result")
            return
        }
        
        XCTAssertEqual(firstData, expectedData)
        XCTAssertEqual(secondData, expectedData)
    }
    
    func test_givenTwoCallersForTheSameURL_whenBothPause_thenTheSharedTaskIsCancelledOnce() {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubURLSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubURLSessionDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        let firstDownloadToken = sut.scheduleDownload(for: url) { _ in }
        let secondDownloadToken = sut.scheduleDownload(for: url) { _ in }
        
        sut.pauseDownload(firstDownloadToken)
        
        //somebody still wants it, so nothing is cancelled yet
        XCTAssertEqual(downloadTask.events.count, 1)
        
        sut.pauseDownload(secondDownloadToken)
        
        //the last interested caller has gone, so the shared task is cancelled exactly once
        XCTAssertEqual(downloadTask.events.count, 2)
        
        guard case .cancelByProducingResumeData = downloadTask.events.last else {
            XCTFail("Expected the shared download to be cancelled")
            return
        }
    }
    
    func test_givenTwoCallersJoinedAPauseInFlight_whenTheResumptionDataLands_thenOnlyOneTaskIsStarted() {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubURLSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubURLSessionDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        let firstDownloadToken = sut.scheduleDownload(for: url) { _ in }
        sut.pauseDownload(firstDownloadToken)
        
        guard case let .cancelByProducingResumeData(resumeDataHandler) = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        let resumedTask = StubURLSessionDownloadTask()
        resumedTask.taskIdentifierToReturn = 2
        session.downloadTaskWithResumeDataToReturn = resumedTask
        
        //both scheduled whilst the pause is still in flight, so both join it
        var secondResults = [Result<Data, Error>]()
        sut.scheduleDownload(for: url) { secondResults.append($0) }
        
        var thirdResults = [Result<Data, Error>]()
        sut.scheduleDownload(for: url) { thirdResults.append($0) }
        
        XCTAssertEqual(session.events.count, 1)
        
        resumeDataHandler(Data("resumption".utf8))
        
        //one task serves both of them
        XCTAssertEqual(session.events.count, 2)
        
        guard case .downloadTaskWithResumeData = session.events.last else {
            XCTFail("Expected a resumed download task")
            return
        }
        
        sut.handleFailedDownloading(for: url, taskIdentifier: resumedTask.taskIdentifier, error: TestError.test)
        
        XCTAssertEqual(secondResults.count, 1)
        XCTAssertEqual(thirdResults.count, 1)
    }
    
    func test_givenARetiredTaskThatFailsAfterTheDownloadWasResumed_whenItCompletes_thenTheResumedDownloadIsUnaffected() {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubURLSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubURLSessionDownloadTask()
        downloadTask.taskIdentifierToReturn = 1
        session.downloadTaskToReturn = downloadTask
        
        let firstDownloadToken = sut.scheduleDownload(for: url) { _ in }
        sut.pauseDownload(firstDownloadToken)
        
        guard case let .cancelByProducingResumeData(resumeDataHandler) = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        resumeDataHandler(Data("resumption".utf8))
        
        let resumedTask = StubURLSessionDownloadTask()
        resumedTask.taskIdentifierToReturn = 2
        session.downloadTaskWithResumeDataToReturn = resumedTask
        
        var results = [Result<Data, Error>]()
        sut.scheduleDownload(for: url) { results.append($0) }
        
        /* The retired task winds down with a real error rather than a cancellation, so
         nothing but the phase stops it being mistaken for the download now running.
         */
        sut.handleFailedDownloading(for: url, taskIdentifier: downloadTask.taskIdentifier, error: TestError.test)
        
        XCTAssertTrue(results.isEmpty)
        
        sut.handleFailedDownloading(for: url, taskIdentifier: resumedTask.taskIdentifier, error: TestError.test)
        
        XCTAssertEqual(results.count, 1)
    }
    
    func test_givenADownloadThatIsPausing_whenMemoryPressureIsReceived_thenAJoinedCallerIsStillAnswered() {
        let url = URL(string: "http://test.com/example")!
        
        let memoryPressureMonitor = StubMemoryPressureMonitor()
        
        let session = StubURLSession()
        let sut = createSUT(session: session, memoryPressureMonitor: memoryPressureMonitor)
        
        guard case let .startMonitoring(memoryPressureHandler) = memoryPressureMonitor.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        let downloadTask = StubURLSessionDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        let firstDownloadToken = sut.scheduleDownload(for: url) { _ in }
        sut.pauseDownload(firstDownloadToken)
        
        guard case let .cancelByProducingResumeData(resumeDataHandler) = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        let resumedTask = StubURLSessionDownloadTask()
        resumedTask.taskIdentifierToReturn = 2
        session.downloadTaskWithResumeDataToReturn = resumedTask
        
        var results = [Result<Data, Error>]()
        sut.scheduleDownload(for: url) { results.append($0) }
        
        //purging must leave a pause in flight alone or the caller that joined it is stranded
        memoryPressureHandler()
        
        resumeDataHandler(Data("resumption".utf8))
        
        XCTAssertEqual(session.events.count, 2)
        
        guard case .downloadTaskWithResumeData = session.events.last else {
            XCTFail("Expected a resumed download task")
            return
        }
        
        sut.handleFailedDownloading(for: url, taskIdentifier: resumedTask.taskIdentifier, error: TestError.test)
        
        XCTAssertEqual(results.count, 1)
    }
    
    func test_givenAPausedDownloadWithResumptionData_whenTwoCallersScheduleTheSameURL_thenTheResumptionDataIsUsedOnce() {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubURLSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubURLSessionDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        let firstDownloadToken = sut.scheduleDownload(for: url) { _ in }
        sut.pauseDownload(firstDownloadToken)
        
        guard case let .cancelByProducingResumeData(resumeDataHandler) = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        resumeDataHandler(Data("resumption".utf8))
        
        session.downloadTaskWithResumeDataToReturn = StubURLSessionDownloadTask()
        
        sut.scheduleDownload(for: url) { _ in }
        sut.scheduleDownload(for: url) { _ in }
        
        //the second caller coalesces onto the resumed download rather than starting afresh
        XCTAssertEqual(session.events.count, 2)
        
        guard case .downloadTaskWithResumeData = session.events.last else {
            XCTFail("Expected the resumption data to be used exactly once")
            return
        }
    }
}

extension AssetDownloadsSessionTests {
    func createSUT(session: StubURLSession = StubURLSession(),
                   memoryPressureMonitor: MemoryPressureMonitor = StubMemoryPressureMonitor()) -> DefaultAssetDownloadsSession {
        let urlSessionFactory = StubURLSessionFactory()
        urlSessionFactory.sessionToReturn = session
        
        return createSUT(urlSessionFactory: urlSessionFactory,
                         memoryPressureMonitor: memoryPressureMonitor)
    }
    
    func createSUT(urlSessionFactory: URLSessionFactoryType,
                   memoryPressureMonitor: MemoryPressureMonitor = StubMemoryPressureMonitor()) -> DefaultAssetDownloadsSession {
        DefaultAssetDownloadsSession(urlSessionFactory: urlSessionFactory,
                                     memoryPressureMonitor: memoryPressureMonitor)
    }
}
