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
        let img1URL = Bundle(for: type(of: self)).url(forResource:"DSC00583", withExtension: "ARW")!

        let tempDir = URL(fileURLWithPath:NSTemporaryDirectory() + "/\(UUID().uuidString)")
        
        try! FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: [:])
        
        let converter = RAWImageLoader(imageURL: img1URL, thumbnailScheme: .fullImageWhenThumbnailMissing)
        
        converter.loadThumbnailImage(handler: { thumb, imageMetadata in
            XCTAssert(thumb.size.width > 1615 && thumb.size.width < 1617, "Unexpected thumbnail width: \(thumb.size.width)")
            XCTAssert(thumb.size.width > 1079 && thumb.size.height < 1081, "Unexpected thumbnail height: \(thumb.size.height)")
        }) { err in
            XCTFail("Error: \(err)")
        }
        
        try! FileManager.default.removeItem(at: tempDir)
    }
    
    func testDistanceMatrixComputation() {
        let resourcesDir = Bundle(for: type(of: self)).resourceURL!
        let imgColl = try! Collection(contentsOfURL: resourcesDir)
        
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
        let resourcesDir = Bundle(for: type(of: self)).resourceURL!
        let imgColl = try! Collection(contentsOfURL: resourcesDir)
        
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
    
}
