//
//  ImageLoader.swift
//  PausableDownloads-Example
//
//  Created by William Boles on 15/01/2018.
//  Copyright © 2018 William Boles. All rights reserved.
//

import Foundation
import UIKit
import os

typealias LoadImageCompletionHandler = (Result<UIImage, Error>) -> ()

//callers of `ImageLoader` only need to hand this back to `cancel`; that it is a download
//underneath is the loader's business
typealias LoadToken = DownloadToken

enum ImageLoaderError: Error {
    case invalidImageData
}

protocol ImageLoader {
    //returns nil when the image was served from the cache - nothing is in flight, so
    //there is nothing to cancel
    @discardableResult
    func load(_ imageDomainModel: ImageDomainModel,
              callbackQueue: DispatchQueue,
              completionHandler: @escaping LoadImageCompletionHandler) -> LoadToken?
    func cancel(_ token: LoadToken)
}

final class DefaultImageLoader: ImageLoader {
    private let downloader: Downloader
    private let fileManager: FileManager
    
    // MARK: - Init
    
    init(downloader: Downloader = DefaultDownloader.shared,
         fileManager: FileManager = FileManager.default) {
        self.downloader = downloader
        self.fileManager = fileManager
    }
    
    // MARK: - Load
    
    @discardableResult
    func load(_ imageDomainModel: ImageDomainModel,
              callbackQueue: DispatchQueue,
              completionHandler: @escaping LoadImageCompletionHandler) -> LoadToken? {
        //hop to the caller's queue once here, so nothing further down has to remember to
        let complete: LoadImageCompletionHandler = { result in
            callbackQueue.async {
                completionHandler(result)
            }
        }
        
        let cacheURL = cacheURL(for: imageDomainModel)
        
        if let image = cachedImage(at: cacheURL) {
            complete(.success(image))
            
            return nil
        }
        
        return downloader.download(imageDomainModel.url) { result in
            complete(result.flatMap { data in
                self.imageResult(from: data,
                                 cachingTo: cacheURL,
                                 for: imageDomainModel)
            })
        }
    }
    
    // MARK: - Cancel
    
    func cancel(_ token: LoadToken) {
        downloader.pause(token)
    }
    
    // MARK: - Cache
    
    private func cacheURL(for imageDomainModel: ImageDomainModel) -> URL {
        let cachesDirectory = fileManager.urls(for: .cachesDirectory,
                                               in: .userDomainMask).first!
        let fileName = "\(imageDomainModel.identifier).\(imageDomainModel.url.pathExtension)"
        
        return cachesDirectory.appendingPathComponent(fileName)
    }
    
    private func cachedImage(at url: URL) -> UIImage? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        
        return UIImage(data: data)
    }
    
    private func imageResult(from data: Data,
                             cachingTo cacheURL: URL,
                             for imageDomainModel: ImageDomainModel) -> Result<UIImage, Error> {
        guard let image = UIImage(data: data) else {
            return .failure(ImageLoaderError.invalidImageData)
        }
        
        do {
            try data.write(to: cacheURL,
                           options: .atomic)
        } catch {
            os_log(.error, "Failed to cache image %{public}@: %{public}@", imageDomainModel.identifier, error.localizedDescription)
        }
        
        //send the image regardless of write success or failure
        return .success(image)
    }
}
