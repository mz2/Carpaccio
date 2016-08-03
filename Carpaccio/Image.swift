//
//  Image.swift
//  Trimmer
//
//  Created by Matias Piipari on 07/05/2016.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Cocoa

public enum ImageError:ErrorType
{
    case URLMissing
    case URLHasNoPath(NSURL)
    case LocationNotEnumerable(NSURL)
    case LoadingFailed(underlyingError:ErrorType)
}

public class Image: Equatable
{
    public let name: String
    public var thumbnailImage: NSImage? = nil
    public var fullImage: NSImage?
    public let URL: NSURL?
    
    public typealias MetadataHandler = (metadata: ImageMetadata) -> Void
    public typealias ErrorHandler = (error: ErrorType) -> Void
    
    public typealias DistanceFunction = (a:Image, b:Image)-> Double
    
    public required init(image: NSImage)
    {
        self.fullImage = image
        self.name = image.name() ?? "Untitled"
        self.URL = nil
    }
    
    public init(URL: NSURL)
    {
        self.URL = URL
        self.name = URL.lastPathComponent ?? "Untitled"
        self.fullImage = nil
        
        if let pathExtension = URL.pathExtension?.lowercaseString
        {
            if Image.RAWImageFileExtensions.contains(pathExtension)
            {
                self.imageLoader = RAWImageLoader(imageURL: URL, thumbnailScheme: .DecodeFullImageIfThumbnailTooSmall)
                //self.imageLoader = RAWImageLoader(imageURL: URL, thumbnailScheme: .AlwaysDecodeFullImage)
            }
            else if Image.bakedImageFileExtensions.contains(pathExtension)
            {
                self.imageLoader = RAWImageLoader(imageURL: URL, thumbnailScheme: .DecodeFullImageIfThumbnailTooSmall)
            }
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
            if let metadata = self.metadata {
                return true
            }
            return false
        }
    }
    
    public var presentedImage: NSImage {
        return self.fullImage ?? self.thumbnailImage ?? self.placeholderImage
    }
    
    public func fetchMetadata(store: Bool = true, handler: MetadataHandler, errorHandler: ErrorHandler)
    {
        self.imageLoader?.loadImageMetadata({ (metadata: ImageMetadata) in
            
            if store {
                self.metadata = metadata
            }
            handler(metadata: metadata)

        }, errorHandler: { error in errorHandler(error: error) })
    }
    
    public func fetchThumbnail(presentedHeight presentedHeight: CGFloat? = nil, force: Bool = false, store: Bool = true, completionHandler:(image:NSImage)->Void, errorHandler:(ErrorType)->Void)
    {
        if !force
        {
            if let thumb = self.thumbnailImage
            {
                completionHandler(image: thumb)
                return
            }
        }
        
        if let URL = self.URL
        {
            self.imageLoader?.loadThumbnailImage(maximumPixelDimensions: presentedHeight != nil ? NSSize(constrainHeight: presentedHeight! * 2.0) : nil, handler: { (thumbnailImage: NSImage, metadata: ImageMetadata) in
                
                if self.metadata == nil {
                    self.metadata = metadata
                }
                
                if store {
                    self.thumbnailImage = thumbnailImage
                }
                
                completionHandler(image: thumbnailImage)

            }, errorHandler: { (error) in errorHandler(error) })
        }
        else
        {
            errorHandler(ImageError.URLMissing)
            return
        }
    }
    
    public func fetchFullSizeImage(presentedHeight presentedHeight: CGFloat? = nil, store: Bool = false, completionHandler: (image: NSImage) -> Void, errorHandler: (ErrorType) -> Void)
    {
        if let url = self.URL
        {
            // TODO: Query actual screen scale factor instead of hard-coded 2.0
            self.imageLoader?.loadFullSizeImage(maximumPixelDimensions: presentedHeight != nil ? NSSize(constrainHeight: presentedHeight! * 2.0) : nil, handler: { (image: NSImage, metadata: ImageMetadata) in
                
                if self.metadata == nil {
                    self.metadata = metadata
                }
                
                if store {
                    self.fullImage = image
                }
                
                completionHandler(image: image)
                
                }, errorHandler: { error in errorHandler(error) }
            )
        }
        else
        {
            errorHandler(ImageError.URLMissing)
            return
        }
    }
    
    public class var imageFileExtensions:Set<String> {
        var extensions = self.RAWImageFileExtensions
        extensions.unionInPlace(self.bakedImageFileExtensions)
        return extensions
    }
    
    public class var RAWImageFileExtensions:Set<String> {
        return Set(["arw", "nef", "cr2"])
    }

    public class var bakedImageFileExtensions:Set<String> {
        return Set(["jpg", "jpeg"]) //, "png", "tiff"])
    }

    public typealias LoadHandler = (index:Int, total:Int, image:Image) -> Void
    public typealias LoadErrorHandler = (ImageError) -> Void
    
    internal class func imageURLs(atCollectionURL URL: NSURL) throws -> [NSURL]
    {
        let fileManager = NSFileManager.defaultManager()
        
        guard let path = URL.path else {
            throw ImageError.URLHasNoPath(URL)
        }
        
        guard let enumerator = fileManager.enumeratorAtPath(path) else {
            throw ImageError.LocationNotEnumerable(URL)
        }
        
        let imagePaths = (enumerator.allObjects as! [String]).filter
        {
            // TODO: should filter out directories etc. here, just in case — or use the enumeration method with options for that
            let pathExtension = ($0 as NSString).pathExtension.lowercaseString
            return Image.imageFileExtensions.contains(pathExtension)
        }
        
        let imageURLs = imagePaths.flatMap { (path: String) -> NSURL? in
            return URL.URLByAppendingPathComponent(path, isDirectory: false).absoluteURL
        }
        
        return imageURLs
    }
    
    public class func loadImages(contentsOfURL URL:NSURL, loadHandler: LoadHandler? = nil) throws -> [Image]
    {
        let imageURLs = try self.imageURLs(atCollectionURL: URL)
        var images = [Image]()
        
        for (i, imageURL) in imageURLs.enumerate()
        {
            if let pathExtension = imageURL.pathExtension
            {
                let image = Image(URL: imageURL)
                loadHandler?(index: i, total: imageURLs.count, image: image)
                images.append(image)
            }
        }
        
        return images
    }
    
    public class func loadImagesAsynchronously(contentsOfURL URL:NSURL, loadHandler:LoadHandler? = nil, errorHandler:LoadErrorHandler) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
            do {
                try loadImages(contentsOfURL: URL, loadHandler: loadHandler)
            }
            catch {
                errorHandler(.LoadingFailed(underlyingError: error))
            }
        }
    }
}

public func == (lhs:Image, rhs:Image) -> Bool {
    return lhs.name == rhs.name
            && lhs.thumbnailImage === rhs.thumbnailImage
            && lhs.fullImage === rhs.fullImage
            && lhs.URL == rhs.URL
}