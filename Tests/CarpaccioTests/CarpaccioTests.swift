//
//  CarpaccioTests.swift
//  CarpaccioTests
//
//  Created by Matias Piipari on 07/05/2016.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import XCTest
@testable import Carpaccio

class CarpaccioTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testSonyRAWConversion() {
        let img1URL = Bundle.module.url(forResource:"DSC00583_", withExtension: "ARW")!
        
        let tempDir = URL(fileURLWithPath:NSTemporaryDirectory() + "/\(UUID().uuidString)")
        
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: [:])
        
        let loader = ImageLoader(imageURL: img1URL, thumbnailScheme: .decodeFullImageIfEmbeddedThumbnailMissing)
        let (thumb, imageMetadata) = try! loader.loadBitmapImage(maximumPixelDimensions: nil, colorSpace: nil, allowCropping: true, cancelled: nil)
        
        XCTAssertEqual(thumb.size.width, 1616)
        XCTAssertEqual(thumb.size.height, 1080)
        
        XCTAssertEqual(imageMetadata.cameraMaker, "SONY")
        XCTAssertEqual(imageMetadata.cameraModel, "ILCE-7RM2")
        XCTAssertNil(imageMetadata.lensMaker)
        XCTAssertEqual(imageMetadata.iso, 125.0)
        XCTAssertEqual(imageMetadata.exposureCompensation, 0.0)
        XCTAssertNil(imageMetadata.lensMaker)
        XCTAssertEqual(imageMetadata.lensModel, "----")
        XCTAssertEqual(imageMetadata.flashMode, FlashMode.offNotFired)
        XCTAssertEqual(imageMetadata.meteringMode, MeteringMode.pattern)
        XCTAssertEqual(imageMetadata.whiteBalance, WhiteBalance.auto)

        #if os(macOS)
        // As of this writing, iOS returns the incorrect image size of 1616x1080, so for now, we only check this on macOS
        XCTAssertEqual(imageMetadata.nativeSize.width, 7952.0)
        XCTAssertEqual(imageMetadata.nativeSize.height, 5304.0)
        #endif
        
        let testedComponents:Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let date = imageMetadata.timestamp!
        let components = Calendar(identifier: .gregorian).dateComponents(testedComponents, from: date)
        
        XCTAssertEqual(components.year, 2016)
        XCTAssertEqual(components.day, 16)
        XCTAssertEqual(components.month, 3)
        XCTAssertEqual(components.hour, 16)
        XCTAssertEqual(components.minute, 34)
        XCTAssertEqual(components.second, 21)
        
        try! FileManager.default.removeItem(at: tempDir)
    }
    
    func testiPhone5Image()
    {
        let img1URL = Bundle.module.url(forResource: "iphone5", withExtension: "jpg")!
        
        let tempDir = URL(fileURLWithPath:NSTemporaryDirectory() + "/\(UUID().uuidString)")
        
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: [:])
        
        let loader = ImageLoader(imageURL: img1URL, thumbnailScheme: .decodeFullImage)
        let (image, imageMetadata) = try! loader.loadBitmapImage(maximumPixelDimensions: nil, colorSpace: nil, allowCropping: true, cancelled: nil)
        
        XCTAssertEqual(image.size.width, 2448.0)
        XCTAssertEqual(image.size.height, 3264.0)
        
        XCTAssertEqual(imageMetadata.cameraMaker, "Apple")
        XCTAssertEqual(imageMetadata.cameraModel, "iPhone 5")
        XCTAssertEqual(imageMetadata.iso, 50.0)
        XCTAssertEqual(imageMetadata.nativeSize.width, 3264.0)
        XCTAssertEqual(imageMetadata.nativeSize.height, 2448.0)
        XCTAssertEqual(imageMetadata.fNumber!, 2.4, accuracy: 0.01)
        XCTAssertEqual(imageMetadata.focalLength!, 4.12, accuracy: 0.01)
        XCTAssertEqual(imageMetadata.focalLength35mmEquivalent!, 33.0, accuracy: 0.000000001)
        XCTAssertEqual(imageMetadata.shutterSpeed!, 0.00145772, accuracy: 0.00000001)
        XCTAssertEqual(imageMetadata.exposureCompensation, 0.0)
        XCTAssertEqual(imageMetadata.flashMode, FlashMode.offNotFired)
        XCTAssertEqual(imageMetadata.lensMaker, "Apple")
        XCTAssertEqual(imageMetadata.lensModel, "iPhone 5 back camera 4.12mm f/2.4")
        XCTAssertEqual(imageMetadata.meteringMode, MeteringMode.spot)
        XCTAssertEqual(imageMetadata.whiteBalance, WhiteBalance.auto)
        
        let testedComponents:Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
        let date = imageMetadata.timestamp!
        let components = Calendar(identifier: .gregorian).dateComponents(testedComponents, from: date)
        
        XCTAssertEqual(components.year, 2016)
        XCTAssertEqual(components.day, 8)
        XCTAssertEqual(components.month, 9)
        XCTAssertEqual(components.hour, 11)
        XCTAssertEqual(components.minute, 56)
        XCTAssertEqual(components.second, 3)
        
        try! FileManager.default.removeItem(at: tempDir)
    }
    
    func testDistanceMatrixComputation() {
        let resourcesDir = Bundle.module.resourceURL!
        let imgColl = try! Collection(contentsOf: resourcesDir)
        
        // just checking that the matrix computation succeeds.
        let distances = imgColl.distanceMatrix { a, b in
            return Double.infinity
        }
        
        for (r, row) in distances.enumerated() {
            for (c, dist) in row.enumerated() {
                if c > r {
                    XCTAssert(dist.isInfinite)
                }
                else if c == r {
                    XCTAssert(dist == 0)
                }
                else if c < r {
                    XCTAssert(dist.isNaN) // the lower part under diagonal is filled with NaN (for now anyway, until we create a sparse matrix for the purpose)
                }
            }
        }
    }
    
    
    func testDistanceTableComputation() {
        let resourcesDir = Bundle.module.resourceURL!
        let imgColl = try! Collection(contentsOf: resourcesDir)
        
        let distances = imgColl.distanceTable { a, b in
            return Double.infinity
        }
        
        for (r, row) in distances.enumerated() {
            for (c, dist) in row.enumerated() {
                if c == r {
                    XCTAssert(dist == 0)
                }
                else {
                    XCTAssert(dist.isInfinite)
                }
            }
        }
    }
    
    func testFailingMetadataThrowsError() {
        guard let url = Bundle.module.url(forResource: "DP2M1726_", withExtension: "X3F") else {
            XCTAssert(false)
            return
        }
        
        let loader = ImageLoader(imageURL: url, thumbnailScheme: .decodeFullImageIfEmbeddedThumbnailMissing)
        
        XCTAssertThrowsError(try loader.loadImageMetadataIfNeeded())
        XCTAssertThrowsError(try loader.loadImageMetadataIfNeeded(forceReload: true))
    }

    func testFailingThumbnailThrowsError() {
        guard let url = Bundle.module.url(forResource: "hdrmerge-bayer-fp16-w-pred-deflate_", withExtension: "dng") else {
            XCTAssert(false)
            return
        }
        
        let loader = ImageLoader(imageURL: url, thumbnailScheme: .decodeFullImageIfEmbeddedThumbnailMissing)
        XCTAssertThrowsError(try loader.loadBitmapImage(maximumPixelDimensions: nil, colorSpace: nil, allowCropping: true, cancelled: nil))
    }

    func testDictionaryRepresentation() {
        guard let url = Bundle.module.url(forResource: "iphone5", withExtension: "jpg") else {
            XCTAssert(false)
            return
        }
        
        let loader = ImageLoader(imageURL: url, thumbnailScheme: .decodeFullImageIfEmbeddedThumbnailMissing)
        let imageMetadata = try! loader.loadImageMetadata()
        let dictRep = imageMetadata.dictionaryRepresentation
        XCTAssertEqual(imageMetadata.cameraMaker, dictRep[ImageMetadata.CodingKeys.cameraMaker.dictionaryRepresentationKey] as! String?)
        XCTAssertEqual(imageMetadata.cameraModel, dictRep[ImageMetadata.CodingKeys.cameraModel.dictionaryRepresentationKey] as! String?)

        let nativeSizeArray = dictRep[ImageMetadata.CodingKeys.nativeSize.dictionaryRepresentationKey]! as! [CGFloat]
        XCTAssertEqual(imageMetadata.nativeSize.width, nativeSizeArray[0])
        XCTAssertEqual(imageMetadata.nativeSize.height, nativeSizeArray[1])
        XCTAssertEqual(imageMetadata.shape.rawValue, dictRep["shape"] as! String)
        XCTAssertEqual(imageMetadata.focalLength35mmEquivalent, (dictRep[ImageMetadata.CodingKeys.focalLength35mmEquivalent.dictionaryRepresentationKey] as! NSNumber).doubleValue)
        XCTAssertEqual(imageMetadata.iso, (dictRep[ImageMetadata.CodingKeys.iso.dictionaryRepresentationKey] as! NSNumber).doubleValue)
        XCTAssertEqual(imageMetadata.shutterSpeed, (dictRep[ImageMetadata.CodingKeys.shutterSpeed.dictionaryRepresentationKey] as! NSNumber).doubleValue)
        XCTAssertEqual(imageMetadata.focalLength, (dictRep[ImageMetadata.CodingKeys.focalLength.dictionaryRepresentationKey] as! NSNumber).doubleValue)
        XCTAssertEqual(
            imageMetadata.nativeOrientation.cgImageOrientation,
            CGImagePropertyOrientation(rawValue: (dictRep[ImageMetadata.CodingKeys.nativeOrientation.dictionaryRepresentationKey] as! NSNumber).uint32Value)
        )
        XCTAssertEqual(imageMetadata.fNumber, (dictRep[ImageMetadata.CodingKeys.fNumber.dictionaryRepresentationKey] as! NSNumber).doubleValue)
        XCTAssertEqual(imageMetadata.exposureCompensation, (dictRep[ImageMetadata.CodingKeys.exposureCompensation.dictionaryRepresentationKey] as! NSNumber).doubleValue)
        XCTAssertEqual(imageMetadata.flashMode, dictRep[ImageMetadata.CodingKeys.flashMode.dictionaryRepresentationKey] as! FlashMode)
        XCTAssertEqual(imageMetadata.lensMaker, dictRep[ImageMetadata.CodingKeys.lensMaker.dictionaryRepresentationKey] as! String)
        XCTAssertEqual(imageMetadata.lensModel, dictRep[ImageMetadata.CodingKeys.lensModel.dictionaryRepresentationKey] as! String)
        XCTAssertEqual(imageMetadata.meteringMode, dictRep[ImageMetadata.CodingKeys.meteringMode.dictionaryRepresentationKey] as! MeteringMode)
        XCTAssertEqual(imageMetadata.whiteBalance, dictRep[ImageMetadata.CodingKeys.whiteBalance.dictionaryRepresentationKey] as! WhiteBalance)
        XCTAssertEqual(imageMetadata.timestamp?.timeIntervalSince1970, (dictRep[ImageMetadata.CodingKeys.timestamp.dictionaryRepresentationKey] as! NSNumber).doubleValue)

        let jsonEncoder = JSONEncoder()
        let jsonImageMetadata = try! jsonEncoder.encode(imageMetadata)

        let decodedImageMetadata = try! JSONDecoder().decode(ImageMetadata.self, from: jsonImageMetadata)
        XCTAssertEqual(imageMetadata.cameraMaker, decodedImageMetadata.cameraMaker)
        XCTAssertEqual(imageMetadata.cameraModel, decodedImageMetadata.cameraModel)
        XCTAssertEqual(imageMetadata.nativeSize, decodedImageMetadata.nativeSize)
        XCTAssertEqual(imageMetadata.shape, decodedImageMetadata.shape)
        XCTAssertEqual(imageMetadata.focalLength35mmEquivalent, decodedImageMetadata.focalLength35mmEquivalent)
        XCTAssertEqual(imageMetadata.iso, decodedImageMetadata.iso)
        XCTAssertEqual(imageMetadata.shutterSpeed!, decodedImageMetadata.shutterSpeed!, accuracy: 0.0001)
        XCTAssertEqual(imageMetadata.focalLength, decodedImageMetadata.focalLength)
        XCTAssertEqual(imageMetadata.exposureCompensation!, decodedImageMetadata.exposureCompensation!, accuracy: 0.0001)
        XCTAssertEqual(imageMetadata.flashMode, decodedImageMetadata.flashMode)
        XCTAssertEqual(imageMetadata.lensMaker, decodedImageMetadata.lensMaker)
        XCTAssertEqual(imageMetadata.lensModel, decodedImageMetadata.lensModel)
        XCTAssertEqual(imageMetadata.meteringMode, decodedImageMetadata.meteringMode)
        XCTAssertEqual(imageMetadata.whiteBalance, decodedImageMetadata.whiteBalance)
        XCTAssertEqual(imageMetadata.nativeOrientation, decodedImageMetadata.nativeOrientation)
        XCTAssertEqual(imageMetadata.timestamp, decodedImageMetadata.timestamp)
    }

    func testImageHashing() throws {
        // Mock up an Images and Words dictionary
        let originalURL1 = URL(fileURLWithPath: "/Users/erkki/Pictures/1.jpg")
        let image1 = Image(URL: originalURL1)
        let originalURL2 = URL(fileURLWithPath: "/Users/erkki/Pictures/2.jpg")
        let image2 = Image(URL: originalURL2)
        let originalURL3 = URL(fileURLWithPath: "/Users/erkki/Pictures/3.jpg")
        let image3 = Image(URL: originalURL3)

        let map = [image1: "cat", image2: "dog", image3: "walrus"]

        XCTAssertEqual(map[image1], "cat")
        XCTAssertEqual(map[image2], "dog")
        XCTAssertEqual(map[image3], "walrus")

        // Simulate moving images to a Keepers subdirectory
        let newURL1 = originalURL1.deletingLastPathComponent().appendingPathComponent("Keepers").appendingPathComponent(originalURL1.lastPathComponent)
        image1.updateURL(newURL1)
        let newURL2 = originalURL1.deletingLastPathComponent().appendingPathComponent("Keepers").appendingPathComponent(originalURL2.lastPathComponent)
        image2.updateURL(newURL2)
        let newURL3 = originalURL1.deletingLastPathComponent().appendingPathComponent("Keepers").appendingPathComponent(originalURL3.lastPathComponent)
        image3.updateURL(newURL3)

        XCTAssertEqual(map[image1], "cat")
        XCTAssertEqual(map[image2], "dog")
        XCTAssertEqual(map[image3], "walrus")
    }
}
