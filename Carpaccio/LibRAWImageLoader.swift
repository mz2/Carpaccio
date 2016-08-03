//
//  LibRAWImageLoader.swift
//  Carpaccio
//
//  Created by Markus Piipari on 27/07/16.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Cocoa


public class LibRAWImageLoader: ImageLoaderProtocol
{
    public let imageURL: NSURL

    init(imageURL: NSURL)
    {
        self.imageURL = imageURL
    }
    
    private var _converter: LibRAWConverter?
    
    private func converter() throws -> LibRAWConverter
    {
        if let converter = self._converter
        {
            if !converter.isImageDecoded {
                return converter
            }
        }
        
        try self._converter = LibRAWConverter(URL: self.imageURL)
        
        return self._converter!
    }
    
    public func extractImageMetadata(handler: ImageMetadataHandler, errorHandler: ImageLoadingErrorHandler)
    {
        let converter: LibRAWConverter
        do {
            converter = try self.converter()
        }
        catch
        {
            errorHandler(error: error)
            return
        }
        
        converter.decodeMetadata({ metadataDictionary in
            
            let metadata = ImageMetadata(LibRAWConverterMetadata: metadataDictionary)
            handler(metadata: metadata)
            
        }, errorHandler: { error in errorHandler(error: error) })
    }
    
    public func loadThumbnailImage(maximumPixelDimensions maxPixelSize: NSSize?, handler: PresentableImageHandler, errorHandler: ImageLoadingErrorHandler)
    {
        let converter: LibRAWConverter
        do {
            converter = try self.converter()
        }
        catch
        {
            errorHandler(error: error)
            return
        }
        
        converter.decodeWithThumbnailHandler({ fetchedThumbnail in
            
            let metadata = ImageMetadata(LibRAWConverterMetadata: converter.metadata!)
            handler(image: fetchedThumbnail, metadata: metadata)
            
        }) { error in errorHandler(error: error) }
    }
    
    public func loadFullSizeImage(maximumPixelDimensions maxPixelSize: NSSize?, handler: PresentableImageHandler, errorHandler: ImageLoadingErrorHandler)
    {
        let converter: LibRAWConverter
        let URL: NSURL
        
        do
        {
            converter = try self.converter()
            URL = try NSFileManager.defaultManager().URLForDirectory(.CachesDirectory, inDomain: .UserDomainMask, appropriateForURL: nil, create: true)
        }
        catch
        {
            errorHandler(error: error)
            return
        }
        
        converter.decodeToDirectoryAtURL(URL, thumbnailHandler: nil, imageHandler: { (image: NSImage) in

            let metadata = ImageMetadata(LibRAWConverterMetadata: converter.metadata!)
            handler(image: image, metadata: metadata)
            
            self._converter = nil // Can't reuse LibRAW converter after unpacking & processing have been done
            
            }, imageURLHandler: nil, errorHandler: { error in
                errorHandler(error: error)
                self._converter = nil
            }
        )

    }
}