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
        case ready(description: String)
        case loadingAsset(description: String)
        case loadedAsset(UIImage, description: String)
        case failed
    }
    
    weak var delegate: ImageViewerViewModelDelegate?
    
    private(set) var state: State
    
    let imageDomainModel: ImageDomainModel
    
    private let assetService: AssetService
    
    //the download this view model started, so a pause targets its own and nobody else's
    private var downloadToken: DownloadToken?
    
    // MARK: - Init
    
    init(imageDomainModel: ImageDomainModel,
         assetService: AssetService = DefaultAssetService()) {
        self.imageDomainModel = imageDomainModel
        self.assetService = assetService
        self.state = .ready(description: imageDomainModel.url.absoluteString)
    }
    
    // MARK: - Load
    
    func load() {
        /* Returning to an image that has already downloaded shouldn't tear the
         asset back off screen, and one that is already in flight is being taken
         care of by the download session.
         */
        guard !isLoaded && !isLoading else {
            return
        }
        
        transition(to: .loadingAsset(description: imageDomainModel.url.absoluteString))
        
        downloadToken = assetService.loadImage(imageDomainModel, callbackQueue: .main) { [weak self] (result) in
            guard let self = self else {
                return
            }
            
            switch result {
            case .success(let loadResult):
                //a stale download for an image this view model no longer represents
                guard loadResult.imageDomainModel == self.imageDomainModel else {
                    return
                }
                
                self.transition(to: .loadedAsset(loadResult.image, description: self.imageDomainModel.url.absoluteString))
            case .failure(_):
                self.transition(to: .failed)
            }
        }
    }
    
    // MARK: - Pause
    
    func pause() {
        guard isLoading,
              let downloadToken = downloadToken else {
            return
        }
        
        assetService.cancelLoadingImage(downloadToken)
        
        self.downloadToken = nil
        
        transition(to: .ready(description: imageDomainModel.url.absoluteString))
    }
    
    // MARK: - State
    
    private var isLoaded: Bool {
        guard case .loadedAsset = state else {
            return false
        }
        
        return true
    }
    
    private var isLoading: Bool {
        guard case .loadingAsset = state else {
            return false
        }
        
        return true
    }
    
    private func transition(to state: State) {
        self.state = state
        
        delegate?.viewModel(self, didChangeTo: state)
    }

}
