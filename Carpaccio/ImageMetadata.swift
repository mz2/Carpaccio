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
    
    public init(nativeSize: CGSize, nativeOrientation: CGImagePropertyOrientation = .up, colorSpace: CGColorSpace? = nil, fNumber: Double? = nil, focalLength: Double? = nil, focalLength35mmEquivalent: Double? = nil, ISO: Double? = nil, shutterSpeed: TimeInterval? = nil, cameraMaker: String? = nil, cameraModel: String? = nil, timestamp: Date? = nil)
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
    }
    
    public var size: CGSize
    {
        let shouldSwapWidthAndHeight: Bool
        
        switch self.nativeOrientation
        {
        case .left, .right, .leftMirrored, .rightMirrored:
            shouldSwapWidthAndHeight = true
        default:
            shouldSwapWidthAndHeight = false
        }
        
        if shouldSwapWidthAndHeight {
            return CGSize(width: self.nativeSize.height, height: self.nativeSize.width)
        }
        
        return self.nativeSize
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
        get
        {
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
    }
    
    public var humanReadableFocalLength: String? {
        get
        {
            guard let f = self.focalLength, f > 0.0 else {
                return nil
            }
            
            let mm = Int(round(f))
            return "\(mm)mm"
        }
    }
    
    public var humanReadableFocalLength35mmEquivalent: String? {
        get
        {
            guard let f = self.focalLength35mmEquivalent, f > 0.0 else {
                return nil
            }
            
            let mm = Int(round(f))
            return "(\(mm)mm)"
        }
    }

    public var humanReadableISO: String? {
        get
        {
            guard let ISO = self.ISO, ISO > 0.0 else {
                return nil
            }
            
            let integerISO = Int(round(ISO))
            return "ISO \(integerISO)"
        }
    }
    
    public var humanReadableShutterSpeed: String? {
        get
        {
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
