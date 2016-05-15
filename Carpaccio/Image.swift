//
//  Image.swift
//  Trimmer
//
//  Created by Matias Piipari on 07/05/2016.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Cocoa

public enum ImageError:ErrorType {
    case URLMissing
    case URLHasNoPath(NSURL)
    case LocationNotEnumerable(NSURL)
}

public class Image {
    public let name:String
    public var thumbnailImage:NSImage? = nil
    public let backingImage:NSImage?
    public let URL:NSURL?
    
    public typealias DistanceFunction = (a:Image, b:Image)-> Double
    
    public required init(image:NSImage) {
        self.backingImage = image
        self.name = image.name() ?? "Untitled"
        self.URL = nil
    }
    
    public init(URL:NSURL) {
        self.URL = URL
        self.name = URL.lastPathComponent ?? "Untitled"
        self.backingImage = nil
    }
    
    public var placeholderImage:NSImage {
        return NSImage(named: "ImagePlaceholder")!
    }
    
    public var presentedImage:NSImage {
        return backingImage ?? self.thumbnailImage ?? self.placeholderImage
    }
    
    public func fetchThumbnail(store:Bool = true, completionHandler:(image:NSImage)->Void, errorHandler:(ErrorType)->Void) {
        if let thumb = self.thumbnailImage {
            completionHandler(image: thumb)
            return
        }
        
        if let url = self.URL {
            let converter:RAWConverter
            do {
                converter = try RAWConverter(URL: url)
            }
            catch {
                errorHandler(error)
                return
            }
            
            converter.decodeWithThumbnailHandler({ thumb in
                if store {
                    self.thumbnailImage = thumb
                }
                completionHandler(image:thumb)
                }) { err in
                    errorHandler(err)
                    return
                }
        }
        else {
            errorHandler(ImageError.URLMissing)
            return
        }
    }
    
    public class var imageFileExtensions:Set<String> {
        return Set(["arw", "nef", "cr2"])
    }
    
    public class func images(contentsOfURL URL:NSURL) throws -> [Image] {
        let fileManager = NSFileManager.defaultManager()
        
        guard let path = URL.path else {
            throw ImageError.URLHasNoPath(URL)
        }
        
        guard let enumerator:NSDirectoryEnumerator = fileManager.enumeratorAtPath(path) else {
            throw ImageError.LocationNotEnumerable(URL)
        }
        
        var images = [Image]()
        while let element = enumerator.nextObject() as? String {
            let elementStr = element as NSString
            let pathExtension = elementStr.pathExtension.lowercaseString
            if !Image.imageFileExtensions.contains(pathExtension) {
                continue
            }
            
            let absoluteURL = URL.URLByAppendingPathComponent(element)
            let image = Image(URL: absoluteURL)
            images.append(image)
        }
        
        return images
    }
}