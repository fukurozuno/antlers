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
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0")
    ],
    targets: [
        .executableTarget(
            name: "MafxApp",
            dependencies: ["MafxCore"]
        ),
        .target(
            name: "MafxCore",
            dependencies: ["ZIPFoundation"]
        ),
        .testTarget(
            name: "MafxCoreTests",
            dependencies: ["MafxCore", "ZIPFoundation"]
        ),
        .testTarget(
            name: "MafxAppTests",
            dependencies: ["MafxApp"]
        )
    ]
)
