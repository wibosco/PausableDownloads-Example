//
//  MediaViewerViewController.swift
//  SmartMediaDownloader-Example
//
//  Created by William Boles on 07/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import UIKit

class AlbumViewerViewController: UIViewController {

    @IBOutlet weak var assetImageView: UIImageView!
    @IBOutlet weak var descriptionLabel: UILabel!
    @IBOutlet weak var loadingActivityIndicator: UIActivityIndicatorView!
    
    @IBOutlet weak var tapGstureRecognizer: UITapGestureRecognizer!
    
    private let assetDataManager = AssetDataManager()
    
    var galleryItems = [GalleryItem]()
    
    var index = 0
    
    // MARK: - ViewLifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        retrieveAsset()
        updateTitle()
    }
    
    // MARK: - Title
    
    func updateTitle() {
        guard let titleView = navigationItem.titleView as? AlbumViewerTitleView else {
            return
        }
        
        titleView.titleLabel.text = "\(index+1) of \(galleryItems.count)"
        
        if index+1 == galleryItems.count {
            titleView.subtitleLabel.text = "Tap to close album"
        }
    }
    
    // MARK: - GestureRecognizer
    
    @IBAction func didTap(_ sender: Any) {
        cancelAssertRetrieval()
        index += 1
        
        if index < galleryItems.count {
            retrieveAsset()
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
    
    func retrieveAsset() {
        let galleryItem = galleryItems[index]
        prepareForReuse()
        descriptionLabel.text = "\(galleryItem.asset.url.absoluteString)"
        assetDataManager.loadGalleryItemAsset(galleryItem.asset) { [weak self] (result) in
            guard let strongSelf = self else {
                return
            }
            
            guard strongSelf.index <= strongSelf.galleryItems.count else {
                return
            }
            
            switch result {
            case .success(let loadResult):
                let currentGalleryItem = strongSelf.galleryItems[strongSelf.index]
                if loadResult.asset == currentGalleryItem.asset {
                    strongSelf.loadingActivityIndicator.stopAnimating()
                    strongSelf.assetImageView.image = loadResult.image
                }
            case .failure(let error):
                //TODO: Handle
                print(error)
            }
        }
    }
    
    func cancelAssertRetrieval() {
        let galleryItem = galleryItems[index]
        assetDataManager.cancelLoadingGalleryItemAsset(galleryItem.asset)
    }
}
