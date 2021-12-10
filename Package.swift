// swift-tools-version:5.5
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Carpaccio",
    platforms: [
        .macOS(.v10_15),
        .iOS(.v14)
    ],
    products: [
        .library(
            name: "Carpaccio",
            // supposedly making an .xcframework only works if this is made dynamic?
            // didn't work with 12.5.1 anyway, so leaving as static.
            type: .static,
            targets: ["Carpaccio"]
        ),
        .executable(name: "exifdump", targets: ["exifdump"])
    ],
    dependencies: [
        // Dependencies declare other packages that this package depends on.
        // .package(url: /* package url */, from: "1.0.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package. A target can define a module or a test suite.
        // Targets can depend on other targets in this package, and on products in packages which this package depends on.
        .target(
            name: "Carpaccio",
            dependencies: []
        ),
        .executableTarget(name: "exifdump",
                dependencies: ["Carpaccio"]),
        .testTarget(
            name: "CarpaccioTests",
            dependencies: ["Carpaccio"],
            resources: [
                .process("ARW/DSC00583_.ARW"),
                .process("ARW/DSC00588_.ARW"),
                .process("ARW/DSC00593_.ARW"),
                .process("DSC02856.jpg"),
                .process("iphone5.jpg"),
                .process("Pixls/DNG/hdrmerge-bayer-fp16-w-pred-deflate_.dng"),
                .process("Pixls/X3F/DP2M1726_.X3F"),
                .process("outline-invert_2x.png")
            ]
        ),
    ]
)

