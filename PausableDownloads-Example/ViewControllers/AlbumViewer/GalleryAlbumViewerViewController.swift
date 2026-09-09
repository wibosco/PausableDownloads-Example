//
//  GalleryAlbumViewerViewController.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 15/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import UIKit

class GalleryAlbumViewerViewController: UIViewController {

    @IBOutlet weak var assetImageView: UIImageView!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var loadingActivityIndicator: UIActivityIndicatorView!
    
    private let assetDataManager = AssetDataManager()
    
    var catImages = [CatImage]()
    
    var index = 0
    
    // MARK: - ViewLifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        guard index < catImages.count else {
            return
        }
        
        retrieveImage()
        updateTitle()
        navigationItem.hidesBackButton = true
    }
    
    // MARK: - Title
    
    func updateTitle() {
        guard let titleView = navigationItem.titleView as? GalleryAlbumViewerTitleView else {
            return
        }
        
        titleView.titleLabel.text = "\(index+1) of \(catImages.count)"
        
        if index+1 == catImages.count {
            titleView.subtitleLabel.text = "Tap to close"
        }
    }
    
    // MARK: - GestureRecognizer
    
    @IBAction func didTap(_ sender: Any) {
        cancelImageRetrieval()
        index += 1
        
        if index < catImages.count {
            retrieveImage()
            updateTitle()
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
    
    // MARK: - Reuse
    
    func prepareForReuse() {
        loadingActivityIndicator.startAnimating()
        assetImageView.image = nil
    }
    
    // MARK: - Asset
    
    func retrieveImage() {
        let catImage = catImages[index]
        prepareForReuse()
        descriptionLabel.text = "\(catImage.url.absoluteString)"
        assetDataManager.loadImage(catImage) { [weak self] (result) in
            guard let strongSelf = self else {
                return
            }
            
            guard strongSelf.index < strongSelf.catImages.count else {
                return
            }
            
            switch result {
            case .success(let loadResult):
                let currentCatImage = strongSelf.catImages[strongSelf.index]
                if loadResult.catImage == currentCatImage {
                    strongSelf.loadingActivityIndicator.stopAnimating()
                    strongSelf.assetImageView.image = loadResult.image
                }
            case .failure(_):
                //TODO: Handle
                break
            }
        }
    }
    
    func cancelImageRetrieval() {
        guard index < catImages.count else {
            return
        }
        
        let catImage = catImages[index]
        assetDataManager.cancelLoadingImage(catImage)
    }
}
