//
//  DownloaderTests.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 15/12/2019.
//  Copyright © 2019 William Boles. All rights reserved.
//

import XCTest

@testable import PausableDownloads_Example

class DownloaderTests: XCTestCase {
    
    // MARK: - Tests
    
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
        
        let session = StubDownloadSession()
        let sut = createSUT(session: session, memoryPressureMonitor: memoryPressureMonitor)
        
        guard case let .startMonitoring(memoryPressureHandler) = memoryPressureMonitor.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        let downloadTask = StubDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        let downloadToken = sut.download(url) { _ in }
        
        XCTAssertEqual(session.events.count, 1)
        
        sut.cancel(downloadToken)
        
        XCTAssertEqual(downloadTask.events.count, 2)
        
        guard case let .cancelByProducingResumeData(resumeDataHandler) = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        resumeDataHandler(Data("resumption".utf8))
        
        memoryPressureHandler()
        
        //the purged item took its resumption data with it, so the next schedule starts over
        session.downloadTaskWithResumeDataToReturn = StubDownloadTask()
        
        sut.download(url) { _ in }
        
        XCTAssertEqual(session.events.count, 2)
        
        guard case .downloadTask = session.events.last else {
            XCTFail("Expected a new download task rather than a resumed one")
            return
        }
    }
    
    func test_givenActiveDownload_whenMemoryPressureIsReceived_thenTheDownloadTaskIsNotCancelled() {
        let url = URL(string: "http://test.com/example")!
        
        let memoryPressureMonitor = StubMemoryPressureMonitor()
        
        let session = StubDownloadSession()
        let sut = createSUT(session: session, memoryPressureMonitor: memoryPressureMonitor)
        
        let downloadTask = StubDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        guard case let .startMonitoring(memoryPressureHandler) = memoryPressureMonitor.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        sut.download(url) { _ in }
        
        XCTAssertEqual(downloadTask.events.count, 1)
        
        memoryPressureHandler()
        
        XCTAssertEqual(downloadTask.events.count, 1)
        
        guard case .resume = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
    }
    
    // MARK: Schedule
    
    func test_givenNoExistingDownload_whendownloadIsCalled_thenDownloadTaskIsCreatedForURLAndResumed() {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubDownloadSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        sut.download(url) { _ in }
        
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
    
    func test_givenNoExistingDownloads_whendownloadIsCalledForTwoDifferentURLs_thenBothDownloadTasksAreResumed() {
        let session = StubDownloadSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        let urlA = URL(string: "http://example.com/resourceA")!
        let urlB = URL(string: "http://example.com/resourceB")!
        
        sut.download(urlA) { _ in }
        sut.download(urlB) { _ in }
        
        XCTAssertEqual(downloadTask.events.count, 2)
        
        guard case .resume = downloadTask.events.first,
              case .resume = downloadTask.events.last else {
            XCTFail("Unexpected events")
            return
        }
    }
    
    func test_givenInFlightDownload_whendownloadIsCalledForTheSameURL_thenOneDownloadIsSharedAndBothCompletionHandlersAreCalled() {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubDownloadSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubDownloadTask()
        downloadTask.taskIdentifierToReturn = 1
        session.downloadTaskToReturn = downloadTask
        
        var firstResults = [Result<Data, Error>]()
        sut.download(url) { firstResults.append($0) }
        
        var secondResults = [Result<Data, Error>]()
        sut.download(url) { secondResults.append($0) }
        
        //a second caller coalesces onto the download that's already running
        XCTAssertEqual(session.events.count, 1)
        XCTAssertEqual(downloadTask.events.count, 1)
        
        sut.handleFailedDownloading(for: url, taskIdentifier: downloadTask.taskIdentifier, error: TestError.test)
        
        XCTAssertEqual(firstResults.count, 1)
        XCTAssertEqual(secondResults.count, 1)
    }
    
    func test_givenTwoCallersForTheSameURL_whenOneCancels_thenTheSharedTaskIsNotCancelledAndTheOtherIsStillAnswered() throws {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubDownloadSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubDownloadTask()
        downloadTask.taskIdentifierToReturn = 1
        session.downloadTaskToReturn = downloadTask
        
        var firstResults = [Result<Data, Error>]()
        let firstDownloadToken = sut.download(url) { firstResults.append($0) }
        
        var secondResults = [Result<Data, Error>]()
        sut.download(url) { secondResults.append($0) }
        
        sut.cancel(firstDownloadToken)
        
        //the second caller still wants this URL, so the shared task keeps running
        XCTAssertEqual(downloadTask.events.count, 1)
        
        guard case .resume = downloadTask.events.last else {
            XCTFail("Expected the shared download not to be cancelled")
            return
        }

        //the caller that cancelled is answered there and then rather than being left waiting
        XCTAssertEqual(firstResults.count, 1)

        guard case let .failure(error) = try XCTUnwrap(firstResults.first),
              case DownloadError.cancelled = error else {
            XCTFail("Expected a cancellation failure")
            return
        }

        sut.handleFailedDownloading(for: url, taskIdentifier: downloadTask.taskIdentifier, error: TestError.test)

        //only the caller still waiting hears about how the download itself ended
        XCTAssertEqual(secondResults.count, 1)
        XCTAssertEqual(firstResults.count, 1)
    }
    
    func test_givenPausedDownloadThatProducedNoResumptionData_whendownloadIsCalledForTheSameURL_thenTheDownloadRestarts() {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubDownloadSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        let downloadToken = sut.download(url) { _ in }
        sut.cancel(downloadToken)
        
        XCTAssertEqual(downloadTask.events.count, 2)
        
        guard case let .cancelByProducingResumeData(resumeDataHandler) = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        //a server that can't resume hands back no data, so starting over is all that's left
        resumeDataHandler(nil)
        
        sut.download(url) { _ in }
        
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
    
    func test_givenAPauseStillProducingResumptionData_whendownloadIsCalledForTheSameURL_thenAFreshTaskIsStartedWithoutWaiting() {
        let url = URL(string: "http://test.com/example")!

        let session = StubDownloadSession()
        let sut = createSUT(session: session)

        let downloadTask = StubDownloadTask()
        session.downloadTaskToReturn = downloadTask

        let downloadToken = sut.download(url) { _ in }
        sut.cancel(downloadToken)

        guard case .cancelByProducingResumeData = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }

        //rescheduling whilst the resumption data is still in flight - the fast swipe back.
        //Nothing is holding the download open for that data, so it starts over rather than
        //leaving the caller waiting on data that may never arrive
        sut.download(url) { _ in }

        XCTAssertEqual(session.events.count, 2)

        guard case .downloadTask = session.events.last else {
            XCTFail("Expected a new download task rather than a resumed one")
            return
        }
    }

    func test_givenARestartedDownload_whenTheEarlierPausesResumptionDataLands_thenItIsDiscarded() {
        let url = URL(string: "http://test.com/example")!

        let session = StubDownloadSession()
        let sut = createSUT(session: session)

        let downloadTask = StubDownloadTask()
        session.downloadTaskToReturn = downloadTask
        session.downloadTaskWithResumeDataToReturn = StubDownloadTask()

        let downloadToken = sut.download(url) { _ in }
        sut.cancel(downloadToken)

        guard case let .cancelByProducingResumeData(resumeDataHandler) = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }

        let restartedDownloadToken = sut.download(url) { _ in }

        XCTAssertEqual(session.events.count, 2)

        //the download this data belonged to has already started over, so it is of no use
        //to anybody by the time it lands
        resumeDataHandler(Data("resumption".utf8))

        XCTAssertEqual(session.events.count, 2)

        //nor is it kept around for the next request to pick up
        sut.cancel(restartedDownloadToken)
        sut.download(url) { _ in }

        XCTAssertEqual(session.events.count, 3)

        guard case .downloadTask = session.events.last else {
            XCTFail("Expected the discarded resumption data not to be used")
            return
        }
    }
    
    func test_givenCancelledDownload_whenTheRetiredTaskReportsItsCancellation_thenTheCallerIsNotToldTwice() throws {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubDownloadSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubDownloadTask()
        downloadTask.taskIdentifierToReturn = 1
        session.downloadTaskToReturn = downloadTask
        
        var results = [Result<Data, Error>]()
        let downloadToken = sut.download(url) { results.append($0) }
        
        guard case .downloadTask = session.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        sut.cancel(downloadToken)

        //the cancel itself is what answers the caller
        XCTAssertEqual(results.count, 1)

        guard case let .failure(error) = try XCTUnwrap(results.first),
              case DownloadError.cancelled = error else {
            XCTFail("Expected a cancellation failure")
            return
        }

        //pausing cancels the underlying task, which reports back as a cancellation error
        sut.handleFailedDownloading(for: url, taskIdentifier: downloadTask.taskIdentifier, error: URLError(.cancelled))

        XCTAssertEqual(results.count, 1)
    }
    
    func test_givenCompletedDownload_whendownloadIsCalledForTheSameURL_thenANewDownloadTaskIsCreated() throws {
        let url = URL(string: "http://test.com/example")!
        let fileURL = try XCTUnwrap(Bundle(for: type(of: self)).url(forResource: "square", withExtension: "pdf"))
        
        let session = StubDownloadSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubDownloadTask()
        downloadTask.taskIdentifierToReturn = 1
        session.downloadTaskToReturn = downloadTask
        
        sut.download(url) { _ in }
        
        XCTAssertEqual(session.events.count, 1)
        
        guard case .downloadTask = session.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        sut.handleFinishedDownloading(for: url, taskIdentifier: downloadTask.taskIdentifier, to: fileURL)
        
        sut.download(url) { _ in }
        
        XCTAssertEqual(session.events.count, 2)
    }
    
    func test_givenScheduledDownload_whenTheDownloadTaskFails_thenTheCompletionHandlerIsCalled() {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubDownloadSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubDownloadTask()
        downloadTask.taskIdentifierToReturn = 1
        session.downloadTaskToReturn = downloadTask
        
        let completionExpectation = expectation(description: "completionExpectation")
        sut.download(url) { _ in
            completionExpectation.fulfill()
        }
        
        guard case .downloadTask = session.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        sut.handleFailedDownloading(for: url, taskIdentifier: downloadTask.taskIdentifier, error: TestError.test)
        
        waitForExpectations(timeout: 3, handler: nil)
    }
    
    func test_givenPausedDownloadWithResumptionData_whendownloadIsCalledForTheSameURL_thenDownloadTaskIsCreatedFromResumeData() {
        let url = URL(string: "http://test.com/example")!
        let resumptionData = Data("resumption".utf8)
        
        let session = StubDownloadSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        let downloadToken = sut.download(url) { _ in }
        sut.cancel(downloadToken)
        
        guard case let .cancelByProducingResumeData(resumeDataHandler) = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        resumeDataHandler(resumptionData)
        
        let resumedDownloadTask = StubDownloadTask()
        session.downloadTaskWithResumeDataToReturn = resumedDownloadTask
        
        sut.download(url) { _ in }
        
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
        
        let session = StubDownloadSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubDownloadTask()
        downloadTask.taskIdentifierToReturn = 1
        session.downloadTaskToReturn = downloadTask
        
        var receivedResult: Result<Data, Error>?
        let completionExpectation = expectation(description: "completionExpectation")
        sut.download(url) { (result) in
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
        
        let session = StubDownloadSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubDownloadTask()
        downloadTask.taskIdentifierToReturn = 1
        session.downloadTaskToReturn = downloadTask
        
        var receivedResult: Result<Data, Error>?
        let completionExpectation = expectation(description: "completionExpectation")
        sut.download(url) { (result) in
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
              case let DownloadError.failed(underlyingError) = error else {
            XCTFail("Expected a retrieval failure")
            return
        }
        
        XCTAssertEqual(underlyingError as? TestError, .test)
    }
    
    func test_givenScheduledDownload_whenTheDownloadTaskCompletesWithAnUnreadableFileURL_thenTheCompletionHandlerReceivesAnInvalidDataFailure() throws {
        let url = URL(string: "http://test.com/example")!
        let unreadableFileURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("does-not-exist-\(UUID().uuidString)")
        
        let session = StubDownloadSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubDownloadTask()
        downloadTask.taskIdentifierToReturn = 1
        session.downloadTaskToReturn = downloadTask
        
        var receivedResult: Result<Data, Error>?
        let completionExpectation = expectation(description: "completionExpectation")
        sut.download(url) { (result) in
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
              case DownloadError.invalidData = error else {
            XCTFail("Expected an invalid data failure")
            return
        }
    }
    
    func test_givenPauseThenResume_whenTheCancelledDownloadTaskCompletes_thenItIsIgnoredAndTheResumedTaskStillCompletes() {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubDownloadSession()
        let sut = createSUT(session: session)
        
        let retiredDownloadTask = StubDownloadTask()
        retiredDownloadTask.taskIdentifierToReturn = 1
        session.downloadTaskToReturn = retiredDownloadTask
        
        let downloadToken = sut.download(url) { _ in }
        sut.cancel(downloadToken)
        
        guard case let .cancelByProducingResumeData(resumeDataHandler) = retiredDownloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        resumeDataHandler(Data("resumption".utf8))
        
        let resumedDownloadTask = StubDownloadTask()
        resumedDownloadTask.taskIdentifierToReturn = 2
        session.downloadTaskWithResumeDataToReturn = resumedDownloadTask
        
        var results = [Result<Data, Error>]()
        sut.download(url) { results.append($0) }
        
        //the task the pause retired winds down late and must not be mistaken for this download
        sut.handleFailedDownloading(for: url, taskIdentifier: retiredDownloadTask.taskIdentifier, error: URLError(.cancelled))
        
        XCTAssertTrue(results.isEmpty)
        
        sut.handleFailedDownloading(for: url, taskIdentifier: resumedDownloadTask.taskIdentifier, error: TestError.test)
        
        XCTAssertEqual(results.count, 1)
    }
    
    func test_givenNoMatchingDownload_whenAnEventForAnUnknownTaskIsReceived_thenItIsIgnored() {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubDownloadSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubDownloadTask()
        downloadTask.taskIdentifierToReturn = 1
        session.downloadTaskToReturn = downloadTask
        
        var results = [Result<Data, Error>]()
        sut.download(url) { results.append($0) }
        
        let unknownURL = URL(string: "http://test.com/unknown")!
        let unknownTaskIdentifier = 2
        
        sut.handleProgress(for: unknownURL, totalBytesWritten: 50, expectedTotalBytes: 100)
        sut.handleResumption(for: unknownURL, fileOffset: 50, expectedTotalBytes: 100)
        sut.handleFinishedDownloading(for: unknownURL, taskIdentifier: unknownTaskIdentifier, to: URL(fileURLWithPath: "/dev/null"))
        sut.handleFailedDownloading(for: unknownURL, taskIdentifier: unknownTaskIdentifier, error: TestError.test)
        
        XCTAssertTrue(results.isEmpty)
    }
    
    // MARK: Cancel
    
    func test_givenScheduledDownload_whenCancelIsCalled_thenDownloadTaskIsCancelledByProducingResumeData() {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubDownloadSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        let downloadToken = sut.download(url) { _ in }
        sut.cancel(downloadToken)
        
        XCTAssertEqual(downloadTask.events.count, 2)
        
        guard case .cancelByProducingResumeData = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
    }
    
    func test_givenScheduledDownload_whenCancelIsCalled_thenTheCallerIsToldItWasCancelled() throws {
        let url = URL(string: "http://test.com/example")!

        let session = StubDownloadSession()
        let sut = createSUT(session: session)

        let downloadTask = StubDownloadTask()
        session.downloadTaskToReturn = downloadTask

        var results = [Result<Data, Error>]()
        let downloadToken = sut.download(url) { results.append($0) }

        sut.cancel(downloadToken)

        XCTAssertEqual(results.count, 1)

        guard case let .failure(error) = try XCTUnwrap(results.first),
              case DownloadError.cancelled = error else {
            XCTFail("Expected a cancellation failure")
            return
        }
    }

    func test_givenNoScheduledDownloads_whenCancelIsCalledForAnUnknownToken_thenNoDownloadTaskEventsAreRecorded() {
        let session = StubDownloadSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        sut.cancel(DownloadToken())
        
        XCTAssertTrue(session.events.isEmpty)
        XCTAssertTrue(downloadTask.events.isEmpty)
    }
    
    // MARK: - Coalescing
    
    func test_givenTwoCoalescedDownloads_whenTheDownloadTaskCompletes_thenBothCompletionHandlersReceiveTheSameData() throws {
        let url = URL(string: "http://test.com/example")!
        let fileURL = try XCTUnwrap(Bundle(for: type(of: self)).url(forResource: "square", withExtension: "pdf"))
        let expectedData = try Data(contentsOf: fileURL)
        
        XCTAssertFalse(expectedData.isEmpty)
        
        let session = StubDownloadSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubDownloadTask()
        downloadTask.taskIdentifierToReturn = 1
        session.downloadTaskToReturn = downloadTask
        
        var firstResult: Result<Data, Error>?
        sut.download(url) { firstResult = $0 }
        
        var secondResult: Result<Data, Error>?
        sut.download(url) { secondResult = $0 }
        
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
    
    func test_givenTwoCallersForTheSameURL_whenBothCancel_thenTheSharedTaskIsCancelledOnce() {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubDownloadSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        let firstDownloadToken = sut.download(url) { _ in }
        let secondDownloadToken = sut.download(url) { _ in }
        
        sut.cancel(firstDownloadToken)
        
        //somebody still wants it, so nothing is cancelled yet
        XCTAssertEqual(downloadTask.events.count, 1)
        
        sut.cancel(secondDownloadToken)
        
        //the last interested caller has gone, so the shared task is cancelled exactly once
        XCTAssertEqual(downloadTask.events.count, 2)
        
        guard case .cancelByProducingResumeData = downloadTask.events.last else {
            XCTFail("Expected the shared download to be cancelled")
            return
        }
    }
    
    func test_givenAPauseStillProducingResumptionData_whenTwoCallersScheduleTheSameURL_thenTheyCoalesceOntoOneRestartedTask() {
        let url = URL(string: "http://test.com/example")!

        let session = StubDownloadSession()
        let sut = createSUT(session: session)

        let downloadTask = StubDownloadTask()
        downloadTask.taskIdentifierToReturn = 1
        session.downloadTaskToReturn = downloadTask

        let firstDownloadToken = sut.download(url) { _ in }
        sut.cancel(firstDownloadToken)

        guard case .cancelByProducingResumeData = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }

        let restartedDownloadTask = StubDownloadTask()
        restartedDownloadTask.taskIdentifierToReturn = 2
        session.downloadTaskToReturn = restartedDownloadTask

        //both scheduled whilst the pause is still in flight, so the first starts the
        //download over and the second coalesces onto it
        var secondResults = [Result<Data, Error>]()
        sut.download(url) { secondResults.append($0) }

        var thirdResults = [Result<Data, Error>]()
        sut.download(url) { thirdResults.append($0) }

        XCTAssertEqual(session.events.count, 2)

        guard case .downloadTask = session.events.last else {
            XCTFail("Expected a new download task rather than a resumed one")
            return
        }

        //one task serves both of them
        sut.handleFailedDownloading(for: url, taskIdentifier: restartedDownloadTask.taskIdentifier, error: TestError.test)

        XCTAssertEqual(secondResults.count, 1)
        XCTAssertEqual(thirdResults.count, 1)
    }
    
    func test_givenARetiredTaskThatFailsAfterTheDownloadWasResumed_whenItCompletes_thenTheResumedDownloadIsUnaffected() {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubDownloadSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubDownloadTask()
        downloadTask.taskIdentifierToReturn = 1
        session.downloadTaskToReturn = downloadTask
        
        let firstDownloadToken = sut.download(url) { _ in }
        sut.cancel(firstDownloadToken)
        
        guard case let .cancelByProducingResumeData(resumeDataHandler) = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        resumeDataHandler(Data("resumption".utf8))
        
        let resumedTask = StubDownloadTask()
        resumedTask.taskIdentifierToReturn = 2
        session.downloadTaskWithResumeDataToReturn = resumedTask
        
        var results = [Result<Data, Error>]()
        sut.download(url) { results.append($0) }
        
        //The retired task winds down with a real error rather than a cancellation, so
        //nothing but its task identifier stops it being mistaken for the download now
        //running.
        sut.handleFailedDownloading(for: url, taskIdentifier: downloadTask.taskIdentifier, error: TestError.test)
        
        XCTAssertTrue(results.isEmpty)
        
        sut.handleFailedDownloading(for: url, taskIdentifier: resumedTask.taskIdentifier, error: TestError.test)
        
        XCTAssertEqual(results.count, 1)
    }
    
    func test_givenAPausedDownloadWithResumptionData_whenTwoCallersScheduleTheSameURL_thenTheResumptionDataIsUsedOnce() {
        let url = URL(string: "http://test.com/example")!
        
        let session = StubDownloadSession()
        let sut = createSUT(session: session)
        
        let downloadTask = StubDownloadTask()
        session.downloadTaskToReturn = downloadTask
        
        let firstDownloadToken = sut.download(url) { _ in }
        sut.cancel(firstDownloadToken)
        
        guard case let .cancelByProducingResumeData(resumeDataHandler) = downloadTask.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        resumeDataHandler(Data("resumption".utf8))
        
        session.downloadTaskWithResumeDataToReturn = StubDownloadTask()
        
        sut.download(url) { _ in }
        sut.download(url) { _ in }
        
        //the second caller coalesces onto the resumed download rather than starting afresh
        XCTAssertEqual(session.events.count, 2)
        
        guard case .downloadTaskWithResumeData = session.events.last else {
            XCTFail("Expected the resumption data to be used exactly once")
            return
        }
    }
}

extension DownloaderTests {
    func createSUT(session: StubDownloadSession = StubDownloadSession(),
                   memoryPressureMonitor: MemoryPressureMonitor = StubMemoryPressureMonitor()) -> DefaultDownloader {
        let sessionFactory = StubDownloadSessionFactory()
        sessionFactory.sessionToReturn = session
        
        return DefaultDownloader(sessionFactory: sessionFactory,
                                 memoryPressureMonitor: memoryPressureMonitor)
    }
}
