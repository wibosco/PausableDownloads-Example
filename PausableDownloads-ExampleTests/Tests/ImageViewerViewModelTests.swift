//
//  ImageViewerViewModelTests.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 09/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import XCTest

@testable import PausableDownloads_Example

final class ImageViewerViewModelTests: XCTestCase {
    
    // MARK: - Tests
    
    // MARK: Init
    
    func test_givenImage_whenInitialised_thenStateIsReady() {
        let image = ImageDomainModel.testData(identifier: "a",
                                              url: URL(string: "http://test.com/a.jpg")!)
        
        let sut = createSUT(imageDomainModel: image)
        
        XCTAssertEqual(sut.state, .ready(description: image.url.absoluteString))
    }
    
    // MARK: Load
    
    func test_givenViewModel_whenLoadIsCalled_thenTheAssetIsRequested() {
        let assetService = StubAssetService()
        let image = ImageDomainModel.testData(identifier: "a",
                                              url: URL(string: "http://test.com/a.jpg")!)
        
        let sut = createSUT(imageDomainModel: image, assetService: assetService)
        
        sut.load()
        
        XCTAssertEqual(assetService.events.count, 1)
        
        guard case let .loadImage(loadedImage, callbackQueue, _) = assetService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(loadedImage, image)
        XCTAssertTrue(callbackQueue === DispatchQueue.main)
        XCTAssertEqual(sut.state, .loadingAsset(description: image.url.absoluteString))
    }
    
    func test_givenAssetLoadInProgress_whenTheAssetLoads_thenStateTransitionsToLoadedAsset() {
        let assetService = StubAssetService()
        let image = ImageDomainModel.testData(identifier: "a",
                                              url: URL(string: "http://test.com/a.jpg")!)
        
        let sut = createSUT(imageDomainModel: image, assetService: assetService)
        
        sut.load()
        
        guard case let .loadImage(_, _, completionHandler) = assetService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        let loadedImage = UIImage()
        completionHandler(.success(LoadImageResult(imageDomainModel: image, image: loadedImage)))
        
        XCTAssertEqual(sut.state, .loadedAsset(loadedImage, description: image.url.absoluteString))
    }
    
    func test_givenAssetLoadInProgress_whenTheAssetFailsToLoad_thenStateTransitionsToFailed() {
        let assetService = StubAssetService()
        
        let sut = createSUT(assetService: assetService)
        
        sut.load()
        
        guard case let .loadImage(_, _, completionHandler) = assetService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(.failure(TestError.test))
        
        XCTAssertEqual(sut.state, .failed)
    }
    
    func test_givenAssetLoadInProgress_whenAResultForAnotherImageArrives_thenStateIsUnchanged() {
        let assetService = StubAssetService()
        let delegate = StubImageViewerViewModelDelegate()
        
        let imageA = ImageDomainModel.testData(identifier: "a",
                                               url: URL(string: "http://test.com/a.jpg")!)
        let imageB = ImageDomainModel.testData(identifier: "b",
                                               url: URL(string: "http://test.com/b.jpg")!)
        
        let sut = createSUT(imageDomainModel: imageA, assetService: assetService)
        sut.delegate = delegate
        
        sut.load()
        
        guard case let .loadImage(_, _, completionHandler) = assetService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        let eventCountBeforeStaleResult = delegate.events.count
        
        completionHandler(.success(LoadImageResult(imageDomainModel: imageB, image: UIImage())))
        
        XCTAssertEqual(delegate.events.count, eventCountBeforeStaleResult)
        XCTAssertEqual(sut.state, .loadingAsset(description: imageA.url.absoluteString))
    }
    
    func test_givenAssetLoadInProgress_whenLoadIsCalledAgain_thenTheAssetIsNotRequestedASecondTime() {
        let assetService = StubAssetService()
        
        let sut = createSUT(assetService: assetService)
        
        sut.load()
        sut.load()
        
        XCTAssertEqual(assetService.events.count, 1)
    }
    
    func test_givenLoadedAsset_whenLoadIsCalledAgain_thenTheAssetIsNotRequestedASecondTime() {
        let assetService = StubAssetService()
        let image = ImageDomainModel.testData(identifier: "a",
                                              url: URL(string: "http://test.com/a.jpg")!)
        
        let sut = createSUT(imageDomainModel: image, assetService: assetService)
        
        sut.load()
        
        guard case let .loadImage(_, _, completionHandler) = assetService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        let loadedImage = UIImage()
        completionHandler(.success(LoadImageResult(imageDomainModel: image, image: loadedImage)))
        
        sut.load()
        
        XCTAssertEqual(assetService.events.count, 1)
        XCTAssertEqual(sut.state, .loadedAsset(loadedImage, description: image.url.absoluteString))
    }
    
    // MARK: Pause
    
    func test_givenAssetLoadInProgress_whenPauseIsCalled_thenTheAssetLoadIsCancelledAndStateReturnsToReady() {
        let assetService = StubAssetService()
        let image = ImageDomainModel.testData(identifier: "a",
                                              url: URL(string: "http://test.com/a.jpg")!)
        
        let downloadToken = DownloadToken(url: image.url)
        assetService.downloadTokenToReturn = downloadToken
        
        let sut = createSUT(imageDomainModel: image, assetService: assetService)
        
        sut.load()
        sut.pause()
        
        XCTAssertEqual(assetService.events.count, 2)
        
        guard case let .cancelLoadingImage(cancelledDownloadToken) = assetService.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        //the view model pauses the download it started, not whatever shares the URL
        XCTAssertEqual(cancelledDownloadToken, downloadToken)
        XCTAssertEqual(sut.state, .ready(description: image.url.absoluteString))
    }
    
    func test_givenNoAssetLoadInProgress_whenPauseIsCalled_thenNothingIsCancelled() {
        let assetService = StubAssetService()
        
        let sut = createSUT(assetService: assetService)
        
        sut.pause()
        
        XCTAssertTrue(assetService.events.isEmpty)
    }
    
    func test_givenPausedAssetLoad_whenLoadIsCalledAgain_thenTheAssetIsRequestedAgain() {
        let assetService = StubAssetService()
        let image = ImageDomainModel.testData()
        
        assetService.downloadTokenToReturn = DownloadToken(url: image.url)
        
        let sut = createSUT(imageDomainModel: image, assetService: assetService)
        
        sut.load()
        sut.pause()
        sut.load()
        
        XCTAssertEqual(assetService.events.count, 3)
        
        guard case .loadImage = assetService.events.last else {
            XCTFail("Unexpected event")
            return
        }
    }

}

extension ImageViewerViewModelTests {
    func createSUT(imageDomainModel: ImageDomainModel = .testData(),
                   assetService: AssetService = StubAssetService()) -> ImageViewerViewModel {
        ImageViewerViewModel(imageDomainModel: imageDomainModel,
                             assetService: assetService)
    }
}
