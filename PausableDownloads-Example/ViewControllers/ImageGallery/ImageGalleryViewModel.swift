//
//  ImageGalleryViewModel.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 09/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import Foundation

protocol ImageGalleryViewModelDelegate: AnyObject {
    func viewModel(_ viewModel: ImageGalleryViewModel,
                   didChangeTo state: ImageGalleryViewModel.State)
}

final class ImageGalleryViewModel {
    enum State: Equatable {
        case loadingImages
        case loadedImages
        case failed
    }
    
    weak var delegate: ImageGalleryViewModelDelegate?
    
    private(set) var state: State = .loadingImages
    private(set) var currentIndex = 0
    
    private let imagesService: ImagesService
    private let assetService: AssetService
    
    private var images = [ImageDomainModel]()
    private var imageViewerViewModels = [Int: ImageViewerViewModel]()
    
    // MARK: - Init
    
    init(imagesService: ImagesService = DefaultImagesService(),
         assetService: AssetService = DefaultAssetService()) {
        self.imagesService = imagesService
        self.assetService = assetService
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
                self.imageViewerViewModels.removeAll()
                self.currentIndex = 0
                
                self.transition(to: .loadedImages)
                
                self.viewModel(at: self.currentIndex)?.load()
            case .failure(_):
                self.transition(to: .failed)
            }
        }
    }
    
    // MARK: - Pages
    
    var numberOfImages: Int {
        return images.count
    }
    
    func viewModel(at index: Int) -> ImageViewerViewModel? {
        guard index >= 0 && index < images.count else {
            return nil
        }
        
        if let existingViewModel = imageViewerViewModels[index] {
            return existingViewModel
        }
        
        let viewModel = ImageViewerViewModel(imageDomainModel: images[index],
                                             assetService: assetService)
        imageViewerViewModels[index] = viewModel
        
        return viewModel
    }
    
    // MARK: - Move
    
    func moveTo(index: Int) {
        guard index != currentIndex,
              index >= 0,
              index < images.count else {
            return
        }
        
        imageViewerViewModels[currentIndex]?.pause()
        
        currentIndex = index
        
        viewModel(at: index)?.load()
    }
    
    // MARK: - State
    
    private func transition(to state: State) {
        self.state = state
        
        delegate?.viewModel(self, didChangeTo: state)
    }
}
