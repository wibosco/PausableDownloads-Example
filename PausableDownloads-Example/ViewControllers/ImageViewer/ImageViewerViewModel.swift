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
        case ready
        case loading
        case loaded(UIImage)
        case failed
    }
    
    weak var delegate: ImageViewerViewModelDelegate?
    
    private(set) var state: State = .ready
    
    let imageDomainModel: ImageDomainModel
    let description: String
    
    private let imageLoader: ImageLoader
    
    //a live token means a load is in flight - cleared when the load finishes or is cancelled
    private var loadToken: LoadToken?
    
    // MARK: - Init
    
    init(imageDomainModel: ImageDomainModel,
         imageLoader: ImageLoader = DefaultImageLoader()) {
        self.imageDomainModel = imageDomainModel
        self.imageLoader = imageLoader
        self.description = imageDomainModel.url.absoluteString
    }
    
    // MARK: - Load
    
    func loadImage() {
        guard canLoad else {
            return
        }
        
        transition(to: .loading)
        
        loadToken = imageLoader.load(imageDomainModel,
                                     callbackQueue: .main) { [weak self] result in
            guard let self = self else {
                return
            }
            
            self.loadToken = nil
            
            switch result {
            case let .success(image):
                self.transition(to: .loaded(image))
            case .failure:
                self.transition(to: .failed)
            }
        }
    }
    
    // MARK: - Cancel
    
    func cancelImageLoad() {
        guard let loadToken else {
            return
        }
        
        imageLoader.cancel(loadToken)
        self.loadToken = nil
        
        transition(to: .ready)
    }
    
    // MARK: - State
    
    private var canLoad: Bool {
        switch state {
        case .ready, .failed:
            return true
        case .loading, .loaded:
            return false
        }
    }
    
    private func transition(to state: State) {
        self.state = state
        
        delegate?.viewModel(self,
                            didChangeTo: state)
    }
}
