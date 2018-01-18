//
//  MediaViewerViewController.swift
//  SmartMediaDownloader-Example
//
//  Created by William Boles on 07/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import UIKit

class AlbumViewerViewController: UIViewController {

    @IBOutlet weak var tableView: UITableView!
    
    let assetDataManager = AssetDataManager()
    
    var galleryItems = [GalleryItem]()
    
    var index = 0
    
    // MARK: - ViewLifecycle
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        tableView.rowHeight = view.frame.height
        tableView.isScrollEnabled = false
    }
}

extension AlbumViewerViewController: UITableViewDataSource {
    
    // MARK: - UITableViewDataSource
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return galleryItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: GalleryItemTableViewCell.className, for: indexPath) as? GalleryItemTableViewCell else {
            fatalError("unknown cell type being used") // fail fast
        }
        
        let galleryItem = galleryItems[indexPath.row]
        
        cell.configure(galleryItem: galleryItem)
        
        return cell
    }
}

extension AlbumViewerViewController: UITableViewDelegate {
    
    // MARK: - UITableViewDelegate
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        index = (indexPath.row + 1)
        
        if index < galleryItems.count {
            let nextIndexPath = IndexPath(row: index, section: 0)
            
            tableView.scrollToRow(at: nextIndexPath, at: .bottom, animated: false)
        } else {
            navigationController?.popViewController(animated: true)
        }
    }
}
