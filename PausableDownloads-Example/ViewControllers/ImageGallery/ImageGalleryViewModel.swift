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
        case loading
        case loaded
        case failed
    }
    
    weak var delegate: ImageGalleryViewModelDelegate?
    
    private(set) var state: State = .loading
    private(set) var currentIndex = 0
    
    private let imagesService: ImagesService
    private let imageLoader: ImageLoader
    
    private var images = [ImageDomainModel]()
    
    //keyed by position in `images` - safe because `images` is only ever replaced wholesale
    //and this is cleared at the same moment, so the indices can't drift apart
    private var imageViewerViewModels = [Int: ImageViewerViewModel]()
    
    // MARK: - Init
    
    init(imagesService: ImagesService = DefaultImagesService(),
         imageLoader: ImageLoader = DefaultImageLoader()) {
        self.imagesService = imagesService
        self.imageLoader = imageLoader
    }
    
    // MARK: - Load
    
    func load() {
        transition(to: .loading)
        
        imagesService.load(callbackQueue: .main) { [weak self] result in
            guard let self else {
                return
            }
            
            switch result {
            case let .success(images):
                self.images = images
                self.imageViewerViewModels.removeAll()
                self.currentIndex = 0
                
                self.transition(to: .loaded)
                
                self.viewModel(at: self.currentIndex)?.loadImage()
            case .failure:
                self.transition(to: .failed)
            }
        }
    }
    
    // MARK: - Pages
    
    var numberOfImages: Int {
        images.count
    }
    
    func viewModel(at index: Int) -> ImageViewerViewModel? {
        guard images.indices.contains(index) else {
            return nil
        }
        
        if let existingViewModel = imageViewerViewModels[index] {
            return existingViewModel
        }
        
        let viewModel = ImageViewerViewModel(imageDomainModel: images[index],
                                             imageLoader: imageLoader)
        imageViewerViewModels[index] = viewModel
        
        return viewModel
    }
    
    // MARK: - Move
    
    func move(to index: Int) {
        guard index != currentIndex,
              images.indices.contains(index) else {
            return
        }
        
        //deliberately not `viewModel(at:)` - a page that never had a view model never
        //started a load, so there is nothing to cancel and no reason to create one
        imageViewerViewModels[currentIndex]?.cancelImageLoad()
        
        currentIndex = index
        
        viewModel(at: index)?.loadImage()
    }
    
    // MARK: - State
    
    private func transition(to state: State) {
        self.state = state
        
        delegate?.viewModel(self,
                            didChangeTo: state)
    }
}
