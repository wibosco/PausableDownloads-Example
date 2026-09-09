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
    
    // MARK: Load
    
    func test_givenViewModel_whenLoadIsCalled_thenImagesAreRetrieved() {
        let imagesService = StubImagesService()
        
        let sut = createSUT(imagesService: imagesService)
        
        sut.load()
        
        XCTAssertEqual(imagesService.events.count, 1)
        
        guard case .retrieveImages = imagesService.events.first else {
            XCTFail("Unexpected event")
            return
        }
    }
    
    func test_givenViewModel_whenLoadIsCalled_thenDelegateIsNotifiedOfLoadingImages() {
        let delegate = StubImageViewerViewModelDelegate()
        
        let sut = createSUT()
        sut.delegate = delegate
        
        sut.load()
        
        XCTAssertEqual(delegate.events.count, 1)
        
        guard case let .didChangeTo(state) = delegate.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(state, .loadingImages)
        XCTAssertEqual(sut.state, .loadingImages)
    }
    
    func test_givenLoadInProgress_whenImagesAreRetrieved_thenTheFirstAssetIsLoaded() {
        let imagesService = StubImagesService()
        let assetService = StubAssetService()
        
        let sut = createSUT(imagesService: imagesService,
                            assetService: assetService)
        
        sut.load()
        
        guard case let .retrieveImages(completionHandler) = imagesService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        let imageA = createImage(identifier: "a")
        let imageB = createImage(identifier: "b")
        
        completionHandler(.success([imageA, imageB]))
        
        XCTAssertEqual(assetService.events.count, 1)
        
        guard case let .loadImage(loadedImage, _) = assetService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(loadedImage, imageA)
        XCTAssertEqual(sut.state, .loadingAsset(description: imageA.url.absoluteString))
    }
    
    func test_givenLoadInProgress_whenImageRetrievalFails_thenStateTransitionsToFailed() {
        let imagesService = StubImagesService()
        let assetService = StubAssetService()
        
        let sut = createSUT(imagesService: imagesService,
                            assetService: assetService)
        
        sut.load()
        
        guard case let .retrieveImages(completionHandler) = imagesService.events.first else {
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
        
        guard case let .retrieveImages(completionHandler) = imagesService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(.success([]))
        
        XCTAssertTrue(assetService.events.isEmpty)
        XCTAssertEqual(sut.state, .loadingImages)
    }
    
    // MARK: Asset
    
    func test_givenAssetLoadInProgress_whenTheAssetLoads_thenStateTransitionsToLoadedAsset() {
        let imagesService = StubImagesService()
        let assetService = StubAssetService()
        
        let sut = createSUT(imagesService: imagesService,
                            assetService: assetService)
        
        let imageA = createImage(identifier: "a")
        
        loadImages([imageA], into: sut, using: imagesService)
        
        guard case let .loadImage(_, completionHandler) = assetService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        let image = UIImage()
        completionHandler(.success(LoadImageResult(imageDomainModel: imageA, image: image)))
        
        XCTAssertEqual(sut.state, .loadedAsset(image, description: imageA.url.absoluteString))
    }
    
    func test_givenAssetLoadInProgress_whenTheAssetFailsToLoad_thenStateTransitionsToFailed() {
        let imagesService = StubImagesService()
        let assetService = StubAssetService()
        
        let sut = createSUT(imagesService: imagesService,
                            assetService: assetService)
        
        loadImages([createImage(identifier: "a")], into: sut, using: imagesService)
        
        guard case let .loadImage(_, completionHandler) = assetService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(.failure(TestError.test))
        
        XCTAssertEqual(sut.state, .failed)
    }
    
    func test_givenAdvancedPastAnImage_whenTheStaleAssetLoads_thenStateIsUnchanged() {
        let imagesService = StubImagesService()
        let assetService = StubAssetService()
        let delegate = StubImageViewerViewModelDelegate()
        
        let sut = createSUT(imagesService: imagesService,
                            assetService: assetService)
        sut.delegate = delegate
        
        let imageA = createImage(identifier: "a")
        let imageB = createImage(identifier: "b")
        
        loadImages([imageA, imageB], into: sut, using: imagesService)
        
        guard case let .loadImage(_, staleCompletionHandler) = assetService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        sut.advance()
        
        let eventCountBeforeStaleResult = delegate.events.count
        
        staleCompletionHandler(.success(LoadImageResult(imageDomainModel: imageA, image: UIImage())))
        
        XCTAssertEqual(delegate.events.count, eventCountBeforeStaleResult)
        XCTAssertEqual(sut.state, .loadingAsset(description: imageB.url.absoluteString))
    }
    
    // MARK: Advance
    
    func test_givenLoadedImages_whenAdvanceIsCalled_thenTheCurrentAssetLoadIsCancelled() {
        let imagesService = StubImagesService()
        let assetService = StubAssetService()
        
        let sut = createSUT(imagesService: imagesService,
                            assetService: assetService)
        
        let imageA = createImage(identifier: "a")
        let imageB = createImage(identifier: "b")
        
        loadImages([imageA, imageB], into: sut, using: imagesService)
        
        sut.advance()
        
        XCTAssertEqual(assetService.events.count, 3)
        
        guard case let .cancelLoadingImage(cancelledImage) = assetService.events[1] else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(cancelledImage, imageA)
    }
    
    func test_givenLoadedImages_whenAdvanceIsCalled_thenTheNextAssetIsLoaded() {
        let imagesService = StubImagesService()
        let assetService = StubAssetService()
        
        let sut = createSUT(imagesService: imagesService,
                            assetService: assetService)
        
        let imageA = createImage(identifier: "a")
        let imageB = createImage(identifier: "b")
        
        loadImages([imageA, imageB], into: sut, using: imagesService)
        
        sut.advance()
        
        guard case let .loadImage(loadedImage, _) = assetService.events.last else {
            XCTFail("Unexpected event")
            return
        }
        
        XCTAssertEqual(loadedImage, imageB)
        XCTAssertEqual(sut.state, .loadingAsset(description: imageB.url.absoluteString))
    }
    
    func test_givenTheLastImage_whenAdvanceIsCalled_thenNoFurtherAssetIsLoaded() {
        let imagesService = StubImagesService()
        let assetService = StubAssetService()
        
        let sut = createSUT(imagesService: imagesService,
                            assetService: assetService)
        
        loadImages([createImage(identifier: "a")], into: sut, using: imagesService)
        
        let eventCountBeforeAdvance = assetService.events.count
        
        sut.advance()
        
        XCTAssertEqual(assetService.events.count, eventCountBeforeAdvance + 1)
        
        guard case .cancelLoadingImage = assetService.events.last else {
            XCTFail("Unexpected event")
            return
        }
    }
    
    func test_givenTheLastImage_whenAdvanceIsCalled_thenStateIsUnchanged() {
        let imagesService = StubImagesService()
        let assetService = StubAssetService()
        let delegate = StubImageViewerViewModelDelegate()
        
        let sut = createSUT(imagesService: imagesService,
                            assetService: assetService)
        sut.delegate = delegate
        
        let imageA = createImage(identifier: "a")
        
        loadImages([imageA], into: sut, using: imagesService)
        
        let eventCountBeforeAdvance = delegate.events.count
        
        sut.advance()
        
        XCTAssertEqual(delegate.events.count, eventCountBeforeAdvance)
        XCTAssertEqual(sut.state, .loadingAsset(description: imageA.url.absoluteString))
    }
    
    func test_givenNoImages_whenAdvanceIsCalled_thenNoAssetIsCancelledOrLoaded() {
        let assetService = StubAssetService()
        
        let sut = createSUT(assetService: assetService)
        
        sut.advance()
        
        XCTAssertTrue(assetService.events.isEmpty)
    }
}

extension ImageViewerViewModelTests {
    func createSUT(imagesService: ImagesService = StubImagesService(),
                   assetService: AssetService = StubAssetService()) -> ImageViewerViewModel {
        ImageViewerViewModel(imagesService: imagesService,
                             assetService: assetService)
    }
    
    func createImage(identifier: String) -> ImageDomainModel {
        ImageDomainModel(identifier: identifier,
                         url: URL(string: "http://test.com/\(identifier).jpg")!,
                         width: 100,
                         height: 100)
    }
    
    func loadImages(_ images: [ImageDomainModel],
                    into sut: ImageViewerViewModel,
                    using imagesService: StubImagesService) {
        sut.load()
        
        guard case let .retrieveImages(completionHandler) = imagesService.events.first else {
            XCTFail("Unexpected event")
            return
        }
        
        completionHandler(.success(images))
    }
}
