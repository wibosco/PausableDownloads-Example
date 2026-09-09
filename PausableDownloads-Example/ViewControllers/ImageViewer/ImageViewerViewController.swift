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
    
    private let assetService = AssetService()
    private let imagesService = ImagesService()
    
    private var images = [ImageDomainModel]()
    private var index = 0
    
    // MARK: - ViewLifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
    
        retrieveImages()
    }
    
    // MARK: - GestureRecognizer
    
    @IBAction func didTap(_ sender: Any) {
        cancelImageRetrieval()
        index += 1
        retrieveImage()
    }
    
    // MARK: - Reuse
    
    func prepareForReuse() {
        loadingActivityIndicator.startAnimating()
        assetImageView.image = nil
    }
    
    // MARK: - Images
    
    func retrieveImages() {
        loadingActivityIndicator.startAnimating()
        
        imagesService.retrieveImages { (result) in
            self.loadingActivityIndicator.stopAnimating()
            
            switch result {
            case .success(let images):
                self.images = images
                self.retrieveImage()
            case .failure(_):
                //TODO: Handle error
                break
            }
        }
    }
    
    func retrieveImage() {
        guard index < images.count else { return }
        
        let image = images[index]
        
        prepareForReuse()
        descriptionLabel.text = "\(image.url.absoluteString)"
        
        assetService.loadImage(image) { [weak self] (result) in
            guard let self = self else {
                return
            }
            
            guard self.index < self.images.count else {
                return
            }
            
            switch result {
            case .success(let loadResult):
                let currentImage = self.images[self.index]
                if loadResult.imageDomainModel == currentImage {
                    self.loadingActivityIndicator.stopAnimating()
                    self.assetImageView.image = loadResult.image
                }
            case .failure(_):
                //TODO: Handle
                break
            }
        }
    }
    
    func cancelImageRetrieval() {
        guard index < images.count else {
            return
        }
        
        let image = images[index]
        assetService.cancelLoadingImage(image)
    }
}
