// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "sms_autodetect",
    platforms: [
        .iOS("12.0")
    ],
    products: [
        .library(name: "sms-autodetect", targets: ["sms_autodetect"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "sms_autodetect",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            cSettings: [
                .headerSearchPath("include/sms_autodetect")
            ]
        )
    ]
)
