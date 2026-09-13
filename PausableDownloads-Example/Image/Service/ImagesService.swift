//
//  ImagesService.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 09/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import Foundation

typealias LoadImagesCompletionHandler = (Result<[ImageDomainModel], Error>) -> ()

protocol ImagesService {
    func load(callbackQueue: DispatchQueue,
              completionHandler: @escaping LoadImagesCompletionHandler)
}

final class DefaultImagesService: ImagesService {
    private let repository: DefaultImagesRepository
    private let domainModelFactory: ImagesDomainModelFactory
    
    // MARK: - Init
    
    init(repository: DefaultImagesRepository = DefaultImagesRepository(),
         domainModelFactory: ImagesDomainModelFactory = ImagesDomainModelFactory()) {
        self.repository = repository
        self.domainModelFactory = domainModelFactory
    }
    
    // MARK: - Load
    
    func load(callbackQueue: DispatchQueue,
              completionHandler: @escaping LoadImagesCompletionHandler) {
        repository.load { [domainModelFactory] result in
            //a failure passes straight through; a success is mapped from DTOs to domain models
            let images = result
                .map { dtos in dtos.map { domainModelFactory.buildImage(from: $0) } }
                .mapError { $0 as Error }
            
            callbackQueue.async {
                completionHandler(images)
            }
        }
    }
}
