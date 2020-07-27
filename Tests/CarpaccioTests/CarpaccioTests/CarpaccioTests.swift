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
        let img1URL = Bundle.module.url(forResource:"DSC00583", withExtension: "ARW")!
        
        let tempDir = URL(fileURLWithPath:NSTemporaryDirectory() + "/\(UUID().uuidString)")
        
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: [:])
        
        let converter = ImageLoader(imageURL: img1URL, thumbnailScheme: .fullImageIfThumbnailMissing, colorSpace: nil)
        
        let (thumb, imageMetadata) = try! converter.loadThumbnailImage(maximumPixelDimensions: nil, allowCropping: true, cancelled: nil)
        
        XCTAssertEqual(thumb.size.width, 1616)
        XCTAssertEqual(thumb.size.height, 1080)
        
        XCTAssertEqual(imageMetadata.cameraMaker, "SONY")
        XCTAssertEqual(imageMetadata.cameraModel, "ILCE-7RM2")
        XCTAssertEqual(imageMetadata.iso, 125.0)
        XCTAssertEqual(imageMetadata.nativeSize.width, 7952.0)
        XCTAssertEqual(imageMetadata.nativeSize.height, 5304.0)
        
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
        
        let converter = ImageLoader(imageURL: img1URL, thumbnailScheme: .fullImageIfThumbnailMissing, colorSpace: nil)
        
        let (image, imageMetadata) = try! converter.loadFullSizeImage()
        
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
        guard let url = Bundle.module.url(forResource: "DP2M1726", withExtension: "X3F") else {
            XCTAssert(false)
            return
        }
        
        let loader = ImageLoader(imageURL: url, thumbnailScheme: .fullImageIfThumbnailMissing, colorSpace: nil)
        
        XCTAssertThrowsError(try loader.loadImageMetadataIfNeeded())
        XCTAssertThrowsError(try loader.loadImageMetadataIfNeeded(forceReload: true))
    }
    
    func testFailingThumbnailThrowsError() {
        guard let url = Bundle.module.url(forResource: "hdrmerge-bayer-fp16-w-pred-deflate", withExtension: "dng") else {
            XCTAssert(false)
            return
        }
        
        let loader = ImageLoader(imageURL: url, thumbnailScheme: .fullImageIfThumbnailMissing, colorSpace: nil)
        XCTAssertThrowsError(try loader.loadThumbnailImage(maximumPixelDimensions: nil, allowCropping: true, cancelled: nil))
    }

    func testDictionaryRepresentation() {
        guard let url = Bundle.module.url(forResource: "iphone5", withExtension: "jpg") else {
            XCTAssert(false)
            return
        }
        
        let loader = ImageLoader(imageURL: url, thumbnailScheme: .fullImageIfThumbnailMissing, colorSpace: nil)
        let imageMetadata = try! loader.loadImageMetadata()
        let dictRep = imageMetadata.dictionaryRepresentation
        XCTAssertEqual(imageMetadata.cameraMaker, dictRep["cameraMaker"] as! String?)
        XCTAssertEqual(imageMetadata.cameraModel, dictRep["cameraModel"] as! String?)

        let nativeSizeArray = dictRep["nativeSize"]! as! [CGFloat]
        XCTAssertEqual(imageMetadata.nativeSize.width, nativeSizeArray[0])
        XCTAssertEqual(imageMetadata.nativeSize.height, nativeSizeArray[1])
        XCTAssertEqual(imageMetadata.shape.rawValue, dictRep["shape"] as! String)
        XCTAssertEqual(imageMetadata.focalLength35mmEquivalent, (dictRep["focalLength35mmEquivalent"] as! NSNumber).doubleValue)
        XCTAssertEqual(imageMetadata.iso, (dictRep["ISO"] as! NSNumber).doubleValue)
        XCTAssertEqual(imageMetadata.shutterSpeed, (dictRep["shutterSpeed"] as! NSNumber).doubleValue)
        XCTAssertEqual(imageMetadata.focalLength, (dictRep["focalLength"] as! NSNumber).doubleValue)
        XCTAssertEqual(imageMetadata.nativeOrientation.rawValue, (dictRep["nativeOrientation"] as! NSNumber).uint32Value)
        XCTAssertEqual(imageMetadata.fNumber, (dictRep["fNumber"] as! NSNumber).doubleValue)
        XCTAssertEqual(imageMetadata.timestamp?.timeIntervalSince1970, (dictRep["timestamp"] as! NSNumber).doubleValue)

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
        XCTAssertEqual(imageMetadata.nativeOrientation, decodedImageMetadata.nativeOrientation)
        XCTAssertEqual(imageMetadata.timestamp, decodedImageMetadata.timestamp)
    }
}
