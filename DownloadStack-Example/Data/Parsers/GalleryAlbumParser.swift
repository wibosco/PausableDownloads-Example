//
//  GalleryAlbumParser.swift
//  DownloadStack-Example
//
//  Created by William Boles on 12/11/2017.
//  Copyright © 2017 William Boles. All rights reserved.
//

import Foundation

class GalleryAlbumParser: Parser<[GalleryAlbum]> {
    
    // MARK: - Parse
    
    override func parseResponse(_ response: [String: Any]) -> [GalleryAlbum] {
        var galleryAlbums = [GalleryAlbum]()
        
        guard let itemsResponse = response["data"] as? [[String: Any]] else {
            return galleryAlbums
        }

        for itemResponse in itemsResponse {
            if let galleryItems = parseItem(itemResponse) {
                if galleryItems.count > 0 {
                    let galleryItem = galleryItems[0]
                    let galleryAlbumThumbnailURL = generateThumbnailURL(from: galleryItem)
                    let thumbnailAsset = GalleryAsset(id: fileName(forURL: galleryAlbumThumbnailURL), url: galleryAlbumThumbnailURL)
                    
                    let galleryAlbum = GalleryAlbum(thumbnailAsset: thumbnailAsset, items: galleryItems)
                    
                    galleryAlbums.append(galleryAlbum)
                }
            }
        }
        
        return galleryAlbums
    }
    
    private func parseItem(_ itemResponse: [String: Any]) -> [GalleryItem]? {
        guard let isAlbum = itemResponse["is_album"] as? Bool else {
            return nil
        }
        
        if isAlbum {
            return parseItemAlbum(itemResponse)
        } else {
            return parseItemImage(itemResponse)
        }
    }
    
    func parseItemImage(_ itemResponse: [String: Any]) -> [GalleryItem]? {
        guard let itemTitle = itemResponse["title"] as? String,
            let imageURLString = itemResponse["link"] as? String,
            let imageURL = URL(string: imageURLString)
            else {
                return nil
        }
        
        let asset = GalleryAsset(id: fileName(forURL: imageURL), url: imageURL)
                
        return [GalleryItem(title: itemTitle, asset: asset)]
    }
    
    func parseItemAlbum(_ itemResponse: [String: Any]) -> [GalleryItem]? {
        guard let itemTitle = itemResponse["title"] as? String,
            let imageResponses = itemResponse["images"] as? [[String: Any]]
            else {
            return nil
        }
        
        var galleryItems = [GalleryItem]()
        
        for imageResponse in imageResponses {
            if let linkURLString = imageResponse["link"] as? String {
                if let linkURL = URL(string: linkURLString) {
                    var title = itemTitle

                    if let imageTitle = imageResponse["description"] as? String {
                        title = imageTitle
                    }
                    
                    let asset = GalleryAsset(id: fileName(forURL: linkURL), url: linkURL)

                    let galleryItem = GalleryItem(title: title, asset: asset)
                    galleryItems.append(galleryItem)
                }
            }
        }
        
        return galleryItems
    }
    
    func generateThumbnailURL(from galleryItem: GalleryItem) -> URL {
        let pathExtension = galleryItem.asset.url.pathExtension
        let linkWithoutPathExtension = galleryItem.asset.url.deletingPathExtension()
        
        let thumbnailURLString = "\(linkWithoutPathExtension)t.\(pathExtension)"
        
        return URL(string: thumbnailURLString)!
    }
    
    func fileName(forURL url: URL) -> String {
        return url.deletingPathExtension().lastPathComponent
    }
}
