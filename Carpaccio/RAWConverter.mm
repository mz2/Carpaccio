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

NSString *const RAWConverterMetadataKeyAperture = @"aperture";
NSString *const RAWConverterMetadataKeyFocalLength = @"focalLength";
NSString *const RAWConverterMetadataKeyImageWidth = @"imageWidth";
NSString *const RAWConverterMetadataKeyImageHeight = @"imageHeight";
NSString *const RAWConverterMetadataKeyISO = @"ISO";
NSString *const RAWConverterMetadataKeyShutterSpeed = @"shutterSpeed";


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
    NSString *libRawErrorString = (errorCode != -1)
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
    processor->verbose = true;
    
    //processor->imgdata.params.output_tiff = 1; // Let us output TIFF
    //processor->imgdata.params.filtering_mode = LIBRAW_FILTERING_AUTOMATIC;
    //processor->imgdata.params.document_mode = 1; // standard processing (with white balance)
    
    // See libraw_types.h and https://www.cybercom.net/~dcoffin/dcraw/dcraw.1.html for some of the values
    //processor->imgdata.params.camera_profile = "embed";
    processor->imgdata.params.half_size = 1;
    //processor->imgdata.params.highlight = 5;
    //processor->imgdata.params.gamm[0] = processor->imgdata.params.gamm[1] = processor->imgdata.params.gamm[2] = processor->imgdata.params.gamm[3] = processor->imgdata.params.gamm[4] = processor->imgdata.params.gamm[5] = processor->imgdata.params.gamm[6] = 1.0; // linear gamma curve
    processor->imgdata.params.no_auto_bright = 0; // Don't use automatic increase of brightness by histogram.
    processor->imgdata.params.output_bps = 8;
    processor->imgdata.params.output_color = 2; // 1 = sRGB d65 (apparently the default), 2 = Adobe RGB
    processor->imgdata.params.use_camera_wb = 1; // If possible, use the white balance from the camera.
    processor->imgdata.params.use_rawspeed = 1;
    processor->imgdata.params.user_qual = 3; // 0: High-speed, low-quality bilinear interpolation. 1: Variable Number of Gradients (VNG) interpolation. 2: Patterned Pixel Grouping (PPG) interpolation. 3: Adaptive Homogeneity-Directed (AHD) interpolation. At quick test, doesn't seem to affect decoding speed at all?!
    
    return processor;
}

- (BOOL)isStateFlagSet:(RAWConverterState)flag
{
    if (flag == 0)
        return YES;
    return ((self.state & flag) == flag);

}

- (BOOL)isOpened {
    return [self isStateFlagSet:RAWConverterStateOpened];
}

- (BOOL)isThumbnailUnpacked {
    return [self isStateFlagSet:RAWConverterStateThumbnailUnpacked];
}

- (BOOL)isThumbnailDecoded {
    return [self isStateFlagSet:RAWConverterStateThumbnailDecodedToMemory];
}

- (BOOL)isImageUnpacked {
    return [self isStateFlagSet:RAWConverterStateImageUnpacked];
}

- (BOOL)isImageProcessed {
    return [self isStateFlagSet:RAWConverterStateImageProcessed];
}

- (BOOL)isImageDecoded {
    return [self isStateFlagSet:RAWConverterStateImageDecoded];
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

- (NSImage *)thumbnailImage
{
    NSParameterAssert(!self.error);
    NSParameterAssert(!(self.state & RAWConverterStateThumbnailDecodedToMemory));
    
    self.state = self.state | RAWConverterStateThumbnailDecodedToMemory;
    
    libraw_processed_image_t *processedThumb = self.RAWProcessor->dcraw_make_mem_thumb();
    
    NSImage *thumb = nil;
    NSData *data = [NSData dataWithBytes:processedThumb->data length:processedThumb->data_size];
    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithData:data];
    
    if (rep)
    {
        thumb = [[NSImage alloc] init];
        thumb.cacheMode = NSImageCacheNever;
        [thumb addRepresentation:rep];
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
    //NSParameterAssert(!(self.state & RAWConverterStateImageUnpacked));
    
    if (self.isImageUnpacked) {
        return LIBRAW_SUCCESS;
    }
    
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
    //NSParameterAssert(!(self.state & RAWConverterStateImageProcessed));
    
    if (self.isImageProcessed) {
        return LIBRAW_SUCCESS;
    }
    
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

- (NSDictionary *)metadata
{
    NSParameterAssert(self.RAWProcessor);
    
    if (!(self.state & RAWConverterStateOpened)) {
        return nil;
    }
    
    CGFloat width = (CGFloat)self.RAWProcessor->imgdata.sizes.width;
    CGFloat height = (CGFloat)self.RAWProcessor->imgdata.sizes.height;
    
    if (self.RAWProcessor->imgdata.sizes.flip)
    {
        CGFloat h = width;
        width = height;
        height = h;
    }
    
    CGFloat aperture = (CGFloat)self.RAWProcessor->imgdata.other.aperture;
    CGFloat focalLength = (CGFloat)self.RAWProcessor->imgdata.other.focal_len;
    CGFloat ISO = (CGFloat)self.RAWProcessor->imgdata.other.iso_speed;
    CGFloat shutterSpeed = (CGFloat)self.RAWProcessor->imgdata.other.shutter;
    
    NSDictionary *metadata = @{
                               RAWConverterMetadataKeyAperture: @(aperture),
                               RAWConverterMetadataKeyFocalLength: @(focalLength),
                               RAWConverterMetadataKeyImageWidth: @(width),
                               RAWConverterMetadataKeyImageHeight: @(height),
                               RAWConverterMetadataKeyISO: @(ISO),
                               RAWConverterMetadataKeyShutterSpeed: @(shutterSpeed)
                               };
    return metadata;
}

- (void)decodeMetadata:(RAWConverterMetadataHandler)metadataHandler errorHandler:(RAWConverterErrorHandler)errorHandler
{
    int ret = LIBRAW_SUCCESS;
    
    if (!(self.state & RAWConverterStateOpened))
    {
        ret = [self openURL];
        if (ret != LIBRAW_SUCCESS) {
            NSParameterAssert(self.error);
            errorHandler(self.error);
            return;
        }
    }
    
    metadataHandler(self.metadata);
}

- (void)decodeWithThumbnailHandler:(RAWConverterImageHandler)thumbnailHandler
                      errorHandler:(RAWConverterErrorHandler)errorHandler {
    [self _decodeToDirectoryAtURL:nil
                 thumbnailHandler:thumbnailHandler
                     imageHandler:nil
                  imageURLHandler:nil
                     errorHandler:errorHandler];
}

- (void)decodeWithImageHandler:(RAWConverterImageHandler)imageHandler
                  errorHandler:(RAWConverterErrorHandler)errorHandler
{
    [self _decodeToDirectoryAtURL:nil
                 thumbnailHandler:nil
                     imageHandler:imageHandler
                  imageURLHandler:nil
                     errorHandler:errorHandler];
}

- (void)decodeToDirectoryAtURL:(NSURL *)convertedImagesRootURL
              thumbnailHandler:(RAWConverterImageHandler)thumbnailHandler
                  imageHandler:(RAWConverterImageHandler)imageHandler
               imageURLHandler:(nullable RAWConverterImageURLHandler)imageURLHandler
                  errorHandler:(RAWConverterErrorHandler)errorHandler
{
    [self _decodeToDirectoryAtURL:convertedImagesRootURL
                 thumbnailHandler:thumbnailHandler
                     imageHandler:imageHandler
                  imageURLHandler:imageURLHandler
                     errorHandler:errorHandler];
}

// this _ prefixed method is used so that convertedImagesRootURL can be made publicly nonnull but still used by the simpler -decodeWithThumbnailHandler:errorHandler: method above.
- (void)_decodeToDirectoryAtURL:(NSURL *)convertedImagesRootURL
               thumbnailHandler:(RAWConverterImageHandler)thumbnailHandler
                   imageHandler:(RAWConverterImageHandler)imageHandler
                imageURLHandler:(RAWConverterImageURLHandler)imageURLHandler
                   errorHandler:(RAWConverterErrorHandler)errorHandler
{
    NSParameterAssert(!self.error);
    //NSParameterAssert(!(self.state & RAWConverterStateImageDecoded));
    NSAssert(!(imageURLHandler && imageURLHandler), @"Must provide either in-memory image handler, or on-disk image URL handler — not both");
    
    if (self.isImageDecoded) {
        NSLog(@"Hmm, why you decodin' %@ again?", self.URL);
    }
    
    self.state = self.state | RAWConverterStateImageDecoded;
    int ret = LIBRAW_SUCCESS;
    
    if (!self.isOpened)
    {
        ret = [self openURL];
        if (ret != LIBRAW_SUCCESS) {
            NSParameterAssert(self.error);
            errorHandler(self.error);
            return;
        }
    }
    
    if (thumbnailHandler)
    {
        if (!self.isThumbnailUnpacked)
        {
            ret = [self unpackThumbnail];
            if (ret != LIBRAW_SUCCESS) {
                NSParameterAssert(self.error);
                errorHandler(self.error);
                return;
            }
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
    
    if (imageHandler || imageURLHandler)
    {
        if (!self.isImageUnpacked)
        {
            if ((ret = [self unpackImage]) != LIBRAW_SUCCESS) {
                NSParameterAssert(self.error);
                errorHandler(self.error);
                return;
            }
        }
        
        if (!self.isImageProcessed)
        {
            if ((ret = [self processImage]) != LIBRAW_SUCCESS) {
                NSParameterAssert(self.error);
                errorHandler(self.error);
                return;
            }
        }
        
        if (imageHandler)
        {
            int errorCode = 0;
            libraw_processed_image_t *processedImage = self.RAWProcessor->dcraw_make_mem_image(&errorCode);
            
            if (errorCode != 0)
            {
                self.error = [self.class RAWConversionErrorWithCode:RAWConversionErrorInMemoryFullSizeImageCreationFailed
                                                        description:@"Failed to load full-size image into memory from postprocessed RAW data."
                                                 recoverySuggestion:@"Check that the file is a valid RAW file supported by libraw."
                                                    LibRawErrorCode:-1];
                errorHandler(self.error);
                return;
            }
            
            int width, height, bps, colors;
            self.RAWProcessor->get_mem_image_format(&width, &height, &colors, &bps);
            
            unsigned int n = processedImage->data_size;
            unsigned char *data = (unsigned char *)malloc(n);
            memcpy(data, processedImage->data, n);
            
            NSBitmapImageRep *rep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes:&data
                                                                            pixelsWide:width
                                                                            pixelsHigh:height
                                                                         bitsPerSample:bps
                                                                       samplesPerPixel:colors
                                                                              hasAlpha:NO
                                                                              isPlanar:NO
                                                                        colorSpaceName:NSCalibratedRGBColorSpace
                                                                           bytesPerRow:(width * colors)
                                                                          bitsPerPixel:24];
            NSImage *image = nil;
            
            if (rep)
            {
                image = [[NSImage alloc] init];
                image.cacheMode = NSImageCacheNever;
                [image addRepresentation:rep];
            }
            
            if (image) {
                imageHandler(image);
            }
            else {
                self.error = [self.class RAWConversionErrorWithCode:RAWConversionErrorInMemoryFullSizeImageCreationFailed
                                                        description:@"Failed to load full-size image into memory from postprocessed RAW data."
                                                 recoverySuggestion:@"Check that the file is a valid RAW file supported by libraw."
                                                    LibRawErrorCode:-1];
                errorHandler(self.error);
            }
            
            delete processedImage;
        }
        else
        {
            NSURL *imgURL = [convertedImagesRootURL URLByAppendingPathComponent:[self.URL.lastPathComponent.stringByDeletingPathExtension stringByAppendingString:@".tiff"]];
            
            if ((ret = [self writeToURL:imgURL]) != LIBRAW_SUCCESS) {
                NSParameterAssert(self.error);
                errorHandler(self.error);
                return;
            }
            
            imageURLHandler(imgURL);
        }
    }
}

@end
