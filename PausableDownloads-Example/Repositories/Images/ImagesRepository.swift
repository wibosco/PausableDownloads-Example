//
//  ImagesRepository.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 15/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation

protocol ImagesRepository {
    func load(completionHandler: @escaping NetworkCompletionHandler<[ImageDTO]>)
}

final class DefaultImagesRepository {
    private let networkService: NetworkService
    
    // MARK: - Init
    
    init(networkService: NetworkService = DefaultNetworkService()) {
        self.networkService = networkService
    }
    
    // MARK: - List
    
    func load(completionHandler: @escaping NetworkCompletionHandler<[ImageDTO]>) {
        networkService.makeJSONRequest(urlRequest(),
                                       completionHandler: completionHandler)
    }
    
    private func urlRequest() -> URLRequest {
        let url = networkService.baseURL.appendingPathComponent("images/search")
        
        var components = URLComponents(url: url,
                                       resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "limit", value: "10"),
                                 URLQueryItem(name: "order", value: "RANDOM"),
                                 URLQueryItem(name: "size", value: "full")]
        
        return URLRequest(url: components.url!)
    }
}
