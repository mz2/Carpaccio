//
//  ImageCollection.swift
//  Trimmer
//
//  Created by Matias Piipari on 07/05/2016.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Foundation

public protocol ImageCollection: class {
    var images: AnyCollection<Image> { get }
    var imageCount: Int { get }
    var imageURLs: AnyCollection<URL> { get }
    var name: String { get }
    var URL: Foundation.URL? { get }
    
    func contains(image: Image) -> Bool
}

open class Collection: ImageCollection {
    private(set) open var name: String
    private(set) open var images: AnyCollection<Image>
    private(set) open var URL: Foundation.URL?

    public init(name: String, URL: Foundation.URL, images: AnyCollection<Image>) {
        self.name = name
        self.URL = URL
        self.images = images
    }

    public init(contentsOf url: Foundation.URL) throws {
        self.URL = url
        self.name = url.lastPathComponent
        self.images = try Collection.load(contentsOfURL: url)
    }

    open func contains(image: Image) -> Bool {
        return images.contains(image)
    }

    open var imageCount: Int {
        return images.count
    }

    open var imageURLs: AnyCollection<URL> {
        return AnyCollection<URL>(self.images.lazy.compactMap { image in
            return image.URL
        })
    }

    open func updateImages(_ images: AnyCollection<Image>) {
        self.images = images
    }

    /**
     Return images found in this collection whose URL is included in given input array or URLs.
     */
    public func images(forURLs urls: [Foundation.URL]) -> [Image] {
        return images.filter {
            if let url = $0.URL {
                return urls.contains(url)
            }
            return false
        }
    }

    public typealias URLFilter = (URL) -> Bool

    // MARK: - Loading images from the local filesystem
    public class func imageURLs(
        at directoryURL: URL,
        filteringSubdirectoriesWith subdirectoryFilter: URLFilter? = nil) throws -> [URL] {

        guard let enumerator = FileManager.default.enumerator(atPath: directoryURL.path) else {
            throw Image.Error.locationNotEnumerable(directoryURL)
        }
        
        let urls: [URL] = enumerator.compactMap({
            guard let relativePath = $0 as? String else {
                return nil
            }

            let url = directoryURL.appendingPathComponent(relativePath).absoluteURL

            if let attributes = enumerator.fileAttributes {
                let type = attributes[.type] as! FileAttributeType
                if type == .typeDirectory {
                    if let filter = subdirectoryFilter, !filter(url) {
                        enumerator.skipDescendants()
                    }
                } else if type == .typeRegular {
                    let isImage = Image.imageFileExtensions.contains(url.pathExtension.lowercased())
                    if isImage {
                        return url
                    }
                }
            }

            return nil
        })

        return urls
    }

    public typealias ImageLoadHandler = (_ index: Int, _ image: Image) -> Void
    public typealias ImageLoadErrorHandler = (Error) -> Void
    
    public class func load(contentsOfURL URL: Foundation.URL, loadHandler: ImageLoadHandler? = nil) throws -> AnyCollection<Image>
    {
        let imageURLs = try Collection.imageURLs(at: URL)
        let images = try loadImages(at: imageURLs, loadHandler: loadHandler)
        return images
    }

    public class func loadImages(at imageURLs: [URL], loadHandler: ImageLoadHandler? = nil) throws -> AnyCollection<Image> {
        let lazyImages = try imageURLs.lazy.enumerated().compactMap { i, imageURL -> Image? in
            let pathExtension = imageURL.pathExtension
            
            guard pathExtension.utf8.count > 0 else {
                return nil
            }
            
            let image = try Image(URL: imageURL)
            loadHandler?(i, image)
            
            return image
        }
        
        let images = AnyCollection<Image>(lazyImages)
        return images
    }
    
    public class func loadAsynchronously(contentsOfURL URL:Foundation.URL,
                                         queue:DispatchQueue = DispatchQueue.global(),
                                         loadHandler: ImageLoadHandler? = nil,
                                         errorHandler:@escaping ImageLoadErrorHandler) {
        queue.async {
            do {
                _ = try load(contentsOfURL: URL, loadHandler: loadHandler)
            }
            catch {
                errorHandler(Image.Error.loadingFailed(underlyingError: error))
            }
        }
    }

    // TODO: Create a specific type for a sparse distance matrix.
    public func distanceMatrix(_ distance:Image.DistanceFunction) -> [[Double]] {
        return images.indices.lazy.compactMap { i in
            var row = [Double]()
            for e in images.indices {
                if e == i {
                    row.append(0)
                }
                else {
                    row.append(Double.nan)
                }
            }
            
            let iSuccessor = self.images.indices.index(after: i)
            for j in (self.images.indices.suffix(from: iSuccessor)) {
                let col = self.images.indices.distance(from: self.images.indices.startIndex, to: j)
                row[col] = distance(images[i], images[j])
            }

            return row
        }
    }
    
    // TODO: Use a Swot data frame as return type instead?
    public func distanceTable(_ distance:Image.DistanceFunction) -> [[Double]] {
        let distMatrix = self.distanceMatrix(distance)
        
        if (distMatrix.count == 0) { return [[Double]]() }
        
        return images.indices.map { i in
            let iDist = images.indices.distance(from: images.indices.startIndex, to: i)
            
            return images.indices.map { j in
                let jDist = images.indices.distance(from: images.indices.startIndex, to: j)
            
                if j < i {
                    return distMatrix[jDist][iDist]
                }
                
                return distMatrix[iDist][jDist]
            }
        }
    }
        
}
