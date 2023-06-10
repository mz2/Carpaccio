//
//  ImageMetadata.swift
//  Carpaccio
//
//  Created by Markus Piipari on 25/07/16.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//


import Foundation
import QuartzCore
import ImageIO

///
/// Model select parts of the metadata of an image, read either from an image file's embedded metadata, or restored from a
/// `Codable` representation.
///
/// For extracting metadata from images, this implementation uses Apple's Image I/O API and its defined keys for the EXIF, TIFF
/// and IPTC metadata standards, with some custom logic for making the best educated guess for crucial bits like native size,
/// orientation and creation date & time.
///
/// ## See also
///
/// [IPTC Photo Metadata specification](https://iptc.org/std/photometadata/specification/IPTC-PhotoMetadata)
///
public struct ImageMetadata: Codable, Equatable {
    
    // MARK: Required metadata

    /** Width and height of the image. */
    public let nativeSize: CGSize
    
    /** Orientation of the image's pixel data. Default is `.up`. */
    public let nativeOrientation: ImageOrientation
    
    // MARK: Optional metadata

    public let cameraMaker: String?
    public let cameraModel: String?
    
    public let lensMaker: String?
    public let lensModel: String?
    
    public let flashMode: FlashMode?
    public let meteringMode: MeteringMode?
    public let whiteBalance: WhiteBalance?

    public let colorSpaceName: String?
    
    /// In common photographer parlance, this would be "aperture": f/2.8 etc.
    public let fNumber: Double?
    
    public let focalLength: Double?
    public let focalLength35mmEquivalent: Double?
    public let iso: Double?
    public let shutterSpeed: TimeInterval?
    public let exposureCompensation: Double?
        
    /**
     
     Date & time best suitable to be interpreted as the image's original creation timestamp.
     
     Some notes:
     
     - The value is usually extracted from EXIF or TIFF metadata (in that order), which both appear
     to save it as a string with one second resolution, without time zone information.
     
     - This means the value alone is suitable only for coarse sorting, and typically needs combining
     with the image filename saved by the camera, which usually contains a numerical sequence. For
     example, you will encounter images shot in burst mode that will have the same timestamp.
     
     - As of this writing (2016-08-25), it is unclear if this limitation is fundamentally about
     cameras, the EXIF/TIFF metadata specs or (most unlikely) the Core Graphics implementation.
     However, neither Lightroom, Capture One, FastRawViewer nor RawRightAway display any more
     detail or timezone-awareness, so it seems like this needs to be accepted as just the way it
     is.

     */
    public let timestamp: Date?

    /// Description of image contents, mapping to the value of the `kCGImagePropertyIPTCCaptionAbstract` key in IPTC metadata.
    public let description: String?
    
    /// Summary of image contents, mapping to the value of the `kCGImagePropertyIPTCHeadline` key in IPTC metadata.
    public let summary: String?

    ///
    /// Star rating of the image, mapping to the value of `kCGImagePropertyIPTCStarRating` in IPTC metadata.
    ///
    /// The intended value range is 0 ... 5, inclusive. The
    /// [IPTC specification](https://iptc.org/std/photometadata/specification/IPTC-PhotoMetadata#image-rating) says:
    ///
    /// _The value shall be -1 or in the range 0..5. -1 indicates "rejected" and 0 "unrated". If an explicit value is missing
    /// the implicit default value is 0 should be assumed._
    ///
    public let rating: Int?
    
    /// Keywords/tags relevant to image contents, mapping to the value of the `kCGImagePropertyIPTCKeywords` key in IPTC metadata.
    public let keywords: [String]?

    // Derived properties
    public var colorSpace: CGColorSpace? {
        guard let name = colorSpaceName else {
            return nil
        }
        return CGColorSpace(name: name as CFString)
    }

    // Codable
    public enum CodingKeys: String, CodingKey {
        case nativeSize = "native-size"
        case nativeOrientation = "native-orientation"
        case cameraMaker = "camera-maker"
        case cameraModel = "camera-model"
        case lensMaker = "lens-maker"
        case lensModel = "lens-model"
        case colorSpaceName = "color-space"
        case fNumber = "f-number"
        case focalLength = "focal-length"
        case focalLength35mmEquivalent = "focal-length-35mm-equivalent"
        case iso
        case shutterSpeed = "shutter-speed"
        case exposureCompensation = "exposure-compensation"
        case timestamp
        case flashMode = "flash-mode"
        case meteringMode = "metering-mode"
        case whiteBalance = "white-balance"
        case summary = "summary"
        case description = "description"
        case rating = "rating"
        case keywords = "keywords"

        var dictionaryRepresentationKey: String {
            switch self {
            case .nativeSize:
                return "nativeSize"
            case .nativeOrientation:
                return "nativeOrientation"
            case .cameraMaker:
                return "cameraMaker"
            case .cameraModel:
                return "cameraModel"
            case .lensMaker:
                return "lensMaker"
            case .lensModel:
                return "lensModel"
            case .colorSpaceName:
                return "colorSpace"
            case .fNumber:
                return "fNumber"
            case .focalLength:
                return "focalLength"
            case .focalLength35mmEquivalent:
                return "focalLength35mmEquivalent"
            case .iso:
                return "ISO"
            case .shutterSpeed:
                return "shutterSpeed"
            case .exposureCompensation:
                return "exposureCompensation"
            case .timestamp:
                return "timestamp"
            case .flashMode:
                return "flashMode"
            case .meteringMode:
                return "meteringMode"
            case .whiteBalance:
                return "whiteBalance"
            case .description:
                return "description"
            case .summary:
                return "summary"
            case .rating:
                return "rating"
            case .keywords:
                return "keywords"
            }
        }
    }

    // MARK: - Initialisers
    
    public init(
        nativeSize: CGSize,
        nativeOrientation: ImageOrientation = .up,
        colorSpaceName: String? = nil,
        fNumber: Double? = nil,
        focalLength: Double? = nil,
        focalLength35mmEquivalent: Double? = nil,
        iso: Double? = nil,
        shutterSpeed: TimeInterval? = nil,
        exposureCompensation: Double? = nil,
        cameraMaker: String? = nil,
        cameraModel: String? = nil,
        lensMaker: String? = nil,
        lensModel: String? = nil,
        flashMode: FlashMode? = nil,
        meteringMode: MeteringMode? = nil,
        whiteBalance: WhiteBalance? = nil,
        timestamp: Date? = nil,
        description: String? = nil,
        summary: String? = nil,
        rating: Int? = nil,
        keywords: [String]? = nil
    ) {
        self.fNumber = fNumber
        self.cameraMaker = cameraMaker
        self.cameraModel = cameraModel
        
        self.lensMaker = lensMaker
        self.lensModel = lensModel
        
        self.flashMode = flashMode
        self.meteringMode = meteringMode
        self.whiteBalance = whiteBalance

        self.colorSpaceName = colorSpaceName

        self.focalLength = focalLength
        self.focalLength35mmEquivalent = focalLength35mmEquivalent
        self.iso = iso
        self.nativeOrientation = nativeOrientation
        self.nativeSize = nativeSize
        self.shutterSpeed = shutterSpeed
        self.exposureCompensation = exposureCompensation
        self.timestamp = timestamp
        
        self.description = description
        self.summary = summary
        self.rating = rating
        self.keywords = keywords
    }

    public static func cgColorSpaceNameForPictureStyleColorSpaceName(_ name: String) -> String? {
        if name == "Adobe RGB" {
            return CGColorSpace.adobeRGB1998 as String
        }
        return nil
    }

    public init(imageSource: ImageIO.CGImageSource) throws {
        guard (CGImageSourceGetCount(imageSource) >= 1) else {
            throw Image.Error.sourceHasNoImages
        }

        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) else {
            throw Image.Error.noMetadata
        }
        
        let properties = NSDictionary(dictionary: imageProperties) as? [String: Any]
        try self.init(cgImagePropertiesDictionary: properties ?? [:], imageSource: imageSource)
    }

    public init(cgImagePropertiesDictionary properties: [AnyHashable: Any], imageSource: ImageIO.CGImageSource? = nil) throws {
        var fNumber: Double? = nil, focalLength: Double? = nil, focalLength35mm: Double? = nil, iso: Double? = nil, shutterSpeed: Double? = nil, exposureCompensation: Double? = nil
        var lensMaker: String? = nil, lensModel: String? = nil
        var flashMode: FlashMode? = nil, meteringMode: MeteringMode? = nil, whiteBalance: WhiteBalance? = nil
        var colorSpaceName: String? = nil
        var width, height, exifWidth, exifHeight: CGFloat?
        var timestamp: Date? = nil
        
        //
        // Get image dimensions. Priority order of finding this out is:
        //
        // 1. Top-level kCGImagePropertyPixelWidth and kCGImagePropertyPixelHeight metadata keys.
        //
        // 2. EXIF dictionary's kCGImagePropertyExifPixelXDimension and kCGImagePropertyExifPixelYDimension metadata keys.
        //
        // 3. If neither is available, or both are, but their values are in conflict, actually opening and examining the image.
        //    (We don't do this always, for every image, because it is measurably slower than examining the metadata.)
        //
        // To be clear, we _have_ observed real-life images where the EXIF dimensions mismatch the top-level metadata, and/or the
        // actual image size. Most annoyingly, this can also vary between macOS and iOS.
        //
        if let pixelWidth = properties[kCGImagePropertyPixelWidth] as? CGFloat,
           let pixelHeight = properties[kCGImagePropertyPixelHeight] as? CGFloat {
            width = pixelWidth
            height = pixelHeight
        }
        
        // Examine EXIF metadata
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            fNumber = (exif[kCGImagePropertyExifFNumber as String] as? NSNumber)?.doubleValue
            colorSpaceName = exif[kCGImagePropertyExifColorSpace as String] as? String
            focalLength = (exif[kCGImagePropertyExifFocalLength as String] as? NSNumber)?.doubleValue
            focalLength35mm = (exif[kCGImagePropertyExifFocalLenIn35mmFilm as String] as? NSNumber)?.doubleValue
            exposureCompensation = (exif[kCGImagePropertyExifExposureBiasValue as String] as? NSNumber)?.doubleValue
            lensMaker = exif[kCGImagePropertyExifLensMake as String] as? String
            lensModel = exif[kCGImagePropertyExifLensModel as String] as? String
            flashMode = FlashMode(flashState: (exif[kCGImagePropertyExifFlash as String] as? NSNumber)?.intValue)
            meteringMode = MeteringMode(meteringMode: (exif[kCGImagePropertyExifMeteringMode as String] as? NSNumber)?.intValue)
            whiteBalance = WhiteBalance(whiteBalance: (exif[kCGImagePropertyExifWhiteBalance as String] as? NSNumber)?.intValue)
            
            if let isoValues = exif[kCGImagePropertyExifISOSpeedRatings as String] {
                let isoArray = NSArray(array: isoValues as! CFArray)
                if isoArray.count > 0 {
                    iso = (isoArray[0] as? NSNumber)?.doubleValue
                }
            }
            
            shutterSpeed = (exif[kCGImagePropertyExifExposureTime as String] as? NSNumber)?.doubleValue
            
            // Take note of width and height, for later deciding whether to use them or the top-level values
            if let pixelXDimension = (exif[kCGImagePropertyExifPixelXDimension as String] as? NSNumber)?.doubleValue,
               let pixelYDimension = (exif[kCGImagePropertyExifPixelYDimension as String] as? NSNumber)?.doubleValue
            {
                exifWidth = CGFloat(pixelXDimension)
                exifHeight = CGFloat(pixelYDimension)
            }
            
            if let originalDateString = (exif[kCGImagePropertyExifDateTimeOriginal as String] as? String) {
                timestamp = ImageMetadata.EXIFDateFormatter.date(from: originalDateString)
            }
        }
        
        // Examine TIFF metadata
        var cameraMaker: String? = nil, cameraModel: String? = nil, orientation: ImageOrientation? = nil
        
        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any]
        {
            cameraMaker = tiff[kCGImagePropertyTIFFMake as String] as? String
            cameraModel = tiff[kCGImagePropertyTIFFModel as String] as? String
            if let tiffOrientation = (tiff[kCGImagePropertyTIFFOrientation as String] as? NSNumber)?.uint32Value {
                orientation = try? ImageOrientation(tiffOrientation: tiffOrientation)
            }
            
            if timestamp == nil, let dateTimeString = (tiff[kCGImagePropertyTIFFDateTime as String] as? String) {
                timestamp = ImageMetadata.EXIFDateFormatter.date(from: dateTimeString)
            }
        }
        
        // Examine IPTC metadata
        var description: String? = nil
        var summary: String? = nil
        var rating: Int? = nil
        var keywords: [String]? = nil
        
        if let iptc = properties[kCGImagePropertyIPTCDictionary as String] as? [String: Any] {
            description = iptc[kCGImagePropertyIPTCCaptionAbstract as String] as? String
            summary = iptc[kCGImagePropertyIPTCHeadline as String] as? String
            rating = iptc[kCGImagePropertyIPTCStarRating as String] as? Int
            if let keywordsArray = iptc[kCGImagePropertyIPTCKeywords as String] as? [String], !keywordsArray.isEmpty {
                keywords = keywordsArray
            }
        }
        
        // Determine color space
        if colorSpaceName == nil {
            if let pictureStyleDictionary = properties["{PictureStyle}"] as? [String: Any],
                let names = pictureStyleDictionary["PictStyleColorSpace"] as? [Any],
                let name = names.first as? String {
                colorSpaceName = ImageMetadata.cgColorSpaceNameForPictureStyleColorSpaceName(name)
            }
        }

        // If image dimensions didn't appear in metadata (as can happen with some RAW files like Nikon NEFs), or top-level and
        // EXIF dimensions are in conflict (observed with some Sony ARW files on iOS), take one more step: open the image, and use
        // its actual dimensions. This thankfully doesn't appear to immediately load image data (and, as a consequence, totally
        // kill performance.)
        let exifDimensionsAvailable = exifWidth != nil && exifHeight != nil

        if let imageSource = imageSource {
            let topLevelDimensionsAvailable = width != nil && height != nil
            let examineImage: Bool

            if !topLevelDimensionsAvailable && !exifDimensionsAvailable {
                // No dimensions available in metadata
                examineImage = true
            } else if topLevelDimensionsAvailable && exifDimensionsAvailable && (width != exifWidth || height != exifHeight) {
                // Top-level and EXIF dimensions are in conflict
                examineImage = true
            } else {
                examineImage = false
            }

            if examineImage {
                let options: CFDictionary = [String(kCGImageSourceShouldCache): false] as NSDictionary as CFDictionary
                guard let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options) else {
                    throw Image.Error.failedToDecodeImage
                }
                width = CGFloat(image.width)
                height = CGFloat(image.height)
            }
        }

        if width == nil && exifDimensionsAvailable {
            // Only EXIF dimensions are available; use them
            width = exifWidth
            height = exifHeight
        }

        guard let validWidth = width, let validHeight = height else {
            throw Image.Error.invalidImageSize
        }

        self.init(
            nativeSize: CGSize(width: validWidth, height: validHeight),
            nativeOrientation: orientation ?? .up,
            colorSpaceName: colorSpaceName,
            fNumber: fNumber,
            focalLength: focalLength,
            focalLength35mmEquivalent: focalLength35mm,
            iso: iso,
            shutterSpeed: shutterSpeed,
            exposureCompensation: exposureCompensation,
            cameraMaker: cameraMaker,
            cameraModel: cameraModel,
            lensMaker: lensMaker,
            lensModel: lensModel,
            flashMode: flashMode,
            meteringMode: meteringMode,
            whiteBalance: whiteBalance,
            timestamp: timestamp,
            description: description,
            summary: summary,
            rating: rating,
            keywords: keywords
        )
    }

    public static func loadImageMetadataIfNeeded(from source: CGImageSource, having inputMetadata: ImageMetadata?) throws -> ImageMetadata {
        if let metadata = inputMetadata {
            return metadata
        }
        return try ImageMetadata(imageSource: source)
    }

    // See ImageMetadata.timestamp for known caveats about EXIF/TIFF
    // date metadata, as interpreted by this date formatter.
    private static let EXIFDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter
    }()

    // MARK: Derived properties
  
    public var size: CGSize {
        if self.nativeOrientation.dimensionsSwapped {
            return CGSize(width: nativeSize.height, height: nativeSize.width)
        }
        return nativeSize
    }

    public enum Shape: String {
        case landscape
        case portrait
        case square

        init(size: CGSize) {
            if size.width > size.height {
                self = .landscape
            } else if size.width < size.height {
                self = .portrait
            } else {
                self = .square
            }
        }
    }

    public var shape: Shape {
        return Shape(size: size)
    }

    public var cleanedUpCameraModel: String? {
        get {
            guard let model = self.cameraModel else {
                return nil
            }

            let cleanModel = model.replacingOccurrences(of: "NIKON", with: "Nikon")
            return cleanModel
        }
    }

    public var humanReadableFNumber: String? {
        guard let f = fNumber, f > 0.0 else {
            return nil
        }

        // Default to showing one decimal place...
        let oneTenthPrecisionfNumber = round(f * 10.0) / 10.0
        let integerAperture = Int(oneTenthPrecisionfNumber)

        // ..but avoid displaying .0
        if oneTenthPrecisionfNumber == Double(integerAperture) {
            return "f/\(integerAperture)"
        }

        return "f/\(oneTenthPrecisionfNumber)"
    }

    public var humanReadableFocalLength: String? {
        guard let f = self.focalLength, f > 0.0 else {
            return nil
        }

        let mm = Int(round(f))
        return "\(mm)mm"
    }

    public var humanReadableFocalLength35mmEquivalent: String? {
        guard let f = self.focalLength35mmEquivalent, f > 0.0 else {
            return nil
        }

        let mm = Int(round(f))
        return "(\(mm)mm)"
    }

    public var humanReadableISO: String? {
        guard let iso = self.iso, iso > 0.0 else {
            return nil
        }

        let integerISO = Int(round(iso))
        return "ISO \(integerISO)"
    }

    public var humanReadableShutterSpeed: String? {
        guard let s = self.shutterSpeed, s > 0.0 else {
            return nil
        }

        if s < 1.0
        {
            let dividend = Int(round(1.0 / s))
            return "1/\(dividend)"
        }

        let oneTenthPrecisionSeconds = round(s * 10.0) / 10.0
        return "\(oneTenthPrecisionSeconds)s"
    }
    
    public var humanReadableFlashMode: String? {
        guard let fm = self.flashMode else {
            return nil
        }
        
        switch (fm) {
            case .unknown:
                return "unknown"
            case .noFlash:
                return "No flash"
            case .fired:
                return "Fired"
            case .firedNotReturned:
                return "Fired, return not detected"
            case .firedReturned:
                return "Fired, return detected"
            case .onNotFired:
                return "On, did not fire"
            case .onFired:
                return "On, fired"
            case .onNotReturned:
                return "On, return not detected"
            case .onReturned:
                return "On, return detected"
            case .offNotFired:
                return "Off, did not fire"
            case .offNotFiredNotReturned:
                return "Off, did not fire, return not detected"
            case .autoNotFired:
                return "Auto, did not fire"
            case .autoFired:
                return "Auto, fired"
            case .autoFiredNotReturned:
                return "Auto, fired, return not detected"
            case .autoFiredReturned:
                return "Auto, fired, return detected"
            case .noFlashFunction:
                return "No flash function"
            case .offNoFlashFunction:
                return "Off, no flash function"
            case .firedRedEye:
                return "Fired, red-eye reduction"
            case .firedRedEyeNotReturned:
                return "Fired, red-eye reduction, return not detected"
            case .firedRedEyeReturned:
                return "Fired, red-eye reduction, return detected"
            case .onRedEye:
                return "On, red-eye reduction"
            case .onRedEyeNotReturned:
                return "On, red-eye reduction, return not detected"
            case .onRedEyeReturned:
                return "On, red-eye reduction, return detected"
            case .offRedEye:
                return "Off, red-eye reduction"
            case .autoNotFiredRedEye:
                return "Auto, did not fire, red-eye reduction"
            case .autoFiredRedEye:
                return "Auto, fired, red-eye reduction"
            case .autoFiredRedEyeNotReturned:
                return "Auto, fired, red-eye reduction, return not detected"
            case .autoFiredRedEyeReturned:
                return "Auto, fired, red-eye reduction, return detected"
        }
    }

    /// Implement a dictionary representation used by some client code implemented before `ImageMetadata`
    /// implemented `Codable`. Therefore the keys are different (CodingKeys.x.dictionaryRepresentationKey
    /// rather than CodingKeys.x.rawValue), plus tow other differences:
    ///   - Native orientation is stored as the numeric CGImageOrientation value, rather than its string equivalent
    ///   - `shape` is included, even though it is a derived property
    public var dictionaryRepresentation: [String: Any] {
        var result: [String: Any] = [String: Any]()

        if let cameraMaker = self.cameraMaker {
          result[CodingKeys.cameraMaker.dictionaryRepresentationKey] = cameraMaker
        }

        if let cameraModel = self.cameraModel {
            result[CodingKeys.cameraModel.dictionaryRepresentationKey] = cameraModel
        }
        
        if let lensMaker = self.lensMaker {
            result[CodingKeys.lensMaker.dictionaryRepresentationKey] = lensMaker
        }
        
        if let lensModel = self.lensModel {
            result[CodingKeys.lensModel.dictionaryRepresentationKey] = lensModel
        }

        if let space = self.colorSpace, let spaceName = space.name {
            result[CodingKeys.colorSpaceName.dictionaryRepresentationKey] = spaceName
        }

        if let fNumber = self.fNumber {
            result[CodingKeys.fNumber.dictionaryRepresentationKey] = fNumber
        }

        if let focalLength = self.focalLength {
            result[CodingKeys.focalLength.dictionaryRepresentationKey] = focalLength
        }

        if let focalLength35mmEquivalent = self.focalLength35mmEquivalent {
            result[CodingKeys.focalLength35mmEquivalent.dictionaryRepresentationKey] = focalLength35mmEquivalent
        }

        if let iso = self.iso {
            result[CodingKeys.iso.dictionaryRepresentationKey] = iso
        }
        
        if let exposureCompensation = self.exposureCompensation {
            result[CodingKeys.exposureCompensation.dictionaryRepresentationKey] = exposureCompensation
        }

        // Note: we store the numeric CGImageOrientation value here, rather than the string equivalent
        result[CodingKeys.nativeOrientation.dictionaryRepresentationKey] = nativeOrientation.cgImageOrientation.rawValue

        result[CodingKeys.nativeSize.dictionaryRepresentationKey] = [nativeSize.width, nativeSize.height]

        // Note: we use a string literal here, because `shape` being a derived property, is not part of
        // the Codable implementation (and hence has not corresponding CodingKeys case)
        result["shape"] = shape.rawValue

        if let shutterSpeed = self.shutterSpeed {
            result[CodingKeys.shutterSpeed.dictionaryRepresentationKey] = shutterSpeed
        }
        
        if let flashMode = self.flashMode {
            result[CodingKeys.flashMode.dictionaryRepresentationKey] = flashMode
        }
        
        if let meteringMode = self.meteringMode {
            result[CodingKeys.meteringMode.dictionaryRepresentationKey] = meteringMode
        }
        
        if let whiteBalance = self.whiteBalance {
            result[CodingKeys.whiteBalance.dictionaryRepresentationKey] = whiteBalance
        }

        if let timestamp = self.timestamp {
            result[CodingKeys.timestamp.dictionaryRepresentationKey] = timestamp.timeIntervalSince1970
        }
        
        if let rating = self.rating {
            result[CodingKeys.rating.dictionaryRepresentationKey] = rating
        }

        return result
    }

    private static var formatters: [DateFormatterStylePair: DateFormatter] = [:]
    private static func timestampFormatter(dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> DateFormatter
    {
        let stylePair = DateFormatterStylePair(dateStyle: dateStyle, timeStyle: timeStyle)

        if let existingFormatter = formatters[stylePair] {
            return existingFormatter
        }

        let f = DateFormatter()
        f.dateStyle = dateStyle
        f.timeStyle = timeStyle

        formatters[stylePair] = f

        return f
    }

    public func humanReadableTimestamp(dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style) -> String {
        if let t = timestamp {
            return ImageMetadata.timestampFormatter(dateStyle: dateStyle,
                                                    timeStyle: timeStyle).string(from: t)
        }
        return ""
    }

    public enum SummaryStyle {
        case short
        case medium
    }

    public func humanReadableSummary(style: SummaryStyle) -> String {
        return "\(style == .medium ? padTail(ofString:self.cleanedUpCameraModel) : "")\(padTail(ofString: self.humanReadableFocalLength))\(padTail(ofString: conditional(string: self.humanReadableFocalLength35mmEquivalent, condition: (self.focalLength35mmEquivalent != self.focalLength))))\(padTail(ofString: self.humanReadableFNumber))\(padTail(ofString: self.humanReadableShutterSpeed))\(padTail(ofString: self.humanReadableISO))"
    }

    public var humanReadableNativeSize: String {
        return "\(Int(self.nativeSize.width))x\(Int(self.nativeSize.height))"
    }
}

public enum ImageOrientation: String, Codable {
    case up = "up"
    case upMirrored = "up-mirrored"
    case down = "down"
    case downMirrored = "down-mirrored"
    case leftMirrored = "left-mirrored"
    case right = "right"
    case rightMirrored = "right-mirrored"
    case left = "left"
    
    public init(cgImageOrientation: CGImagePropertyOrientation) {
        switch cgImageOrientation {
        case .up:
            self = .up
        case .upMirrored:
            self = .upMirrored
        case .down:
            self = .down
        case .downMirrored:
            self = .downMirrored
        case .leftMirrored:
            self = .leftMirrored
        case .right:
            self = .right
        case .rightMirrored:
            self = .rightMirrored
        case .left:
            self = .left
        }
    }

    ///
    /// Initialize image orientation from a raw value contained in a TIFF metadata dictionary, under the
    /// `kCGImagePropertyTIFFOrientation` key.
    ///
    /// The values _should_ map 1:1 to the supported values of the `CGImagePropertyOrientation` enum, but we have seen real-life
    /// images where this is not the case. Hence, this method throws an error if an unsupported raw value is encountered.
    ///
    public init(tiffOrientation: UInt32) throws {
        switch tiffOrientation {
        case CGImagePropertyOrientation.up.rawValue:
            self = .up
        case CGImagePropertyOrientation.upMirrored.rawValue:
            self = .upMirrored
        case CGImagePropertyOrientation.down.rawValue:
            self = .down
        case CGImagePropertyOrientation.downMirrored.rawValue:
            self = .downMirrored
        case CGImagePropertyOrientation.leftMirrored.rawValue:
            self = .leftMirrored
        case CGImagePropertyOrientation.right.rawValue:
            self = .right
        case CGImagePropertyOrientation.rightMirrored.rawValue:
            self = .rightMirrored
        case CGImagePropertyOrientation.left.rawValue:
            self = .left
        default:
            throw Image.Error.invalidNativeOrientation
        }
    }
    
    public var cgImageOrientation: CGImagePropertyOrientation {
        switch self {
        case .up:
            return .up
        case .upMirrored:
            return .upMirrored
        case .down:
            return .down
        case .downMirrored:
            return .downMirrored
        case .leftMirrored:
            return .leftMirrored
        case .right:
            return .right
        case .rightMirrored:
            return .rightMirrored
        case .left:
            return .left
        }
    }

    var dimensionsSwapped: Bool {
        switch self {
        case .left, .right, .leftMirrored, .rightMirrored:
            return true
        default:
            return false
        }
    }
}

public enum FlashMode: String, Codable {
    case unknown = "unknown"
    case noFlash = "no-flash"
    case fired = "fired"
    case firedNotReturned = "fired-not-returned"
    case firedReturned = "fired-returned"
    case onNotFired = "on-not-fired"
    case onFired = "on-fired"
    case onNotReturned = "on-not-returned"
    case onReturned = "on-returned"
    case offNotFired = "off-not-fired"
    case offNotFiredNotReturned = "off-not-fired-not-returned"
    case autoNotFired = "auto-not-fired"
    case autoFired = "auto-fired"
    case autoFiredNotReturned = "auto-fired-not-returned"
    case autoFiredReturned = "auto-fired-returned"
    case noFlashFunction = "no-flash-function"
    case offNoFlashFunction = "off-no-flash-function"
    case firedRedEye = "fired-red-eye"
    case firedRedEyeNotReturned = "fired-red-eye-not-returned"
    case firedRedEyeReturned = "fired-red-eye-returned"
    case onRedEye = "on-red-eye"
    case onRedEyeNotReturned = "on-red-eye-not-returned"
    case onRedEyeReturned = "on-red-eye-returned"
    case offRedEye = "off-red-eye"
    case autoNotFiredRedEye = "auto-not-fired-red-eye"
    case autoFiredRedEye = "auto-fired-red-eye"
    case autoFiredRedEyeNotReturned = "auto-fired-red-eye-not-returned"
    case autoFiredRedEyeReturned = "auto-fired-red-eye-returned"
    
    init(flashState: Int?) {
        switch(flashState) {
            case 0:
                self = .noFlash
            case 1:
                self = .fired
            case 5:
                self = .firedNotReturned
            case 7:
                self = .firedReturned
            case 8:
                self = .onNotFired
            case 9:
                self = .onFired
            case 13:
                self = .onNotReturned
            case 15:
                self = .onReturned
            case 16:
                self = .offNotFired
            case 20:
                self = .offNotFiredNotReturned
            case 24:
                self = .autoNotFired
            case 25:
                self = .autoFired
            case 29:
                self = .autoFiredNotReturned
            case 31:
                self = .autoFiredReturned
            case 32:
                self = .noFlash
            case 48:
                self = .offNoFlashFunction
            case 65:
                self = .firedRedEye
            case 69:
                self = .firedRedEyeNotReturned
            case 71:
                self = .firedRedEyeReturned
            case 73:
                self = .onRedEye
            case 77:
                self = .onRedEyeNotReturned
            case 79:
                self = .onRedEyeReturned
            case 80:
                self = .offRedEye
            case 88:
                self = .autoNotFiredRedEye
            case 89:
                self = .autoFiredRedEye
            case 93:
                self = .autoFiredRedEyeNotReturned
            case 95:
                self = .autoFiredRedEyeReturned
            default:
                self = .unknown
        }
    }
}

public enum MeteringMode: String, Codable {
    case average = "average"
    case centerWeightedAverage = "center-weighted-average"
    case multiSpot = "multi-spot"
    case other = "other"
    case partial = "partial"
    case pattern = "pattern"
    case spot = "spot"
    case unknown = "unknown"
    
    init(meteringMode: Int?) {
        switch(meteringMode) {
            case 1:
                self = .average
            case 2:
                self = .centerWeightedAverage
            case 3:
                self = .spot
            case 4:
                self = .multiSpot
            case 5:
                self = .pattern
            case 6:
                self = .partial
            case 255:
                self = .other
            case 0:
                self = .unknown
            default:
                self = .unknown
        }
    }
}

public enum WhiteBalance: String, Codable {
    case auto = "auto"
    case manual = "manual"
    case unknown = "unknown"
    
    init(whiteBalance: Int?) {
        switch(whiteBalance) {
            case 0:
                self = .auto
            case 1:
                self = .manual
            default:
                self = .unknown
        }
    }
}

fileprivate struct DateFormatterStylePair: Equatable, Hashable {
    let dateStyle: DateFormatter.Style
    let timeStyle: DateFormatter.Style
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(dateStyle)
        hasher.combine(timeStyle)
    }
    
    static fileprivate func == (lhs: DateFormatterStylePair, rhs: DateFormatterStylePair) -> Bool {
        return lhs.dateStyle == rhs.dateStyle && lhs.timeStyle == rhs.timeStyle
    }
}

// MARK: -

func conditional(string s: String?, condition: Bool) -> String
{
    if let t = s
    {
        if condition {
            return t
        }
    }
    return ""
}

func padTail(ofString s: String?, with: String = " ") -> String
{
    if let t = s
    {
        if !t.isEmpty {
            return "\(t)\(with)"
        }
    }
    return ""
}
