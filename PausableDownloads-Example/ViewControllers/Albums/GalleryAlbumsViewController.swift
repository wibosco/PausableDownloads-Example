//
//  GalleryAlbumsViewController.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 15/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import UIKit

class GalleryAlbumsViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var loadingActivityIndicatorView: UIActivityIndicatorView!
    
    let dataManager = CatImagesDataManager()
    var catImages = [CatImage]()
    let fileManager = FileManager.default
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        retrieveImages()
    }
    
    // MARK: - Images
    
    func retrieveImages() {
        loadingActivityIndicatorView.startAnimating()
        
        dataManager.retrieveImages { (result) in
            self.loadingActivityIndicatorView.stopAnimating()
            
            switch result {
            case .success(let catImages):
                self.catImages = catImages
                self.collectionView.reloadData()
            case .failure(_):
                //TODO: Handle error
                break
            }
        }
    }
    
    // MARK: - SegueWay
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showAlbum" {
            guard let viewController = segue.destination as? GalleryAlbumViewerViewController,
                let cell = sender as? GalleryAlbumCollectionViewCell,
                let indexPath = collectionView.indexPath(for: cell) else {
                    return
            }
            
            viewController.catImages = catImages
            viewController.index = indexPath.item
        }
    }
    
    // MARK: - Reset
    
    @IBAction func resetButtonPressed(_ sender: Any) {
        loadingActivityIndicatorView.startAnimating()
        
        for catImage in catImages {
            try? fileManager.removeItem(at: catImage.cachedLocalAssetURL())
        }
        
        catImages.removeAll()
        collectionView.reloadData()
        retrieveImages()
    }
}

extension GalleryAlbumsViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return catImages.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: GalleryAlbumCollectionViewCell.className, for: indexPath) as? GalleryAlbumCollectionViewCell else {
            fatalError("Expected cell of type: \(GalleryAlbumCollectionViewCell.className)")
        }
        
        let catImage = catImages[indexPath.item]
        
        cell.configure(catImage: catImage)
        
        return cell
    }
}

extension GalleryAlbumsViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cellWidth = (view.frame.size.width - 12.0)/3.0
        return CGSize(width: cellWidth, height: cellWidth)
    }
}
