//
//  Image.swift
//  Trimmer
//
//  Created by Matias Piipari on 07/05/2016.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Foundation
import QuartzCore
import CoreImage

/**

 This enumeration indicates the current stage of loading an image's metadata. The values
 can be used by a client to determine whether a particular image should be completely
 omitted, or if an error indication should be communicated to the user.

 */
public enum ImageMetadataState {
    /** Metadata has not yet been loaded. */
    case initialized

    /** Metadata is currently being loaded. */
    case loading

    /** Loading image metadata has succesfully completed. */
    case completed

    /** Loading image metadata failed with an error. */
    case failed
}

open class Image: Equatable, Hashable, CustomStringConvertible {
    public enum Error: Swift.Error, LocalizedError {
        case noLoader(Image)
        case noFileExtension // FIXME: lift this restriction.
        case urlMissing
        case locationNotEnumerable(URL)
        case loadingFailed(underlyingError: Swift.Error)
        case noThumbnail(Image)
        case noHistogram(Image)
        case noMetadata
        case sourceHasNoImages
        case failedToDecodeImage
        case invalidImageSize
        case nativeSizeMissing
        case invalidNativeOrientation
        
        public var errorDescription: String? {
            switch self {
            case .noLoader:
                return "Operation failed because no loader is available for image"
            case .noFileExtension:
                return "Operation failed because image lacks a file extension"
            case .urlMissing:
                return "Operation failed because image has no URL"
            case .locationNotEnumerable(let URL):
                return "Operation failed because location at \(URL) is not possible to read from."
            case .loadingFailed(let underlyingError):
                return "Loading failed because of an underlying error: \(underlyingError)"
            case .noThumbnail:
                return "No thumbnail for image"
            case .noHistogram(let img):
                return "Operation failed because no histogram is available for image \(img)"
            case .noMetadata:
                return "Operation failed because there is no metadata for image"
            case .sourceHasNoImages:
                return "Operation failed because image has no sources for image data"
            case .failedToDecodeImage:
                return "Failed to decode image"
            case .invalidImageSize:
                return "Operation failed because an invalid or missing dimension was provided for its height of width"
            case .nativeSizeMissing:
                return "Native size array representation is missing from JSON representation, or is of unexpected dimensions (expecting 2, for width and height)"
            case .invalidNativeOrientation:
                return "Invalid native orientation"
            }
        }
    }
    
    public let name: String

    public var size: CGSize {
        guard let size = self.metadata?.size else {
            return CGSize.zero
        }
        return size
    }
    
    public private(set) var URL: Foundation.URL?

    public func updateURL(_ url: Foundation.URL) {
        self.URL = url
    }
    
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
    
    public typealias MetadataHandler = (_ metadata: ImageMetadata) -> Void
    public typealias ErrorHandler = (_ error: Image.Error) -> Void
    public typealias DistanceFunction = (_ a:Image, _ b:Image)-> Double
    
    /// Set the value for this to alter the type of object used by default for image and metadata loading.
    internal static var defaultImageLoaderType: URLBackedImageLoaderProtocol.Type = ImageLoader.self
    
    public init(image: BitmapImage, imageLoader: ImageLoaderProtocol) {
        self.cachedImageLoader = imageLoader
        self.URL = imageLoader.imageURL
        self.name = image.nameString ?? "Untitled"
    }
    
    public init(URL: Foundation.URL, imageLoader: ImageLoaderProtocol? = nil) {
        self.URL = URL
        self.cachedImageLoader = imageLoader
        self.name = URL.lastPathComponent
    }
    
    private var cachedImageLoader: ImageLoaderProtocol?
    
    open class func isBakedImage(at url: URL) -> Bool {
        let isBakedImage = Image.bakedImageFileExtensions.contains(url.pathExtension.lowercased())
        return isBakedImage
    }
    
    /// Determine if this `Image` represents an image file stored in a baked, non-RAW format.
    open var isBaked: Bool {
        guard let pathExtension = URL?.pathExtension else {
            return false
        }
        return Image.bakedImageFileExtensions.contains(pathExtension.lowercased())
    }

    open class func isRAWImage(at url: URL) -> Bool {
        let isRAW = Image.RAWImageFileExtensions.contains(url.pathExtension.lowercased())
        return isRAW
    }

    /// Determine if this `Image` represents an image file stored in a RAW format.
    open var isRAW: Bool {
        guard let pathExtension = URL?.pathExtension else {
            return false
        }
        return Image.RAWImageFileExtensions.contains(pathExtension.lowercased())
    }
    
    open class func isImage(at url: URL) -> Bool {
        let isImage = isBakedImage(at: url) || isRAWImage(at: url)
        return isImage
    }

    public func clearCachedResources() {
        self.cachedImageLoader = nil
        self.fileModificationTimestamp = nil
    }
    
    //
    // Return an image loader for this image. If one has previously been created, that matches the
    // requested color space, a cached instance is returned.
    //
    // @param `colorSpace` color space to convert thumbnail and full-sized image data into. If `nil`,
    //         color space is assumed to not matter, and no conversion will not be performed. Has no
    //         effect for fetching image metadata.
    //
    open func imageLoader() -> ImageLoaderProtocol? {
        if let cachedLoader = cachedImageLoader {
            return cachedLoader
        }
        guard let url = self.URL else {
            return nil
        }
        cachedImageLoader = Image.defaultImageLoaderType.init(imageURL: url, thumbnailScheme: .decodeFullImageIfEmbeddedThumbnailTooSmall)
        return cachedImageLoader
    }
    
    /**
     
     Metadata for this image, which, when succesfully loaded, at minimum will contain valid width, height and orientation values.
     
     Note that this property will be `nil` if metadata has not yet been loaded, or if loading image metadata has previously failed.
     Code depending on the details of that should consult `imageLoader.imageMetadataState` for the current state of affairs.

     */
    public private(set) var metadata: ImageMetadata?

    public var metadataState: ImageMetadataState {
        return imageLoader()?.imageMetadataState ?? .initialized
    }
    
    public func fetchMetadata() throws -> ImageMetadata {
        guard let loader = imageLoader() else {
            throw Error.noLoader(self)
        }
        let metadata = try loader.loadImageMetadata()
        self.metadata = metadata
        return metadata
    }

    public func updateMetadata(_ metadata: ImageMetadata) {
        self.metadata = metadata
        self.imageLoader()?.updateCachedMetadata(metadata)
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
            let metadata = try self.fetchMetadata()
            return metadata.timestamp ?? self.fileTimestamp
        } catch {
          print("ERROR! Failed to read image metadata for \(self.URL?.path ?? self.name): \(error.localizedDescription)")
        }
        
        return nil
    }
    
    public func fetchThumbnail(presentedHeight: CGFloat? = nil,
                               colorSpace: CGColorSpace?,
                               cancelled: CancellationChecker?) throws -> BitmapImage
    {
        guard let loader = imageLoader() else {
            throw Error.noLoader(self)
        }
        
        guard self.URL != nil else {
            throw Error.urlMissing
        }
        
        let maxDimensions = CGSize(constrainHeight: presentedHeight ?? CGFloat.unconstrained)
        let (thumbnailImage, metadata) = try loader.loadBitmapImage(maximumPixelDimensions: maxDimensions, colorSpace: colorSpace, allowCropping: true, cancelled: cancelled)
        
        if self.metadata == nil {
            self.metadata = metadata
        }

        return thumbnailImage
    }

    public func fetchEditableImage(
        presentedHeight: CGFloat? = nil,
        scaleFactor: CGFloat = 2.0,
        colorSpace: CGColorSpace?,
        cancelled: CancellationChecker?) throws -> CIImage
    {
        guard self.URL != nil else {
            throw Error.urlMissing
        }
        guard let loader = imageLoader() else {
            throw Error.noLoader(self)
        }

        let maxDimensions: CGSize? = {
            if let presentedHeight = presentedHeight {
                return CGSize(constrainHeight: presentedHeight * scaleFactor)
            }
            return nil
        }()

        let options = ImageLoadingOptions(maximumPixelDimensions: maxDimensions)

        let (ciImage, metadata): (CIImage, ImageMetadata) = try {
            do {
                return try loader.loadCIImage(options: options, cancelled: cancelled)
            } catch {
                throw Error.loadingFailed(underlyingError: error)
            }
        }()

        if self.metadata == nil {
            self.metadata = metadata
        }

        return ciImage
    }

    public static var imageFileExtensions: Set<String> = {
        var extensions = Image.RAWImageFileExtensions
        extensions.formUnion(Image.bakedImageFileExtensions)
        return extensions
    }()
    
    public static var RAWImageFileExtensions: Set<String> = {
        return Set([
            "3fr", // Hasselblad 3F RAW Image https://fileinfo.com/extension/3fr
            "arw", // Sony Digital Camera Image https://fileinfo.com/extension/arw
            "cr2", // Canon Raw Image File https://fileinfo.com/extension/cr2
            "crw", // Canon Raw CIFF Image File https://fileinfo.com/extension/crw
            "dcr", // Kodak https://fileinfo.com/extension/dcr
            "dng", // Adobe Digital Negative Image https://fileinfo.com/extension/dng
            "erf", // Epson RAW File https://fileinfo.com/extension/erf
            "fff", // Hasselblad RAW Image https://fileinfo.com/extension/fff
            "gpr", // GenePix Results File https://fileinfo.com/extension/gpr
            "iiq", // Phase One RAW Image https://fileinfo.com/extension/iiq
            "kdc", // Kodak DC120 digital camera RAW image https://www.file-extensions.org/kdc-file-extension
            "mdc", // Minolta RD175 image https://www.file-extensions.org/mdc-file-extension
            "mef", // Mamiya RAW Image https://fileinfo.com/extension/mef
            "mos", // Leaf Camera RAW File https://fileinfo.com/extension/mos
            "mrw", // Minolta Raw Image File https://fileinfo.com/extension/mrw
            "nef", // Nikon Electronic Format RAW Image https://fileinfo.com/extension/nef
            "nrw", // Nikon Raw Image File https://fileinfo.com/extension/nrw
            "orf", // Olympus RAW File https://fileinfo.com/extension/orf
            "pef", // Pentax Electronic File https://fileinfo.com/extension/pef
            "raf", // Fuji RAW Image File https://fileinfo.com/extension/raf
            "raw", // Raw Image Data File (Panasonic, Leica, Casio) https://fileinfo.com/extension/raw
            "rw2", // Panasonic RAW Image https://fileinfo.com/extension/rw2
            "rwl", // Leica RAW Image https://fileinfo.com/extension/rwl
            "sr2", // Sony RAW Image https://fileinfo.com/extension/sr2
            "srf", // Garmin vehicle image (!) https://www.file-extensions.org/srf-file-extension
            "srw", // Samsung RAW Image https://fileinfo.com/extension/srw
            "x3f"  // SIGMA X3F Camera RAW File https://fileinfo.com/extension/x3f
        ])
    }()

    public static var bakedImageFileExtensions: Set<String> = {
        return Set(["jpg", "jpeg", "png", "tiff", "tif", "gif", "heic", "heif"])
    }()

    public var description: String {
        return "(name: \(self.name), URL: \(self.URL?.absoluteString ?? "(unknown)"))"
    }

    // MARK: - Equatable & Hashable

    // Note: as long as we have a mutable, optional URL property, we will be using a private, transient
    // UUID for equality and hashing. This will be refactored in:
    //   https://gitlab.com/sashimiapp-public/Carpaccio/-/issues/12

    private lazy var identity = UUID()

    public static func == (lhs:Image, rhs:Image) -> Bool {
        return lhs.identity == rhs.identity
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(identity)
    }
}
