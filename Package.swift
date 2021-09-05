// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Carpaccio",
    platforms: [.macOS(.v10_15),
                .iOS(.v14)],
    products: [
        // Products define the executables and libraries produced by a package, and make them visible to other packages.
        .library(
            name: "Carpaccio",
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
        .target(name: "exifdump",
                dependencies: ["Carpaccio"]),
        .testTarget(
            name: "CarpaccioTests",
            dependencies: ["Carpaccio"],
            resources: [
                .process("ARW/DSC00583.ARW"),
                .process("ARW/DSC00588.ARW"),
                .process("ARW/DSC00593.ARW"),
                .process("DSC02856.jpg"),
                .process("iphone5.jpg"),
                .process("Pixls/DNS/hdrmerge-bayer-fp16-w-pred-deflate.dng"),
                .process("Pixls/X3F/DP2M1726.X3F"),
            ]
        ),
    ]
)

