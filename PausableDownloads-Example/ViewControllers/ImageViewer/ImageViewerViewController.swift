//
//  ImageViewerViewController.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 15/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import UIKit

class ImageViewerViewController: UIViewController {
    @IBOutlet weak var assetImageView: UIImageView!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var loadingActivityIndicator: UIActivityIndicatorView!
    
    private let viewModel = ImageViewerViewModel()
    
    // MARK: - ViewLifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewModel.delegate = self
        viewModel.load()
    }
    
    // MARK: - GestureRecognizer
    
    @IBAction func didTap(_ sender: Any) {
        viewModel.advance()
    }
}

extension ImageViewerViewController: ImageViewerViewModelDelegate {
    
    // MARK: - ImageViewerViewModelDelegate
    
    func viewModel(_ viewModel: ImageViewerViewModel,
                   didChangeTo state: ImageViewerViewModel.State) {
        switch state {
        case .loadingImages:
            loadingActivityIndicator.startAnimating()
            assetImageView.image = nil
        case .loadingAsset(let description):
            loadingActivityIndicator.startAnimating()
            assetImageView.image = nil
            descriptionLabel.text = description
        case .loadedAsset(let image, let description):
            loadingActivityIndicator.stopAnimating()
            assetImageView.image = image
            descriptionLabel.text = description
        case .failed:
            loadingActivityIndicator.stopAnimating()
            //TODO: Handle error
            break
        }
    }
}
