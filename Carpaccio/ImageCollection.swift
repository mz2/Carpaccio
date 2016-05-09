//
//  ImageCollection.swift
//  Trimmer
//
//  Created by Matias Piipari on 07/05/2016.
//  Copyright © 2016 Matias Piipari & Co. All rights reserved.
//

import Foundation

public struct ImageCollection {
    public let name:String
    public let images:[Image]
    public let URL:NSURL
    
    public init(contentsOfURL URL:NSURL) throws {
        self.URL = URL
        self.name = URL.lastPathComponent ?? "Untitled"
        self.images = try Image.images(contentsOfURL: URL)
    }
}