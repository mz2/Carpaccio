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
        case noURL
        case noLoader(Image)
        case noFileExtension // FIXME: lift this restriction.
        case urlMissing
        case alreadyPreparing
        case alreadyPrepared
        case locationNotEnumerable(URL)
        case loadingFailed(underlyingError: Swift.Error)
        case noThumbnail(Image)
        case noHistogram(Image)
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
    
    /// Set the value for this to alter the type of object used by default for image and metadata loading.
    public static var defaultImageLoaderType: URLBackedImageLoaderProtocol.Type = ImageLoader.self
    
    
    public init(image: BitmapImage, imageLoader: ImageLoaderProtocol)
    {
        self.fullImage = image
        self.cachedImageLoader = imageLoader
        self.URL = imageLoader.imageURL
        self.name = image.name() ?? "Untitled"
    }
    
    public init(URL: Foundation.URL, imageLoader:ImageLoaderProtocol? = nil) throws
    {
        self.URL = URL
        self.cachedImageLoader = imageLoader
        self.name = URL.lastPathComponent
        self.fullImage = nil
    }
    
    public var placeholderImage:BitmapImage {
        return BitmapImageUtility.image(named:"ImagePlaceholder")!
    }

    private var cachedImageLoader: ImageLoaderProtocol?
    
    open class func isBakedImage(at url: URL) -> Bool {
        let isBakedImage = Image.bakedImageFileExtensions.contains(url.pathExtension.lowercased())
        return isBakedImage
    }
    
    open class func isRAWImage(at url: URL) -> Bool {
        let isRAW = Image.RAWImageFileExtensions.contains(url.pathExtension.lowercased())
        return isRAW
    }
    
    open class func isImage(at url: URL) -> Bool {
        let isImage = isBakedImage(at: url) || isRAWImage(at: url)
        return isImage
    }

    public func clearCachedResources() {
        self.cachedImageLoader = nil
        self.fullImage = nil
        self.thumbnailImage = nil
        self.fileModificationTimestamp = nil
    }
    
    open var imageLoader: ImageLoaderProtocol?
    {
        if let loader = cachedImageLoader {
            return loader
        }
        
        guard let url = self.URL else {
            return nil
        }
        
        if Image.isRAWImage(at: url) {
            cachedImageLoader = Image.defaultImageLoaderType.init(imageURL: url, thumbnailScheme: .fullImageWhenTooSmallThumbnail)
        } else if Image.isBakedImage(at: url) {
            cachedImageLoader = Image.defaultImageLoaderType.init(imageURL: url, thumbnailScheme: .fullImageWhenTooSmallThumbnail)
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

    public func fetchMetadata(_ store: Bool = true) throws -> ImageMetadata
    {
        // Previously the failure to have an image loader would silently cause a failure.
        // Here we create a temporary image loader for the purposes of metadata fetching,
        // if the image loader passed in as a property is not set.
        // This is necessary for at least the case where fetchMetadata is called with
        // Image is initialized with its init(URL: Foundation.URL) initializer.
        let loader = try { () throws -> ImageLoaderProtocol in
            if let loader = self.imageLoader {
                return loader
            }
            
            guard let URL = self.URL else {
                throw Error.noURL
            }
            
            let loader = Image.defaultImageLoaderType.init(imageURL: URL, thumbnailScheme: .never)
            return loader
        }()
        
        let mdata = try loader.loadImageMetadata()
        if store {
            self.metadata = mdata
        }
        
        return mdata
    }
    
    private var fileModificationTimestamp: Date?
    public var fileTimestamp: Date? {
        if let fileModificationTimestamp = fileModificationTimestamp {
            return fileModificationTimestamp
        }
        
        guard let url = self.URL else {
            return nil
        }
        
        do {
            if let fileTimestamp = try FileManager.default.attributesOfFileSystem(forPath: url.path)[.modificationDate] as? Date {
                fileModificationTimestamp = fileTimestamp
                return fileModificationTimestamp
            }
        }
        catch {
            print("ERROR! Failed to read attributes of image file at path \(url.path)")
        }
        
        return nil
    }
    
    /// Return the metadata based file timestamp, and fall backs to file modification date 
    /// if reading metadata (and therefore the timestamp from the metadata) failed.
    /// Also falls back to file modification date if metadata doesn't contain the timestamp.
    public var approximateTimestamp: Date? {
        if let metadata = metadata {
            return metadata.timestamp ?? self.fileTimestamp
        }
        
        do {
            let metadata = try self.fetchMetadata(true)
            return metadata.timestamp ?? self.fileTimestamp
        }
        catch {
            print("ERROR! Failed to read image metadata for \(self)")
        }
        
        return nil
    }
    
    public func fetchThumbnail(presentedHeight: CGFloat? = nil,
                               force: Bool = false,
                               store: Bool = true,
                               scaleFactor:CGFloat = 2.0) throws -> BitmapImage
    {
        if !force, let thumb = self.thumbnailImage {
            return thumb
        }
        
        guard let loader = self.imageLoader else {
            throw Error.noLoader(self)
        }
        
        guard self.URL != nil else {
            throw Error.urlMissing
        }
        
        let maxDim = presentedHeight != nil ? CGSize(constrainHeight: presentedHeight! * scaleFactor) : nil

        let (thumbnailImage, imgMetadata) = try loader.loadThumbnailImage(maximumPixelDimensions: maxDim)
        
        if self.metadata == nil {
            self.metadata = imgMetadata
        }
        
        if store {
            self.thumbnailImage = thumbnailImage
        }
        
        return thumbnailImage
    }
    
    public func fetchFullSizeImage(presentedHeight: CGFloat? = nil,
                                   store: Bool = false,
                                   scaleFactor:CGFloat = 2.0) throws -> BitmapImage
    {
        guard self.URL != nil else {
            throw Error.urlMissing
        }
        
        let maxDimensions:CGSize? = {
            if let presentedHeight = presentedHeight {
                return CGSize(constrainHeight: presentedHeight * scaleFactor)
            }
            
            return nil
        }()
        
        var options = FullSizedImageLoadingOptions()
        options.maximumPixelDimensions = maxDimensions
        
        guard let loader = self.imageLoader else {
            throw Error.noLoader(self)
        }
        
        let image: BitmapImage, metadata: ImageMetadata
        do {
            // looks ugly but I couldn't find a neater way to destructure into existing local variables.
            let (img, mdata) = try loader.loadFullSizeImage(options:options)
            image = img
            metadata = mdata
        }
        catch {
            throw Error.loadingFailed(underlyingError: error)
        }
        
        if self.metadata == nil {
            self.metadata = metadata
        }
        
        if store {
            self.fullImage = image
        }
        
        return image
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
