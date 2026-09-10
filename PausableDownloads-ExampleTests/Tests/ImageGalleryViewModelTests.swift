//
//  ImageGalleryViewModelTests.swift
//  PausableDownloads-ExampleTests
//
//  Created by William Boles on 09/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import XCTest

@testable import PausableDownloads_Example

final class ImageGalleryViewModelTests: XCTestCase {
    
    // MARK: - Tests
    
    // MARK: Load
    
    func test_givenViewModel_whenLoadIsCalled_thenImagesAreRetrievedOnTheMainQueue() {
        let imagesService = StubImagesService()
        let delegate = StubImageGalleryViewModelDelegate()
        
        let sut = createSUT(imagesService: imagesService)
        sut.delegate = delegate
        
        sut.load()
        
        XCTAssertEqual(imagesService.events.count, 1)
        
        guard case let .retrieveImages(callbackQueue, _) = imagesService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertTrue(callbackQueue === DispatchQueue.main)
        XCTAssertEqual(sut.state, .loadingImages)
        
        guard case let .didChangeTo(state) = delegate.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(state, .loadingImages)
    }
    
    func test_givenLoadInProgress_whenImagesAreRetrieved_thenTheFirstAssetIsLoaded() {
        let imagesService = StubImagesService()
        let assetService = StubAssetService()
        
        let sut = createSUT(imagesService: imagesService,
                            assetService: assetService)
        
        sut.load()
        
        guard case let .retrieveImages(_, completionHandler) = imagesService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(.success([imageA, imageB]))
        
        XCTAssertEqual(sut.state, .loadedImages)
        XCTAssertEqual(sut.numberOfImages, 2)
        XCTAssertEqual(sut.currentIndex, 0)
        
        XCTAssertEqual(assetService.events.count, 1)
        
        guard case let .loadImage(loadedImage, _, _) = assetService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(loadedImage, imageA)
    }
    
    func test_givenLoadInProgress_whenImageRetrievalFails_thenStateTransitionsToFailed() {
        let imagesService = StubImagesService()
        let assetService = StubAssetService()
        
        let sut = createSUT(imagesService: imagesService,
                            assetService: assetService)
        
        sut.load()
        
        guard case let .retrieveImages(_, completionHandler) = imagesService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(.failure(TestError.test))
        
        XCTAssertEqual(sut.state, .failed)
        XCTAssertTrue(assetService.events.isEmpty)
    }
    
    func test_givenLoadInProgress_whenNoImagesAreRetrieved_thenNoAssetIsLoaded() {
        let imagesService = StubImagesService()
        let assetService = StubAssetService()
        
        let sut = createSUT(imagesService: imagesService,
                            assetService: assetService)
        
        sut.load()
        
        guard case let .retrieveImages(_, completionHandler) = imagesService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(.success([]))
        
        XCTAssertEqual(sut.state, .loadedImages)
        XCTAssertEqual(sut.numberOfImages, 0)
        XCTAssertTrue(assetService.events.isEmpty)
    }
    
    // MARK: Pages
    
    func test_givenRetrievedImages_whenAViewModelIsRequestedTwiceForTheSameIndex_thenTheSameInstanceIsReturned() {
        let sut = createLoadedSUT()
        
        let first = sut.viewModel(at: 1)
        let second = sut.viewModel(at: 1)
        
        XCTAssertNotNil(first)
        XCTAssertTrue(first === second)
    }
    
    func test_givenRetrievedImages_whenAViewModelIsRequestedForEachIndex_thenItRepresentsThatImage() {
        let sut = createLoadedSUT()
        
        XCTAssertEqual(sut.viewModel(at: 0)?.imageDomainModel, imageA)
        XCTAssertEqual(sut.viewModel(at: 1)?.imageDomainModel, imageB)
    }
    
    func test_givenRetrievedImages_whenAViewModelIsRequestedOutOfBounds_thenNilIsReturned() {
        let sut = createLoadedSUT()
        
        XCTAssertNil(sut.viewModel(at: -1))
        XCTAssertNil(sut.viewModel(at: 2))
    }
    
    // MARK: Move
    
    func test_givenLoadedImages_whenMoveToIsCalled_thenTheOutgoingAssetIsPausedAndTheIncomingOneIsLoaded() {
        let assetService = StubAssetService()
        
        let sut = createLoadedSUT(assetService: assetService)
        
        sut.moveTo(index: 1)
        
        XCTAssertEqual(sut.currentIndex, 1)
        XCTAssertEqual(assetService.events.count, 3)
        
        guard case let .cancelLoadingImage(pausedDownloadID) = assetService.events[1] else {
            XCTFail("Unexpected event")
            return
        }
        
        //the download issued for imageA, which is the page being swiped away from
        XCTAssertEqual(pausedDownloadID, assetService.issuedDownloadIDs[0])
        
        guard case let .loadImage(loadedImage, _, _) = assetService.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(loadedImage, imageB)
    }
    
    func test_givenAPausedImage_whenMovedBackTo_thenItsAssetIsLoadedAgain() {
        let assetService = StubAssetService()
        
        let sut = createLoadedSUT(assetService: assetService)
        
        sut.moveTo(index: 1)
        sut.moveTo(index: 0)
        
        XCTAssertEqual(sut.currentIndex, 0)
        XCTAssertEqual(assetService.events.count, 5)
        
        guard case let .cancelLoadingImage(pausedDownloadID) = assetService.events[3] else {
            XCTFail("Unexpected event")
            return
        }
        
        //the download issued for imageB, which is the page being swiped away from
        XCTAssertEqual(pausedDownloadID, assetService.issuedDownloadIDs[1])
        
        /* Rescheduling the same URL is what hands the paused download back to the
         session to resume rather than restart.
         */
        guard case let .loadImage(loadedImage, _, _) = assetService.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(loadedImage, imageA)
    }
    
    func test_givenLoadedImages_whenMoveToIsCalledForTheCurrentIndex_thenNothingHappens() {
        let assetService = StubAssetService()
        
        let sut = createLoadedSUT(assetService: assetService)
        
        let eventCountBeforeMove = assetService.events.count
        
        sut.moveTo(index: 0)
        
        XCTAssertEqual(assetService.events.count, eventCountBeforeMove)
        XCTAssertEqual(sut.currentIndex, 0)
    }
    
    func test_givenLoadedImages_whenMoveToIsCalledOutOfBounds_thenNothingHappens() {
        let assetService = StubAssetService()
        
        let sut = createLoadedSUT(assetService: assetService)
        
        let eventCountBeforeMove = assetService.events.count
        
        sut.moveTo(index: 2)
        sut.moveTo(index: -1)
        
        XCTAssertEqual(assetService.events.count, eventCountBeforeMove)
        XCTAssertEqual(sut.currentIndex, 0)
    }
}

extension ImageGalleryViewModelTests {
    var imageA: ImageDomainModel {
        ImageDomainModel.testData(identifier: "a",
                                  url: URL(string: "http://test.com/a.jpg")!)
    }
    
    var imageB: ImageDomainModel {
        ImageDomainModel.testData(identifier: "b",
                                  url: URL(string: "http://test.com/b.jpg")!)
    }
    
    func createSUT(imagesService: ImagesService = StubImagesService(),
                   assetService: AssetService = StubAssetService()) -> ImageGalleryViewModel {
        ImageGalleryViewModel(imagesService: imagesService,
                              assetService: assetService)
    }
    
    func createLoadedSUT(assetService: AssetService = StubAssetService()) -> ImageGalleryViewModel {
        let imagesService = StubImagesService()
        
        let sut = createSUT(imagesService: imagesService,
                            assetService: assetService)
        
        sut.load()
        
        guard case let .retrieveImages(_, completionHandler) = imagesService.events.first else {
            fatalError("Expected images to have been retrieved")
        }
        
        completionHandler(.success([imageA, imageB]))
        
        return sut
    }
}
