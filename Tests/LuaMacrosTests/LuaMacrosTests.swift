// Copyright (c) 2025 Tom Sutcliffe
// See LICENSE file for license information.

// Last tested with: Xcode Version 16.3 (16E140)

import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

import Lua
import LuaMacros
import LuaMacrosImpl

let testMacros: [String: Macro.Type] = [
    "Pushable": PushableMacro.self,
    "Lua": LuaAttributeMacro.self,
]

final class LuaSwiftMacrosTests: XCTestCase {

    func testLetProperty() throws {
        assertMacroExpansion(
            """
            @Pushable struct Foo {
                public let member: String
            }
            """,
            expandedSource: #"""
            struct Foo {
                public let member: String

                static var metatable: Metatable<Foo> {
                    .init(fields: [
                            "member": .property(\.member)
                        ])
                }
            }

            extension Foo: PushableWithMetatable {
            }
            """#,
            macros: testMacros)
    }

    func testVarProperty() throws {
        assertMacroExpansion(
            """
            @Pushable struct Foo {
                public var member: String
            }
            """,
            expandedSource: #"""
            struct Foo {
                public var member: String

                static var metatable: Metatable<Foo> {
                    .init(fields: [
                            "member": .property(\.member)
                        ])
                }
            }

            extension Foo: PushableWithMetatable {
            }
            """#,
            macros: testMacros)
    }

    func testBarewordProperty() throws {
        assertMacroExpansion(
            """
            @Pushable struct Foo {
                public var `public`: String
            }
            """,
            expandedSource: #"""
            struct Foo {
                public var `public`: String

                static var metatable: Metatable<Foo> {
                    .init(fields: [
                            "public": .property(\.public)
                        ])
                }
            }

            extension Foo: PushableWithMetatable {
            }
            """#,
            macros: testMacros)
    }

    func testGenericProperty() throws {
        assertMacroExpansion(
            """
            @Pushable struct Foo<T> {
                public var prop: T
            }
            """,
            expandedSource: #"""
            struct Foo<T> {
                public var prop: T

                static var metatable: Metatable<Foo> {
                    .init(fields: [
                            "prop": .property(\.prop)
                        ])
                }
            }

            extension Foo: PushableWithMetatable {
            }
            """#,
            macros: testMacros)
    }

    func testStaticLet() throws {
        assertMacroExpansion(
            """
            @Pushable struct Foo {
                public static let member = "woop"
            }
            """,
            expandedSource: #"""
            struct Foo {
                public static let member = "woop"

                static var metatable: Metatable<Foo> {
                    .init(fields: [
                            "member": .constant(Foo.member)
                        ])
                }
            }

            extension Foo: PushableWithMetatable {
            }
            """#,
            macros: testMacros)
    }

    func testStaticVar() throws {
        assertMacroExpansion(
            """
            @Pushable struct Foo {
                public static var member: String { "woop" }
            }
            """,
            expandedSource: #"""
            struct Foo {
                public static var member: String { "woop" }

                static var metatable: Metatable<Foo> {
                    .init(fields: [
                            "member": .staticvar {
                                    return Foo.member
                                }
                        ])
                }
            }

            extension Foo: PushableWithMetatable {
            }
            """#,
            macros: testMacros)
    }

    func testMemberFn() throws {
        assertMacroExpansion(
            """
            @Pushable struct Foo {
                public func noargs() -> Bool { return true }
                public func namedArg(arg: Int) { }
                public func anonArg(_ arg: String) -> String { return arg }
                public func mixedArgs(arg1: Int, _ arg2: Int, arg3: Int) { }
            }
            """,
            expandedSource: #"""
            struct Foo {
                public func noargs() -> Bool { return true }
                public func namedArg(arg: Int) { }
                public func anonArg(_ arg: String) -> String { return arg }
                public func mixedArgs(arg1: Int, _ arg2: Int, arg3: Int) { }

                static var metatable: Metatable<Foo> {
                    .init(fields: [
                            "noargs": .memberfn {
                                    $0.noargs()
                                },
                            "namedArg": .memberfn {
                                    $0.namedArg(arg: $1)
                                },
                            "anonArg": .memberfn {
                                    $0.anonArg($1)
                                },
                            "mixedArgs": .memberfn {
                                    $0.mixedArgs(arg1: $1, $2, arg3: $3)
                                }
                        ])
                }
            }

            extension Foo: PushableWithMetatable {
            }
            """#,
            macros: testMacros)
    }

    func testStaticFn() throws {
        assertMacroExpansion(
            """
            @Pushable struct Foo {
                public static func noargs() -> Bool { return true }
            }
            """,
            expandedSource: #"""
            struct Foo {
                public static func noargs() -> Bool { return true }

                static var metatable: Metatable<Foo> {
                    .init(fields: [
                            "noargs": .staticfn {
                                    Foo.noargs()
                                }
                        ])
                }
            }
            
            extension Foo: PushableWithMetatable {
            }
            """#,
            macros: testMacros)
    }

    func testEquatableAuto() throws {
        assertMacroExpansion(
            """
            @Pushable struct EqThing: Equatable {}
            """,
            expandedSource: #"""
            struct EqThing: Equatable {

                static var metatable: Metatable<EqThing> {
                    .init(fields: [:],
                        eq: .synthesize)
                }
            }

            extension EqThing: PushableWithMetatable {
            }
            """#,
            macros: testMacros)
    }

    func testEquatableNope() throws {
        assertMacroExpansion(
            """
            @Pushable
            struct NotEq: Equatable {
                private static var metafield_eq: Metatable<NotEq>.EqType { .none }
            }
            """,
            expandedSource: #"""
            struct NotEq: Equatable {
                private static var metafield_eq: Metatable<NotEq>.EqType { .none }

                static var metatable: Metatable<NotEq> {
                    .init(fields: [:],
                        eq: .none)
                }
            }

            extension NotEq: PushableWithMetatable {
            }
            """#,
            macros: testMacros)
    }

    func testHideDecls() throws {
        assertMacroExpansion(
            """
            @Pushable
            struct Foo {
                public var yep: String
                @Lua(false)
                public var nope: String
                public func yepFn() {}
                @Lua(false)
                public func nopeFn() {}
            }
            """,
            expandedSource: #"""
            struct Foo {
                public var yep: String
                public var nope: String
                public func yepFn() {}
                public func nopeFn() {}

                static var metatable: Metatable<Foo> {
                    .init(fields: [
                            "yep": .property(\.yep),
                            "yepFn": .memberfn {
                                    $0.yepFn()
                                }
                        ])
                }
            }
            
            extension Foo: PushableWithMetatable {
            }
            """#,
            macros: testMacros)
    }

    func testRenameDecls() throws {
        assertMacroExpansion(
            """
            @Pushable
            struct Foo {
                public var yep: String
                @Lua(name: "maybe")
                private var nope: String
                public func yepFn() {}
                @Lua(name: "maybeFn")
                private func nopeFn() {}
            }
            """,
            expandedSource: #"""
            struct Foo {
                public var yep: String
                private var nope: String
                public func yepFn() {}
                private func nopeFn() {}

                static var metatable: Metatable<Foo> {
                    .init(fields: [
                            "yep": .property(\.yep),
                            "maybe": .property(\.nope),
                            "yepFn": .memberfn {
                                    $0.yepFn()
                                },
                            "maybeFn": .memberfn {
                                    $0.nopeFn()
                                }
                        ])
                }
            }
            
            extension Foo: PushableWithMetatable {
            }
            """#,
            macros: testMacros)
    }
}
