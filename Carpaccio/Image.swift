//
//  Image.swift
//  Trimmer
//
//  Created by Matias Piipari on 07/05/2016.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Foundation
import QuartzCore

open class Image: Equatable, Hashable {
    
    public enum Error: Swift.Error {
        case noFileExtension // FIXME: lift this restriction.
        case urlMissing
        case locationNotEnumerable(URL)
        case loadingFailed(underlyingError: Swift.Error)
    }
    
    public let name: String
    public var thumbnailImage: BitmapImage? = nil
    public var fullImage: BitmapImage?

    public var size: CGSize {
        guard let size = self.metadata?.size else {
            return CGSize.zero
        }
        return size
    }
    
    public let URL: Foundation.URL?
    
    private var _directoryPath: String?
    public var directoryPath: String? {
        if let url = URL {
            if _directoryPath == nil {
                _directoryPath = url.deletingLastPathComponent().path
            }
            return _directoryPath
        }
        return nil
    }
    
    public let UUID: String = {
        return Foundation.UUID().uuidString
    }()
    
    public typealias MetadataHandler = (_ metadata: ImageMetadata) -> Void
    public typealias ErrorHandler = (_ error: Image.Error) -> Void
    
    public typealias DistanceFunction = (_ a:Image, _ b:Image)-> Double
    
    public init(image: BitmapImage, imageLoader:ImageLoaderProtocol)
    {
        self.fullImage = image
        self.cachedImageLoader = imageLoader
        self.URL = imageLoader.imageURL
        self.name = image.name() ?? "Untitled"
    }
    
    public init(URL: Foundation.URL) throws
    {
        self.URL = URL
        self.name = URL.lastPathComponent 
        self.fullImage = nil
    }
    
    public var placeholderImage:BitmapImage {
        return BitmapImageUtility.image(named:"ImagePlaceholder")!
    }

    private var cachedImageLoader: ImageLoaderProtocol?
    
    open var imageLoader: ImageLoaderProtocol?
    {
        if let loader = cachedImageLoader {
            return loader
        }
        
        guard let URL = self.URL else {
            return nil
        }
        
        let pathExtension = URL.pathExtension.lowercased()
        
        if Image.RAWImageFileExtensions.contains(pathExtension)
        {
            //return RAWImageLoader(imageURL: URL, thumbnailScheme: .AlwaysDecodeFullImage)
            cachedImageLoader = RAWImageLoader(imageURL: URL, thumbnailScheme: .fullImageWhenTooSmallThumbnail)
        }
        else if Image.bakedImageFileExtensions.contains(pathExtension)
        {
            cachedImageLoader = RAWImageLoader(imageURL: URL, thumbnailScheme: .fullImageWhenTooSmallThumbnail)
        }
        
        return cachedImageLoader
    }
    
    public lazy var metadata: ImageMetadata? = {
        let metadata = self.imageLoader?.imageMetadata
        return metadata
    }()
    
    public var presentedImage: BitmapImage {
        return self.fullImage ?? self.thumbnailImage ?? self.placeholderImage
    }
    
    @discardableResult public func fetchMetadata() -> Bool {
        return self.metadata != nil
    }

    public func fetchMetadata(_ store: Bool = true,
                              handler: @escaping MetadataHandler,
                              errorHandler: @escaping ErrorHandler)
    {
        self.imageLoader?.loadImageMetadata({ metadata in
            if store {
                self.metadata = metadata
            }
            handler(metadata)
        }, errorHandler: { error in errorHandler(Error.loadingFailed(underlyingError:error)) })
    }
    
    public func fetchThumbnailSynchronously(presentedHeight: CGFloat? = nil,
                                            force: Bool = false,
                                            store: Bool = true,
                                            scaleFactor:CGFloat = 2.0) throws -> BitmapImage
    {
        precondition(!Thread.isMainThread)
        
        let semaphore = DispatchSemaphore(value: 0)
        
        var image:BitmapImage? = nil
        var err: Error?
        DispatchQueue.global().async {
            self.fetchThumbnail(presentedHeight: presentedHeight,
                                force: force,
                                store: store,
                                scaleFactor: scaleFactor,
                                completionHandler:
                { bitmap in // completion handler
                    image = bitmap
                    semaphore.signal()
                })
                { error in // error handler
                    err = error
                    semaphore.signal()
                }
        }
        
        semaphore.wait()
        
        if let err = err {
            throw err
        }
        
        return image!
    }
                                            
    
    public func fetchThumbnail(presentedHeight: CGFloat? = nil,
                               force: Bool = false,
                               store: Bool = true,
                               scaleFactor:CGFloat = 2.0,
                               completionHandler:@escaping (_ image:BitmapImage)->Void,
                               errorHandler:@escaping (Error)->Void)
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

        self.imageLoader?.loadThumbnailImage(maximumPixelDimensions: presentedHeight != nil ? CGSize(constrainHeight: presentedHeight! * scaleFactor) : nil, handler: { (thumbnailImage: BitmapImage, metadata: ImageMetadata) in
            if self.metadata == nil {
                self.metadata = metadata
            }
            
            if store {
                self.thumbnailImage = thumbnailImage
            }
            
            completionHandler(thumbnailImage)

            }, errorHandler: { (error) in errorHandler(.loadingFailed(underlyingError:error)) })
        
    }
    
    public func fetchFullSizeImage(presentedHeight: CGFloat? = nil, store: Bool = false, scaleFactor:CGFloat = 2.0, completionHandler: @escaping (_ image: BitmapImage) -> Void, errorHandler: @escaping (Error) -> Void)
    {
        guard self.URL != nil else {
            errorHandler(.urlMissing)
            return
        }
        
        let maxDimensions:CGSize? = {
            if let presentedHeight = presentedHeight {
                return CGSize(constrainHeight: presentedHeight * scaleFactor)
            }
            
            return nil
        }()
        
        var options = FullSizedImageLoadingOptions()
        options.maximumPixelDimensions = maxDimensions
        
        self.imageLoader?.loadFullSizeImage(options:options, handler: { image, metadata in
            
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
    
    public var hashValue: Int {
        return UUID.hashValue
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
