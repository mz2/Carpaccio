//
//  main.swift
//  exifdump
//
//  Created by Matias Piipari on 15/01/2017.
//  Copyright © 2017 Matias Piipari & Co. All rights reserved.
//

import Foundation

if CommandLine.arguments.count < 2 {
    fputs("USAGE: carpaccio-dump <list of files to output EXIF metadata of>\n", stderr)
    exit(-1)
}

let metadata:[[String: Any]] = try CommandLine.arguments.dropFirst().map {
    let url = URL(fileURLWithPath: $0)
    let image = try Image(URL: url)
    
    return try image.fetchMetadata().dictionaryRepresentation
}

let jsonOutput = try! JSONSerialization.data(withJSONObject: metadata as NSArray, options: [])

puts(String(data:jsonOutput, encoding: .utf8))
