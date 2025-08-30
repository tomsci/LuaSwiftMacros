// swift-tools-version: 6.1

import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "LuaSwiftMacros",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6), .macCatalyst(.v13)],
    products: [
        .library(
            name: "LuaSwiftMacros",
            targets: ["LuaMacros"]
        ),
        .executable(
            name: "ClientTest",
            targets: ["ClientTest"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/tomsci/LuaSwift.git", branch: "main"),
        // .package(path: "LuaSwift"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "601.0.0-latest"),
    ],
    targets: [
        .macro(
            name: "LuaMacrosImpl",
            dependencies: [
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax")
            ]
        ),

        .target(
            name: "LuaMacros",
            dependencies: [
                "LuaMacrosImpl",
                .product(name: "Lua", package: "LuaSwift")
            ]
        ),

        // Standalone test target, used for prototyping
        .executableTarget(name: "ClientTest", dependencies: ["LuaMacros"]),

        .testTarget(
            name: "LuaMacrosTests",
            dependencies: [
                "LuaMacrosImpl",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
                .product(name: "Lua", package: "LuaSwift")
            ]
        ),
    ]
)
