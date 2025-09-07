# ``LuaMacros``

Adds macros to LuaSwift.

## Overview

These macros are intended to automate the boilerplate required to make a type
[Bridgeable into Lua](https://tomsci.github.io/LuaSwift/documentation/lua/bridgingswifttolua#Defining-a-metatable).
The [`@Pushable`](doc:Pushable()) macro adds conformance to
[`PushableWithMetatable`](https://tomsci.github.io/LuaSwift/documentation/lua/pushablewithmetatable).


To include in your project, use a Package.swift file something like this:

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "ExampleLuaSwiftProj",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
        .package(url: "https://github.com/tomsci/LuaSwift.git", branch: "main"),
        .package(url: "https://github.com/tomsci/LuaSwiftMacros.git", branch: "main"),
    ],
    targets: [
        .executableTarget(
            name: "ExampleLuaSwiftProj",
            dependencies: [
                .product(name: "Lua", package: "LuaSwift"),
                .product(name: "LuaMacros", package: "LuaSwiftMacros"),
            ]
        )
    ]
)
```

The project is hosted here: <https://github.com/tomsci/LuaSwiftMacros>.

## Usage

See [`@Pushable`](doc:Pushable()).
