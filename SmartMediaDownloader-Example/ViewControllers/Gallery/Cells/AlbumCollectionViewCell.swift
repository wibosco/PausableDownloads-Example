//
//  AlbumCollectionViewCell.swift
//  SmartMediaDownloader-Example
//
//  Created by William Boles on 17/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import UIKit

class AlbumCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var informationalLabel: UILabel!
    @IBOutlet weak var thumbnailImageView: UIImageView!
    
    private var assetDataManager = AssetDataManager()
    
    // MARK: - Reuse
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        thumbnailImageView.image = UIImage(named: "icon-placeholder")
    }
    
    // MARK: - Configure
    
    func configure(galleryAlbum: GalleryAlbum) {
        
        informationalLabel.text = "\(galleryAlbum.thumbnailAsset.url.absoluteString)"
        
        assetDataManager.loadAlbumThumbnailAsset(galleryAlbum.thumbnailAsset) { [weak self] (result) in
            switch result {
            case .success(let (asset, image)):
                if asset == galleryAlbum.thumbnailAsset {
                    self?.thumbnailImageView.image = image
                }
            case .failure(let error):
                //TODO: Handle
                print(error)
            }
            
        }
    }
}
