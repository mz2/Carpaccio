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

public struct ImageMetadata: Codable {
    // MARK: Required metadata

    /** Width and height of the image. */
    public let nativeSize: CGSize
    
    /** Orientation of the image's pixel data. Default is `.up`. */
    public let nativeOrientation: ImageOrientation
    
    // MARK: Optional metadata

    public let cameraMaker: String?
    public let cameraModel: String?

    public let colorSpaceName: String?
    
    /** In common tog parlance, this'd be "aperture": f/2.8 etc.*/
    public let fNumber: Double?
    
    public let focalLength: Double?
    public let focalLength35mmEquivalent: Double?
    public let iso: Double?
    public let shutterSpeed: TimeInterval?
    
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
        case colorSpaceName = "color-space"
        case fNumber = "f-number"
        case focalLength = "focal-length"
        case focalLength35mmEquivalent = "focal-length-35mm-equivalent"
        case iso
        case shutterSpeed = "shutter-speed"
        case timestamp

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
            case .timestamp:
                return "timestamp"
            }
        }
    }

    // MARK: Initialisers
    public init(
        nativeSize: CGSize,
        nativeOrientation: ImageOrientation = .up,
        colorSpaceName: String? = nil,
        fNumber: Double? = nil,
        focalLength: Double? = nil,
        focalLength35mmEquivalent: Double? = nil,
        iso: Double? = nil,
        shutterSpeed: TimeInterval? = nil,
        cameraMaker: String? = nil,
        cameraModel: String? = nil,
        timestamp: Date? = nil
    ) {
        self.fNumber = fNumber
        self.cameraMaker = cameraMaker
        self.cameraModel = cameraModel

        self.colorSpaceName = colorSpaceName

        self.focalLength = focalLength
        self.focalLength35mmEquivalent = focalLength35mmEquivalent
        self.iso = iso
        self.nativeOrientation = nativeOrientation
        self.nativeSize = nativeSize
        self.shutterSpeed = shutterSpeed
        self.timestamp = timestamp
    }

    public static func cgColorSpaceNameForPictureStyleColorSpaceName(_ name: String) -> String? {
        if name == "Adobe RGB" {
            return CGColorSpace.adobeRGB1998 as String
        }
        return nil
    }

    public init(imageSource: ImageIO.CGImageSource) throws {
        if (CGImageSourceGetCount(imageSource) == 0) {
            throw Image.Error.sourceHasNoImages
        }
        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) else {
            throw Image.Error.noMetadata
        }
        
        let properties = NSDictionary(dictionary: imageProperties) as? [String: Any]
        try self.init(cgImagePropertiesDictionary: properties ?? [:], imageSource: imageSource)
    }

    public init(cgImagePropertiesDictionary properties: [AnyHashable: Any], imageSource: ImageIO.CGImageSource? = nil) throws {
        var fNumber: Double? = nil, focalLength: Double? = nil, focalLength35mm: Double? = nil, iso: Double? = nil, shutterSpeed: Double? = nil
        var colorSpaceName: String? = nil
        var width: CGFloat? = nil, height: CGFloat? = nil
        var timestamp: Date? = nil

        // Get image dimensions
        if let pixelWidth = properties[kCGImagePropertyPixelWidth] as? CGFloat, let pixelHeight = properties[kCGImagePropertyPixelHeight] as? CGFloat {
            width = pixelWidth
            height = pixelHeight
        }

        // Examine EXIF metadata
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            fNumber = (exif[kCGImagePropertyExifFNumber as String] as? NSNumber)?.doubleValue
            colorSpaceName = exif[kCGImagePropertyExifColorSpace as String] as? String
            focalLength = (exif[kCGImagePropertyExifFocalLength as String] as? NSNumber)?.doubleValue
            focalLength35mm = (exif[kCGImagePropertyExifFocalLenIn35mmFilm as String] as? NSNumber)?.doubleValue
            
            if let isoValues = exif[kCGImagePropertyExifISOSpeedRatings as String]
            {
                let isoArray = NSArray(array: isoValues as! CFArray)
                if isoArray.count > 0 {
                    iso = (isoArray[0] as? NSNumber)?.doubleValue
                }
            }
            
            shutterSpeed = (exif[kCGImagePropertyExifExposureTime as String] as? NSNumber)?.doubleValue
            
            if let w = (exif[kCGImagePropertyExifPixelXDimension as String] as? NSNumber)?.doubleValue {
                width = CGFloat(w)
            }
            if let h = (exif[kCGImagePropertyExifPixelYDimension as String] as? NSNumber)?.doubleValue {
                height = CGFloat(h)
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
            if let cgOrientation = CGImagePropertyOrientation(rawValue: (tiff[kCGImagePropertyTIFFOrientation as String] as? NSNumber)?.uint32Value ?? CGImagePropertyOrientation.up.rawValue) {
                orientation = ImageOrientation(cgImageOrientation: cgOrientation)
            }
            
            if timestamp == nil, let dateTimeString = (tiff[kCGImagePropertyTIFFDateTime as String] as? String) {
                timestamp = ImageMetadata.EXIFDateFormatter.date(from: dateTimeString)
            }
        }

        // We may be dealing with a metadata dictionary from ImageCaptureCore (have not found system-defined constants
        // for these keys, yet)
        if width == nil {
            width = properties["PixelWidth"] as? CGFloat
            height = properties["PixelHeight"] as? CGFloat
        }

        if colorSpaceName == nil {
            if let pictureStyleDictionary = properties["{PictureStyle}"] as? [String: Any],
                let names = pictureStyleDictionary["PictStyleColorSpace"] as? [Any],
                let name = names.first as? String {
                colorSpaceName = ImageMetadata.cgColorSpaceNameForPictureStyleColorSpaceName(name)
            }
        }

        // If image dimension didn't appear in metadata (as can happen with some RAW files like Nikon NEFs),
        // take one more step: open the actual image. This thankfully doesn't appear to immediately load image data.
        if width == nil || height == nil, let imageSource = imageSource {
            let options: CFDictionary = [String(kCGImageSourceShouldCache): false] as NSDictionary as CFDictionary
            guard let image = CGImageSourceCreateImageAtIndex(imageSource, 0, options) else {
                throw Image.Error.failedToDecodeImage
            }
            width = CGFloat(image.width)
            height = CGFloat(image.height)
        }

        guard let validWidth = width, let validHeight = height else {
            throw Image.Error.invalidImageSize
        }

        self.init(nativeSize: CGSize(width: validWidth, height: validHeight), nativeOrientation: orientation ?? .up, colorSpaceName: colorSpaceName, fNumber: fNumber, focalLength: focalLength, focalLength35mmEquivalent: focalLength35mm, iso: iso, shutterSpeed: shutterSpeed, cameraMaker: cameraMaker, cameraModel: cameraModel, timestamp: timestamp)
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
    public var size: CGSize
    {
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

        // Note: we store the numeric CGImageOrientation value here, rather than the string equivalent
        result[CodingKeys.nativeOrientation.dictionaryRepresentationKey] = nativeOrientation.cgImageOrientation.rawValue

        result[CodingKeys.nativeSize.dictionaryRepresentationKey] = [nativeSize.width, nativeSize.height]

        // Note: we use a string literal here, because `shape` being a derived property, is not part of
        // the Codable implementation (and hence has not corresponding CodingKeys case)
        result["shape"] = shape.rawValue

        if let shutterSpeed = self.shutterSpeed {
            result[CodingKeys.shutterSpeed.dictionaryRepresentationKey] = shutterSpeed
        }

        if let timestamp = self.timestamp {
            result[CodingKeys.timestamp.dictionaryRepresentationKey] = timestamp.timeIntervalSince1970
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
    
    init(cgImageOrientation: CGImagePropertyOrientation) {
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
