//
//  ImageCollection.swift
//  Trimmer
//
//  Created by Matias Piipari on 07/05/2016.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Foundation

public protocol ImageCollection: class
{
    var images: AnyCollection<Image> { get }
    var imageCount: Int { get }
    var imageURLs: AnyCollection<URL> { get }
    var name: String { get }
    var URL: Foundation.URL? { get }
    
    func contains(image: Image) -> Bool
}

extension Carpaccio.Collection: ImageCollection
{
    public func contains(image: Image) -> Bool {
        return self.images.contains(image)
    }
    
    public var imageURLs: AnyCollection<URL> {
        get {
            return AnyCollection<URL>(self.images.lazy.flatMap { image in
                return image.URL
            })
        }
    }
}

public typealias ImageCollectionPrepareProgressHandler = (_ collection: Collection, _ count: Int, _ total: Int) -> Void
public typealias ImageCollectionHandler = (Collection) -> Void
public typealias ImageCollectionErrorHandler = (Error) -> Void

open class Collection
{
    public let name:String
    private(set) public var images: AnyCollection<Image>
    private(set) public var imageCount: Int
    public let URL: Foundation.URL?
    
    public required init(name: String, URL: Foundation.URL, images: AnyCollection<Image>) {
        self.name = name
        self.URL = URL
        self.images = images
        self.imageCount = Int(images.count)
    }
            
    public init(contentsOf URL: Foundation.URL) throws {
        self.URL = URL
        self.name = URL.lastPathComponent
        
        self.images = try Collection.load(contentsOfURL: URL)
        self.imageCount = Int(self.images.count)
    }
    
    public enum SortingScheme {
        case none
        case byName
    }
    
    public typealias TotalImageCountCalculator = () -> Int
    
    public class func imageURLs(at URL: URL) throws -> [URL] {
        let fileManager = FileManager.default
        let path = URL.path
        
        guard let enumerator = fileManager.enumerator(atPath: path) else {
            throw Image.Error.locationNotEnumerable(URL)
        }
        
        let filterBlock: (URL) -> Bool = { url in
            if let attributes = enumerator.fileAttributes, attributes[.type] as! FileAttributeType == .typeRegular {
                let pathExtension = url.pathExtension.lowercased()
                let isImage = Image.imageFileExtensions.contains(pathExtension)
                return isImage
            }
            return false
        }
        
        let mapBlock:(Any) -> Foundation.URL = { anyPath -> Foundation.URL in
            let path = anyPath as! String
            let url = URL.appendingPathComponent(path, isDirectory: false).absoluteURL
            return url
        }
        
        let urls = enumerator.lazy.map(mapBlock).filter(filterBlock)
        return Array(urls)
    }
    
    private var preparing: Bool = false
    private var prepared: Bool = false
    private var prepareProgressIncrementQueue = DispatchQueue(label: "com.sashimiapp.Carpaccio.Collection.prepareProgressCounter")
    private var _preparedImageCount = 0
    
    func incrementPrepareProgress() -> Int {
        var newCount: Int = 0
        prepareProgressIncrementQueue.sync {
            _preparedImageCount += 1
            newCount = _preparedImageCount
        }
        return newCount
    }
    
    /** Asynchronously initialise an image collection rooted at given URL, with all images found in the subtree prepared up to essential metadata having been loaded. */
    public func prepare(
        queue: DispatchQueue = DispatchQueue.global(),
        sortingScheme: SortingScheme = .none,
        maxMetadataLoadParallelism: Int? = nil,
        progressHandler: @escaping ImageCollectionPrepareProgressHandler,
        completionHandler: @escaping ImageCollectionHandler,
        errorHandler: @escaping ImageCollectionErrorHandler) throws {
        
        guard let url = self.URL else {
            throw Image.Error.urlMissing
        }
        guard !preparing else {
            throw Image.Error.alreadyPreparing
        }
        guard !prepared else {
            throw Image.Error.alreadyPrepared
        }
        
        preparing = true
        weak var weakCollection = self
        
        queue.async {
            guard let collection = weakCollection else {
                return
            }
            
            do {
                let imageURLs = try Collection.imageURLs(at: url)
                let imageURLCount = imageURLs.count
                
                let images: [Image]
                do {
                    images = try imageURLs.lazy.parallelFlatMap(maxParallelism:maxMetadataLoadParallelism) { URL -> Image? in
                        let image = try Image(URL: URL)
                        image.fetchMetadata()
                        let count = collection.incrementPrepareProgress()
                        
                        progressHandler(collection, count, imageURLCount)
                        return image
                    }
                } catch {
                    errorHandler(error)
                    return
                }
                
                let returnedImages:AnyCollection<Image>
                
                switch sortingScheme {
                case .none:
                    returnedImages = AnyCollection<Image>(images)
                    
                case .byName:
                    returnedImages = AnyCollection<Image>(images.sorted { image1, image2 in
                        return image1.name.compare(image2.name) == .orderedAscending
                    })
                }
                
                let returnedCollection = type(of: self).init(name: url.lastPathComponent,
                                                             URL: url,
                                                             images: returnedImages)
                self.images = returnedImages
                self.imageCount = Int(returnedImages.count)
                completionHandler(returnedCollection)
            }
            catch {
                errorHandler(Image.Error.loadingFailed(underlyingError: error))
            }
            
            collection.prepared = true
            collection.preparing = false
        }
    }
    
    public typealias ImageLoadHandler = (_ index:Int, _ image:Image) -> Void
    public typealias ImageLoadErrorHandler = (Error) -> Void
    
    public class func load(contentsOfURL URL: Foundation.URL, loadHandler: ImageLoadHandler? = nil) throws -> AnyCollection<Image>
    {
        let imageURLs = try Collection.imageURLs(at: URL)
        let images = try loadImages(at: imageURLs, loadHandler: loadHandler)
        return images
    }

    public class func loadImages(at imageURLs: [URL], loadHandler: ImageLoadHandler? = nil) throws -> AnyCollection<Image> {
        let lazyImages = try imageURLs.lazy.enumerated().flatMap { i, imageURL -> Image? in
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
    
    /**
     Return images found in this collection whose URL is included in given input array or URLs.
     */
    public func images(forURLs URLs: [Foundation.URL]) -> [Image]
    {
        var images = [Image]()
        
        for URL in URLs
        {
            if let i = self.images.index( where: { (image: Image) -> Bool in
                return image.URL == URL
            }) {
                images.append(self.images[i])
            }
        }
        
        return images
    }
    
    // TODO: Create a specific type for a sparse distance matrix.
    public func distanceMatrix(_ distance:Image.DistanceFunction) -> [[Double]] {
        return images.indices.lazy.flatMap { i in
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
