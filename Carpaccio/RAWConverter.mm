//
//  RAWConverter.m
//  Carpaccio
//
//  Created by Matias Piipari on 07/05/2016.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

#import "RAWConverter.h"

#import <Cocoa/Cocoa.h>
#import <libraw/libraw.h>

NSString *const RAWConverterErrorDomain = @"RAWConversionErrorDomain";

@interface RAWConverter ()
@property (readwrite) LibRaw *RAWProcessor;
@property (readwrite) NSError *error;
@property (readwrite) RAWConverterState state;
@end


// Collected from http://www.libraw.org/docs/Samples-LibRaw-eng.html

@implementation RAWConverter

+ (void)initialize {
    if (self == [RAWConverter class]) {
        // The date in TIFF is written in the local format; let us specify the timezone for compatibility with dcraw
        putenv ((char*)"TZ=UTC");
    }
}

- (instancetype)initWithURL:(NSURL *)URL error:(NSError **)error {
    self = [super init];
    
    if (self) {
        _URL = URL.copy;
        
        BOOL isDir = NO;
        if (![[NSFileManager defaultManager] fileExistsAtPath:_URL.path isDirectory:&isDir] || isDir) {
            if (error) {
                *error = [NSError errorWithDomain:RAWConverterErrorDomain
                                             code:RAWConversionErrorDataAtContentsOfURLIsNotAnImage
                                         userInfo:@{NSLocalizedDescriptionKey:[NSString stringWithFormat:@"Cannot read an image from path %@", _URL.path],
                                                    NSLocalizedRecoverySuggestionErrorKey: [NSString stringWithFormat:@"File does not exist at %@ or it is of an unsupported kind.", URL.path]}];
            }
            return nil;
        }
        
        self.RAWProcessor = [self.class RAWProcessor];
    }
    
    return self;
}

- (void)dealloc {
    delete self.RAWProcessor;
    self.RAWProcessor = nil;
}

+ (NSError *)RAWConversionErrorWithCode:(RAWConversionError)code
                            description:(NSString *)description
                     recoverySuggestion:(NSString *)recoverySuggestion
                        LibRawErrorCode:(int)errorCode {
    NSString *libRawErrorString = errorCode != -1
                                    ? [NSString stringWithUTF8String:libraw_strerror(errorCode)]
                                    : @"Unknown reason.";
    
    return [NSError errorWithDomain:RAWConverterErrorDomain
                               code:code
                           userInfo:@{
                                      NSLocalizedDescriptionKey:description,
                                      NSLocalizedFailureReasonErrorKey:libRawErrorString,
                                      NSLocalizedRecoverySuggestionErrorKey:recoverySuggestion
                                      }];
}

+ (LibRaw *)RAWProcessor {
    LibRaw *processor = new LibRaw();
    processor->imgdata.params.output_tiff = 1; // Let us output TIFF
    //RawProcessor.imgdata.params.filtering_mode = LIBRAW_FILTERING_AUTOMATIC;
    processor->imgdata.params.output_bps = 8; //16; // Write 16 bits per color value
    processor->imgdata.params.gamm[0] = processor->imgdata.params.gamm[1] = 1.0; // linear gamma curve
    processor->imgdata.params.no_auto_bright = 0; //1; // Don't use automatic increase of brightness by histogram.
    //processor->imgdata.params.document_mode = 0; // standard processing (with white balance)
    processor->imgdata.params.use_camera_wb = 1; // If possible, use the white balance from the camera.
    processor->imgdata.params.use_rawspeed = 1;
    processor->imgdata.params.half_size = 1;
    processor->verbose = true;
    processor->imgdata.params.output_tiff = 1;
    
    return processor;
}

- (int)openURL {
    NSParameterAssert(!self.error);
    NSParameterAssert(!(self.state & RAWConverterStateOpened));
    self.state = self.state | RAWConverterStateOpened;
    
    int ret = 0;
    if ((ret = self.RAWProcessor->open_file(self.URL.path.UTF8String)) != LIBRAW_SUCCESS) {
        self.error = [self.class RAWConversionErrorWithCode:RAWConversionErrorOpenFailed
                                                description:[NSString stringWithFormat:@"Opening file \%@ failed", self.URL.path]
                                         recoverySuggestion:@"Check that the file is there, you have permissions to read it, and that it a valid RAW file supported by libraw."
                                            LibRawErrorCode:ret];
    }
    
    return ret;
}

- (int)unpackThumbnail {
    NSParameterAssert(!self.error);
    NSParameterAssert(!(self.state & RAWConverterStateThumbnailUnpacked));
    self.state = self.state | RAWConverterStateThumbnailUnpacked;
    
    int ret = 0;
    if ((ret = self.RAWProcessor->unpack_thumb()) != LIBRAW_SUCCESS) {
        NSError *err = [self.class RAWConversionErrorWithCode:RAWConversionErrorUnpackThumbnailFailed
                                                  description:[NSString stringWithFormat:@"Unpacking thumbnail from file failed."]
                                           recoverySuggestion:@"Check that the file has a thumbnail."
                                              LibRawErrorCode:ret];
        self.error = err;
    }
    return ret;
}

- (NSImage *)thumbnailImage {
    NSParameterAssert(!self.error);
    NSParameterAssert(!(self.state & RAWConverterStateThumbnailDecodedToMemory));
    self.state = self.state | RAWConverterStateThumbnailDecodedToMemory;
    
    libraw_processed_image_t *processedThumb = self.RAWProcessor->dcraw_make_mem_thumb();
    //int errorCode = 0;
    //libraw_processed_image_t *processedThumb = self.RAWProcessor->dcraw_make_mem_image(&errorCode);
    
    NSImage *thumb = nil;
    NSData *data = [NSData dataWithBytes:processedThumb->data length:processedThumb->data_size];
    //NSImage *thumb = [[NSImage alloc] initWithData:data];
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithData:data];
    
    if (rep)
    {
        NSImage *img = [[NSImage alloc] init];
        img.cacheMode = NSImageCacheNever;
        [img addRepresentation:rep];

        CGFloat h = 1000.0;
        CGFloat w = (img.size.width / img.size.height) * h;
        
        thumb = [[NSImage alloc] initWithSize:NSMakeSize(w, h)];
        [thumb lockFocus];
        [NSGraphicsContext currentContext].imageInterpolation = NSImageInterpolationHigh;
        [img drawInRect:NSMakeRect(0.0, 0.0, w, h) fromRect:NSMakeRect(0.0, 0.0, img.size.width, img.size.height)operation:NSCompositeCopy fraction:1.0];
        [thumb unlockFocus];
    }
    
    //libraw_dcraw_clear_mem(processedThumb);
    
    int ret = LIBRAW_SUCCESS;
    if (!thumb) {
        self.error = [self.class RAWConversionErrorWithCode:RAWConversionErrorInMemoryThumbnailCreationFailed
                                                description:@"Failed to load thumbnail in memory from postprocessed RAW data."
                                         recoverySuggestion:@"Check that the file is a valid RAW file supported by libraw."
                                            LibRawErrorCode:-1];
        ret = -1;
    }
    delete processedThumb;
    
    return thumb;
}

- (int)unpackImage {
    NSParameterAssert(!self.error);
    NSParameterAssert(!(self.state & RAWConverterStateImageUnpacked));
    self.state = self.state | RAWConverterStateImageUnpacked;
    
    int ret = 0;
    if ((ret = self.RAWProcessor->unpack()) != LIBRAW_SUCCESS) {
        self.error = [self.class RAWConversionErrorWithCode:RAWConversionErrorUnpackImageFailed
                                                description:[NSString stringWithFormat:@"Unpacking image from file failed."]
                                         recoverySuggestion:@"Check that the file is a valid RAW file supported by libraw."
                                            LibRawErrorCode:ret];
    }
    
    return ret;
}

- (int)processImage {
    NSParameterAssert(!self.error);
    NSParameterAssert(!(self.state & RAWConverterStateImageProcessed));
    self.state = self.state | RAWConverterStateImageProcessed;
    
    int ret = LIBRAW_SUCCESS;
    if ((ret = self.RAWProcessor->dcraw_process()) != LIBRAW_SUCCESS) {
        self.error = [self.class RAWConversionErrorWithCode:RAWConversionErrorPostprocessingFailed
                                                description:[NSString stringWithFormat:@"Post-processing data from file \%@ failed.", self.URL.path]
                                         recoverySuggestion:@"Check that the file is a valid RAW file supported by libraw."
                                            LibRawErrorCode:-1];
        ret = -1;
    }
    
    return ret;
}

- (int)writeToURL:(NSURL *)imgURL {
    int ret = 0;
    if ((ret = self.RAWProcessor->dcraw_ppm_tiff_writer(imgURL.path.UTF8String)) != LIBRAW_SUCCESS) {
        self.error = [self.class RAWConversionErrorWithCode:RAWConversionErrorInMemoryConvertedImageWritingFailed
                                                description:@"Failed to write converted image to a location on disk."
                                         recoverySuggestion:[NSString stringWithFormat:@"Check that you have the permission to write to %@.", imgURL]
                                            LibRawErrorCode:ret];
    }
    
    return ret;
}

- (void)decodeWithThumbnailHandler:(RAWConverterThumbnailHandler)thumbnailHandler
                      errorHandler:(RAWConverterErrorHandler)errorHandler {
    [self _decodeToDirectoryAtURL:nil
                 thumbnailHandler:thumbnailHandler
                     imageHandler:nil
                     errorHandler:errorHandler];
}

- (void)decodeToDirectoryAtURL:(NSURL *)convertedImagesRootURL
             thumbnailHandler:(RAWConverterThumbnailHandler)thumbnailHandler
                 imageHandler:(RAWConverterImageHandler)imageHandler
                 errorHandler:(RAWConverterErrorHandler)errorHandler {
    [self _decodeToDirectoryAtURL:convertedImagesRootURL
                 thumbnailHandler:thumbnailHandler
                     imageHandler:imageHandler
                     errorHandler:errorHandler];
}

// this _ prefixed method is used so that convertedImagesRootURL can be made publicly nonnull but still used by the simpler -decodeWithThumbnailHandler:errorHandler: method above.
- (void)_decodeToDirectoryAtURL:(NSURL *)convertedImagesRootURL
               thumbnailHandler:(RAWConverterThumbnailHandler)thumbnailHandler
                   imageHandler:(RAWConverterImageHandler)imageHandler
                   errorHandler:(RAWConverterErrorHandler)errorHandler {
    NSParameterAssert(!self.error);
    NSParameterAssert(!(self.state & RAWConverterStateImageDecoded));
    self.state = self.state | RAWConverterStateImageDecoded;
    
    int ret = [self openURL];
    if (ret != LIBRAW_SUCCESS) {
        NSParameterAssert(self.error);
        errorHandler(self.error);
        return;
    }
    
    if (thumbnailHandler) {
        ret = [self unpackThumbnail];
        if (ret != LIBRAW_SUCCESS) {
            NSParameterAssert(self.error);
            errorHandler(self.error);
            return;
        }
        
        NSImage *img = [self thumbnailImage];
        if (!img) {
            NSParameterAssert(self.error);
            errorHandler(self.error);
            return;
        }
        else {
            thumbnailHandler(img);
        }
    }
    
    if (imageHandler) {
        if ((ret = [self unpackImage]) != LIBRAW_SUCCESS) {
            NSParameterAssert(self.error);
            errorHandler(self.error);
            return;
        }
        
        if ((ret = [self processImage]) != LIBRAW_SUCCESS) {
            NSParameterAssert(self.error);
            errorHandler(self.error);
            return;
        }
        
        NSURL *imgURL = [convertedImagesRootURL URLByAppendingPathComponent:[self.URL.lastPathComponent.stringByDeletingPathExtension stringByAppendingString:@".tiff"]];

        if ((ret = [self writeToURL:imgURL]) != LIBRAW_SUCCESS) {
            NSParameterAssert(self.error);
            errorHandler(self.error);
            return;
        }
        
        imageHandler(imgURL);
    }
}

@end
