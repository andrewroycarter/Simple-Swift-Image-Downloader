//
//  ImageGetter.swift
//  SimpleImageDownloaderExample
//
//  Created by Andrew Carter on 10/1/17.
//  Copyright © 2017 Andrew Carter. All rights reserved.
//

import Foundation
import UIKit

class ImageGetter {

    enum ImageGetterError: Error {
        case unknown
    }

    typealias CompletionHandler = (Result<UIImage>) -> Void

    private struct Task {
        let sessionTask: URLSessionTask
        let listeners: [CompletionHandler]
        let diskCachePath: String
        let inMemoryCacheName: NSString
    }

    private let imageGetterQueue = DispatchQueue(label: "com.ImageGetter.imageGetterQueue")
    private let session = URLSession(configuration: .default)
    private var tasks: [URL: Task] = [:]
    private let cache = NSCache<NSString, UIImage>()
    private static var cacheDirectory: String {
        return (NSTemporaryDirectory() as NSString).appendingPathComponent("\(String(describing: ImageGetter.self))/")
    }

    init() {
        createCacheDirectory()
    }

    private func createCacheDirectory() {
        do {
            try FileManager.default.createDirectory(atPath: ImageGetter.cacheDirectory, withIntermediateDirectories: true, attributes: [:])
        } catch {
            fatalError("Failed to create storage cache directory")
        }
    }

    func getImage(from url: URL, completion: @escaping CompletionHandler) {
        print("Image at \(url) requested")
        imageGetterQueue.async { [weak self] in
            print("Getting image on image getter queue...")
            self?._getImage(from: url, completion: completion)
        }
    }

    private func _getImage(from url: URL, completion: @escaping CompletionHandler) {
        let urlString = url.absoluteString
        let cacheFileName = urlString.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) ?? String(urlString.hash)
        let diskCachePath = (ImageGetter.cacheDirectory as NSString).appendingPathComponent(cacheFileName)
        let inMemoryCacheName = cacheFileName as NSString

        if let cachedImage = cache.object(forKey: inMemoryCacheName) {
            print("Found image in memory cache, calling completion handler")
            completion(.ok(cachedImage))
        } else if let image = UIImage(contentsOfFile: diskCachePath) {
            print("Found image on disk cache, adding to memory cache and calling completion handler")
            cache.setObject(image, forKey: inMemoryCacheName)
            completion(.ok(image))
        } else if let existingTask = tasks[url] {
            print("Already fetching image, adding completion handler to existing task")
            let newTask = Task(sessionTask: existingTask.sessionTask,
                               listeners: existingTask.listeners + [completion],
                               diskCachePath: diskCachePath,
                               inMemoryCacheName: inMemoryCacheName)
            tasks[url] = newTask
        } else {
            print("Need image from network, creating network task")
            let sessionTask = session.dataTask(with: url, completionHandler: { [weak self] (data, response, error) in
                guard let strongSelf = self else {
                    return

                }
                print("Network task finished for \(url), now handling")
                strongSelf.handleSessionTaskCompletion(url: url, data: data, response: response, error: error)
            })
            print("Stored completion handler for when network task completes")
            tasks[url] = Task(sessionTask: sessionTask,
                              listeners: [completion],
                              diskCachePath: diskCachePath,
                              inMemoryCacheName: inMemoryCacheName)
            print("Starting network task")
            sessionTask.resume()
        }
    }

    private func handleSessionTaskCompletion(url: URL, data: Data?, response: URLResponse?, error: Error?) {
        imageGetterQueue.async { [weak self] in
            print("Handling network task completion on image getter queue")
            guard let strongSelf = self,
                let task = strongSelf.tasks[url] else {
                    return
            }

            strongSelf.tasks[url] = nil

            let result: Result<UIImage>
            if let error = error {
                print("Failed to get image with error \(error)")
                result = .error(error)
            } else if let data = data,
                let image = UIImage(data: data) {
                print("Got image, writing to disk cache and adding to memory cache")
                strongSelf.cache.setObject(image, forKey: task.inMemoryCacheName)
                try? UIImageJPEGRepresentation(image, 1.0)?.write(to: URL(fileURLWithPath: task.diskCachePath), options: [])
                result = .ok(image)
            } else {
                print("Failed to parse image")
                result = .error(ImageGetterError.unknown)
            }

            print("Calling all completion handlers (\(task.listeners.count))")
            task.listeners.forEach { $0(result) }
        }
    }

}

