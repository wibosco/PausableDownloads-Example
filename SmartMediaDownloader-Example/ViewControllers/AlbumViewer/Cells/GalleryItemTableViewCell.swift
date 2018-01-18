//
//  GalleryItemTableViewCell.swift
//  SmartMediaDownloader-Example
//
//  Created by William Boles on 07/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import UIKit

class GalleryItemTableViewCell: UITableViewCell {

    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var itemImageView: UIImageView!

    private var assetDataManager = AssetDataManager()
    
    // MARK: - Reuse
    
    override func prepareForReuse() {
        super.prepareForReuse()
        itemImageView.image = UIImage(named: "icon-placeholder")
    }

    // MARK: - Configure

    func configure(galleryItem: GalleryItem) {
        
        titleLabel.text = "\(galleryItem.title)"
        
        assetDataManager.loadAsset(galleryItem.asset) { [weak self] (result) in
            switch result {
            case .success(let (asset, image)):
                if asset == galleryItem.asset {
                    self?.itemImageView.image = image
                }
            case .failure(let error):
                //TODO: Handle
                print(error)
            }
            
        }
    }
}
