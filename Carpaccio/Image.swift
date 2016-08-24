//
//  Image.swift
//  Trimmer
//
//  Created by Matias Piipari on 07/05/2016.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Cocoa


public class Image: Equatable {
    
    public enum Error: Swift.Error {
        case urlMissing
        case locationNotEnumerable(URL)
        case loadingFailed(underlyingError: Swift.Error)
    }
    
    public let name: String
    public var thumbnailImage: NSImage? = nil
    public var fullImage: NSImage?

    public var size: NSSize {
        guard let size = self.metadata?.size else {
            return NSZeroSize
        }
        return size
    }
    
    public let URL: Foundation.URL?
    
    public typealias MetadataHandler = (_ metadata: ImageMetadata) -> Void
    public typealias ErrorHandler = (_ error: Image.Error) -> Void
    
    public typealias DistanceFunction = (_ a:Image, _ b:Image)-> Double
    
    public required init(image: NSImage)
    {
        self.fullImage = image
        self.name = image.name() ?? "Untitled"
        self.URL = nil
    }
    
    public init(URL: Foundation.URL)
    {
        self.URL = URL
        self.name = URL.lastPathComponent 
        self.fullImage = nil
        
        let pathExtension = URL.pathExtension.lowercased()
        
        if Image.RAWImageFileExtensions.contains(pathExtension) {
            self.imageLoader = RAWImageLoader(imageURL: URL, thumbnailScheme: .decodeFullImageIfThumbnailTooSmall)
            //self.imageLoader = RAWImageLoader(imageURL: URL, thumbnailScheme: .AlwaysDecodeFullImage)
        }
        else if Image.bakedImageFileExtensions.contains(pathExtension)
        {
            self.imageLoader = RAWImageLoader(imageURL: URL, thumbnailScheme: .decodeFullImageIfThumbnailTooSmall)
        }
    }
    
    public var placeholderImage:NSImage {
        return NSImage(named: "ImagePlaceholder")!
    }
    
    private var imageLoader: ImageLoaderProtocol?
    
    public lazy var metadata: ImageMetadata? = {
        return self.imageLoader?.imageMetadata
    }()
    
    public var isMetadataAvailable: Bool {
        get {
            return self.metadata != nil
        }
    }
    
    public var presentedImage: NSImage {
        return self.fullImage ?? self.thumbnailImage ?? self.placeholderImage
    }
    
    public func fetchMetadata(_ store: Bool = true, handler: MetadataHandler, errorHandler: ErrorHandler)
    {
        self.imageLoader?.loadImageMetadata({ (metadata: ImageMetadata) in
            
            if store {
                self.metadata = metadata
            }
            handler(metadata)

            }, errorHandler: { error in errorHandler(Error.loadingFailed(underlyingError:error)) })
    }
    
    public func fetchThumbnail(presentedHeight: CGFloat? = nil, force: Bool = false, store: Bool = true, scaleFactor:CGFloat = 2.0, completionHandler:@escaping (_ image:NSImage)->Void, errorHandler:@escaping (Error)->Void)
    {
        if !force
        {
            if let thumb = self.thumbnailImage
            {
                completionHandler(thumb)
                return
            }
        }
        
        guard self.URL != nil else {
            errorHandler(Error.urlMissing)
            return
        }

        self.imageLoader?.loadThumbnailImage(maximumPixelDimensions: presentedHeight != nil ? NSSize(constrainHeight: presentedHeight! * scaleFactor) : nil, handler: { (thumbnailImage: NSImage, metadata: ImageMetadata) in
            if self.metadata == nil {
                self.metadata = metadata
            }
            
            if store {
                self.thumbnailImage = thumbnailImage
            }
            
            completionHandler(thumbnailImage)

            }, errorHandler: { (error) in errorHandler(.loadingFailed(underlyingError:error)) })
        
    }
    
    public func fetchFullSizeImage(presentedHeight: CGFloat? = nil, store: Bool = false, scaleFactor:CGFloat = 2.0, completionHandler: @escaping (_ image: NSImage) -> Void, errorHandler: @escaping (Error) -> Void)
    {
        guard self.URL != nil else {
            errorHandler(.urlMissing)
            return
        }

        self.imageLoader?.loadFullSizeImage(maximumPixelDimensions: presentedHeight != nil ? NSSize(constrainHeight: presentedHeight! * scaleFactor) : nil, handler: { (image: NSImage, metadata: ImageMetadata) in
            
            if self.metadata == nil {
                self.metadata = metadata
            }
            
            if store {
                self.fullImage = image
            }
            
            completionHandler(image)
            
            }, errorHandler: { error in errorHandler(.loadingFailed(underlyingError:error)) }
        )
    }
    
    public class var imageFileExtensions:Set<String> {
        var extensions = self.RAWImageFileExtensions
        extensions.formUnion(self.bakedImageFileExtensions)
        return extensions
    }
    
    public class var RAWImageFileExtensions:Set<String> {
        return Set(["arw", "nef", "cr2", "crw"])
    }

    public class var bakedImageFileExtensions:Set<String> {
        return Set(["jpg", "jpeg", "png", "tiff", "tif", "gif"])
    }

    public typealias LoadHandler = (_ index:Int, _ total:Int, _ image:Image) -> Void
    public typealias LoadErrorHandler = (Error) -> Void
    
    internal class func imageURLs(atCollectionURL URL: Foundation.URL) throws -> [Foundation.URL]
    {
        let fileManager = FileManager.default
        
        let path = URL.path
        
        guard let enumerator = fileManager.enumerator(atPath: path) else {
            throw Error.locationNotEnumerable(URL)
        }
        
        let imagePaths = (enumerator.allObjects as! [String]).filter
        {
            // TODO: should filter out directories etc. here, just in case — or use the enumeration method with options for that
            let pathExtension = ($0 as NSString).pathExtension.lowercased()
            return Image.imageFileExtensions.contains(pathExtension)
        }
        
        let imageURLs = imagePaths.flatMap { (path: String) -> Foundation.URL? in
            return URL.appendingPathComponent(path, isDirectory: false).absoluteURL
        }
        
        return imageURLs
    }
    
    public class func load(contentsOfURL URL:Foundation.URL, loadHandler: LoadHandler? = nil) throws -> [Image]
    {
        let imageURLs = try self.imageURLs(atCollectionURL: URL)
        
        let images = imageURLs.enumerated().flatMap { (i, imageURL) -> Image? in
            let pathExtension = imageURL.pathExtension
            
            guard pathExtension.utf8.count > 0 else { return nil }
            
            let image = Image(URL: imageURL)
            loadHandler?(i, imageURLs.count, image)
            
            return image
        }
        
        return images
    }
    
    public class func loadAsynchronously(contentsOfURL URL:Foundation.URL, queue:DispatchQueue = DispatchQueue.global(), loadHandler:LoadHandler? = nil, errorHandler:LoadErrorHandler) {
        queue.async {
            do {
                _ = try load(contentsOfURL: URL, loadHandler: loadHandler)
            }
            catch {
                errorHandler(.loadingFailed(underlyingError: error))
            }
        }
    }
}

/*
public func == (lhs:Image, rhs:Image) -> Bool {
    return lhs.name == rhs.name
            && lhs.thumbnailImage === rhs.thumbnailImage
            && lhs.fullImage === rhs.fullImage
            && lhs.URL == rhs.URL
}
 */

public func == (lhs:Image, rhs:Image) -> Bool
{
    return lhs.URL == rhs.URL
}
