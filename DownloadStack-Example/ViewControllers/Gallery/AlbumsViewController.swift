//
//  GalleryViewController.swift
//  DownloadStack-Example
//
//  Created by William Boles on 17/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import UIKit

class AlbumsViewController: UIViewController {
    
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var loadingActivityIndicatorView: UIActivityIndicatorView!
    
    let dataManager = GalleryDataManager()
    var galleryAlbums = [GalleryAlbum]()
    let fileManager = FileManager.default
    
    // MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        retrieveAlbums()
    }
    
    // MARK: - Albums
    
    func retrieveAlbums() {
        loadingActivityIndicatorView.startAnimating()
        
        dataManager.retrieveGallery(forSearchTerms: "cats") { (searchTerms, result) in
            self.loadingActivityIndicatorView.stopAnimating()
            
            switch result {
            case .success(let galleryAlbums):
                self.galleryAlbums = galleryAlbums
                self.collectionView.reloadData()
            case .failure(let error):
                //TODO: Handle
                print("\(error)")
            }
        }
    }
    
    // MARK: - SegueWay
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showAlbum" {
            guard let viewController = segue.destination as? AlbumViewerViewController,
                let cell = sender as? AlbumCollectionViewCell,
                let indexPath = collectionView.indexPath(for: cell) else {
                    return
            }
            
            viewController.galleryItems = galleryAlbums[indexPath.item].items
        }
    }
    
    // MARK: - Reset
    
    @IBAction func resetButtonPressed(_ sender: Any) {
        loadingActivityIndicatorView.startAnimating()
        
        for galleryAlbum in galleryAlbums {
            try? fileManager.removeItem(at: galleryAlbum.thumbnailAsset.cachedLocalAssetURL())
            for galleryItem in galleryAlbum.items {
                try? fileManager.removeItem(at: galleryItem.asset.cachedLocalAssetURL())
            }
        }
        
        galleryAlbums.removeAll()
        collectionView.reloadData()
        retrieveAlbums()
    }
}

extension AlbumsViewController: UICollectionViewDataSource {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return galleryAlbums.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: AlbumCollectionViewCell.className, for: indexPath) as? AlbumCollectionViewCell else {
            fatalError("Expected cell of type: \(AlbumCollectionViewCell.className)")
        }
        
        let galleryAlbum = galleryAlbums[indexPath.row]
        
        cell.configure(galleryAlbum: galleryAlbum)
        
        return cell
    }
}

extension AlbumsViewController: UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let cellWidth = (view.frame.size.width - 12.0)/3.0
        return CGSize(width: cellWidth, height: cellWidth)
    }
}
