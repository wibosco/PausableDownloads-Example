//
//  NetworkService.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 12/09/2026.
//  Copyright © 2026 William Boles. All rights reserved.
//

import Foundation
import os

protocol URLSessionType {
    func data(for request: URLRequest,
              completionHandler: @escaping (Data?, URLResponse?, Error?) -> ())
}

extension URLSession: URLSessionType {
    func data(for request: URLRequest,
              completionHandler: @escaping (Data?, URLResponse?, Error?) -> ()) {
        dataTask(with: request,
                 completionHandler: completionHandler).resume()
    }
}

enum NetworkError: Error {
    case transportFailure(Error?)
    case invalidResponse
    case unacceptableStatusCode(Int)
    case decodingFailed(Error)
}

typealias NetworkCompletionHandler<T> = (Result<T, NetworkError>) -> ()

protocol NetworkService {
    var baseURL: URL { get }
    
    func makeJSONRequest<T: Decodable>(_ request: URLRequest,
                                       decoder: JSONDecoder,
                                       completionHandler: @escaping NetworkCompletionHandler<T>)
}

extension NetworkService {
    func makeJSONRequest<T: Decodable>(_ request: URLRequest,
                                       completionHandler: @escaping NetworkCompletionHandler<T>) {
        makeJSONRequest(request,
                        decoder: .domainDecoder,
                        completionHandler: completionHandler)
    }
}

final class DefaultNetworkService: NetworkService {
    let baseURL = URL(string: "https://api.thecatapi.com/v1")!
    
    private let session: URLSessionType
    private let apiKey: String
    
    // MARK: - Init
    
    init(session: URLSessionType = URLSession.shared,
         apiKey: String = Bundle.main.catAPIKey) {
        self.session = session
        self.apiKey = apiKey
    }
    
    // MARK: - Request
    
    func makeJSONRequest<T: Decodable>(_ request: URLRequest,
                                       decoder: JSONDecoder,
                                       completionHandler: @escaping NetworkCompletionHandler<T>) {
        //the API expects to be told who is asking on every request, so callers don't have to
        var request = request
        request.addValue(apiKey, forHTTPHeaderField: "x-api-key")
        
        session.data(for: request) { data, response, error in
            let result: Result<T, NetworkError> = Self.decode(data,
                                                              response: response,
                                                              error: error,
                                                              using: decoder)
            
            completionHandler(result)
        }
    }
    
    private static func decode<T: Decodable>(_ data: Data?,
                                             response: URLResponse?,
                                             error: Error?,
                                             using decoder: JSONDecoder) -> Result<T, NetworkError> {
        guard let data = data else {
            return .failure(.transportFailure(error))
        }
        
        guard let statusCode = (response as? HTTPURLResponse)?.statusCode else {
            return .failure(.invalidResponse)
        }
        
        guard (200..<300).contains(statusCode) else {
            return .failure(.unacceptableStatusCode(statusCode))
        }
        
        do {
            return .success(try decoder.decode(T.self, from: data))
        } catch let error {
            return .failure(.decodingFailed(error))
        }
    }
}

extension JSONDecoder {
    static var domainDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return decoder
    }
}

extension Bundle {
    var catAPIKey: String {
        let apiKey = object(forInfoDictionaryKey: "CatAPIKey") as? String ?? "" // Add your API key from: https://thecatapi.com/
        
        if apiKey.isEmpty {
            os_log(.error, """
            *******************************************************************************  
            *******************************************************************************  
            *******************************************************************************  
            ******************************* MISSING API KEY *******************************
            *******************************************************************************  
            ******************************************************************************* 
            ******************************************************************************* 
            """)
        }
        
        return apiKey
    }
}
