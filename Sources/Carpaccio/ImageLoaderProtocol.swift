//
//  ImageLoading.swift
//  Carpaccio
//
//  Created by Markus Piipari on 27/07/16.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Foundation
import QuartzCore
import CoreImage

public typealias ImageMetadataHandler = (_ metadata: ImageMetadata) -> Void

public typealias PresentableImageHandler = (_ image: BitmapImage, _ metadata: ImageMetadata) -> Void

public enum ImageLoadingError: Swift.Error, LocalizedError {
    case failedToExtractImageMetadata(URL: URL, message: String)
    case failedToLoadThumbnailImage(URL: URL, message: String)
    case noImageSource(URL: URL, message: String)
    case failedToInitializeDecoder(URL: URL, message: String)
    case failedToDecode(URL: URL, message: String)
    case failedToLoadDecodedImage(URL: URL, message: String)
    case loadingSetToNever(URL: URL, message: String)
    case expectingMetadata(URL: URL, message: String)
    case failedToConvertColorSpace(url: URL, message: String)
    case failedToCreateCGImage
    case cancelled(url: URL, message: String)

    public var errorCode: Int {
        switch self {
        case .failedToExtractImageMetadata: return 1
        case .failedToLoadThumbnailImage: return 2
        case .noImageSource: return 4
        case .failedToInitializeDecoder: return 5
        case .failedToDecode: return 6
        case .failedToLoadDecodedImage: return 7
        case .loadingSetToNever: return 8
        case .expectingMetadata: return 9
        case .failedToConvertColorSpace: return 10
        case .failedToCreateCGImage: return 11
        case .cancelled: return 12
        }
    }

    public var errorDescription: String? {
        switch self {
        case .failedToExtractImageMetadata(let url, let msg):
            return "Failed to extract image metadata for file at URL \(url): \(msg)"
        case .failedToLoadThumbnailImage(let url, let msg):
            return "Failed to load image thumbnail at URL \(url): \(msg)"
        case .noImageSource(let url, let msg):
            return "No sources of image data present in file at URL \(url): \(msg)"
        case .failedToInitializeDecoder(let url, let msg):
            return "Failed to initialize decoder for image file at URL \(url): \(msg)"
        case .failedToDecode(let url, let msg):
            return "Failed to decode image from file at URL \(url): \(msg)"
        case .failedToLoadDecodedImage(let url, let msg):
            return "Failed to load decoded image from image file at URL \(url): \(msg)"
        case .loadingSetToNever(let url, let msg):
            return "Image at \(url) set to be never to be loaded: \(msg)"
        case .expectingMetadata(let url, let msg):
            return "Failing to receive expected metadata for file at URL \(url): \(msg)"
        case .failedToConvertColorSpace(let url, let msg):
            return "Failed to convert image color space for file at URL \(url): \(msg)"
        case .failedToCreateCGImage:
            return "Failed to create CGImage from CIImage"
        case .cancelled(let url, let msg):
            return "Operation for image at URL \(url) was cancelled: \(msg)"
        }
    }

    public var failureReason: String? {
        switch self {
        case .failedToExtractImageMetadata(_, let msg):
            return msg
        case .failedToLoadThumbnailImage(_, let msg):
            return msg
        case .noImageSource(_, let msg):
            return msg
        case .failedToInitializeDecoder(_, let msg):
            return msg
        case .failedToDecode(_, let msg):
            return msg
        case .failedToLoadDecodedImage(_, let msg):
            return msg
        case .loadingSetToNever(_, let msg):
            return msg
        case .expectingMetadata(_, let msg):
            return msg
        case .failedToConvertColorSpace(_, let msg):
            return msg
        case .failedToCreateCGImage:
            return nil
        case .cancelled(_, let msg):
            return msg
        }
    }

    public var recoverySuggestion: String? {
        return "Please check that the file in question exists, is a valid image and that you have permissions to access it."
    }

    public var helpAnchor: String? {
        return "Please check that the file in question exists, is a valid image that you have permissions to access it. For example, check that it opens in another image reading application."
    }
}

public typealias ImageLoadingErrorHandler = (_ error: ImageLoadingError) -> Void

/**
 Closure type for determining if a potentially lengthy thumbnail image loading step should
 not be performed after all, due to the image not being needed anymore.
 */
public typealias CancellationChecker = () -> Bool

public protocol ImageLoaderProtocol {
    var imageURL: URL { get }
    var imageMetadataState: ImageMetadataState { get }

    /**
     Load image metadata synchronously. After a first succesful load, an implementation may choose to return a cached
     copy on later calls.
     */
    func loadImageMetadata() throws -> ImageMetadata

    /**
     If metadata for this loader's image has previously been loaded & stored in a cache, reuse that cached metadata,
     and update `imageMetadataState` to `.completed`.
     */
    func updateCachedMetadata(_ metadata: ImageMetadata)
    
    /**
     Load a `BitmapImage` representation of this loader's associated image, optionally:
     - Scaled down to a maximum pixel size
     - Cropped to the proportions of the image's metadata (to remove letterboxing by some cameras' thumbnails)
     */
    func loadBitmapImage(maximumPixelDimensions maxPixelSize: CGSize?, colorSpace: CGColorSpace?, allowCropping: Bool, cancelled: CancellationChecker?) throws -> (BitmapImage, ImageMetadata)
    
    /**
     Load a `CGImage` representation of this loader's associated image, optionally scaled down to a maximum pixel
     size and cropped to the proportions of the image's metadata.
     */
    func loadCGImage(maximumPixelDimensions maximumSize: CGSize?, colorSpace: CGColorSpace?, allowCropping: Bool, cancelled: CancellationChecker?) throws -> (CGImage, ImageMetadata)

    /**
     Load a `CIImage` representation of this loader's associated image, with maximum pixel dimensions and RAW decoding
     options provided via an `ImageLoadingOptions` argument.
     */
    func loadCIImage(options: ImageLoadingOptions, cancelled: CancellationChecker?) throws -> (CIImage, ImageMetadata)
}

public protocol URLBackedImageLoaderProtocol: ImageLoaderProtocol {
    init(imageURL: URL, thumbnailScheme: ImageLoader.ThumbnailScheme)
    init(imageLoader: ImageLoaderProtocol, thumbnailScheme: ImageLoader.ThumbnailScheme)
}

public extension ImageLoaderProtocol {
    /**
     Convenience func to be called by image loader implementations themselves, to check if a particular
     thumbnail or full size image loading operation has been cancelled.
     @throws An `ImageLoadingError.cancelled` error if cancellation checker returns `true`.
     */
    func stopIfCancelled(_ checker: CancellationChecker?, _ message: String) throws {
        if let checker = checker, checker() {
            throw ImageLoadingError.cancelled(url: self.imageURL, message: message)
        }
    }
}
