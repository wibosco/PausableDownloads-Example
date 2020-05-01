//
//  GalleryDataManager.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 07/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation

class GalleryDataManager {
    
    let urlRequestFactory: GalleryURLRequestFactory
    let session: URLSession
    
    // MARK: - Init
    
    init(session: URLSession = URLSession.shared, urlRequestFactory: GalleryURLRequestFactory = GalleryURLRequestFactory()) {
        self.session = session
        self.urlRequestFactory = urlRequestFactory
    }
    
    // MARK: - List
    
    func retrieveGallery(forSearchTerms searchTerms: String, completionHandler: @escaping ((_ searchTerms: String, _ result: Result<[GalleryAlbum], Error>) -> ())) {
        let request = urlRequestFactory.requestToRetrieveGallerySearchResults(for: searchTerms)
        
        let task = session.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            guard let data = data else {
                DispatchQueue.main.async {
                    let retrievalError = NetworkingError.retrieval(underlayingError: error)
                    completionHandler(searchTerms, Result.failure(retrievalError))
                }
                return
            }

            do {
                let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as! [String: Any]

                let parser = GalleryAlbumParser()
                let galleryAlbums = parser.parseResponse(json)
                
                DispatchQueue.main.async {
                    completionHandler(searchTerms, Result.success(galleryAlbums))
                }
            } catch let error {
                DispatchQueue.main.async {
                    let invalidError = NetworkingError.invalidData(underlayingError: error)
                    completionHandler(searchTerms, Result.failure(invalidError))
                }
            }
        }
        
        task.resume()
    }
}
