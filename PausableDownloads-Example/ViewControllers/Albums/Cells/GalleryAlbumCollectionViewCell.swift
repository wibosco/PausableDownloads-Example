//
//  GalleryAlbumCollectionViewCell.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 15/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import UIKit

class GalleryAlbumCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var informationalLabel: UILabel!
    @IBOutlet weak var thumbnailImageView: UIImageView!
    
    private var assetDataManager = AssetDataManager()
    private var catImage: CatImage?
    
    // MARK: - Reuse
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        thumbnailImageView.image = UIImage(named: "icon-placeholder")
    }
    
    // MARK: - Configure
    
    func configure(catImage: CatImage) {
        informationalLabel.text = "\(catImage.url.absoluteString)"
        self.catImage = catImage
        
        assetDataManager.loadImage(catImage) { [weak self] (result) in
            switch result {
            case .success(let loadResult):
                if loadResult.catImage == self?.catImage {
                    self?.thumbnailImageView.image = loadResult.image
                }
            case .failure(_):
                //TODO: Handle
                break
            }
        }
    }
}
