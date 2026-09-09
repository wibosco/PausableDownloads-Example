//
//  ImagesRepository.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 15/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation

class ImagesRepository {
    private let urlRequestFactory: CatImagesURLRequestFactory
    private let session: URLSession
    
    // MARK: - Init
    
    init(session: URLSession = URLSession.shared,
         urlRequestFactory: CatImagesURLRequestFactory = CatImagesURLRequestFactory()) {
        self.session = session
        self.urlRequestFactory = urlRequestFactory
    }
    
    // MARK: - List
    
    func retrieveImages(completionHandler: @escaping ((_ result: Result<[ImageDTO], Error>) -> ())) {
        let request = urlRequestFactory.requestToRetrieveImages()
        
        let task = session.dataTask(with: request) { (data: Data?, response: URLResponse?, error: Error?) in
            guard let data = data else {
                DispatchQueue.main.async {
                    let retrievalError = NetworkingError.retrieval(underlyingError: error)
                    completionHandler(Result.failure(retrievalError))
                }
                return
            }
            
            guard let statusCode = (response as? HTTPURLResponse)?.statusCode,
                (200..<300).contains(statusCode) else {
                    DispatchQueue.main.async {
                        let retrievalError = NetworkingError.retrieval(underlyingError: error)
                        completionHandler(Result.failure(retrievalError))
                    }
                    return
            }
            
            do {
                let dtos = try JSONDecoder().decode([ImageDTO].self, from: data)
                
                DispatchQueue.main.async {
                    completionHandler(Result.success(dtos))
                }
            } catch let error {
                DispatchQueue.main.async {
                    let invalidError = NetworkingError.invalidData(underlyingError: error)
                    completionHandler(Result.failure(invalidError))
                }
            }
        }
        
        task.resume()
    }
}
