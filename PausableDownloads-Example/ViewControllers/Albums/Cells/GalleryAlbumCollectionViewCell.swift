//
//  GalleryAlbumCollectionViewCell.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 17/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import UIKit

class GalleryAlbumCollectionViewCell: UICollectionViewCell {

    @IBOutlet weak var informationalLabel: UILabel!
    @IBOutlet weak var thumbnailImageView: UIImageView!
    
    private var assetDataManager = AssetDataManager()
    private var thumbnailAsset: GalleryAsset?
    
    // MARK: - Reuse
    
    override func prepareForReuse() {
        super.prepareForReuse()
        
        thumbnailImageView.image = UIImage(named: "icon-placeholder")
    }
    
    // MARK: - Configure
    
    func configure(galleryAlbum: GalleryAlbum) {
        informationalLabel.text = "\(galleryAlbum.thumbnailAsset.url.absoluteString)"
        thumbnailAsset = galleryAlbum.thumbnailAsset
        
        assetDataManager.loadAlbumThumbnailAsset(galleryAlbum.thumbnailAsset) { [weak self] (result) in
            switch result {
            case .success(let loadResult):
                if loadResult.asset == self?.thumbnailAsset {
                    self?.thumbnailImageView.image = loadResult.image
                }
            case .failure(_):
                //TODO: Handle
                break
            }
        }
    }
}
