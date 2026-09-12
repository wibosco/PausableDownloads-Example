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
    
    private(set) var index = 0
    private var viewModel: ImageViewerViewModel!
    
    // MARK: - Instantiation
    
    static func instantiate(viewModel: ImageViewerViewModel,
                            index: Int) -> ImageViewerViewController {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        let identifier = String(describing: ImageViewerViewController.self)
        
        guard let viewController = storyboard.instantiateViewController(withIdentifier: identifier) as? ImageViewerViewController else {
            fatalError("Expected \(identifier) to be in Main.storyboard")
        }
        
        viewController.viewModel = viewModel
        viewController.index = index
        
        return viewController
    }
    
    // MARK: - ViewLifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewModel.delegate = self
        
        //This page may well be being rebuilt around a view model that is already
        //loading or loaded, so render what is there rather than waiting for a change.
        render(viewModel.state)
    }
    
    // MARK: - Render
    
    private func render(_ state: ImageViewerViewModel.State) {
        switch state {
        case .ready:
            loadingActivityIndicator.stopAnimating()
            assetImageView.image = nil
            descriptionLabel.text = viewModel.description
        case .loading:
            loadingActivityIndicator.startAnimating()
            assetImageView.image = nil
            descriptionLabel.text = viewModel.description
        case let .loaded(image):
            loadingActivityIndicator.stopAnimating()
            assetImageView.image = image
            descriptionLabel.text = viewModel.description
        case .failed:
            loadingActivityIndicator.stopAnimating()
            //TODO: Handle error
            break
        }
    }
}

extension ImageViewerViewController: ImageViewerViewModelDelegate {
    
    // MARK: - ImageViewerViewModelDelegate
    
    func viewModel(_ viewModel: ImageViewerViewModel,
                   didChangeTo state: ImageViewerViewModel.State) {
        render(state)
    }
}
