// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "antlers",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "Antlers", targets: ["MafxApp"]),
        .library(name: "MafxCore", targets: ["MafxCore"])
    ],
    targets: [
        .executableTarget(
            name: "MafxApp",
            dependencies: ["MafxCore"]
        ),
        .target(name: "MafxCore"),
        .testTarget(
            name: "MafxCoreTests",
            dependencies: ["MafxCore"]
        ),
        .testTarget(
            name: "MafxAppTests",
            dependencies: ["MafxApp"]
        )
    ]
)
