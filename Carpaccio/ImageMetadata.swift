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

extension CGImagePropertyOrientation
{
    var dimensionsSwapped: Bool {
        switch self
        {
        case .left, .right, .leftMirrored, .rightMirrored:
            return true
        default:
            return false
        }
    }
}

public struct ImageMetadata
{
    public let cameraMaker: String?
    public let cameraModel: String?
    public let colorSpace: CGColorSpace?
    
    /** In common tog parlance, this'd be "aperture": f/2.8 etc.*/
    public let fNumber: Double?
    
    public let focalLength: Double?
    public let focalLength35mmEquivalent: Double?
    public let ISO: Double?
    public let nativeOrientation: CGImagePropertyOrientation
    public let nativeSize: CGSize
    public let shutterSpeed: TimeInterval?
    
    /** If loading native image size failed, this metadata represents the built-in placeholder image for failed-to-load images. */
    public let isFailedPlaceholderImage: Bool
    
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
    
    public init(nativeSize: CGSize, nativeOrientation: CGImagePropertyOrientation = .up, colorSpace: CGColorSpace? = nil, fNumber: Double? = nil, focalLength: Double? = nil, focalLength35mmEquivalent: Double? = nil, ISO: Double? = nil, shutterSpeed: TimeInterval? = nil, cameraMaker: String? = nil, cameraModel: String? = nil, timestamp: Date? = nil, isFailedPlaceholderImage: Bool, error: Error? = nil)
    {
        self.fNumber = fNumber
        self.cameraMaker = cameraMaker
        self.cameraModel = cameraModel
        self.colorSpace = colorSpace
        self.focalLength = focalLength
        self.focalLength35mmEquivalent = focalLength35mmEquivalent
        self.ISO = ISO
        self.nativeOrientation = nativeOrientation
        self.nativeSize = nativeSize
        self.shutterSpeed = shutterSpeed
        self.timestamp = timestamp
        self.isFailedPlaceholderImage = isFailedPlaceholderImage
    }
    
    public init(imageSource: CGImageSource) throws {
        guard let imageProperties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) else {
            throw Image.Error.noMetadata
        }
        
        let properties = NSDictionary(dictionary: imageProperties)
        
        var fNumber: Double? = nil, focalLength: Double? = nil, focalLength35mm: Double? = nil, ISO: Double? = nil, shutterSpeed: Double? = nil
        var colorSpace: CGColorSpace? = nil
        var width: CGFloat? = nil, height: CGFloat? = nil
        var timestamp: Date? = nil
        
        // Examine EXIF metadata
        if let EXIF = properties[kCGImagePropertyExifDictionary as String] as? NSDictionary
        {
            fNumber = (EXIF[kCGImagePropertyExifFNumber as String] as? NSNumber)?.doubleValue
            
            if let colorSpaceName = EXIF[kCGImagePropertyExifColorSpace] as? NSString {
                colorSpace = CGColorSpace(name: colorSpaceName)
            }
            
            focalLength = (EXIF[kCGImagePropertyExifFocalLength as String] as? NSNumber)?.doubleValue
            focalLength35mm = (EXIF[kCGImagePropertyExifFocalLenIn35mmFilm as String] as? NSNumber)?.doubleValue
            
            if let ISOs = EXIF[kCGImagePropertyExifISOSpeedRatings as String]
            {
                let ISOArray = NSArray(array: ISOs as! CFArray)
                if ISOArray.count > 0 {
                    ISO = (ISOArray[0] as? NSNumber)?.doubleValue
                }
            }
            
            shutterSpeed = (EXIF[kCGImagePropertyExifExposureTime as String] as? NSNumber)?.doubleValue
            
            if let w = (EXIF[kCGImagePropertyExifPixelXDimension as String] as? NSNumber)?.doubleValue {
                width = CGFloat(w)
            }
            if let h = (EXIF[kCGImagePropertyExifPixelYDimension as String] as? NSNumber)?.doubleValue {
                height = CGFloat(h)
            }
            
            if let originalDateString = (EXIF[kCGImagePropertyExifDateTimeOriginal as String] as? String) {
                timestamp = ImageMetadata.EXIFDateFormatter.date(from: originalDateString)
            }
        }
        
        // Examine TIFF metadata
        var cameraMaker: String? = nil, cameraModel: String? = nil, orientation: CGImagePropertyOrientation? = nil
        
        if let TIFF = properties[kCGImagePropertyTIFFDictionary as String] as? NSDictionary
        {
            cameraMaker = TIFF[kCGImagePropertyTIFFMake as String] as? String
            cameraModel = TIFF[kCGImagePropertyTIFFModel as String] as? String
            orientation = CGImagePropertyOrientation(rawValue: (TIFF[kCGImagePropertyTIFFOrientation as String] as? NSNumber)?.uint32Value ?? CGImagePropertyOrientation.up.rawValue)
            
            if timestamp == nil, let dateTimeString = (TIFF[kCGImagePropertyTIFFDateTime as String] as? String) {
                timestamp = ImageMetadata.EXIFDateFormatter.date(from: dateTimeString)
            }
        }
        
        /*
         If image dimension didn't appear in metadata (can happen with some RAW files like Nikon NEFs), take one more step:
         open the actual image. This thankfully doesn't appear to immediately load image data.
         */
        if width == nil || height == nil {
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
        
        self.init(nativeSize: CGSize(width: validWidth, height: validHeight), nativeOrientation: orientation ?? .up, colorSpace: colorSpace, fNumber: fNumber, focalLength: focalLength, focalLength35mmEquivalent: focalLength35mm, ISO: ISO, shutterSpeed: shutterSpeed, cameraMaker: cameraMaker, cameraModel: cameraModel, timestamp: timestamp, isFailedPlaceholderImage: false)
    }
    
    // See ImageMetadata.timestamp for known caveats about EXIF/TIFF
    // date metadata, as interpreted by this date formatter.
    private static let EXIFDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter
    }()
    
    public var size: CGSize
    {
        if self.nativeOrientation.dimensionsSwapped {
            return CGSize(width: nativeSize.height, height: nativeSize.width)
        }
        return nativeSize
    }
    
    public enum Shape {
        case landscape
        case portrait
        case square
        
        init(size: CGSize) {
            if size.width > size.height {
                self = .landscape
            }
            else if size.width < size.height {
                self = .portrait
            }
            self = .square
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
        let integerApterture = Int(oneTenthPrecisionfNumber)
        
        // ..but avoid displaying .0
        if oneTenthPrecisionfNumber == Double(integerApterture) {
            return "f/\(integerApterture)"
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
        guard let ISO = self.ISO, ISO > 0.0 else {
            return nil
        }
        
        let integerISO = Int(round(ISO))
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
    
    public var dictionaryRepresentation: [String: Any] {
        var dict: [String: Any] = [String: Any]()
        
        if let cameraMaker = self.cameraMaker {
            dict["cameraMaker"] = cameraMaker
        }
        
        if let cameraModel = self.cameraModel {
            dict["cameraModel"] = cameraModel
        }
        
        if let space = self.colorSpace, let spaceName = space.name {
            dict["colorSpace"] = spaceName
        }
        
        if let fNumber = self.fNumber {
            dict["fNumber"] = fNumber
        }
        
        if let focalLength = self.focalLength {
            dict["focalLength"] = focalLength
        }
        
        if let focalLength35mmEquivalent = self.focalLength35mmEquivalent {
            dict["focalLength35mmEquivalent"] = focalLength35mmEquivalent
        }
        
        if let ISO = self.ISO {
            dict["ISO"] = ISO
        }
        
        dict["nativeOrientation"] = nativeOrientation.rawValue
        
        dict["nativeSize"] = [nativeSize.width, nativeSize.height]
        
        if let shutterSpeed = self.shutterSpeed {
            dict["shutterSpeed"] = shutterSpeed
        }
        
        if let timestamp = self.timestamp {
            dict["timestamp"] = timestamp.timeIntervalSince1970
        }
        
        return dict
    }
    
    static var timestampFormatter: DateFormatter =
    {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f
    }()
    
    public var humanReadableTimestamp: String {
        if let t = timestamp {
            return ImageMetadata.timestampFormatter.string(from: t)
        }
        return ""
    }
    
    public var humanReadableMetadataSummary: String {
        get {
            return "\(padTail(ofString:self.cleanedUpCameraModel))\(padTail(ofString: self.humanReadableFocalLength))\(padTail(ofString: conditional(string: self.humanReadableFocalLength35mmEquivalent, condition: (self.focalLength35mmEquivalent != self.focalLength))))\(padTail(ofString: self.humanReadableFNumber))\(padTail(ofString: self.humanReadableShutterSpeed))\(padTail(ofString: self.humanReadableISO))"
        }
    }
    
    public var humanReadableNativeSize: String {
        return "\(Int(self.nativeSize.width))x\(Int(self.nativeSize.height))"
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
