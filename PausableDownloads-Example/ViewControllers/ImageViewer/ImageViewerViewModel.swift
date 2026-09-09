//
//  ImageViewerViewModel.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 09/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import UIKit

protocol ImageViewerViewModelDelegate: AnyObject {
    func viewModel(_ viewModel: ImageViewerViewModel,
                   didChangeTo state: ImageViewerViewModel.State)
}

final class ImageViewerViewModel {
    enum State: Equatable {
        case loadingImages
        case loadingAsset(description: String)
        case loadedAsset(UIImage, description: String)
        case failed
    }
    
    weak var delegate: ImageViewerViewModelDelegate?
    
    private(set) var state: State = .loadingImages
    
    private let imagesService: ImagesService
    private let assetService: AssetService
    
    private var images = [ImageDomainModel]()
    private var index = 0
    
    // MARK: - Init
    
    init(imagesService: ImagesService = DefaultImagesService(),
         assetService: AssetService = DefaultAssetService()) {
        self.imagesService = imagesService
        self.assetService = assetService
    }
    
    // MARK: - Current
    
    private var currentImage: ImageDomainModel? {
        guard index < images.count else {
            return nil
        }
        
        return images[index]
    }
    
    // MARK: - Load
    
    func load() {
        transition(to: .loadingImages)
        
        imagesService.retrieveImages(callbackQueue: .main) { [weak self] (result) in
            guard let self = self else {
                return
            }
            
            switch result {
            case .success(let images):
                self.images = images
                self.loadCurrentAsset()
            case .failure(_):
                self.transition(to: .failed)
            }
        }
    }
    
    // MARK: - Advance
    
    func advance() {
        cancelCurrentAssetLoad()
        index += 1
        loadCurrentAsset()
    }
    
    // MARK: - Asset
    
    private func loadCurrentAsset() {
        guard let image = currentImage else {
            return
        }
        
        transition(to: .loadingAsset(description: image.url.absoluteString))
        
        assetService.loadImage(image, callbackQueue: .main) { [weak self] (result) in
            guard let self = self else {
                return
            }
            
            guard let currentImage = self.currentImage else {
                return
            }
            
            switch result {
            case .success(let loadResult):
                //a stale download for an image we have already moved past
                guard loadResult.imageDomainModel == currentImage else {
                    return
                }
                
                self.transition(to: .loadedAsset(loadResult.image, description: currentImage.url.absoluteString))
            case .failure(_):
                self.transition(to: .failed)
            }
        }
    }
    
    private func cancelCurrentAssetLoad() {
        guard let image = currentImage else {
            return
        }
        
        assetService.cancelLoadingImage(image)
    }
    
    // MARK: - State
    
    private func transition(to state: State) {
        self.state = state
        
        delegate?.viewModel(self, didChangeTo: state)
    }
}
