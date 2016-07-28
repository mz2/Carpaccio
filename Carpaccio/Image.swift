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

public class Image: Equatable {
    public let name:String
    public var thumbnailImage:NSImage? = nil
    public let backingImage:NSImage?
    public let URL:NSURL?
        
    public typealias MetadataHandler = (metadata: ImageMetadata) -> Void
    public typealias ErrorHandler = (error: ErrorType) -> Void
    
    public typealias DistanceFunction = (a:Image, b:Image)-> Double
    
    public required init(image: NSImage)
    {
        self.backingImage = image
        self.name = image.name() ?? "Untitled"
        self.URL = nil
    }
    
    public init(URL: NSURL)
    {
        self.URL = URL
        self.name = URL.lastPathComponent ?? "Untitled"
        self.backingImage = nil
        
        if let pathExtension = URL.pathExtension?.lowercaseString
        {
            if Image.RAWImageFileExtensions.contains(pathExtension)
            {
                self.imageLoader = LibRAWImageLoader(imageURL: URL)
            }
            else if Image.bakedImageFileExtensions.contains(pathExtension)
            {
                self.imageLoader = BakedImageLoader(imageURL: URL)
            }
        }
    }
    
    public var placeholderImage:NSImage {
        return NSImage(named: "ImagePlaceholder")!
    }
    
    private var imageLoader: ImageLoaderProtocol?
    
    public var metadata: ImageMetadata?
    
    public var isMetadataAvailable: Bool {
        get {
            if let metadata = self.metadata {
                return true
            }
            return false
        }
    }
    
    public var presentedImage:NSImage {
        return backingImage ?? self.thumbnailImage ?? self.placeholderImage
    }
    
    public func fetchMetadata(store: Bool = true, handler: MetadataHandler, errorHandler: ErrorHandler)
    {
        self.imageLoader?.extractImageMetadata({ (metadata: ImageMetadata) in
            
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
            self.imageLoader?.loadThumbnailImage({ (thumbnailImage: NSImage, metadata: ImageMetadata) in
                
                if self.metadata == nil {
                    self.metadata = metadata
                }
                
                let t = presentedHeight != nil ?
                    Image.scale(presentableImage: thumbnailImage, height: presentedHeight!, screenScaleFactor: 2.0) : thumbnailImage
                
                if store {
                    self.thumbnailImage = t
                }
                
                completionHandler(image: t)

            }, errorHandler: { (error) in errorHandler(error) })
        }
        else
        {
            errorHandler(ImageError.URLMissing)
            return
        }
    }
    
    public func fetchFullSizeImage(presentedHeight presentedHeight: CGFloat? = nil, completionHandler: (image: NSImage) -> Void, errorHandler: (ErrorType) -> Void)
    {
        if let url = self.URL
        {
            self.imageLoader?.loadFullSizeImage({ (image: NSImage, metadata: ImageMetadata) in
                
                if self.metadata == nil {
                    self.metadata = metadata
                }
                
                let i = presentedHeight != nil ?
                    Image.scale(presentableImage: image, height: presentedHeight!, screenScaleFactor: 2.0) : image
                
                completionHandler(image: i)
                
                }, errorHandler: { error in errorHandler(error) }
            )
        }
        else
        {
            errorHandler(ImageError.URLMissing)
            return
        }
    }
    
    internal class func scale(presentableImage t: NSImage, height: CGFloat, screenScaleFactor: CGFloat) -> NSImage
    {
        let widthToHeightRatio = t.size.width / t.size.height
        let pixelHeight = height * screenScaleFactor
        let pixelWidth = round(widthToHeightRatio * pixelHeight)
        
        let thumb = NSImage(size: NSSize(width: pixelWidth, height: pixelHeight))
        thumb.cacheMode = .Never
        
        thumb.lockFocus()
        NSGraphicsContext.currentContext()?.imageInterpolation = .Default
        t.drawInRect(NSRect(x: 0.0, y: 0.0, width: pixelWidth, height: pixelHeight), fromRect: NSRect(x: 0.0, y: 0.0, width: t.size.width, height: t.size.height), operation: .CompositeCopy, fraction: 1.0)
        thumb.unlockFocus()

        return thumb
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
    
    public class func loadImages(contentsOfURL URL:NSURL, loadHandler:LoadHandler? = nil) throws -> [Image] {
        let fileManager = NSFileManager.defaultManager()
        
        guard let path = URL.path else {
            throw ImageError.URLHasNoPath(URL)
        }
        
        guard let enumerator = fileManager.enumeratorAtPath(path) else {
            throw ImageError.LocationNotEnumerable(URL)
        }
        
        var images = [Image]()
        
        let allPaths = (enumerator.allObjects as! [String]).filter {
            let pathExtension = ($0 as NSString).pathExtension.lowercaseString
            return Image.imageFileExtensions.contains(pathExtension)
        }
        
        for (i, elementStr) in allPaths.enumerate() {
            let absoluteURL = URL.URLByAppendingPathComponent(elementStr)
            
            if let pathExtension = absoluteURL.pathExtension
            {
                let image = Image(URL: absoluteURL)
                loadHandler?(index: i, total:allPaths.count, image: image)
                images.append(image)
            }
        }
        
        return images
    }
}

public func == (lhs:Image, rhs:Image) -> Bool {
    return lhs.name == rhs.name
            && lhs.thumbnailImage === rhs.thumbnailImage
            && lhs.backingImage === rhs.backingImage
            && lhs.URL == rhs.URL
}