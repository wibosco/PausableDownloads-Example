//
//  AlbumCollectionViewCell.swift
//  SmartMediaDownloader-Example
//
//  Created by William Boles on 17/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import UIKit

class AlbumCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var albumItemsCountLabel: UILabel!
    @IBOutlet weak var thumbnailImageView: UIImageView!
    
    private var assetDataManager = AssetDataManager()
    
    // MARK: - Reuse
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        thumbnailImageView.image = UIImage(named: "icon-placeholder")
    }
    
    // MARK: - Configure
    
    func configure(galleryAlbum: GalleryAlbum) {
        
        albumItemsCountLabel.text = "Photos in album: \(galleryAlbum.items.count)"
        
        assetDataManager.loadAsset(galleryAlbum.thumbnailAsset) { [weak self] (result) in
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
