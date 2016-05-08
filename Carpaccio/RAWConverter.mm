//
//  RAWConverter.m
//  Carpaccio
//
//  Created by Matias Piipari on 07/05/2016.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

#import "RAWConverter.h"

#import <Cocoa/Cocoa.h>
#import <libraw.h>

NSString *const RAWConverterErrorDomain = @"RAWConversionErrorDomain";

@interface RAWConverter () {
}
@end


// Collected from http://www.libraw.org/docs/Samples-LibRaw-eng.html

@implementation RAWConverter

- (instancetype)initWithURL:(NSURL *)URL convertedImagesRootURL:(NSURL *)directoryURL {
    self = [super init];
    
    if (self) {
        _URL = URL.copy;
        _convertedImagesRootURL = directoryURL;
        
        // The date in TIFF is written in the local format; let us specify the timezone for compatibility with dcraw
        putenv ((char*)"TZ=UTC");
    }
    
    return self;
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

- (void)decodeContentsOfURL:(NSURL *)URL
           thumbnailHandler:(RAWConverterThumbnailHandler)thumbnailHandler
               imageHandler:(RAWConverterImageHandler)imageHandler
               errorHandler:(RAWConverterErrorHandler)errorHandler {
    LibRaw RawProcessor;
    RawProcessor.imgdata.params.output_tiff = 1; // Let us output TIFF
    //RawProcessor.imgdata.params.filtering_mode = LIBRAW_FILTERING_AUTOMATIC;
    RawProcessor.imgdata.params.output_bps = 16; // Write 16 bits per color value
    RawProcessor.imgdata.params.gamm[0] = RawProcessor.imgdata.params.gamm[1] = 1.0; // linear gamma curve
    RawProcessor.imgdata.params.no_auto_bright = 1; // Don't use automatic increase of brightness by histogram.
    //RawProcessor.imgdata.params.document_mode = 0; // standard processing (with white balance)
    RawProcessor.imgdata.params.use_camera_wb = 1; // If possible, use the white balance from the camera.
    RawProcessor.imgdata.params.half_size = 1;
    
    NSString *path = URL.path;
    
    int ret = 0;
    //BOOL verbose = NO;
    //BOOL output_thumbs = NO;
    
    RawProcessor.verbose = true;
    RawProcessor.imgdata.params.output_tiff = 1; // Let us output TIFF
    
    if ((ret = RawProcessor.open_file(path.UTF8String)) != LIBRAW_SUCCESS) {
        errorHandler([self.class RAWConversionErrorWithCode:RAWConversionErrorOpenFailed
                                                description:[NSString stringWithFormat:@"Opening file \%@ failed", URL.path]
                                         recoverySuggestion:@"Check that the file is there, you have permissions to read it, and that it a valid RAW file supported by libraw."
                                            LibRawErrorCode:ret]);
        return;
    }
    
    if ((ret = RawProcessor.unpack_thumb()) != LIBRAW_SUCCESS) {
        errorHandler([self.class RAWConversionErrorWithCode:RAWConversionErrorUnpackThumbnailFailed
                                                description:[NSString stringWithFormat:@"Unpacking thumbnail from file \%@ failed.", URL.path]
                                         recoverySuggestion:@"Check that the file has a thumbnail."
                                            LibRawErrorCode:ret]);
        return;
    }
    
    libraw_processed_image_t *processedThumb = RawProcessor.dcraw_make_mem_thumb();
    NSImage *thumb = [[NSImage alloc] initWithData:[NSData dataWithBytes:processedThumb->data length:processedThumb->data_size]];
    if (!thumb) {
        errorHandler([self.class RAWConversionErrorWithCode:RAWConversionErrorInMemoryThumbnailCreationFailed
                                                description:@"Failed to load thumbnail in memory from postprocessed RAW data."
                                         recoverySuggestion:@"Check that the file is a valid RAW file supported by libraw."
                                            LibRawErrorCode:-1]);
        delete processedThumb;
        return;
    }
    delete processedThumb;
    thumbnailHandler(thumb);
    
    if ((ret = RawProcessor.unpack()) != LIBRAW_SUCCESS) {
        errorHandler([self.class RAWConversionErrorWithCode:RAWConversionErrorUnpackImageFailed
                                                description:[NSString stringWithFormat:@"Unpacking image from file \%@ failed.", URL.path]
                                         recoverySuggestion:@"Check that the file is a valid RAW file supported by libraw."
                                            LibRawErrorCode:ret]);
        return;
    }
    
    if ((ret = RawProcessor.dcraw_process() != LIBRAW_SUCCESS)) {
        errorHandler([self.class RAWConversionErrorWithCode:RAWConversionErrorPostprocessingFailed
                                                description:[NSString stringWithFormat:@"Post-processing data from file \%@ failed.", URL.path]
                                         recoverySuggestion:@"Check that the file is a valid RAW file supported by libraw."
                                            LibRawErrorCode:ret]);
    }
    
    NSURL *imgURL = [self.convertedImagesRootURL URLByAppendingPathComponent:[URL.lastPathComponent.stringByDeletingPathExtension stringByAppendingString:@".tiff"]];
    
    if ((ret = RawProcessor.dcraw_ppm_tiff_writer(imgURL.path.UTF8String)) != LIBRAW_SUCCESS) {
        errorHandler([self.class RAWConversionErrorWithCode:RAWConversionErrorInMemoryConvertedImageWritingFailed
                                                description:@"Failed to write converted image to a location on disk."
                                         recoverySuggestion:[NSString stringWithFormat:@"Check that you have the permission to write to %@.",
                                                             self.convertedImagesRootURL.path]
                                            LibRawErrorCode:ret]);
        return;
    }
    
    imageHandler(imgURL);
}

@end
