//
//  ImagesService.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 09/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import Foundation

protocol ImagesService {
    func retrieveImages(callbackQueue: DispatchQueue,
                        completionHandler: @escaping ((_ result: Result<[ImageDomainModel], Error>) -> ()))
}

final class DefaultImagesService: ImagesService {
    private let repository: ImagesRepository
    private let domainModelFactory: ImagesDomainModelFactory
    
    // MARK: - Init
    
    init(repository: ImagesRepository = ImagesRepository(),
         domainModelFactory: ImagesDomainModelFactory = ImagesDomainModelFactory()) {
        self.repository = repository
        self.domainModelFactory = domainModelFactory
    }
    
    // MARK: - Retrieval
    
    func retrieveImages(callbackQueue: DispatchQueue,
                        completionHandler: @escaping ((_ result: Result<[ImageDomainModel], Error>) -> ())) {
        repository.retrieveImages { [domainModelFactory] (result) in
            switch result {
            case .success(let dtos):
                let images = dtos.map { domainModelFactory.buildImage(from: $0) }
                
                callbackQueue.async {
                    completionHandler(.success(images))
                }
            case .failure(let error):
                callbackQueue.async {
                    completionHandler(.failure(error))
                }
            }
        }
    }
}
