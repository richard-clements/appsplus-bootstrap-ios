// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

extension Target {
    static func target(
        name: String,
        sources: [String],
        resources: [Resource]? = nil,
        dependencies: [Target.Dependency] = []
    ) -> Target {
        .target(
            name: name,
            dependencies: dependencies,
            path: "Sources",
            exclude: [],
            sources: sources,
            resources: resources,
            publicHeadersPath: nil,
            cSettings: nil,
            cxxSettings: nil,
            swiftSettings: nil,
            linkerSettings: nil
        )
    }
}

extension Target {
    static func testTarget(
        name: String,
        sources: [String],
        resources: [Resource]? = nil,
        dependencies: [Target.Dependency] = []
    ) -> Target {
        .testTarget(
            name: name,
            dependencies: dependencies,
            path: "Tests",
            exclude: [],
            sources: sources,
            resources: resources,
            cSettings: nil,
            cxxSettings: nil,
            swiftSettings: nil,
            linkerSettings: nil
        )
    }
}

let package = Package(
    name: "AppsPlus",
    products: [
        .library(
            name: "AppsPlus",
            targets: ["AppsPlus"]
        ),
        .library(
            name: "AppsPlusData",
            targets: ["AppsPlusData"]
        ),
        .library(
            name: "AppsPlusUI",
            targets: ["AppsPlusUI"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/typelift/SwiftCheck", .exact("0.12.0"))
    ],
    targets: [
        .target(
            name: "AppsPlus",
            sources: ["AppsPlus"],
            dependencies: [
                "AppsPlusData",
                "AppsPlusUI"
            ]
        ),
        .target(
            name: "AppsPlusData",
            sources: ["Data"]
        ),
        .testTarget(
            name: "AppsPlusDataTests",
            sources: ["Data"],
            resources: [
                .copy("Resources")
            ],
            dependencies: ["AppsPlusData", "SwiftCheck"]
        ),
        .target(
            name: "AppsPlusUI",
            sources: ["UI"]
        )
    ]
)
