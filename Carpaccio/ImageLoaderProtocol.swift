//
//  ImageLoading.swift
//  Carpaccio
//
//  Created by Markus Piipari on 27/07/16.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Foundation
import QuartzCore

public typealias ImageMetadataHandler = (_ metadata: ImageMetadata) -> Void

public typealias PresentableImageHandler = (_ image: BitmapImage, _ metadata: ImageMetadata) -> Void

public typealias ImageLoadingErrorHandler = (_ error: RAWImageLoaderError) -> Void

public struct FullSizedImageLoadingOptions {
    var maximumPixelDimensions:CGSize?
    var allowDraftMode = true
    var noiseReductionAmount = 0.5
    var colorNoiseReductionAmount = 1.0
    var noiseReductionSharpnessAmount = 0.5
    var noiseReductionContrastAmount = 0.5
    var boostShadowAmount = 1.0
    var enableVendorLensCorrection = true
}

public protocol ImageLoaderProtocol
{
    var imageURL: URL { get }
    var imageMetadata: ImageMetadata? { get }
    
    /** *If*, in addition to `imageURL`, full image image data happens to have been copied into a disk cache location, a direct URL pointing to that location. */
    var cachedImageURL: URL? { get }
    
    /** Retrieve metadata about this loader's image, to be called before loading actual image data. */
    func loadImageMetadata(_ handler: ImageMetadataHandler, errorHandler: ImageLoadingErrorHandler)
    
    /** Load thumbnail image. */
    func loadThumbnailImage(maximumPixelDimensions maxPixelSize: CGSize?,
                            handler: PresentableImageHandler,
                            errorHandler: ImageLoadingErrorHandler)
    
    /** Load full-size image. */
    func loadFullSizeImage(options: FullSizedImageLoadingOptions,
                           handler: PresentableImageHandler,
                           errorHandler: ImageLoadingErrorHandler)
}
