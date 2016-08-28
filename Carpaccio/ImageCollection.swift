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
    func contains(image: Image) -> Bool
    var images: AnyCollection<Image> { get }
    var imageCount: Int { get }
    var imageURLs: AnyCollection<URL> { get }
    var name: String { get }
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

public typealias ImageCollectionHandler = (Collection) -> Void
public typealias ImageCollectionErrorHandler = (Error) -> Void

public class Collection
{
    public let name:String
    public var images:AnyCollection<Image>
    public let imageCount:Int
    public let URL:Foundation.URL
    
    public init(name: String, images: AnyCollection<Image>, imageCount:Int, URL: Foundation.URL) throws
    {
        self.URL = URL
        self.name = name
        self.images = images
        self.imageCount = imageCount
    }
    
    public init(contentsOfURL URL:Foundation.URL) throws {
        self.URL = URL
        self.name = URL.lastPathComponent
        
        let (images, count) = try Image.load(contentsOfURL: URL)
        self.images = AnyCollection<Image>(images)
        self.imageCount = count
    }
    
    public enum SortingScheme {
        case none
        case byName
    }
    
    /** Asynchronously initialise an image collection rooted at given URL, with all images found in the subtree prepared up to essential metadata having been loaded. */
    public class func prepare(atURL collectionURL: Foundation.URL,
                              queue:DispatchQueue = DispatchQueue.global(),
                              sortingScheme:SortingScheme = .none,
                              maxMetadataLoadParallelism:Int? = nil,
                              completionHandler: ImageCollectionHandler,
                              errorHandler: ImageCollectionErrorHandler) {
        queue.async {
            do {
                let imageURLs = try Image.imageURLs(atCollectionURL: collectionURL)
                
                let images = imageURLs.lazy.pmap(maxParallelism:maxMetadataLoadParallelism) { URL -> Image in
                    let image = Image(URL: URL)
                    image.fetchMetadata()
                    return image
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

                let collection = try Collection(name: collectionURL.lastPathComponent,
                                                images: returnedImages,
                                                imageCount: imageURLs.count,
                                                URL: collectionURL)
                
                completionHandler(collection)
                
            }
            catch {
                errorHandler(Image.Error.loadingFailed(underlyingError: error))
            }
        }
    }
    
    /** Return any image found in this collection whose URL is included in given input array or URLs. */
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
        var distTable = [[Double]]()
        
        if (distMatrix.count == 0) { return [[Double]]() }
        
        //let rowCount = distMatrix.count
        //let colCount = distMatrix[0].count
        //precondition(rowCount == self.images.count)
        //precondition(rowCount == colCount)
        
        for i in images.indices {
            let iDist = images.indices.distance(from: images.indices.startIndex, to: i)
            var row = [Double]()
            for j in images.indices {
                let jDist = images.indices.distance(from: images.indices.startIndex, to: i)
            
                if j < i {
                    row.append(distMatrix[jDist][iDist])
                }
                else {
                    row.append(distMatrix[iDist][jDist])
                }
            }
            distTable.append(row)
        }
        
        return distTable
    }
}
