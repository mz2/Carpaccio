//
//  CIImage+Extensions.swift
//  Carpaccio-OSX
//
//  Created by Markus on 27.6.2020.
//  Copyright © 2020 Matias Piipari & Co. All rights reserved.
//

import Foundation
import CoreImage

public extension CIImage {
    static func loadCIImage(from url: URL, imageMetadata: ImageMetadata?, options: ImageLoadingOptions) throws -> CIImage {
        guard let rawFilter = CIFilter(imageURL: url, options: nil) else {
            throw ImageLoadingError.failedToInitializeDecoder(URL: url, message: "Failed to load full-size RAW image at \(url.path)")
        }

        // Determine scale to load image at
        let scale: Double

        if let maximumSize = options.maximumPixelDimensions,
           let imageSize = imageMetadata?.size,
           imageSize.width >= 1.0,
           imageSize.height >= 1.0
        {
            let widthScale = Double(maximumSize.width) / Double(imageSize.width)
            let heightScale = Double(maximumSize.height) / Double(imageSize.height)
            let candidate = min(widthScale, heightScale)
            if candidate < 1.0 {
                scale = candidate
            } else {
                // We won't scale up
                scale = 1.0
            }
        } else {
            // Load image as-is
            scale = 1.0
        }

        // Configure RAW filter
        rawFilter.setDefaults()

        rawFilter.setValue(scale, forKey: CIRAWFilterOption.scaleFactor.rawValue)

        // Note: having draft mode on appears to be crucial to performance, with a difference
        // of 0.3s vs. 2.5s per image on a late 2015 iMac 5K, for instance. The quality is still
        // quite excellent for displaying scaled-down presentations in a collection view,
        // subjectively better than what you get from LibRAW with the half-size option.
        rawFilter.setValue(options.allowDraftMode, forKey: CIRAWFilterOption.allowDraftMode.rawValue)

        if let value = options.baselineExposure {
            rawFilter.setValue(value, forKey: CIRAWFilterOption.baselineExposure.rawValue)
        }

        rawFilter.setValue(options.noiseReductionAmount, forKey: CIRAWFilterOption.noiseReductionAmount.rawValue)
        rawFilter.setValue(options.colorNoiseReductionAmount, forKey: CIRAWFilterOption.colorNoiseReductionAmount.rawValue)
        rawFilter.setValue(options.noiseReductionSharpnessAmount, forKey: CIRAWFilterOption.noiseReductionSharpnessAmount.rawValue)
        rawFilter.setValue(options.noiseReductionContrastAmount, forKey: CIRAWFilterOption.noiseReductionContrastAmount.rawValue)
        rawFilter.setValue(options.boostShadowAmount, forKey: CIRAWFilterOption.boostShadowAmount.rawValue)
        rawFilter.setValue(options.enableVendorLensCorrection, forKey: CIRAWFilterOption.enableVendorLensCorrection.rawValue)

        // Preserve pixel values beyond 0.0 … 1.0, which wide colour images will have
        rawFilter.setValue(true, forKey: CIRAWFilterOption.ciInputEnableEDRModeKey.rawValue)

        guard let rawImage = rawFilter.outputImage else {
            throw ImageLoadingError.failedToDecode(URL: url, message: "Failed to decode image at \(url.path)")
        }

        return rawImage
    }

    func cgImage(using outputColorSpace: CGColorSpace? = nil) throws -> CGImage {
        let colorSpace = outputColorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
        let context = ImageBakery.ciContext(for: colorSpace)

        //
        // Pixel format and color space set as discussed around 21:50 in:
        //
        //   https://developer.apple.com/videos/play/wwdc2016/505/
        //
        // The `deferred: false` argument is important, to ensure significant rendering work will not
        // be performed later _at drawing time_ on the main thread.
        //
        guard let cgImage = context.createCGImage(self, from: extent, format: CIFormat.RGBAh, colorSpace: colorSpace, deferred: false) else {
            throw ImageLoadingError.failedToCreateCGImage
        }
        return cgImage
    }

    func bitmapImage(using colorSpace: CGColorSpace? = nil) throws -> BitmapImage {
        let cgImage = try self.cgImage(using: colorSpace)
        return BitmapImageUtility.image(cgImage: cgImage, size: CGSize.zero)
    }

}

fileprivate struct ImageBakery {
    private static var ciContextsByOutputColorSpace = [CGColorSpace: CIContext]()
    private static let ciContextQueue = DispatchQueue(label: "com.sashimiapp.ImageBakeryQueue")

    fileprivate static func ciContext(for colorSpace: CGColorSpace) -> CIContext {
        return ciContextQueue.sync {
            if let context = ciContextsByOutputColorSpace[colorSpace] {
                return context
            }

            let context = CIContext(options: [
                CIContextOption.outputColorSpace: colorSpace,

                // Caching does provide a minor speed boost without ballooning memory use, so let's have it on
                CIContextOption.cacheIntermediates: true,

                // Low GPU priority would make sense for a background operation that isn't performance-critical,
                // but we are interested in disk-to-display performance
                CIContextOption.priorityRequestLow: false,

                // Definitely no CPU rendering, please
                CIContextOption.useSoftwareRenderer: false,

                // This option is undocumented, possibly only effective on iOS? Sounds more like
                // allowLowPerformance, though, so turn it off
                CIContextOption.allowLowPower: false,

                // We are likely to encounter images with wider colour than sRGB
                CIContextOption.workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB)!,

                // This is the Apple recommendation, see cgImage(using:) above
                CIContextOption.workingFormat: CIFormat.RGBAh,
            ])

            ciContextsByOutputColorSpace[colorSpace] = context
            return context
        }
    }
}

extension CGColorSpace: Hashable {
}
