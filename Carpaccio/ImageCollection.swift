//
//  ImageCollection.swift
//  Trimmer
//
//  Created by Matias Piipari on 07/05/2016.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Foundation


public typealias ImageCollectionHandler = (_ collection: ImageCollection) -> Void
public typealias ImageCollectionErrorHandler = (_ error: Error) -> Void


public class ImageCollection
{
    public let name:String
    public var images:[Image]
    public let URL:Foundation.URL
    
    public init(name: String, images: [Image], URL: Foundation.URL) throws
    {
        self.URL = URL
        self.name = name
        self.images = images
    }
    
    public init(contentsOfURL URL:Foundation.URL) throws {
        self.URL = URL
        self.name = URL.lastPathComponent ?? "Untitled"
        self.images = try Image.load(contentsOfURL: URL)
    }
    
    /** Asynchronously initialise an image collection rooted at given URL, with all images found in the subtree prepared up to essential metadata having been loaded. */
    public class func prepare(atURL collectionURL: Foundation.URL, queue:DispatchQueue = DispatchQueue.global(), completionHandler: ImageCollectionHandler, errorHandler: ImageCollectionErrorHandler) {
        queue.async {
            do {
                let imageURLs = try Image.imageURLs(atCollectionURL: collectionURL)
                var images = [Image]()
                
                for URL in imageURLs
                {
                    let image = Image(URL: URL)
                    images.append(image)
                    _ = image.metadata
                }
                
                let collection = try ImageCollection(name: collectionURL.lastPathComponent ?? "Untitled", images: images, URL: collectionURL)
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
        return (images.indices).lazy.flatMap { i in
            var row = [Double]()
            for e in images.indices {
                if e == i {
                    row.append(0)
                }
                else {
                    row.append(Double.nan)
                }
            }
            
            let iSuccessor = (i + 1)
            for j in (self.images.indices.suffix(from: iSuccessor)) {
                row[j] = distance(images[i], images[j])
            }

            return row
        }
    }
    
    // TODO: Use a Swot data frame as return type instead?
    public func distanceTable(_ distance:Image.DistanceFunction) -> [[Double]] {
        let distMatrix = self.distanceMatrix(distance)
        var distTable = [[Double]]()
        
        if (distMatrix.count == 0) { return [[Double]]() }
        
        let rowCount = distMatrix.count
        let colCount = distMatrix[0].count
        precondition(rowCount == self.images.count)
        precondition(rowCount == colCount)
        
        for i in images.indices {
            var row = [Double]()
            for j in images.indices {
                if j < i {
                    row.append(distMatrix[j][i])
                }
                else {
                    row.append(distMatrix[i][j])
                }
            }
            distTable.append(row)
        }
        
        return distTable
    }
}
