//
//  ImageCollection.swift
//  Trimmer
//
//  Created by Matias Piipari on 07/05/2016.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Foundation


public typealias ImageCollectionHandler = (collection: ImageCollection) -> Void
public typealias ImageCollectionErrorHandler = (error: ErrorType) -> Void


public class ImageCollection
{
    public let name:String
    public var images:[Image]
    public let URL:NSURL
    
    public init(name: String, images: [Image], URL: NSURL) throws
    {
        self.URL = URL
        self.name = name
        self.images = images
    }
    
    public init(contentsOfURL URL:NSURL) throws {
        self.URL = URL
        self.name = URL.lastPathComponent ?? "Untitled"
        self.images = try Image.loadImages(contentsOfURL: URL)
    }
    
    /** Asynchronously initialise an image collection rooted at given URL, with all images found in the subtree prepared up to essential metadata having been loaded. */
    public class func prepareImageCollection(atURL collectionURL: NSURL, completionHandler: ImageCollectionHandler, errorHandler: ImageCollectionErrorHandler)
    {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0))
        {
            do
            {
                let imageURLs = try Image.imageURLs(atCollectionURL: collectionURL)
                var images = [Image]()
                
                for URL in imageURLs
                {
                    let image = Image(URL: URL)
                    images.append(image)
                    _ = image.metadata
                }
                
                let collection = try ImageCollection(name: collectionURL.lastPathComponent ?? "Untitled", images: images, URL: collectionURL)
                completionHandler(collection: collection)
                
            }
            catch {
                errorHandler(error: ImageError.LoadingFailed(underlyingError: error))
            }
        }
    }
    
    /** Return any image found in this collection whose URL is included in given input array or URLs. */
    public func images(forURLs URLs: [NSURL]) -> [Image]
    {
        var images = [Image]()
        
        for URL in URLs
        {
            if let i = self.images.indexOf( { (image: Image) -> Bool in
                return image.URL == URL
            }) {
                images.append(self.images[i])
            }
        }
        
        return images
    }
    
    // TODO: Create a specific type for a sparse distance matrix.
    public func distanceMatrix(distance:Image.DistanceFunction) -> [[Double]] {
        return (images.startIndex ..< self.images.endIndex).lazy.flatMap { i in
            var row = [Double]()
            for e in images.startIndex ..< images.endIndex {
                if e == i {
                    row.append(0)
                }
                else {
                    row.append(Double.NaN)
                }
            }
            
            let iSuccessor = i.successor()
            for j in (iSuccessor ..< self.images.endIndex) {
                row[j] = distance(a: images[i], b: images[j])
            }

            return row
        }
    }
    
    // TODO: Use a Swot data frame as return type instead?
    public func distanceTable(distance:Image.DistanceFunction) -> [[Double]] {
        let distMatrix = self.distanceMatrix(distance)
        var distTable = [[Double]]()
        
        if (distMatrix.count == 0) { return [[Double]]() }
        
        let rowCount = distMatrix.count
        let colCount = distMatrix[0].count
        precondition(rowCount == self.images.count)
        precondition(rowCount == colCount)
        
        for i in images.startIndex ..< images.endIndex {
            var row = [Double]()
            for j in images.startIndex ..< images.endIndex {
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