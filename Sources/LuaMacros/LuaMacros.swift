// Copyright (c) 2025 Tom Sutcliffe
// See LICENSE file for license information.

import Lua

/// A macro that declares a struct or class to conform to `PushableWithMetatable`, and generates a metatable for it.
///
/// The generated metatable will by default include all public properties and member functions defined on the type.
/// Use [`@Lua`](doc:Lua(_:name:)) to control individual symbols' visibility.
///
/// For example:
///
/// ```swift
/// import Lua
/// import LuaMacros
///
/// @Pushable
/// class Foo {
///     public var bar = "baz"
///     public func hello() -> String {
///         return "world"
///     }
/// }
/// ```
@attached(member, names: named(metatable))
@attached(extension, conformances: PushableWithMetatable)
public macro Pushable() = #externalMacro(module: "LuaMacrosImpl", type: "PushableMacro")


/// A macro that generates a metatable for a class whose parent conforms to `PushableWithMetatable`.
///
/// This is similar to ``Pushable()`` but specifically for subclasses. The `Parent` class type parameter should be the
/// type of the superclass with the metatable. For example:
///
/// ```swift
/// @Pushable
/// class BaseClass {
///     public func test() -> String {
///         return "Base"
///     }
/// }
/// 
/// @PushableSubclass<BaseClass>
/// class DerivedClass: BaseClass {
///     override func test() -> String {
///         return "Derived"
///     }
/// 
///     public func derivedfn() {}
/// }
/// ```
///
/// The macro assumes that `Parent` has a `metatable` that was added by `@Pushable` or `@PushableSubclass`. Unlike
/// `@Pushable`, it does not add an extension with conformance to `PushableWithMetatable` (because the superclass should
/// already have done that).
@attached(member, names: named(metatable))
public macro PushableSubclass<Parent>() = #externalMacro(module: "LuaMacrosImpl", type: "PushableMacro")

/// A macro that can hide or rename a symbol from being bridged in a metatable.
///
/// Specify `@Lua(false)` to prevent a property or function from being included in the metatable created by
/// `@Pushable`.
///
/// Specify `@Lua` or `@Lua(true)` to add a property or function to the metatable when it otherwise wouldn't be (for
/// example because it is `private`).
///
/// Specify `@Lua(name: "newname")` to cause `@Pushable` to use `newname` as the Lua-side name for the property or
/// function. For example:
///
/// ```swift
/// @Pushable
/// class Foo {
///     @Lua(name: "helloWorld")
///     public func hello_world() {
///         print("Hello!")
///     }
/// }
/// ```
///
/// Outside of a struct/class decorated with `@Pushable`, the `@Lua` macro has no effect.
@attached(peer, names: arbitrary)
public macro Lua(_ visible: Bool = true, name: String? = nil)
    = #externalMacro(module: "LuaMacrosImpl", type: "LuaAttributeMacro")
